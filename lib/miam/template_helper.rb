module Miam
  module TemplateHelper
    def include_template(template_name, context = {})
      @template_name = template_name
      @caller = caller[0]
      tmplt = @context.templates[template_name.to_s]

      unless tmplt
        raise "Template `#{template_name}` is not defined"
      end

      context_orig = @context
      @context = @context.merge(context)
      instance_eval(&tmplt)
      @context = context_orig
    end

    def context
      @context
    end

    def required(*args)
      missing_args = args.map(&:to_s) - @context.keys
      unless missing_args.empty?
        ex = ArgumentError.new("Missing arguments: #{missing_args.join(", ")} in '#{@template_name}'")
        ex.set_backtrace(@caller)
        raise ex
      end
    end
  end
end
