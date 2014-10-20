class Miam::Exporter
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
    users = list_users
    groups = list_groups
    roles = list_roles
    instance_profiles = list_instance_profiles
    group_users = {}
    instance_profile_roles = {}

    unless @options[:no_progress]
      progress_total = users.length + groups.length + roles.length + instance_profiles.length
      @progressbar = ProgressBar.create(:title => "Loading", :total => progress_total, :output => $stderr)
    end

    expected = {
      :users => export_users(users, group_users),
      :groups => export_groups(groups),
      :roles => export_roles(roles, instance_profile_roles),
      :instance_profiles => export_instance_profiles(instance_profiles),
    }

    [expected, group_users, instance_profile_roles]
  end

  private

  def export_users(users, group_users)
    result = {}

    Parallel.each(users, :in_threads => @concurrency) do |user|
      user_name = user.user_name
      groups = export_user_groups(user_name)
      policies = export_user_policies(user_name)
      login_profile = export_login_profile(user_name)

      @mutex.synchronize do
        groups.each do |group_name|
          group_users[group_name] ||= []
          group_users[group_name] << user_name
        end

        result[user_name] = {
          :path => user.path,
          :groups => groups,
          :policies => policies,
        }

        if login_profile
          result[user_name][:login_profile] = login_profile
        end

        progress
      end
    end

    result
  end

  def export_user_groups(user_name)
    @iam.list_groups_for_user(:user_name => user_name).map {|resp|
      resp.groups.map do |group|
        group.group_name
      end
    }.flatten
  end

  def export_user_policies(user_name)
    result = {}

    @iam.list_user_policies(:user_name => user_name).each do |resp|
      resp.policy_names.map do |policy_name|
        policy = @iam.get_user_policy(:user_name => user_name, :policy_name => policy_name)
        document = CGI.unescape(policy.policy_document)
        result[policy_name] = JSON.parse(document)
      end
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

  def export_groups(groups)
    result = {}

    Parallel.each(groups, :in_threads => @concurrency) do |group|
      group_name = group.group_name
      policies = export_group_policies(group_name)

      @mutex.synchronize do
        result[group_name] = {
          :path => group.path,
          :policies => policies,
        }

        progress
      end
    end

    result
  end

  def export_group_policies(group_name)
    result = {}

    @iam.list_group_policies(:group_name => group_name).each do |resp|
      resp.policy_names.map do |policy_name|
        policy = @iam.get_group_policy(:group_name => group_name, :policy_name => policy_name)
        document = CGI.unescape(policy.policy_document)
        result[policy_name] = JSON.parse(document)
      end
    end

    result
  end

  def export_roles(roles, instance_profile_roles)
    result = {}

    Parallel.each(roles, :in_threads => @concurrency) do |role|
      role_name = role.role_name
      instance_profiles = export_role_instance_profiles(role_name)
      policies = export_role_policies(role_name)

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
        }

        progress
      end
    end

    result
  end

  def export_role_instance_profiles(role_name)
    @iam.list_instance_profiles_for_role(:role_name => role_name).map {|resp|
      resp.instance_profiles.map do |instance_profile|
        instance_profile.instance_profile_name
      end
    }.flatten
  end

  def export_role_policies(role_name)
    result = {}

    @iam.list_role_policies(:role_name => role_name).each do |resp|
      resp.policy_names.map do |policy_name|
        policy = @iam.get_role_policy(:role_name => role_name, :policy_name => policy_name)
        document = CGI.unescape(policy.policy_document)
        result[policy_name] = JSON.parse(document)
      end
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

  def export_role_instance_profiles(role_name)
    @iam.list_instance_profiles_for_role(:role_name => role_name).map {|resp|
      resp.instance_profiles.map do |instance_profile|
        instance_profile.instance_profile_name
      end
    }.flatten
  end

  def list_users
    @iam.list_users.map {|resp|
      resp.users.to_a
    }.flatten
  end

  def list_groups
    @iam.list_groups.map {|resp|
      resp.groups.to_a
    }.flatten
  end

  def list_roles
    @iam.list_roles.map {|resp|
      resp.roles.to_a
    }.flatten
  end

  def list_instance_profiles
    @iam.list_instance_profiles.map {|resp|
      resp.instance_profiles.to_a
    }.flatten
  end

  def progress
    @progressbar.increment if @progressbar
  end
end
