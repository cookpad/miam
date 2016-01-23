class Miam::DSL::Context::ManagedPolicy
  include Miam::TemplateHelper

  def initialize(context, name, &block)
    @policy_name = name
    @context = context.merge(:policy_name => name)
    @result = {:document => get_document(block)}
  end

  attr_reader :result

  private

  def get_document(block)
    document = instance_eval(&block)

    unless document.kind_of?(Hash)
      raise "ManagedPolicy `#{@policy_name}`: wrong argument type #{document.class} (expected Hash)"
    end

    document
  end
end
