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
    walk(file)
  end

  private

  def walk(file)
    expected = load_file(file)
    #actual = Miam::Exporter.export(@iam, @options)
    # XXX:
  end

  def load_file(file)
    if file.kind_of?(String)
      open(file) do |f|
        Miam::DSL.parse(f.read, file)
      end
    elsif file.respond_to?(:read)
      Miam::DSL.parse(file.read, file.path)
    else
      raise TypeError, "can't convert #{file} into File"
    end
  end
end
