# coding: utf-8
class Miam::Exporter
  AWS_MANAGED_POLICY_PREFIX = 'arn:aws:iam::aws:'
  AWS_CN_MANAGED_POLICY_PREFIX = 'arn:aws-cn:iam::aws:'

  def self.export(iam, options = {})
    self.new(iam, options).export
  end

  def initialize(iam, options = {})
    @iam = iam
    @options = options
    @mutex = Mutex.new
    @concurrency = options[:export_concurrency] || 16
  end

  def export
    account_authorization_details = get_account_authorization_details

    users = account_authorization_details[:user_detail_list]
    groups = account_authorization_details[:group_detail_list]
    roles = account_authorization_details[:role_detail_list]
    policies = account_authorization_details[:policies]
    instance_profiles = list_instance_profiles
    group_users = {}
    instance_profile_roles = {}

    unless @options[:no_progress]
      progress_total = users.length + groups.length + roles.length + instance_profiles.length

      @progressbar = ProgressBar.create(
                       :format => ' %bᗧ%i %p%%',
                       :progress_mark  => ' ',
                       :remainder_mark => '･',
                       :total => progress_total,
                       :output => $stderr)
    end

    expected = {
      :users => export_users(users, group_users),
      :groups => export_groups(groups),
      :roles => export_roles(roles, instance_profile_roles),
      :instance_profiles => export_instance_profiles(instance_profiles),
      :policies => export_policies(policies),
    }

    [expected, group_users, instance_profile_roles]
  end

  private

  def export_users(users, group_users)
    result = {}

    Parallel.each(users, :in_threads => @concurrency) do |user|
      user_name = user.user_name
      groups = user.group_list
      policies = export_user_policies(user)
      login_profile = export_login_profile(user_name)
      access_key = export_access_key(user_name)
      attached_managed_policies = user.attached_managed_policies.map(&:policy_arn)

      @mutex.synchronize do
        groups.each do |group_name|
          group_users[group_name] ||= []
          group_users[group_name] << user_name
        end

        result[user_name] = {
          :path => user.path,
          :groups => groups,
          :policies => policies,
          :attached_managed_policies => attached_managed_policies
        }

        if login_profile
          result[user_name][:login_profile] = login_profile
        end

        if access_key.present?
          result[user_name][:access_key] = {
            :access_key_id => access_key,
            :access_key_prohibited => false
          }
        else
          result[user_name][:access_key] = {
            :access_key_id => [],
          }
        end

        progress
      end
    end

    result
  end

  def export_user_policies(user)
    result = {}

    user.user_policy_list.each do |policy|
      document = CGI.unescape(policy.policy_document)
      result[policy.policy_name] = JSON.parse(document)
    end

    result
  end

  def export_login_profile(user_name)
    begin
      resp = @iam.get_login_profile(:user_name => user_name)
      {:password_reset_required => resp.login_profile.password_reset_required}
    rescue Aws::IAM::Errors::NoSuchEntity
      nil
    end
  end

  def export_access_key(user_name)
    begin
      resp = @iam.list_access_keys(:user_name => user_name)
      resp.access_key_metadata.map do |i|
        i[:access_key_id]
      end
    rescue Aws::IAM::Errors::NoSuchEntity
      nil
    end
  end

  def export_groups(groups)
    result = {}

    Parallel.each(groups, :in_threads => @concurrency) do |group|
      group_name = group.group_name
      policies = export_group_policies(group)
      attached_managed_policies = group.attached_managed_policies.map(&:policy_arn)

      @mutex.synchronize do
        result[group_name] = {
          :path => group.path,
          :policies => policies,
          :attached_managed_policies => attached_managed_policies,
        }

        progress
      end
    end

    result
  end

  def export_group_policies(group)
    result = {}

    group.group_policy_list.each do |policy|
      document = CGI.unescape(policy.policy_document)
      result[policy.policy_name] = JSON.parse(document)
    end

    result
  end

  def export_roles(roles, instance_profile_roles)
    result = {}

    Parallel.each(roles, :in_threads => @concurrency) do |role|
      role_name = role.role_name
      instance_profiles = role.instance_profile_list.map {|i| i.instance_profile_name }
      policies = export_role_policies(role)
      attached_managed_policies = role.attached_managed_policies.map(&:policy_arn)
      role_data = @iam.get_role(role_name: role_name).role
      max_session_duration = role_data.max_session_duration

      @mutex.synchronize do
        instance_profiles.each do |instance_profile_name|
          instance_profile_roles[instance_profile_name] ||= []
          instance_profile_roles[instance_profile_name] << role_name
        end

        document = CGI.unescape(role.assume_role_policy_document)

        result[role_name] = {
          :path => role.path,
          :assume_role_policy_document => JSON.parse(document),
          :instance_profiles => instance_profiles,
          :policies => policies,
          :attached_managed_policies => attached_managed_policies,
          :max_session_duration => max_session_duration,
        }

        progress
      end
    end

    result
  end

  def export_role_policies(role)
    result = {}

    role.role_policy_list.each do |policy|
      document = CGI.unescape(policy.policy_document)
      result[policy.policy_name] = JSON.parse(document)
    end

    result
  end

  def export_instance_profiles(instance_profiles)
    result = {}

    Parallel.each(instance_profiles, :in_threads => @concurrency) do |instance_profile|
      instance_profile_name = instance_profile.instance_profile_name

      @mutex.synchronize do
        result[instance_profile_name] = {
          :path => instance_profile.path,
        }

        progress
      end
    end

    result
  end

  def export_policies(policies)
    result = {}

    Parallel.each(policies, :in_threads => @concurrency) do |policy|
      if policy.arn.start_with?(AWS_MANAGED_POLICY_PREFIX) or policy.arn.start_with?(AWS_CN_MANAGED_POLICY_PREFIX)
        next
      end

      policy_name = policy.policy_name
      document = export_policy_document(policy)

      result[policy_name] = {
        :path => policy.path,
        :document => document,
      }
    end

    result
  end

  def export_policy_document(policy)
    policy_version = nil

    policy_version_list = policy.policy_version_list.sort_by do |pv|
      pv.version_id[1..-1].to_i
    end

    policy_version_list.each do |pv|
      policy_version = pv

      if pv.is_default_version
        break
      end
    end

    document = CGI.unescape(policy_version.document)
    JSON.parse(document)
  end

  def list_instance_profiles
    @iam.list_instance_profiles.map {|resp|
      resp.instance_profiles.to_a
    }.flatten
  end

  def get_account_authorization_details
    account_authorization_details = {}

    unless @options[:no_progress]
      progressbar = ProgressBar.create(:title => 'Loading', :total => nil, :output => $stderr)
    end

    keys = [
      :user_detail_list,
      :group_detail_list,
      :role_detail_list,
      :policies,
    ]

    keys.each do |key|
      account_authorization_details[key] = []
    end

    @iam.get_account_authorization_details.each do |resp|
      keys.each do |key|
        account_authorization_details[key].concat(resp[key])
      end

      unless @options[:no_progress]
        progressbar.increment
      end
    end

    account_authorization_details
  end

  def progress
    @progressbar.increment if @progressbar
  end
end
