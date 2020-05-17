struct Float64
  def to_canonical_extjson(builder : JSON::Builder)
    builder.object {
      builder.string("$numberDouble")
      builder.scalar(to_s)
    }
  end
end
