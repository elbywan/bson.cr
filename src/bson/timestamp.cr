struct BSON
  # Timestamp - Special internal type used by MongoDB replication and sharding. First 4 bytes are an increment, second 4 are a timestamp.
  struct Timestamp
    include Comparable(Timestamp)

    getter t, i

    def initialize(@t : UInt32, @i : UInt32)
    end

    def <=>(other : Timestamp)
      timestamp_comparison = self.t <=> other.t

      if timestamp_comparison == 0
        self.i <=> other.i
      else
        timestamp_comparison
      end
    end

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

    # Serialize to a canonical extended json representation.
    #
    # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
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
