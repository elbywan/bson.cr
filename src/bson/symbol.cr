struct BSON
  struct Symbol
    getter data

    def initialize(@data : String)
    end

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$symbol")
        builder.scalar(@data)
      }
    end
  end
end
