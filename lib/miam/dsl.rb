class Miam::DSL
  def self.convert(exported, options = {})
    Miam::DSL::Converter.convert(exported, options)
  end

  def self.parse(dsl, path, options = {})
    Miam::DSL::Context.eval(dsl, path, options).result
  end
end
