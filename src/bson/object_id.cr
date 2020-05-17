struct BSON
  struct ObjectId

    getter data : Bytes

    @@counter : Int32 = rand(0x1000000)
    @@mutex = Mutex.new

    def initialize(str : String)
      @data = str.hexbytes
    end

    def initialize(@data : Bytes); end

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

    def to_s(io : IO) : Nil
      io << @data.hexstring
    end

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$oid")
        builder.scalar(@data.hexstring)
      }
    end
  end
end
