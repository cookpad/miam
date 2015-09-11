class Miam::Utils
  class << self
    def unbrace(str)
      str.sub(/\A\s*\{/, '').sub(/\}\s*\z/, '')
    end

    def camelize(str)
      str.slice(0, 1).upcase + str.slice(1..-1).downcase
    end

    def bytesize(str)
      if str.respond_to?(:bytesize)
        str.bytesize
      else
        str.length
      end
    end

    def diff(obj1, obj2, options = {})
      diffy = Diffy::Diff.new(
        obj1.pretty_inspect,
        obj2.pretty_inspect,
        :diff => '-u'
      )

      out = diffy.to_s(options[:color] ? :color : :text).gsub(/\s+\z/m, '')
      out.gsub!(/^/, options[:indent]) if options[:indent]
      out
    end
  end # of class methods
end
