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

  @[BSON::Field(key: other_str)]
  @[JSON::Field(key: other_str)]
  property renamed_string : String

  @[BSON::Field(ignore: true)]
  @[JSON::Field(ignore: true)]
  property ignored_field : String?
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
      "other_str": "str"
  })

describe BSON::Serializable do
  it "should perform a round-trip" do
    bson = BSON.new
    bson["str"] = "str"
    bson["optional_int"] = 10
    bson["array_of_union_types"] = [10, "str"]
    bson["nested_object"] = { key: "value" }
    bson["array_of_objects"] = [{
      "key": "0"
    }]
    free_form = BSON.new
    free_form["one"] = 1
    free_form["two"] = "two"
    bson["free_form"] = free_form
    hash = BSON.new
    hash["one"] = 1
    hash["two"] = "two"
    bson["hash"] = hash
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
end