struct BSON
  # Min key - Special type which compares lower than all other possible BSON element values.
  struct MinKey

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

    # Serialize to a canonical extended json representation.
    #
    # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$minKey")
        builder.scalar(1)
      }
    end
  end

  # Max key - Special type which compares higher than all other possible BSON element values.
  struct MaxKey

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

    # Serialize to a canonical extended json representation.
    #
    # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$maxKey")
        builder.scalar(1)
      }
    end
  end
end
