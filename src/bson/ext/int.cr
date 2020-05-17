struct Int32
  def to_canonical_extjson(builder : JSON::Builder)
    builder.object {
      builder.string("$numberInt")
      builder.scalar(self.to_s)
    }
  end
end

struct Int64
  def to_canonical_extjson(builder : JSON::Builder)
    builder.object {
      builder.string("$numberLong")
      builder.scalar(self.to_s)
    }
  end
end
