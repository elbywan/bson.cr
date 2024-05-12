module BSON::Serializable
  macro included
    {% verbatim do %}

    # Allocate an instance and copies data from a BSON struct.
    #
    # ```
    # class User
    #   include BSON::Serializable
    #   property name : String
    # end
    #
    # data = BSON.new
    # data["name"] = "John"
    # User.new(data)
    # ```
    def initialize(bson : BSON)
      {% begin %}
        {% global_options = @type.annotations(BSON::Options) %}
        {% camelize = global_options.reduce(false) { |_, a| a[:camelize] } %}

        {% for ivar in @type.instance_vars %}
          {% ann = ivar.annotation(BSON::Field) %}
          {% types = ivar.type.union_types.select { |t| t != Nil } %}
          {% key = ivar.name %}
          {% bson_key = ann ? ann[:key].id : camelize ? ivar.name.camelcase(lower: camelize == "lower") : ivar.name %}
          {% number_conversion_added = false %}

          {% unless ann && ann[:ignore] %}
            bson_value = bson["{{ bson_key }}"]?
            if !bson_value.nil?
              case bson_value
              {% for typ in types %}
              {% if typ <= BSON::Serializable %}
              when BSON
                @{{ key }} = {{ typ }}.from_bson(bson_value)
              {% elsif typ.class.has_method? :from_bson %}
              when BSON, BSON::Value
                @{{ key }} = {{ typ }}.from_bson(bson_value)
              {% elsif typ <= Int || typ <= Float %}
              when {{ typ }}
                @{{ key }} = bson_value.as({{ typ }})
              {% unless number_conversion_added %}
              # ameba:disable Lint/UselessAssign
              {% number_conversion_added = true %}
              when Int, Float
                @{{ key }} = {{typ}}.new!(bson_value)
              {% end %}
              {% else %}
              when {{ typ }}
                @{{ key }} = bson_value.as({{ typ }})
              {% end %}
              {% end %}
              else
                raise Exception.new "Unable to deserialize key (#{{{key.stringify}}}) having value (#{bson_value}) and of type (#{bson_value.class}) belonging to type '#{{{@type.stringify}}}'. Expected type(s) '#{{{types}}}'."
              end
            {% if !ivar.type.nilable? && !ivar.has_default_value? %}
            else
              # The key is required but was not found - or nil.
              raise Exception.new "Unable to deserialize key (#{{{key.stringify}}}) having value (#{bson_value}) of type (#{bson_value.class}) belonging to type '#{{{@type.stringify}}}'. Expected type(s) '#{{{types}}}'."
            {% elsif ivar.type.nilable? %}
            else
              @{{ key }} = nil
            {% end %}
            end
          {% end %}
        {% end %}
      {% end %}
    end

    # NOTE: See `self.new`.
    def self.from_bson(bson : BSON)
      self.new(bson)
    end

    # Converts to a BSON representation.
    #
    # ```
    # user = User.new name: "John"
    # bson = user.to_bson
    # ```
    def to_bson(bson = BSON.new)
      {% begin %}
      {% global_options = @type.annotations(BSON::Options) %}
      {% camelize = global_options.reduce(false) { |_, a| a[:camelize] } %}
      {% for ivar in @type.instance_vars %}
        {% ann = ivar.annotation(BSON::Field) %}
        {% typ = ivar.type.union_types.select { |t| t != Nil }[0] %}
        {% key = ivar.name %}
        {% bson_key = ann ? ann[:key].id : camelize ? ivar.name.camelcase(lower: camelize == "lower") : ivar.name %}
        {% unless ann && ann[:ignore] %}
          {% getter_names = [key + "?", key, key + "!"] %}
          {% getter_name = getter_names.find { |name| @type.has_method? name } %}
          {% if getter_name %}
            {% unless ann && ann[:emit_null] %}
              unless self.{{ getter_name }}.nil?
            {% end %}
              {% if typ.has_method? :to_bson %}
                bson["{{ bson_key }}"] = self.{{ getter_name }}.try &.to_bson
              {% else %}
                bson["{{ bson_key }}"] = self.{{ getter_name }}
              {% end %}
            {% unless ann && ann[:emit_null] %}
              end
            {% end %}
          {% end %}
        {% end %}
      {% end %}
      {% end %}
      bson
    end

    {% end %}
  end
end
