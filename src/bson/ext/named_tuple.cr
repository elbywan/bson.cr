struct NamedTuple
  def self.from_bson(bson : BSON::Value) : self
    raise "Invalid BSON" unless bson.is_a? BSON

    {% begin %}
    self.new(
      {% for key, typ in T %}
        {% if typ <= BSON::Serializable || typ.class.has_method? :from_bson %}
          {{ key }}: {{ typ }}.from_bson(bson[{{ key.stringify }}]),
        {% else %}
          {{ key }}: bson[{{ key.stringify }}].as({{ typ }}),
        {% end %}
      {% end %}
    )
    {% end %}
  end
end
