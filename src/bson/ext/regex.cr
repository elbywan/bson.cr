class Regex
  # Serialize to a canonical extended json representation.
  #
  # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
  def to_canonical_extjson(builder : JSON::Builder)
    builder.object {
      builder.string("$regularExpression")
      builder.object {
        builder.string("pattern")
        builder.string(self.source)
        builder.string("options")
        options = String.build do |str|
          str << "i" if self.options.includes? :ignore_case
          str << "m" if self.options.includes? :multiline
          str << "x" if self.options.includes? :extended
          str << "u" if self.options.includes? :utf_8
        end
        builder.string(options)
      }
    }
  end
end
