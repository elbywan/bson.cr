struct BSON
  # Symbol. Deprecated.
  struct Symbol
    getter data

    def initialize(@data : String)
    end

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

    # Serialize to a canonical extended json representation.
    #
    # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$symbol")
        builder.scalar(@data)
      }
    end
  end
end
