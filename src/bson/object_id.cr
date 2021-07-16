struct BSON
  # Unique object identifier.
  #
  # See: dochub.mongodb.org/core/objectids
  struct ObjectId
    include Comparable(ObjectId)

    # This converter can be used to serialize the ObjectId to a String value.
    #
    # ```
    # @[JSON::Field(converter: BSON::ObjectId::StringConverter)]
    # property _id : BSON::ObjectId
    # ```
    module StringConverter
      def self.from_json(pull : JSON::PullParser) : BSON::ObjectId
        BSON::ObjectId.new pull.read_string
      end

      def self.to_json(value : BSON::ObjectId, builder : JSON::Builder)
        builder.string value.to_s
      end
    end

    getter data : Bytes

    @@counter : Int32 = rand(0x1000000)
    @@mutex = Mutex.new
    # Fixed random bytes in order to have a better ordering.
    @@random_bytes : Bytes = Random.new.random_bytes(5)

    # Initialize from a hex string representation.
    def initialize(str : String)
      @data = str.hexbytes
    end

    # Initialize from a Byte array.
    def initialize(@data : Bytes); end

    # Initialize from a JSON object.
    def self.new(pull : JSON::PullParser)
      pull.read_begin_object
      key = pull.read_object_key
      raise "ObjectID key must be $oid but is #{key}." if key != "$oid"
      value = BSON::ObjectId.new pull.read_string
      pull.read_end_object
      value
    end

    # Create a random ObjectId.
    def initialize
      io = IO::Memory.new
      io.write_bytes Time.utc.to_unix.to_u32, IO::ByteFormat::BigEndian
      io.write @@random_bytes
      counter = @@mutex.synchronize {
        @@counter = (@@counter + 1) % 0xFFFFFF
      }
      counter_slice = Bytes.new(4)
      IO::ByteFormat::BigEndian.encode(counter, counter_slice)
      io.write counter_slice[1..3]
      @data = io.to_slice
    end

    # Return a string hex representation of the ObjectId.
    def to_s(io : IO) : Nil
      io << @data.hexstring
    end

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

    # Serialize to a canonical extended json representation.
    #
    # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$oid")
        builder.scalar(@data.hexstring)
      }
    end

    def <=>(other : ObjectId)
      @data <=> other.data
    end

    # Validate that a provided string is a well formated ObjectId.
    def self.validate(id : String) : Bool
      id.hexbytes?.try &.size == 12
    end
  end
end
