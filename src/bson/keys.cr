struct BSON
  struct MinKey
    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$minKey")
        builder.scalar(1)
      }
    end
  end
  struct MaxKey
    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$maxKey")
        builder.scalar(1)
      }
    end
  end
end
