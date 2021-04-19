class Array(T)
  def self.from_bson(bson : BSON::Value) : self
    raise "Invalid BSON" unless bson.is_a? BSON
    {% begin %}
    {% types = T.union_types %}

    {% if types.select(&.<=(Hash)).size > 1 %}
    {% raise "Unable to deserialize #{@type.id}. Can only have one Hash value type." %}
    {% end %}

    {% if types.select(&.<=(Array)).size > 1 %}
    {% raise "Unable to deserialize #{@type.id}. Can only have one Array value type." %}
    {% end %}

    arr = self.new

    bson.each do |(_, v, code, _)|
      case {v, code}
      {% htyp = types.find(&.<=(Hash)) %}
      {% if htyp %}
      when {BSON, BSON::Element::Document}
        arr << {{ htyp }}.from_bson(v)
      {% end %}

      {% atyp = types.find(&.<=(Array)) %}
      {% if atyp %}
      when {BSON, BSON::Element::Array}
        arr << {{ atyp }}.from_bson(v)
      {% end %}

      {% for typ in types %}
        {% if typ <= Hash || typ <= Array %}

        {% elsif typ <= BSON::Serializable || typ.class.has_method? :from_bson %}
        when {BSON, _}
          arr << {{ typ }}.from_bson(v)
        {% else %}
        when { {{ typ }}, _}
          arr << v.as({{ typ }})
        {% end %}
      {% end %}
      else
        raise Exception.new "Unable to deserialize BSON array '#{{{@type.stringify}}}'."
      end
    end

    arr

    {% end %}
  end
end
