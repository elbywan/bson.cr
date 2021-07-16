require "./spec_helper"
require "base64"

describe BSON do
  describe "corpus tests" do
    {% begin %}
    {%
      files = %w(
        array
        binary
        boolean
        code_w_scope
        code
        datetime
        dbpointer
        dbref
        decimal128-1
        decimal128-2
        decimal128-3
        decimal128-4
        decimal128-5
        document
        double
        int32
        int64
        maxkey
        minkey
        multi-type-deprecated
        multi-type
        null
        oid
        regex
        string
        symbol
        timestamp
        top
        undefined
      )
    %}
    {% for file in files %}
      describe {{file}} do
        Runner::Corpus.run({{file}})
      end
    {% end %}
    {% end %}
  end

  describe "constructors" do
    it "#initialize(bytes)" do
      bson = BSON.new(REFERENCE_BYTES)
      bson.to_json.should eq JSON.parse(REFERENCE_JSON).to_json
      BSON.new(bson.data).data.should eq REFERENCE_BYTES
    end
    it "#initialize(io)" do
      io = IO::Memory.new(REFERENCE_BYTES)
      bson = BSON.new(io)
      bson.to_json.should eq JSON.parse(REFERENCE_JSON).to_json
      BSON.new(bson.data).data.should eq REFERENCE_BYTES
    end
    it "#initialize(tuple)" do
      bson = BSON.new(REFERENCE_TUPLE)
      bson.data.should eq REFERENCE_BYTES
    end
    it "#initialize(hash)" do
      bson = BSON.new(REFERENCE_TUPLE.to_h)
      bson.data.should eq REFERENCE_BYTES
    end
    it "#initialize(json)" do
      bson = BSON.from_json(REFERENCE_JSON)
      bson.data.should eq REFERENCE_BYTES
    end
  end

  describe "append" do
    merged_bson_data = BSON.new(REFERENCE_TUPLE.merge({
      field:  "value",
      field2: "value2",
    })).data

    it "#[]=" do
      bson = BSON.new(REFERENCE_TUPLE)
      bson["field"] = "value"
      bson["field2"] = "value2"
      bson.data.should eq merged_bson_data
    end

    it "#append(**args)" do
      bson = BSON.new(REFERENCE_TUPLE)
      bson.append(field: "value", field2: "value2")
      bson.data.should eq merged_bson_data
    end

    it "#append(bson)" do
      bson = BSON.new(REFERENCE_TUPLE)
      bson.append(BSON.new({field: "value", field2: "value2"}))
      bson.data.should eq merged_bson_data
    end
  end

  describe "fetch" do
    it "#[]" do
      bson = BSON.new(REFERENCE_TUPLE)
      REFERENCE_TUPLE.each { |k, v|
        if v.is_a? BSON::Binary
          bson[k].should eq v.data
        elsif v.is_a? Array
          v.each_with_index { |item, idx|
            bson[k].as(BSON)["#{idx}"].should eq item
          }
        else
          bson[k].should eq v
        end
      }
      expect_raises(Exception) {
        bson[:unknown_key]
      }
    end

    it "#[]?" do
      bson = BSON.new(REFERENCE_TUPLE)
      REFERENCE_TUPLE.each { |k, v|
        if v.is_a? BSON::Binary
          bson[k].should eq v.data
        elsif v.is_a? Array
          v.each_with_index { |item, idx|
            bson[k]?.as(BSON)["#{idx}"].should eq item
          }
        else
          bson[k]?.should eq v
        end
      }

      bson[:unknown_key]?.should be_nil
    end

    it "#dig" do
      bson = BSON.new(REFERENCE_TUPLE)
      bson.dig(:Subdocument, :foo).should eq "bar"
      expect_raises(Exception) {
        bson.dig(:Subdocument, :invalid_key)
      }
      expect_raises(Exception) {
        bson.dig(:invalid_key)
      }
    end

    it "#dig?" do
      bson = BSON.new(REFERENCE_TUPLE)
      bson.dig?(:Subdocument, :foo).should eq "bar"
      bson.dig?(:Subdocument, :invalid_key).should be_nil
      bson.dig?(:invalid_key).should be_nil
    end
  end

  describe "compare" do
    it "<=>" do
      comparison = BSON.new(REFERENCE_BYTES) <=> BSON.new(REFERENCE_BYTES)
      comparison.should eq 0

      comparison = BSON.new(REFERENCE_BYTES) <=> BSON.new({a: 1})
      comparison.should_not eq 0
    end

    it "ObjectId(<=>)" do
      iod = BSON::ObjectId.new
      iod2 = BSON::ObjectId.new(iod.data.hexstring)
      iod.should eq iod2
      iod.should_not eq BSON::ObjectId.new
    end
  end

  describe "iterate" do
    it "using an iterator" do
      bson = BSON.new(REFERENCE_TUPLE)
      bson.each.map { |(k, v, code, subtype)|
        if v.is_a? Bytes
          code.should eq BSON::Element::Binary
          REFERENCE_TUPLE[k].should eq BSON::Binary.new(subtype.not_nil!, v)
        elsif v.is_a? BSON && code == BSON::Element::Array
          v.each { |key, value|
            REFERENCE_TUPLE[k].as(Array)[key.to_i32].should eq value
          }
        else
          REFERENCE_TUPLE[k].should eq v
        end
      }.to_a
    end

    it "using an enumerable" do
      bson = BSON.new(REFERENCE_TUPLE)
      bson.each { |k, v, code, subtype|
        if v.is_a? Bytes
          code.should eq BSON::Element::Binary
          REFERENCE_TUPLE[k].should eq BSON::Binary.new(subtype.not_nil!, v)
        elsif v.is_a? BSON && code == BSON::Element::Array
          v.each { |key, value|
            REFERENCE_TUPLE[k].as(Array)[key.to_i32].should eq value
          }
        else
          REFERENCE_TUPLE[k].should eq v
        end
      }
    end
  end

  describe "convert" do
    it "to_h" do
      bson = BSON.new(REFERENCE_BYTES)
      bson.to_h.each { |k, v|
        if v.is_a? BSON::Binary
          bson[k].should eq v.data
        elsif v.is_a? Array
          v.each_with_index { |item, idx|
            bson[k]?.as(BSON)["#{idx}"].should eq item
          }
        elsif v.is_a? Hash
          v.each { |key, value|
            bson[k]?.as(BSON)[key].should eq value
          }
        else
          bson[k]?.should eq v
        end
      }
    end
  end

  describe "validate" do
    it "ObjectId" do
      BSON::ObjectId.validate(Random::Secure.hex(12)).should be_true
      BSON::ObjectId.validate(Random::Secure.base64(Random.rand(48))).should be_false
    end
  end
end
