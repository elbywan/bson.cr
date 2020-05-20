struct BSON
  # List of field values
  alias Value = Float64 |
                String |
                BSON |
                Bytes |
                ObjectId |
                Bool |
                Time |
                Int32 |
                Int64 |
                UUID |
                Code |
                Regex |
                Decimal128 |
                DBPointer |
                BSON::Symbol |
                Timestamp |
                MinKey |
                MaxKey |
                Undefined |
                Code |
                Nil

  # Used for recursive hash conversions.
  alias RecursiveValue = Float64 |
                         String |
                         BSON |
                         Bytes |
                         ObjectId |
                         Bool |
                         Time |
                         Int32 |
                         Int64 |
                         UUID |
                         Code |
                         Regex |
                         Decimal128 |
                         DBPointer |
                         BSON::Symbol |
                         Timestamp |
                         MinKey |
                         MaxKey |
                         Undefined |
                         Code |
                         Nil |
                         Hash(String, RecursiveValue) |
                         Array(RecursiveValue)

  # List of BSON elements
  enum Element : UInt8
    Double          = 0x01
    String          = 0x02
    Document        = 0x03
    Array           = 0x04
    Binary          = 0x05
    Undefined       = 0x06
    ObjectId        = 0x07
    Boolean         = 0x08
    DateTime        = 0x09
    Null            = 0x0A
    Regexp          = 0x0B
    DBPointer       = 0x0C
    JSCode          = 0x0D
    Symbol          = 0x0E
    JSCodeWithScope = 0x0F
    Int32           = 0x10
    Timestamp       = 0x11
    Int64           = 0x12
    Decimal128      = 0x13
    MinKey          = 0xFF
    MaxKey          = 0x7F
  end

  alias Item = {String, BSON::Value, BSON::Element, Binary::SubType?}
end
