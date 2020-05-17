struct Time
  # Serialize to a canonical extended json representation.
  #
  # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
  def to_canonical_extjson(builder : JSON::Builder)
    builder.object {
      builder.string("$date")
      builder.object {
        builder.string("$numberLong")
        builder.string(self.to_unix_ms.to_s)
      }
    }
  end

  # Serialize to a canonical extended json representation.
  #
  # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
  def to_relaxed_extjson(builder : JSON::Builder)
    builder.object {
      builder.string("$date")
      builder.string(self.to_rfc3339)
    }
  end
end
