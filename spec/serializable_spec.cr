require "./spec_helper"

class Inner
  include BSON::Serializable
  include JSON::Serializable

  property key : String?
end

class Outer
  include BSON::Serializable
  include JSON::Serializable

  def initialize(**args)
    {% for ivar in @type.instance_vars %}
      {% if ivar.type.nilable? %}
        instance.{{ivar.id}} = args["{{ivar.id}}"]?
      {% else %}
        instance.{{ivar.id}} = args["{{ivar.id}}"]
      {% end %}
    {% end %}
  end

  property str : String
  property optional_int : Int32?
  property array_of_union_types : Array(String | Int32)
  property nested_object : Inner
  property array_of_objects : Array(Inner)
  property free_form : JSON::Any
  property hash : Hash(String, String | Int32)
  property named_tuple : {int: Int32, string: String}

  @[BSON::Field(key: other_str)]
  @[JSON::Field(key: other_str)]
  property renamed_string : String

  @[BSON::Field(ignore: true)]
  @[JSON::Field(ignore: true)]
  property ignored_field : String?
end

@[BSON::Options(camelize: true)]
class CamelizeTest
  include BSON::Serializable
  include JSON::Serializable

  property snake_case_field : String
  property other : Int32
end

@[BSON::Options(camelize: "lower")]
class LowerCamelizeTest
  include BSON::Serializable
  include JSON::Serializable

  property snake_case_field : String
  property other : Int32
end

class GettersTest
  include BSON::Serializable
  include JSON::Serializable

  property regular : String
  property? optional : String
  property! mandatory : String
  @ignored : Bool = true
end

reference_json = %({
      "str": "str",
      "optional_int": 10,
      "array_of_union_types": [
          10,
          "str"
      ],
      "nested_object": {
          "key": "value"
      },
      "array_of_objects": [
          {
              "key": "0"
          }
      ],
      "free_form": {
          "one": 1,
          "two": "two"
      },
      "hash": {
          "one": 1,
          "two": "two"
      },
      "named_tuple": {
        "int": 1,
        "string": "str"
      },
      "other_str": "str"
  })

describe BSON::Serializable do
  it "should perform a round-trip" do
    bson = BSON.new
    bson["str"] = "str"
    bson["optional_int"] = 10
    bson["array_of_union_types"] = [10, "str"]
    bson["nested_object"] = {key: "value"}
    bson["array_of_objects"] = [{
      "key": "0",
    }]
    free_form = BSON.new
    free_form["one"] = 1
    free_form["two"] = "two"
    bson["free_form"] = free_form
    hash = BSON.new
    hash["one"] = 1
    hash["two"] = "two"
    bson["hash"] = hash
    named_tuple = BSON.new
    named_tuple["int"] = 1
    named_tuple["string"] = "str"
    bson["named_tuple"] = named_tuple
    bson["other_str"] = "str"

    expected_json = JSON.parse(reference_json).to_json

    # bson -> json
    JSON.parse(bson.to_json).to_json.should eq expected_json

    # bson -> bson::serializable
    bson["ignored_field"] = "nope"
    instance = Outer.from_bson bson
    # test the annotations
    instance.renamed_string.should eq bson["other_str"]
    instance.ignored_field.should be_nil
    # bson::serializable -> json
    instance.to_json.should eq expected_json
    # bson::serializable -> bson -> json
    JSON.parse(instance.to_bson.to_json).to_json.should eq expected_json
  end

  it "should camelize keys" do
    json = %({
      "snake_case_field": "test",
      "other": 1
    })

    test = CamelizeTest.from_json(json)
    bson = test.to_bson
    bson.each { |key, value|
      case key
      when "SnakeCaseField"
        value.should eq test.snake_case_field
      when "Other"
        value.should eq test.other
      else
        raise "Bad key: #{key}"
      end
    }
    round_trip = CamelizeTest.from_bson(bson)
    round_trip.snake_case_field.should eq test.snake_case_field
    round_trip.other.should eq test.other

    test = LowerCamelizeTest.from_json(json)
    bson = test.to_bson
    bson.each { |key, value|
      case key
      when "snakeCaseField"
        value.should eq test.snake_case_field
      when "other"
        value.should eq test.other
      else
        raise "Bad key: #{key}"
      end
    }
    round_trip = LowerCamelizeTest.from_bson(bson)
    round_trip.snake_case_field.should eq test.snake_case_field
    round_trip.other.should eq test.other
  end

  it "should take into account associated getters" do
    json = %({
      "regular": "regular",
      "optional": "optional",
      "mandatory": "mandatory"
    })

    test = GettersTest.from_json(json)
    bson = test.to_bson
    bson.each { |key, value|
      case key
      when "regular"
        value.should eq test.regular
      when "optional"
        value.should eq test.optional?
      when "mandatory"
        value.should eq test.mandatory
      else
        raise "Bad key: #{key}"
      end
    }
  end
end
