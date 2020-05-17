struct BSON
  # DBPointer — Deprecated.
  struct DBPointer
    getter data, oid

    def initialize(@data : String, @oid : ObjectId)
    end

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

    # Serialize to a canonical extended json representation.
    #
    # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$dbPointer")
        builder.object {
          builder.string("$ref")
          builder.string(@data)
          builder.string("$id")
          @oid.to_canonical_extjson(builder)
        }
      }
    end
  end
end
