class Hash(K, V)
  def self.from_bson(bson : BSON::Value) : self
    raise "Invalid BSON" unless bson.is_a? BSON

    {% begin %}
    {% types = V.union_types %}

    {% if types.select(&.<=(Hash)).size > 1 %}
    {% raise "Unable to deserialize #{@type.id}. Can only have one Hash value type." %}
    {% end %}

    {% if types.select(&.<=(Array)).size > 1 %}
    {% raise "Unable to deserialize #{@type.id}. Can only have one Array value type." %}
    {% end %}

    hash = self.new

    bson.each do |(k, v, code, _)|
      case {v, code}

      {% htyp = types.find(&.<=(Hash)) %}
      {% if htyp %}
      when {BSON, BSON::Element::Document}
        hash[k] = {{ htyp }}.from_bson(v)
      {% end %}

      {% atyp = types.find(&.<=(Array)) %}
      {% if atyp %}
      when {BSON, BSON::Element::Array}
        hash[k] = {{ atyp }}.from_bson(v)
      {% end %}

      {% for typ in types.uniq %}
        {% if typ <= Hash || typ <= Array %}

        {% elsif (typ <= BSON::Serializable || typ.class.has_method? :from_bson) %}
        when { BSON, _ }
          hash[k] = {{ typ }}.from_bson(v)

        {% else %}
        when { {{ typ }}, _ }
          hash[k] = v.as({{typ}})
        {% end %}
      {% end %}
      else
        raise Exception.new "Unable to deserialize key '#{k}' for hash '{{@type.id}}'."
      end
    end

    hash
    {% end %}
  end
end
