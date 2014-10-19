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
  end
end
