class Miam::DSL
  def self.convert(exported, options = {})
    Miam::DSL::Converter.convert(exported, options)
  end

  def self.parse(dsl, path, options = {})
    # XXX:
  end
end
