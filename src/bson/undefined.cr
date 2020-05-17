struct BSON
  struct Undefined
    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$undefined")
        builder.scalar(true)
      }
    end
  end
end
