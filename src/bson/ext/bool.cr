struct Bool
  def to_canonical_extjson(builder : JSON::Builder)
    builder.scalar(self)
  end
end
