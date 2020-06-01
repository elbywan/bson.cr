module BSON::Serializable
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
  annotation BSON::Options
  end

  # This annotation can be used to ignore or rename properties.
  #
  # ```
  # @[BSON::Field(ignore: true)]
  # property ignored_property : Type
  # @[BSON::Field(key: new_name)]
  # property renamed_property
  # ```
  annotation BSON::Field
  end

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
      {{@type}}.from_bson bson
    end

    # NOTE: See `self.new`.
    def self.from_bson(bson : BSON)
      instance = allocate

      {% begin %}
      {% global_options = @type.annotations(BSON::Options) %}
      {% camelize = global_options.reduce(false) { |_, a| a[:camelize] } %}

      {% for ivar in @type.instance_vars %}
        {% ann = ivar.annotation(BSON::Field) %}
        {% types = ivar.type.union_types.select { |t| t != Nil } %}
        {% key = ivar.name %}
        {% bson_key = ann ? ann[:key].id : camelize ? ivar.name.camelcase(lower: camelize == "lower") : ivar.name %}

        {% unless ann && ann[:ignore] %}
          bson_value = bson["{{ bson_key }}"]?
          if !bson_value.nil?
            case bson_value
            {% for typ in types %}
            {% if typ <= BSON::Serializable || typ.class.has_method? :from_bson %}
            when BSON
              instance.{{ key }} = {{ typ }}.from_bson(bson_value)
            {% elsif typ <= Int %}
            when {{ typ }}
              instance.{{ key }} = bson_value.as({{ typ }})
            when Int, Float
              instance.{{ key }} = {{typ}}.new!(bson_value)
            {% elsif typ <= Float %}
            when {{ typ }}
              instance.{{ key }} = bson_value.as({{ typ }})
            when Int, Float
              instance.{{ key }} = {{typ}}.new!(bson_value)
            {% else %}
            when {{ typ }}
              instance.{{ key }} = bson_value.as({{ typ }})
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
            instance.{{ key }} = nil
          {% end %}
          end
        {% end %}
      {% end %}
      {% end %}

      instance
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
          {% unless ann && ann[:emit_null] %}
            unless self.{{ key }}.nil?
          {% end %}
            {% if typ.has_method? :to_bson %}
              bson["{{ bson_key }}"] = self.{{ key }}.to_bson
            {% else %}
              bson["{{ bson_key }}"] = self.{{ key }}
            {% end %}
          {% unless ann && ann[:emit_null] %}
            end
          {% end %}
        {% end %}
      {% end %}
      {% end %}
      bson
    end

    {% end %}
  end
end
