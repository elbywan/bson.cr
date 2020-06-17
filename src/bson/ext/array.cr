class Array(T)
  def self.from_bson(bson : BSON::Value) : self
    raise "Invalid BSON" unless bson.is_a? BSON
    {% begin %}
    {% types = T.union_types %}

    arr = self.new

    bson.each do |_, v|
      case v
      {% for typ in types %}
        {% if typ <= BSON::Serializable || typ.class.has_method? :from_bson %}
        when BSON
          arr << {{ typ }}.from_bson(v)
        {% else %}
        when {{ typ }}
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
