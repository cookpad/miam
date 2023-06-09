class Hash
  def sort_array!
    keys.each do |key|
      value = self[key]
      self[key] = sort_array0(value)
    end

    self
  end

  private

  def sort_array0(value)
    case value
    when Hash
      new_value = {}

      value.keys.sort.each do |k|
        new_value[k] = sort_array0(value.fetch(k))
      end

      new_value
    when Array
      value.map {|v| sort_array0(v) }.sort_by(&:to_s)
    else
      value
    end
  end
end
