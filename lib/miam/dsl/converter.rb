class Miam::DSL::Converter
  def self.convert(exported, options = {})
    self.new(exported, options).convert
  end

  def initialize(exported, options = {})
    @exported = exported
    @options = options
  end

  def convert
    [
      output_users(@exported[:users]),
      output_groups(@exported[:groups]),
      output_roles(@exported[:roles]),
      output_instance_profiles(@exported[:instance_profiles]),
    ].join("\n")
  end

  private

  def output_users(users)
    users.each.sort_by {|k, v| k }.map {|user_name, attrs|
      next unless target_matched?(user_name)
      output_user(user_name, attrs)
    }.select {|i| i }.join("\n")
  end

  def output_user(user_name, attrs)
    user_options = {:path => attrs[:path]}

    <<-EOS
user #{user_name.inspect}, #{Miam::Utils.unbrace(user_options.inspect)} do
  #{output_login_profile(attrs[:login_profile])}

  #{output_user_groups(attrs[:groups])}

  #{output_policies(attrs[:policies])}
end
    EOS
  end

  def output_user_groups(groups)
    if groups.empty?
      groups = ['# no group']
    else
      groups = groups.map {|i| i.inspect }
    end

    groups = "\n    " + groups.join(",\n    ") + "\n  "
    "groups(#{groups})"
  end

  def output_login_profile(login_profile)
    if login_profile
      "login_profile #{Miam::Utils.unbrace(login_profile.inspect)}"
    else
      '# login_profile :password_reset_required=>true'
    end
  end

  def output_groups(groups)
    groups.each.sort_by {|k, v| k }.map {|group_name, attrs|
      next unless target_matched?(group_name)
      output_group(group_name, attrs)
    }.select {|i| i }.join("\n")
  end

  def output_group(group_name, attrs)
    group_options = {:path => attrs[:path]}

    <<-EOS
group #{group_name.inspect}, #{Miam::Utils.unbrace(group_options.inspect)} do
  #{output_policies(attrs[:policies])}
end
    EOS
  end

  def output_roles(roles)
    roles.each.sort_by {|k, v| k }.map {|role_name, attrs|
      next unless target_matched?(role_name)
      output_role(role_name, attrs)
    }.select {|i| i }.join("\n")
  end

  def output_role(role_name, attrs)
    role_options = {:path => attrs[:path]}

    <<-EOS
role #{role_name.inspect}, #{Miam::Utils.unbrace(role_options.inspect)} do
  #{output_role_instance_profiles(attrs[:instance_profiles])}

  #{output_assume_role_policy_document(attrs[:assume_role_policy_document])}

  #{output_policies(attrs[:policies])}
end
    EOS
  end

  def output_role_instance_profiles(instance_profiles)
    if instance_profiles.empty?
      instance_profiles = ['# no instance_profile']
    else
      instance_profiles = instance_profiles.map {|i| i.inspect }
    end

    instance_profiles = "\n    " + instance_profiles.join(",\n    ") + "\n  "
    "instance_profiles(#{instance_profiles})"
  end

  def output_instance_profiles(instance_profiles)
    instance_profiles.each.sort_by {|k, v| k }.map {|instance_profile_name, attrs|
      next unless target_matched?(instance_profile_name)
      output_instance_profile(instance_profile_name, attrs)
    }.select {|i| i }.join("\n")
  end

  def output_assume_role_policy_document(assume_role_policy_document)
    assume_role_policy_document = assume_role_policy_document.pretty_inspect
    assume_role_policy_document.gsub!("\n", "\n    ").strip!

    <<-EOS.strip
  assume_role_policy_document do
    #{assume_role_policy_document}
  end
    EOS
  end

  def output_instance_profile(instance_profile_name, attrs)
    instance_profile_options = {:path => attrs[:path]}

    <<-EOS
instance_profile #{instance_profile_name.inspect}, #{Miam::Utils.unbrace(instance_profile_options.inspect)}
    EOS
  end

  def output_policies(policies)
    if policies.empty?
      "# no policy"
    else
      policies.map {|policy_name, policy_document|
        output_policy(policy_name, policy_document)
      }.join("\n\n  ").strip
    end
  end

  def output_policy(policy_name, policy_document)
    policy_document = policy_document.pretty_inspect
    policy_document.gsub!("\n", "\n    ").strip!

    <<-EOS.strip
  policy #{policy_name.inspect} do
    #{policy_document}
  end
    EOS
  end

  def target_matched?(name)
    if @options[:target]
      name =~ @options[:target]
    else
      true
    end
  end
end
