class Miam::DSL::Context::Role
  def initialize(name, &block)
    @name = name
    @result = {:instance_profiles => [], :policies => {}}
    instance_eval(&block)
  end

  attr_reader :result

  private

  def instance_profiles(*profiles)
    @result[:instance_profiles].concat(profiles.map {|i| i.to_s })
  end

  def assume_role_policy_document
    if @result[:assume_role_policy_document]
      raise "Role `#{name}` > AssumeRolePolicyDocument: already defined"
    end

    assume_role_policy_document = yield

    unless assume_role_policy_document.kind_of?(Hash)
      raise "Role `#{name}` > AssumeRolePolicyDocument: wrong argument type #{policy_document.class} (expected Hash)"
    end

    @result[:assume_role_policy_document] = assume_role_policy_document
  end

  def policy(name)
    name = name.to_s

    if @result[:policies][name]
      raise "Role `#{name}` > Policy `#{name}`: already defined"
    end

    policy_document = yield

    unless policy_document.kind_of?(Hash)
      raise "Role `#{name}` > Policy `#{name}`: wrong argument type #{policy_document.class} (expected Hash)"
    end

    @result[:policies][name] = policy_document
  end
end
