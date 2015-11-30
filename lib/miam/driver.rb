class Miam::Driver
  include Miam::Logger::Helper

  MAX_POLICY_SIZE = 2048

  def initialize(iam, options = {})
    @iam = iam
    @options = options
  end

  def create_user(user_name, attrs)
    log(:info, "Create User `#{user_name}`", :color => :cyan)

    unless_dry_run do
      params = {:user_name => user_name}
      params[:path] = attrs[:path] if attrs[:path]
      @iam.create_user(params)
    end

    new_user_attrs = {:groups => [], :policies => {}, :attached_managed_policies => []}
    new_user_attrs[:path] = attrs[:path] if attrs[:path]
    new_user_attrs
  end

  def create_access_key(user_name)
    log(:info, "Create access key for User `#{user_name}`", :color => :cyan)
    access_key = nil

    unless_dry_run do
      resp = @iam.create_access_key(:user_name => user_name)

      access_key = {
        :access_key_id => resp.access_key.access_key_id,
        :secret_access_key => resp.access_key.secret_access_key,
      }
    end

    access_key
  end

  def delete_user(user_name, attrs)
    log(:info, "Delete User `#{user_name}`", :color => :red)

    unless_dry_run do
      if attrs[:login_profile]
        @iam.delete_login_profile(:user_name => user_name)
      end

      attrs[:policies].keys.each do |policy_name|
        @iam.delete_user_policy(:user_name => user_name, :policy_name => policy_name)
      end

      attrs[:groups].each do |group_name|
        @iam.remove_user_from_group(:group_name => group_name, :user_name => user_name)
      end

      attrs[:attached_managed_policies].each do |policy_arn|
        @iam.detach_user_policy(:user_name => user_name, :policy_arn => policy_arn)
      end

      list_access_key_ids(user_name).each do |access_key_id|
        @iam.delete_access_key(:user_name => user_name, :access_key_id => access_key_id)
      end

      list_signing_certificate_ids(user_name).each do |certificate_id|
        @iam.delete_signing_certificate(:user_name => user_name, :certificate_id => certificate_id)
      end

      @iam.delete_user(:user_name => user_name)
    end
  end

  def create_login_profile(user_name, attrs)
    log_attrs = attrs.dup
    log_attrs.delete(:password)

    log(:info, "Update User `#{user_name}`", :color => :green)
    log(:info, "  create login profile: #{log_attrs.inspect}", :color => :green)

    unless_dry_run do
      @iam.create_login_profile(attrs.merge(:user_name => user_name))
    end
  end

  def delete_login_profile(user_name)
    log(:info, "Update User `#{user_name}`", :color => :green)
    log(:info, "  delete login profile", :color => :green)

    unless_dry_run do
      @iam.delete_login_profile(:user_name => user_name)
    end
  end

  def update_login_profile(user_name, attrs, old_attrs)
    log_attrs = attrs.dup
    log_attrs.delete(:password)

    log(:info, "Update User `#{user_name}`", :color => :green)
    log(:info, "  login profile:\n".green + Miam::Utils.diff(old_attrs, attrs, :color => @options[:color], :indent => '    '), :color => false)

    unless_dry_run do
      @iam.update_login_profile(attrs.merge(:user_name => user_name))
    end
  end

  def add_user_to_groups(user_name, group_names)
    log(:info, "Update User `#{user_name}`", :color => :green)
    log(:info, "  add groups=#{group_names.join(',')}", :color => :green)

    unless_dry_run do
      group_names.each do |group_name|
        @iam.add_user_to_group(:group_name => group_name, :user_name => user_name)
      end
    end
  end

  def remove_user_from_groups(user_name, group_names)
    log(:info, "Update User `#{user_name}`", :color => :green)
    log(:info, "  remove groups=#{group_names.join(',')}", :color => :green)

    unless_dry_run do
      group_names.each do |group_name|
        @iam.remove_user_from_group(:group_name => group_name, :user_name => user_name)
      end
    end
  end

  def create_group(group_name, attrs)
    log(:info, "Create Group `#{group_name}`", :color => :cyan)

    unless_dry_run do
      params = {:group_name => group_name}
      params[:path] = attrs[:path] if attrs[:path]
      @iam.create_group(params)
    end

    new_group_attrs = {:policies => {}, :attached_managed_policies => []}
    new_group_attrs[:path] = attrs[:path] if attrs[:path]
    new_group_attrs
  end

  def delete_group(group_name, attrs, users_in_group)
    log(:info, "Delete Group `#{group_name}`", :color => :red)

    unless_dry_run do
      attrs[:policies].keys.each do |policy_name|
        @iam.delete_group_policy(:group_name => group_name, :policy_name => policy_name)
      end

      users_in_group.each do |user_name|
        @iam.remove_user_from_group(:group_name => group_name, :user_name => user_name)
      end

      attrs[:attached_managed_policies].each do |policy_arn|
        @iam.detach_group_policy(:group_name => group_name, :policy_arn => policy_arn)
      end

      @iam.delete_group(:group_name => group_name)
    end
  end

  def create_role(role_name, attrs)
    log(:info, "Create Role `#{role_name}`", :color => :cyan)
    assume_role_policy_document = attrs.fetch(:assume_role_policy_document)

    unless_dry_run do
      params = {
        :role_name => role_name,
        :assume_role_policy_document => encode_document(assume_role_policy_document),
      }

      params[:path] = attrs[:path] if attrs[:path]
      @iam.create_role(params)
    end

    new_role_attrs = {
      :instance_profiles => [],
      :assume_role_policy_document => assume_role_policy_document,
      :policies => {},
      :attached_managed_policies => [],
    }

    new_role_attrs[:path] = attrs[:path] if attrs[:path]
    new_role_attrs
  end

  def delete_role(role_name, instance_profile_names, attrs)
    log(:info, "Delete Role `#{role_name}`", :color => :red)

    unless_dry_run do
      attrs[:policies].keys.each do |policy_name|
        @iam.delete_role_policy(:role_name => role_name, :policy_name => policy_name)
      end

      instance_profile_names.each do |instance_profile_name|
        @iam.remove_role_from_instance_profile(:instance_profile_name => instance_profile_name, :role_name => role_name)
      end

      attrs[:attached_managed_policies].each do |policy_arn|
        @iam.detach_role_policy(:role_name => role_name, :policy_arn => policy_arn)
      end

      @iam.delete_role(:role_name => role_name)
    end
  end

  def add_role_to_instance_profiles(role_name, instance_profile_names)
    log(:info, "Update Role `#{role_name}`", :color => :green)
    log(:info, "  add instance_profiles=#{instance_profile_names.join(',')}", :color => :green)

    unless_dry_run do
      instance_profile_names.each do |instance_profile_name|
        @iam.add_role_to_instance_profile(:instance_profile_name => instance_profile_name, :role_name => role_name)
      end
    end
  end

  def remove_role_from_instance_profiles(role_name, instance_profile_names)
    log(:info, "Update Role `#{role_name}`", :color => :green)
    log(:info, "  remove instance_profiles=#{instance_profile_names.join(',')}", :color => :green)

    unless_dry_run do
      instance_profile_names.each do |instance_profile_name|
        @iam.remove_role_from_instance_profile(:instance_profile_name => instance_profile_name, :role_name => role_name)
      end
    end
  end

  def update_assume_role_policy(role_name, policy_document, old_policy_document)
    log(:info, "Update Role `#{role_name}` > AssumeRolePolicy", :color => :green)
    log(:info, Miam::Utils.diff(old_policy_document, policy_document, :color => @options[:color]), :color => false)

    unless_dry_run do
      @iam.update_assume_role_policy(
        :role_name => role_name,
        :policy_document => encode_document(policy_document),
      )
    end
  end

  def create_instance_profile(instance_profile_name, attrs)
    log(:info, "Create InstanceProfile `#{instance_profile_name}`", :color => :cyan)

    unless_dry_run do
      params = {:instance_profile_name => instance_profile_name}
      params[:path] = attrs[:path] if attrs[:path]
      @iam.create_instance_profile(params)
    end

    new_instance_profile_attrs = {}
    new_instance_profile_attrs[:path] = attrs[:path] if attrs[:path]
    new_instance_profile_attrs
  end

  def delete_instance_profile(instance_profile_name, attrs, roles_in_instance_profile)
    log(:info, "Delete InstanceProfile `#{instance_profile_name}`", :color => :red)

    unless_dry_run do
      roles_in_instance_profile.each do |role_name|
        @iam.remove_role_from_instance_profile(:instance_profile_name => instance_profile_name, :role_name => role_name)
      end

      @iam.delete_instance_profile(:instance_profile_name => instance_profile_name)
    end
  end

  def update_name(type, user_or_group_name, new_name)
    log(:info, "Update #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}`", :color => :green)
    log(:info, "  name:\n".green + Miam::Utils.diff(user_or_group_name, new_name, :color => @options[:color], :indent => '    '), :color => false)
    update_user_or_group(type, user_or_group_name, "new_#{type}_name".to_sym => new_name)
  end

  def update_path(type, user_or_group_name, new_path, old_path)
    log(:info, "Update #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}`", :color => :green)
    log(:info, "  path:\n".green + Miam::Utils.diff(old_path, new_path, :color => @options[:color], :indent => '    '), :color => false)
    update_user_or_group(type, user_or_group_name, :new_path => new_path)
  end

  def update_user_or_group(type, user_or_group_name, params)
    unless_dry_run do
      params["#{type}_name".to_sym] = user_or_group_name
      @iam.send("update_#{type}", params)
    end
  end

  def create_policy(type, user_or_group_name, policy_name, policy_document)
    log(:info, "Create #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}` > Policy `#{policy_name}`", :color => :cyan)
    log(:info, "  #{policy_document.pretty_inspect.gsub("\n", "\n  ").strip}", :color => :cyan)
    put_policy(type, user_or_group_name, policy_name, policy_document)
  end

  def update_policy(type, user_or_group_name, policy_name, policy_document, old_policy_document)
    log(:info, "Update #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}` > Policy `#{policy_name}`", :color => :green)
    log(:info, Miam::Utils.diff(old_policy_document, policy_document, :color => @options[:color]), :color => false)
    put_policy(type, user_or_group_name, policy_name, policy_document)
  end

  def delete_policy(type, user_or_group_name, policy_name)
    logmsg = "Delete #{Miam::Utils.camelize(type.to_s)} `#{user_or_group_name}` > Policy `#{policy_name}`"
    log(:info, logmsg, :color => :red)

    unless_dry_run do
      params = {:policy_name => policy_name}
      params["#{type}_name".to_sym] = user_or_group_name
      @iam.send("delete_#{type}_policy", params)
    end
  end

  def put_policy(type, user_or_group_name, policy_name, policy_document)
    unless_dry_run do
      params = {
        :policy_name => policy_name,
        :policy_document => encode_document(policy_document),
      }

      params["#{type}_name".to_sym] = user_or_group_name
      @iam.send("put_#{type}_policy", params)
    end
  end

  def attach_policies(type, name, policies)
    type = type.to_s
    type_s = type.slice(0, 1).upcase + type.slice(1..-1)

    log(:info, "Update #{type_s} `#{name}`", :color => :green)
    log(:info, "  attach policies=#{policies.join(',')}", :color => :green)

    unless_dry_run do
      policies.each do |arn|
        @iam.send("attach_#{type}_policy", :"#{type}_name" => name, :policy_arn => arn)
      end
    end
  end

  def detach_policies(type, name, policies)
    type = type.to_s
    type_s = type.slice(0, 1).upcase + type.slice(1..-1)

    log(:info, "Update #{type_s} `#{name}`", :color => :green)
    log(:info, "  detach policies=#{policies.join(',')}", :color => :green)

    unless_dry_run do
      policies.each do |arn|
        @iam.send("detach_#{type}_policy", :"#{type}_name" => name, :policy_arn => arn)
      end
    end
  end

  def list_access_key_ids(user_name)
    @iam.list_access_keys(:user_name => user_name).map {|resp|
      resp.access_key_metadata.map do |metadata|
        metadata.access_key_id
      end
    }.flatten
  end

  def list_signing_certificate_ids(user_name)
    @iam.list_signing_certificates(:user_name => user_name).map {|resp|
      resp.certificates.map do |cert|
        cert.certificate_id
      end
    }.flatten
  end

  private

  def encode_document(policy_document)
    if @options[:disable_form_json]
      JSON.dump(policy_document)
    else
      encoded = JSON.pretty_generate(policy_document)

      if Miam::Utils.bytesize(encoded) > MAX_POLICY_SIZE
        encoded = JSON.pretty_generate(policy_document)
        encoded = encoded.gsub(/^\s+/m, '').strip
      end

      if Miam::Utils.bytesize(encoded) > MAX_POLICY_SIZE
        encoded = JSON.dump(policy_document)
      end

      encoded
    end
  end

  def unless_dry_run
    yield unless @options[:dry_run]
  end
end
