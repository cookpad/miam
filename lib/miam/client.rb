class Miam::Client
  def initialize(options = {})
    @options = options
    aws_config = options.delete(:aws_config) || {}
    @iam = Aws::IAM::Client.new(aws_config)
    @driver = Miam::Driver.new(@iam, options)
    @password_manager = options[:password_manager] || Miam::PasswordManager.new('-', options)
  end

  def export
    exported, group_users = Miam::Exporter.export(@iam, @options) do |export_options|
      progress(*export_options.values_at(:progress_total, :progress))
    end

    Miam::DSL.convert(exported, @options)
  end

  def apply(file)
    walk(file)
  end

  private

  def walk(file)
    expected = load_file(file)

    actual, group_users = Miam::Exporter.export(@iam, @options) do |export_options|
      progress(*export_options.values_at(:progress_total, :progress))
    end

    updated = walk_groups(expected[:groups], actual[:groups], group_users)
    updated = walk_users(expected[:users], actual[:users], group_users) || updated

    if @options[:dry_run]
      false
    else
      updated
    end
  end

  def walk_users(expected, actual, group_users)
    updated = scan_rename(:user, expected, actual, group_users)

    expected.each do |user_name, expected_attrs|
      actual_attrs = actual.delete(user_name)

      if actual_attrs
        updated = walk_user(user_name, expected_attrs, actual_attrs) || updated
      else
        @driver.create_user(user_name, expected_attrs)
        # XXX: create key
        updated = true
      end
    end

    actual.each do |user_name, attrs|
      @driver.delete_user(user_name, attrs)
      updated = true
    end

    updated
  end

  def walk_user(user_name, expected_attrs, actual_attrs)
    updated = walk_login_profile(user_name, expected_attrs[:login_profile], actual_attrs[:login_profile])
    updated = walk_user_groups(user_name, expected_attrs[:groups], actual_attrs[:groups]) || updated
    walk_policies(:user, user_name, expected_attrs[:policies], actual_attrs[:policies])
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

  def walk_groups(expected, actual, group_users)
    updated = scan_rename(:group, expected, actual, group_users)

    expected.each do |group_name, expected_attrs|
      actual_attrs = actual.delete(group_name)

      if actual_attrs
        updated = walk_path(:group, group_name, expected_attrs[:path], actual_attrs[:path]) || updated
        updated = walk_group(group_name, expected_attrs, actual_attrs) || updated
      else
        @driver.create_group(group_name, expected_attrs)
        updated = true
      end
    end

    actual.each do |group_name, attrs|
      users_in_group = group_users[group_name] || []
      @driver.delete_group(group_name, attrs, users_in_group)
      updated = true
    end

    updated
  end

  def walk_group(group_name, expected_attrs, actual_attrs)
    walk_policies(:group, group_name, expected_attrs[:policies], actual_attrs[:policies])
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

  def load_file(file)
    if file.kind_of?(String)
      open(file) do |f|
        Miam::DSL.parse(f.read, file)
      end
    elsif file.respond_to?(:read)
      Miam::DSL.parse(file.read, file.path)
    else
      raise TypeError, "can't convert #{file} into File"
    end
  end

  def progress(total, n)
    return if @options[:no_progress]

    unless @progressbar
      @progressbar = ProgressBar.create(:title => "Loading", :total => total, :output => $stderr)
    end

    @progressbar.progress = n
  end
end
