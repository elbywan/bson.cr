struct BSON
  struct DBPointer
    getter data, oid

    def initialize(@data : String, @oid : ObjectId)
    end

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

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
