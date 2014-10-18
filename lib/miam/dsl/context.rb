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
    @result = {}
    # XXX:
    #instance_eval(&block)
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

  # XXX:
end
