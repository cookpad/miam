class Miam::Client
  include Miam::Logger::Helper

  def initialize(options = {})
    @options = {:format => :ruby}.merge(options)
    aws_config = options.delete(:aws_config) || {}
    @iam = Aws::IAM::Client.new(aws_config)
    @driver = Miam::Driver.new(@iam, options)
    @password_manager = options[:password_manager] || Miam::PasswordManager.new('-', options)
  end

  def export(export_options = {})
    exported, group_users, instance_profile_roles = Miam::Exporter.export(@iam, @options)

    if block_given?
      [:users, :groups, :roles, :instance_profiles].each do |type|
        splitted = {:users => {}, :groups => {}, :roles => {}, :instance_profiles => {}}

        if export_options[:split_more]
          exported[type].sort_by {|k, v| k }.each do |name, attrs|
            more_splitted = splitted.dup
            more_splitted[type] = {}
            more_splitted[type][name] = attrs

            dsl = exec_by_format(
              :ruby => proc { Miam::DSL.convert(more_splitted, @options).strip },
              :json => proc { JSON.pretty_generate(more_splitted) }
            )

            yield(:type => type, :name => name, :dsl => dsl)
          end
        else
          splitted[type] = exported[type]

          dsl = exec_by_format(
            :ruby => proc { Miam::DSL.convert(splitted, @options).strip },
            :json => proc { JSON.pretty_generate(splitted) }
          )

          yield(:type => type, :dsl => dsl)
        end
      end
    else
      dsl = exec_by_format(
        :ruby => proc { Miam::DSL.convert(exported, @options).strip },
        :json => proc { JSON.pretty_generate(exported) }
      )
    end
  end

  def apply(file)
    walk(file)
  end

  private

  def walk(file)
    expected = load_file(file)

    actual, group_users, instance_profile_roles = Miam::Exporter.export(@iam, @options)
    updated = walk_groups(expected[:groups], actual[:groups], actual[:users], group_users)
    updated = walk_users(expected[:users], actual[:users], group_users) || updated
    updated = walk_instance_profiles(expected[:instance_profiles], actual[:instance_profiles], actual[:roles], instance_profile_roles) || updated
    updated = walk_roles(expected[:roles], actual[:roles], instance_profile_roles) || updated

    if @options[:dry_run]
      false
    else
      updated
    end
  end

  def walk_users(expected, actual, group_users)
    updated = scan_rename(:user, expected, actual, group_users)

    expected.each do |user_name, expected_attrs|
      next unless target_matched?(user_name)

      actual_attrs = actual.delete(user_name)

      if actual_attrs
        updated = walk_path(:user, user_name, expected_attrs[:path], actual_attrs[:path]) || updated
        updated = walk_user(user_name, expected_attrs, actual_attrs) || updated
      else
        actual_attrs = @driver.create_user(user_name, expected_attrs)
        access_key = @driver.create_access_key(user_name)

        if access_key
          @password_manager.puts_password(user_name, access_key[:access_key_id], access_key[:secret_access_key])
        end

        walk_user(user_name, expected_attrs, actual_attrs)
        updated = true
      end
    end

    actual.each do |user_name, attrs|
      next unless target_matched?(user_name)

      @driver.delete_user(user_name, attrs)

      group_users.each do |group_name, users|
        users.delete(user_name)
      end

      updated = true
    end

    updated
  end

  def walk_user(user_name, expected_attrs, actual_attrs)
    updated = walk_login_profile(user_name, expected_attrs[:login_profile], actual_attrs[:login_profile])
    updated = walk_user_groups(user_name, expected_attrs[:groups], actual_attrs[:groups]) || updated
    updated = walk_attached_managed_policies(:user, user_name, expected_attrs[:attached_managed_policies], actual_attrs[:attached_managed_policies]) || updated
    walk_policies(:user, user_name, expected_attrs[:policies], actual_attrs[:policies]) || updated
  end

  def walk_login_profile(user_name, expected_login_profile, actual_login_profile)
    updated = false

    [expected_login_profile, actual_login_profile].each do |login_profile|
      if login_profile and not login_profile.has_key?(:password_reset_required)
        login_profile[:password_reset_required] = false
      end
    end

    if expected_login_profile and not actual_login_profile
      expected_login_profile[:password] ||= @password_manager.identify(user_name, :login_profile)
      @driver.create_login_profile(user_name, expected_login_profile)
      updated = true
    elsif not expected_login_profile and actual_login_profile
      @driver.delete_login_profile(user_name)
      updated = true
    elsif expected_login_profile != actual_login_profile
      @driver.update_login_profile(user_name, expected_login_profile)
      updated = true
    end

    updated
  end

  def walk_user_groups(user_name, expected_groups, actual_groups)
    expected_groups = expected_groups.sort
    actual_groups = actual_groups.sort
    updated = false

    if expected_groups != actual_groups
      add_groups = expected_groups - actual_groups
      remove_groups = actual_groups - expected_groups

      unless add_groups.empty?
        @driver.add_user_to_groups(user_name, add_groups)
      end

      unless remove_groups.empty?
        @driver.remove_user_from_groups(user_name, remove_groups)
      end

      updated = true
    end

    updated
  end

  def walk_groups(expected, actual, actual_users, group_users)
    updated = scan_rename(:group, expected, actual, group_users)

    expected.each do |group_name, expected_attrs|
      next unless target_matched?(group_name)

      actual_attrs = actual.delete(group_name)

      if actual_attrs
        updated = walk_path(:group, group_name, expected_attrs[:path], actual_attrs[:path]) || updated
        updated = walk_group(group_name, expected_attrs, actual_attrs) || updated
      else
        actual_attrs = @driver.create_group(group_name, expected_attrs)
        walk_group(group_name, expected_attrs, actual_attrs)
        updated = true
      end
    end

    actual.each do |group_name, attrs|
      next unless target_matched?(group_name)

      users_in_group = group_users.delete(group_name) || []
      @driver.delete_group(group_name, attrs, users_in_group)

      actual_users.each do |user_name, user_attrs|
        user_attrs[:groups].delete(group_name)
      end

      updated = true
    end

    updated
  end

  def walk_group(group_name, expected_attrs, actual_attrs)
    updated = walk_policies(:group, group_name, expected_attrs[:policies], actual_attrs[:policies])
    walk_attached_managed_policies(:group, group_name, expected_attrs[:attached_managed_policies], actual_attrs[:attached_managed_policies]) || updated
  end

  def walk_roles(expected, actual, instance_profile_roles)
    updated = false

    expected.each do |role_name, expected_attrs|
      next unless target_matched?(role_name)

      actual_attrs = actual.delete(role_name)

      if actual_attrs
        updated = walk_role(role_name, expected_attrs, actual_attrs) || updated
      else
        actual_attrs = @driver.create_role(role_name, expected_attrs)
        walk_role(role_name, expected_attrs, actual_attrs)
        updated = true
      end
    end

    actual.each do |role_name, attrs|
      next unless target_matched?(role_name)

      instance_profile_names = []

      instance_profile_roles.each do |instance_profile_name, roles|
        if roles.include?(role_name)
          instance_profile_names << instance_profile_name
        end
      end

      @driver.delete_role(role_name, instance_profile_names, attrs)

      instance_profile_roles.each do |instance_profile_name, roles|
        roles.delete(role_name)
      end

      updated = true
    end

    updated
  end

  def walk_role(role_name, expected_attrs, actual_attrs)
    if expected_attrs.values_at(:path) != actual_attrs.values_at(:path)
      log(:warn, "Role `#{role_name}`: 'path' cannot be updated", :color => :yellow)
    end

    updated = walk_assume_role_policy(role_name, expected_attrs[:assume_role_policy_document], actual_attrs[:assume_role_policy_document])
    updated = walk_role_instance_profiles(role_name, expected_attrs[:instance_profiles], actual_attrs[:instance_profiles]) || updated
    updated = walk_attached_managed_policies(:role, role_name, expected_attrs[:attached_managed_policies], actual_attrs[:attached_managed_policies]) || updated
    walk_policies(:role, role_name, expected_attrs[:policies], actual_attrs[:policies]) || updated
  end

  def walk_assume_role_policy(role_name, expected_assume_role_policy, actual_assume_role_policy)
    updated = false

    if expected_assume_role_policy != actual_assume_role_policy
      @driver.update_assume_role_policy(role_name, expected_assume_role_policy)
      updated = true
    end

    updated
  end

  def walk_role_instance_profiles(role_name, expected_instance_profiles, actual_instance_profiles)
    expected_instance_profiles = expected_instance_profiles.sort
    actual_instance_profiles = actual_instance_profiles.sort
    updated = false

    if expected_instance_profiles != actual_instance_profiles
      add_instance_profiles = expected_instance_profiles - actual_instance_profiles
      remove_instance_profiles = actual_instance_profiles - expected_instance_profiles

      unless add_instance_profiles.empty?
        @driver.add_role_to_instance_profiles(role_name, add_instance_profiles)
      end

      unless remove_instance_profiles.empty?
        @driver.remove_role_from_instance_profiles(role_name, remove_instance_profiles)
      end

      updated = true
    end

    updated
  end

  def walk_instance_profiles(expected, actual, actual_roles, instance_profile_roles)
    updated = false

    expected.each do |instance_profile_name, expected_attrs|
      next unless target_matched?(instance_profile_name)

      actual_attrs = actual.delete(instance_profile_name)

      if actual_attrs
        updated = walk_instance_profile(instance_profile_name, expected_attrs, actual_attrs) || updated
      else
        actual_attrs = @driver.create_instance_profile(instance_profile_name, expected_attrs)
        walk_instance_profile(instance_profile_name, expected_attrs, actual_attrs)
        updated = true
      end
    end

    actual.each do |instance_profile_name, attrs|
      next unless target_matched?(instance_profile_name)

      roles_in_instance_profile = instance_profile_roles.delete(instance_profile_name) || []
      @driver.delete_instance_profile(instance_profile_name, attrs, roles_in_instance_profile)

      actual_roles.each do |role_name, role_attrs|
        role_attrs[:instance_profiles].delete(instance_profile_name)
      end

      updated = true
    end

    updated
  end

  def walk_instance_profile(instance_profile_name, expected_attrs, actual_attrs)
    updated = false

    if expected_attrs != actual_attrs
      log(:warn, "InstanceProfile `#{instance_profile_name}`: 'path' cannot be updated", :color => :yellow)
    end

    updated
  end

  def scan_rename(type, expected, actual, group_users)
    updated = false

    expected.each do |name, expected_attrs|
      renamed_from = expected_attrs[:renamed_from]
      next unless renamed_from

      actual_attrs = actual.delete(renamed_from)
      next unless actual_attrs

      @driver.update_name(type, renamed_from, name)
      actual[name] = actual_attrs

      case type
      when :user
        group_users.each do |group_name, users|
          users.each do |user_name|
            if user_name == renamed_from
              user_name.replace(name)
            end
          end
        end
      when :group
        users = group_users.delete(renamed_from)
        group_users[name] = users if users
      end

      updated = true
    end

    updated
  end

  def walk_path(type, user_or_group_name, expected_path, actual_path)
    updated = false

    if expected_path != actual_path
      @driver.update_path(type, user_or_group_name, expected_path)
      updated = true
    end

    updated
  end

  def walk_policies(type, user_or_group_name, expected_policies, actual_policies)
    updated = false

    expected_policies.each do |policy_name, expected_document|
      actual_document = actual_policies.delete(policy_name)

      if actual_document
        updated = walk_policy(type, user_or_group_name, policy_name, expected_document, actual_document) || updated
      else
        @driver.create_policy(type, user_or_group_name, policy_name, expected_document)
        updated = true
      end
    end

    actual_policies.each do |policy_name, document|
      @driver.delete_policy(type, user_or_group_name, policy_name)
      updated = true
    end

    updated
  end

  def walk_policy(type, user_or_group_name, policy_name, expected_document, actual_document)
    updated = false

    if expected_document != actual_document
      @driver.update_policy(type, user_or_group_name, policy_name, expected_document)
      updated = true
    end

    updated
  end

  def walk_attached_managed_policies(type, name, expected_attached_managed_policies, actual_attached_managed_policies)
    expected_attached_managed_policies = expected_attached_managed_policies.sort
    actual_attached_managed_policies = actual_attached_managed_policies.sort
    updated = false

    if expected_attached_managed_policies != actual_attached_managed_policies
      add_attached_managed_policies = expected_attached_managed_policies - actual_attached_managed_policies
      remove_attached_managed_policies = actual_attached_managed_policies - expected_attached_managed_policies

      unless add_attached_managed_policies.empty?
        @driver.attach_policies(type, name, add_attached_managed_policies)
      end

      unless remove_attached_managed_policies.empty?
        @driver.detach_policies(type, name, remove_attached_managed_policies)
      end

      updated = true
    end

    updated
  end


  def load_file(file)
    if file.kind_of?(String)
      open(file) do |f|
        exec_by_format(
          :ruby => proc { Miam::DSL.parse(f.read, file) },
          :json => proc { load_json(f) }
        )
      end
    elsif file.respond_to?(:read)
      exec_by_format(
        :ruby => proc { Miam::DSL.parse(file.read, file.path) },
        :json => proc { load_json(f) }
      )
    else
      raise TypeError, "can't convert #{file} into File"
    end
  end

  def target_matched?(name)
    if @options[:target]
      name =~ @options[:target]
    else
      true
    end
  end

  def exec_by_format(proc_by_format)
    format_proc = proc_by_format[@options[:format]]
    raise "Invalid format: #{@options[:format]}" unless format_proc
    format_proc.call
  end

  def load_json(json)
    json = JSON.load(json)
    normalized = {}

    json.each do |top_key, top_value|
      normalized[top_key.to_sym] = top_attrs = {}

      top_value.each do |second_key, second_value|
        top_attrs[second_key] = second_attrs = {}

        second_value.each do |third_key, third_value|
          third_key = third_key.to_sym

          if third_key == :login_profile
            new_third_value = {}
            third_value.each {|k, v| new_third_value[k.to_sym] = v }
            third_value = new_third_value
          end

          second_attrs[third_key] = third_value
        end
      end
    end

    normalized
  end
end
