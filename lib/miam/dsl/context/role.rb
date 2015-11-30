class Miam::DSL::Context::Role
  include Miam::TemplateHelper

  def initialize(context, name, &block)
    @role_name = name
    @context = context.merge(:role_name => name)
    @result = {:instance_profiles => [], :policies => {}, :attached_managed_policies => []}
    instance_eval(&block)
  end

  def result
    unless @result[:assume_role_policy_document]
      raise "Role `#{@role_name}`: AssumeRolePolicyDocument is not defined"
    end

    @result
  end

  private

  def instance_profiles(*profiles)
    @result[:instance_profiles].concat(profiles.map(&:to_s))
  end

  def assume_role_policy_document
    if @result[:assume_role_policy_document]
      raise "Role `#{@role_name}` > AssumeRolePolicyDocument: already defined"
    end

    assume_role_policy_document = yield

    unless assume_role_policy_document.kind_of?(Hash)
      raise "Role `#{@role_name}` > AssumeRolePolicyDocument: wrong argument type #{policy_document.class} (expected Hash)"
    end

    @result[:assume_role_policy_document] = assume_role_policy_document
  end

  def policy(name)
    name = name.to_s

    if @result[:policies][name]
      raise "Role `#{@role_name}` > Policy `#{name}`: already defined"
    end

    policy_document = yield

    unless policy_document.kind_of?(Hash)
      raise "Role `#{@role_name}` > Policy `#{name}`: wrong argument type #{policy_document.class} (expected Hash)"
    end

    @result[:policies][name] = policy_document
  end

  def attached_managed_policies(*policies)
    @result[:attached_managed_policies].concat(policies.map(&:to_s))
  end
end
