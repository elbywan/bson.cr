struct JSON::Any
  def to_bson
    case raw = self.raw
    when Nil
      raw
    when Bool
      raw
    when Int64
      raw
    when Float64
      raw
    when String
      raw
    else
      BSON.from_json self.to_json
    end
  end

  def self.from_bson(value : BSON::Value) : self
    case value
    when Nil
      self.new value
    when Bool
      self.new value
    when Int64
      self.new value
    when Float64
      self.new value
    when String
      self.new value
    when BSON
      JSON.parse(value.to_json).dup
    else
      raise "Cannot convert Bson to JSON::Any."
    end
  end
end
