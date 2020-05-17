require "uuid"

struct BSON
  # Binary data.
  struct Binary
    # BSON binary values have a subtype. This is used to indicate what kind of data is in the byte array.
    # Subtypes from zero to 127 are predefined or reserved. Subtypes from 128-255 are user-defined.
    enum SubType : UInt8
      Generic = 0x00
      Function = 0x01
      Binary_Old = 0x02
      UUID_Old = 0x03
      UUID = 0x04
      MD5 = 0x05
      EncryptedBSON = 0x06
      UserDefined = 0x80
    end

    getter subtype, data

    def initialize(@subtype : SubType, data : Bytes)
      @data = data
    end

    def initialize(uuid : UUID)
      @subtype = SubType::UUID
      @data = uuid.bytes.to_slice.clone
    end
  end
end
