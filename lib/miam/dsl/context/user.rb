class Miam::DSL::Context::User
  include Miam::TemplateHelper

  def initialize(context, name, &block)
    @user_name = name
    @context = context.merge(:user_name => name)
    @result = {:groups => [], :policies => {}, :attached_managed_policies => []}
    instance_eval(&block)
  end

  attr_reader :result

  private

  def login_profile(value)
    @result[:login_profile] = value
  end

  def access_key(value)
    @result[:access_key] = value
  end

  def groups(*grps)
    @result[:groups].concat(grps.map(&:to_s))
  end

  def policy(name)
    name = name.to_s

    if @result[:policies][name]
      raise "User `#{@user_name}` > Policy `#{name}`: already defined"
    end

    policy_document = yield

    unless policy_document.kind_of?(Hash)
      raise "User `#{@user_name}` > Policy `#{name}`: wrong argument type #{policy_document.class} (expected Hash)"
    end

    @result[:policies][name] = policy_document
  end

  def attached_managed_policies(*policies)
    @result[:attached_managed_policies].concat(policies.map(&:to_s))
  end
end
