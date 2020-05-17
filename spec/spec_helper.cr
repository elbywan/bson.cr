require "spec"
require "json"
require "../src/bson"

module Runner::Corpus
  extend self

  def run(name : String, *focus)
    corpus = File.open("./spec/corpus/#{name}.json") do |file|
      JSON.parse(file)
    end

    # Valid tests
    corpus["valid"]?.try &.as_a.each { |test|
      description = test["description"].as_s
      it description, focus: focus.includes?(description) do
        # Parse canonical bson
        bson_bytes = test["canonical_bson"].as_s.hexbytes
        bson = BSON.new(bson_bytes)
        # Ensure that the underlying bytes are equal
        bson.data.should eq bson_bytes
        # Serialize into canonical extended json and compare with the expected canonical json.
        bson.to_canonical_extjson.should eq JSON.parse(test["canonical_extjson"].as_s).to_json
        # Serialize into json and compare with the expected relaxed extended json.
        json = bson.to_json
        if relaxed_json = test["relaxed_extjson"]?
          json.should eq relaxed_json.as_s.gsub(' ', "")
        end
        # JSON roundtrip
        unless test["ignore_json_roundtrip"]?
          BSON.from_json(json).to_json.should eq json
        end
      end
    }

    # Errors
    corpus["decodeErrors"]?.try &.as_a.each { |test|
      description = test["description"].as_s
      it description, focus: focus.includes?(description), tags: "decode-errors" do
        expect_raises(Exception) {
          bson = BSON.new(test["bson"].as_s.hexbytes)
          bson.validate!
          puts bson.to_json
        }
      end
    }
  end
end
