class Miam::Client
  def initialize(options = {})
    @options = options
    aws_config = options.delete(:aws_config) || {}
    @iam = Aws::IAM::Client.new(aws_config)
    @driver = Miam::Driver.new(@iam, options)
  end

  def export
    exported = Miam::Exporter.export(@iam, @options) do |export_options|
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

    actual = Miam::Exporter.export(@iam, @options) do |export_options|
      progress(*export_options.values_at(:progress_total, :progress))
    end

    updated = walk_users(expected[:users], actual[:users])
    walk_groups(expected[:groups], actual[:groups]) || updated
  end

  def walk_users(expected, actual)
    updated = false

    expected.each do |user_name, expected_attrs|
      actual_attrs = actual.delete(user_name)

      if actual_attrs
        updated = walk_user(user_name, expected_attrs, actual_attrs) || updated
      else
        # XXX: create user
        updated = true
      end
    end

    actual.each do |user_name, attrs|
      # XXX: delete user
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

    if expected_login_profile != actual_login_profile
      if expected_login_profile
        # XXX: create login_profile
      else
        # XXX: delete login_profile
      end

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

      if add_groups
        # XXX: add_user_to_group
      end

      if remove_groups
        # XXX: remove_user_from_group
      end

      updated = true
    end

    updated
  end

  def walk_groups(expected, actual)
    updated = scan_rename(:group, expected, actual)

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
      @driver.delete_group(group_name)
      updated = true
    end

    updated
  end

  def walk_group(group_name, expected_attrs, actual_attrs)
    walk_policies(:group, group_name, expected_attrs[:policies], actual_attrs[:policies])
  end

  def scan_rename(type, expected, actual)
    updated = false

    expected.each do |name, expected_attrs|
      renamed_from = expected_attrs[:renamed_from]
      next unless renamed_from

      actual_attrs = actual.delete(renamed_from)
      next unless actual_attrs

      @driver.update_name(type, renamed_from, name)
      actual[name] = actual_attrs
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
