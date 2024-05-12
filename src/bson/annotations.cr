struct BSON
  # This annotation can be used to set global serialization options.
  #
  # ```
  # # Use `camelize: "lower"` or `camelize: true` to set lower or higher camelcased properties on the target BSON.
  # @[BSON::Options(camelize: true)]
  # struct Model
  #   include BSON::Serializable
  #   # (…)
  # end
  # ```
  annotation Options
  end

  # This annotation can be used to ignore or rename properties.
  #
  # ```
  # @[BSON::Field(ignore: true)]
  # property ignored_property : Type
  # @[BSON::Field(key: new_name)]
  # property renamed_property
  # ```
  annotation Field
  end
end
