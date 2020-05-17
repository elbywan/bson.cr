struct BSON
  # Unique object identifier.
  #
  # See: dochub.mongodb.org/core/objectids
  struct ObjectId

    getter data : Bytes

    @@counter : Int32 = rand(0x1000000)
    @@mutex = Mutex.new

    # Initialize from a hex string representation.
    def initialize(str : String)
      @data = str.hexbytes
    end

    # Initialize from a Byte array.
    def initialize(@data : Bytes); end

    # Create a random ObjectId.
    def initialize
      io = IO::Memory.new
      io.write_bytes Time.utc.to_unix.to_u32, IO::ByteFormat::LittleEndian
      io.write Random.new.random_bytes(5)
      counter = @@mutex.synchronize {
        @@counter = (@@counter + 1) % 0xFFFFFF
      }
      io.write counter.unsafe_as(StaticArray(UInt8, 3)).to_slice
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
  end
end
