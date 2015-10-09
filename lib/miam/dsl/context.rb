class Miam::DSL::Context
  include Miam::TemplateHelper

  def self.eval(dsl, path, options = {})
    self.new(path, options) {
      eval(dsl, binding, path)
    }
  end

  attr_reader :result

  def initialize(path, options = {}, &block)
    @path = path
    @options = options
    @result = {:users => {}, :groups => {}, :roles => {}, :instance_profiles => {}}

    @context = Hashie::Mash.new(
      :path => path,
      :options => options,
      :templates => {}
    )

    instance_eval(&block)
  end

  def template(name, &block)
    @context.templates[name.to_s] = block
  end

  private

  def require(file)
    iamfile = (file =~ %r|\A/|) ? file : File.expand_path(File.join(File.dirname(@path), file))

    if File.exist?(iamfile)
      instance_eval(File.read(iamfile), iamfile)
    elsif File.exist?(iamfile + '.rb')
      instance_eval(File.read(iamfile + '.rb'), iamfile + '.rb')
    else
      Kernel.require(file)
    end
  end

  def user(name, user_options = {}, &block)
    name = name.to_s

    if @result[:users][name]
      raise "User `#{name}` is already defined"
    end

    attrs = Miam::DSL::Context::User.new(@context, name, &block).result
    @result[:users][name] = user_options.merge(attrs)
  end

  def group(name, group_options = {}, &block)
    name = name.to_s

    if @result[:groups][name]
      raise "Group `#{name}` is already defined"
    end

    attrs = Miam::DSL::Context::Group.new(@context, name, &block).result
    @result[:groups][name] = group_options.merge(attrs)
  end

  def role(name, role_options = {}, &block)
    name = name.to_s

    if @result[:roles][name]
      raise "Role `#{name}` is already defined"
    end

    attrs = Miam::DSL::Context::Role.new(@context, name, &block).result
    @result[:roles][name] = role_options.merge(attrs)
  end

  def instance_profile(name, instance_profile_options = {}, &block)
    name = name.to_s

    if @result[:instance_profiles][name]
      raise "instance_profile `#{name}` is already defined"
    end

    @result[:instance_profiles][name] = instance_profile_options
  end
end
