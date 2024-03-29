struct BSON
  # JavaScript code.
  struct Code
    getter code, scope

    def initialize(@code : String, @scope : BSON? = nil); end

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

    # Serialize to a canonical extended json representation.
    #
    # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$code")
        builder.scalar(@code)
        if scope = @scope
          builder.string("$scope")
          scope.to_canonical_extjson(builder)
        end
      }
    end
  end
end
