class Miam::DSL::Context
  def self.eval(dsl, path, options = {})
    self.new(path, options) {
      eval(dsl, binding, path)
    }
  end

  attr_reader :result

  def initialize(path, options = {}, &block)
    @path = path
    @options = options
    @result = {:users => {}, :groups => {}}
    instance_eval(&block)
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

    attrs = Miam::DSL::Context::User.new(name, &block).result
    @result[:users][name] = user_options.merge(attrs)
  end

  def group(name, group_options = {}, &block)
    name = name.to_s

    if @result[:groups][name]
      raise "Group `#{name}` is already defined"
    end

    attrs = Miam::DSL::Context::Group.new(name, &block).result
    @result[:groups][name] = group_options.merge(attrs)
  end
end
