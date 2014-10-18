class Miam::DSL::Context::Group
  def initialize(name, &block)
    @name = name
    @result = {:policies => {}}
    instance_eval(&block)
  end

  attr_reader :result

  private

  def policy(name)
    if @result[:policies][name]
      raise "Group `#{name}` > Policy `#{name}`: already defined"
    end

    policy_document = yield

    unless policy_document.kind_of?(Hash)
      raise "Group `#{name}` > Policy `#{name}`: wrong argument type #{policy_document.class} (expected Hash)"
    end

    @result[:policies][name] = policy_document
  end
end
