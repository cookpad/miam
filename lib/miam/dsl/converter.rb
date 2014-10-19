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
    ].join("\n")
  end

  private

  def output_users(users)
    users.each.sort_by {|k, v| k }.map {|user_name, attrs|
      output_user(user_name, attrs)
    }.join("\n")
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
      output_group(group_name, attrs)
    }.join("\n")
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
      output_role(role_name, attrs)
    }.join("\n")
  end

  def output_role(role_name, attrs)
    role_options = {:path => attrs[:path]}

    <<-EOS
role #{role_name.inspect}, #{Miam::Utils.unbrace(role_options.inspect)} do
  #{output_policies(attrs[:policies])}
end
    EOS
  end

  def output_policies(policies)
    policies.map {|policy_name, policy_document|
      output_policy(policy_name, policy_document)
    }.join("\n\n  ").strip
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
end
