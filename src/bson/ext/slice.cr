struct Slice(T)
  # Serialize to a canonical extended json representation.
  #
  # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
  def to_canonical_extjson(builder : JSON::Builder, subtype : BSON::Binary::SubType? = nil)
    builder.object {
      builder.string("$binary")
      builder.object {
        builder.string("base64")
        builder.string(Base64.strict_encode(self))
        builder.string("subType")
        builder.string((subtype.try(&.value.to_s(16)) || "").rjust(2, '0'))
      }
    }
  end
end
