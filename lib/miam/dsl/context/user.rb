class Miam::DSL::Context::User
  def initialize(name, &block)
    @name = name
    @result = {:groups => [], :policies => {}}
    instance_eval(&block)
  end

  attr_reader :result

  private

  def login_profile(value)
    @result[:login_profile] = value
  end

  def groups(*grps)
    @result[:groups].concat(grps.map {|i| i.to_s })
  end

  def policy(name)
    name = name.to_s

    if @result[:policies][name]
      raise "User `#{name}` > Policy `#{name}`: already defined"
    end

    policy_document = yield

    unless policy_document.kind_of?(Hash)
      raise "User `#{name}` > Policy `#{name}`: wrong argument type #{policy_document.class} (expected Hash)"
    end

    @result[:policies][name] = policy_document
  end
end
