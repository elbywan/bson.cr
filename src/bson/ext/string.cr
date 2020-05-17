class String
  def to_canonical_extjson(builder : JSON::Builder)
    builder.string(self)
  end
end
