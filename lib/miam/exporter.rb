class Miam::Exporter
  def self.export(iam, options = {})
    self.new(iam, options).export
  end

  def initialize(iam, options = {})
    @iam = iam
    @options = options
  end

  def export
    {
      :users => export_users,
      :groups => export_groups,
    }
  end

  private

  def export_users
    result = {}

    @iam.list_users.each do |resp|
      resp.users.each do |user|
        user_name = user.user_name

        result[user_name] = {
          :path => user.path,
          :groups => export_user_groups(user_name),
          :policies => export_user_policies(user_name),
        }

        login_profile = export_login_profile(user_name)

        if login_profile
          result[user_name][:login_profile] = login_profile
        end
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

  def export_groups
    result = {}

    @iam.list_groups.each do |resp|
      resp.groups.each do |group|
        group_name = group.group_name

        result[group_name] = {
          :path => group.path,
          :policies => export_group_policies(group_name),
        }
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
end
