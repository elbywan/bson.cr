class Hash(K, V)
  def self.from_bson(bson : BSON::Value) : self
    raise "Invalid BSON" unless bson.is_a? BSON

    {% begin %}
    {% types = V.union_types %}

    hash = self.new

    bson.each do |k, v|
      case v
      {% for typ in types %}
        {% if typ <= BSON::Serializable || typ.class.has_method? :from_bson %}
        when BSON
          hash[k] = {{ typ }}.from_bson(v)
        {% else %}
        when {{ typ }}
          hash[k] = v.as({{typ}})
        {% end %}
      {% end %}
      else
        raise Exception.new "Unable to deserialize key '#{k}' for hash '#{{{@type.stringify}}}'."
      end
    end

    hash

    {% end %}
  end
end
