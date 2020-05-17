struct BSON
  struct Timestamp
    getter t, i
    def initialize(@t : UInt32, @i : UInt32)
    end
    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$timestamp")
        builder.object {
          builder.string("t")
          builder.scalar(@t)
          builder.string("i")
          builder.scalar(@i)
        }
      }
    end
  end
end
