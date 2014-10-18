class Miam::Client
  def initialize(options = {})
    @options = options
    aws_config = options.delete(:aws_config) || {}
    @iam = Aws::IAM::Client.new(aws_config)
    @driver = Miam::Driver.new(@iam, options)
  end

  def export
    exported = Miam::Exporter.export(@iam, @options)
    Miam::DSL.convert(exported, @options)
  end

  def apply(file)
    # XXX:
  end

  private

  # XXX:
end
