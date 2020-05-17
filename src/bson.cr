require "json"
require "base64"
require "./bson/*"
require "./bson/ext/*"

struct BSON
  VERSION = "0.1.0"

  alias Value =
    Float64 |
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
    Symbol |
    Timestamp |
    MinKey |
    MaxKey |
    Undefined |
    Code |
    Symbol |
    Binary |
    Nil

  include Enumerable(Value)
  include Iterable(Value)
  include Comparable(BSON)

  getter data

  enum Element : UInt8
    Double = 0x01
    String = 0x02
    Document = 0x03
    Array = 0x04
    Binary = 0x05
    Undefined = 0x06
    ObjectId = 0x07
    Boolean = 0x08
    DateTime = 0x09
    Null = 0x0A
    Regexp = 0x0B
    DBPointer = 0x0C
    JSCode = 0x0D
    Symbol = 0x0E
    JSCodeWithScope = 0x0F
    Int32 = 0x10
    Timestamp = 0x11
    Int64 = 0x12
    Decimal128 = 0x13
    MinKey = 0xFF
    MaxKey = 0x7F
  end

  def initialize(data : Bytes? = nil)
    if d = data
      size = data[0..4].to_unsafe.as(Pointer(Int32)).value
      BSON.check_size! data.size, 5, size
      @data = d.clone
    else
      @data = Bytes.new(5)
    end
  end

  def initialize(tuple : NamedTuple)
    builder = Builder.new
    tuple.each { |key, value|
      builder["#{key}"] = value
    }
    @data = builder.to_bson
  end

  def initialize(h : Hash)
    builder = Builder.new
    h.each { |key, value|
      builder["#{key}"] = value
    }
    @data = builder.to_bson
  end

  def initialize(pull : JSON::PullParser)
    builder = Builder.new
    is_array = pull.kind.begin_array?

    if is_array
      index = 0
      pull.read_array do
        BSON.write_json_key_value(pull.kind, index.to_s, builder, pull)
        index += 1
      end
    else
      pull.read_object do |key|
        kind = pull.kind
        BSON.write_json_key_value(kind, key, builder, pull)
      end
    end

    @data = builder.to_bson
  end

  # ameba:disable Metrics/CyclomaticComplexity
  protected def self.write_json_key_value(kind : JSON::PullParser::Kind, key : String, builder : Builder, pull : JSON::PullParser)
    case kind
    when .null?
      builder[key] = pull.read_null
    when .bool?
      builder[key] = pull.read_bool
    when .int?
      builder[key] = pull.read_int
    when .float?
      builder[key] = pull.read_float
    when .string?
      builder[key] = pull.read_string
    when .begin_array?
      builder.append_array(key, BSON.new(pull))
    when .begin_object?
      pull.read_begin_object
      if pull.kind.end_object?
        builder[key] = BSON.new(Builder.new.to_bson)
      else
        inner_key = pull.read_object_key
        case inner_key
        when "$oid"
          builder[key] = ObjectId.new(pull.read_string)
        when "$symbol"
          builder[key] = Symbol.new(pull.read_string)
        when "$numberDouble"
          double_str = pull.read_string
          if double_str == "Infinity"
            builder[key] = Float64::INFINITY
          elsif double_str == "-Infinity"
            builder[key] = -Float64::INFINITY
          elsif double_str == "NaN"
            builder[key] = Float64::NAN
          else
            raise "Invalid double string representation: #{double_str}"
          end
        when "$numberDecimal"
          builder[key] = Decimal128.new(pull.read_string)
        when "$binary"
          binary_base64 = ""
          binary_subtype : Binary::SubType = :generic
          pull.read_object { |binary_key|
            if binary_key == "base64"
              binary_base64 = pull.read_string
            elsif binary_key == "subType"
              binary_subtype = Binary::SubType.from_value(pull.read_string.hexbytes.to_unsafe.value)
            else
              pull.read_next
            end
          }
          binary_bytes = Base64.decode(binary_base64)
          if binary_subtype.uuid?
            builder[key] = UUID.new(binary_bytes)
          else
            builder[key] = Binary.new(binary_subtype, binary_bytes)
          end
        when "$code"
          code_str = pull.read_string
          scope_document = nil
          unless pull.kind.end_object?
            pull.read_object_key
            scope_document = BSON.new(pull)
          end
          builder[key] = Code.new(code_str, scope_document)
        when "$timestamp"
          timestamp_i = timestamp_t = 0
          pull.read_object { |timestamp_key|
            if timestamp_key == "i"
              timestamp_i = pull.read_int
            elsif timestamp_key == "t"
              timestamp_t = pull.read_int
            else
              pull.read_next
            end
          }
          builder[key] = Timestamp.new(timestamp_t.to_u32, timestamp_i.to_u32)
        when "$regularExpression"
          regex_pattern = ""
          regex_options = ""

          pull.read_object { |regex_key|
            if regex_key == "pattern"
              regex_pattern = pull.read_string
            elsif regex_key == "options"
              regex_options = pull.read_string
            else
              pull.read_next
            end
          }

          regex_modifiers = Regex::Options::None
          regex_modifiers |= Regex::Options::IGNORE_CASE if regex_options.index('i')
          regex_modifiers |= Regex::Options::MULTILINE if regex_options.index('m') || regex_options.index('s')
          regex_modifiers |= Regex::Options::EXTENDED if regex_options.index('x')
          regex_modifiers |= Regex::Options::UTF_8 if regex_options.index('u')

          builder[key] = Regex.new(regex_pattern, regex_modifiers)
        when "$dbPointer"
          db_ref = ""
          db_oid = ""
          pull.read_object { |db_ptr_key|
            if db_ptr_key == "$ref"
              db_ref = pull.read_string
            elsif db_ptr_key == "$id"
              pull.read_object { |oid_key|
                if oid_key === "$oid"
                  db_oid = pull.read_string
                else
                  pull.read_next
                end
              }
            else
              pull.read_next
            end
          }
          builder[key] = DBPointer.new(db_ref, ObjectId.new db_oid)
        when "$date"
          if pull.kind.string?
            builder[key] = Time.new(pull)
          else
            date_time = ""
            pull.read_object { |date_key|
              if date_key === "$numberLong"
                date_time = pull.read_string
              else
                pull.read_next
              end
            }
            builder[key] = Time.unix_ms(date_time.to_i64)
          end
        when "$minKey"
          builder[key] = MinKey.new
          pull.read_next
        when "$maxKey"
          builder[key] = MaxKey.new
          pull.read_next
        when "$undefined"
          builder[key] = Undefined.new
          pull.read_next
        else
          object_builder = Builder.new
          until pull.kind.end_object?
            BSON.write_json_key_value(pull.kind, inner_key, object_builder, pull)
            inner_key = pull.read_object_key unless pull.kind.end_object?
          end
          builder[key] = BSON.new(object_builder.to_bson)
        end
      end
      pull.read_end_object
    else
      # Ignore
    end
  end

  def []=(key : String | Symbol, value)
    io = IO::Memory.new
    io.write @data[4...-2]
    builder = Builder.new(io)
    builder["#{key}"] = value
    @data = builder.to_bson
  end

  def []?(key : String | Symbol) : Value?
    pointer = @data.to_unsafe
    size = pointer.as(Pointer(Int32)).value
    pos = 4

    loop do
      break if (pointer + pos).value == 0

      # Element code
      code = Element.new((pointer + pos).value)
      pos += 1
      # Field name
      field = String.new(pointer + pos)
      pos += field.bytesize + 1

      if field == key
        _, data = BSON.decode_field!(pointer, pos, { code, field }, max_pos: size)
        return data[1]
      else
        pos = BSON.skip_field(code, pointer, pos, max_pos: size)
      end
    end
  end

  def [](key : String | Symbol) : Value
    raise "Missing bson key: #{key}" unless value = self.[]?(key)
    value
  end

  def append(**args)
    size = @data.to_unsafe.as(Pointer(Int32)).value
    io.write @data[4...-2]
    io = IO::Memory.new(size)
    builder = Builder.new(io)
    args.each { |key, value|
      builder["#{key}"] = value
    }
    @data = builder.to_bson
  end

  def <=>(other : BSON)
    self.data <=> other.data
  end

  # ameba:disable Metrics/CyclomaticComplexity
  protected def self.skip_field(code, pointer, pos, *, max_pos = nil)
    case code
    when Element::Double
      pos += 8
    when Element::String
      str_size = (pointer + pos).as(Pointer(Int32)).value
      pos += 4 + str_size
    when Element::Document
      size = (pointer + pos).as(Pointer(Int32)).value
      pos += size
    when Element::Array
      size = (pointer + pos).as(Pointer(Int32)).value
      pos += size
    when Element::Binary
      size = (pointer + pos).as(Pointer(Int32)).value
      pos += 4 # int32 size
      pos += 1 # byte subtype
      pos += size # binary size
    when Element::Undefined
      # size 0
    when Element::ObjectId
      pos += 12
    when Element::Boolean
      pos += 1
    when Element::DateTime
      pos += 8
    when Element::Null
      # size 0
    when Element::Regexp
      # 2 cstrings
      2.times do
        loop do
          break if (pointer + pos).value == 0x00
          break if max_pos && pos >= max_pos
          pos += 1
        end
      end
    when Element::DBPointer
      str_size = (pointer + pos).as(Pointer(Int32)).value
      pos += 4 + str_size + 12
    when Element::JSCode
      str_size = (pointer + pos).as(Pointer(Int32)).value
      pos += 4 + str_size
    when Element::Symbol
      str_size = (pointer + pos).as(Pointer(Int32)).value
      pos += 4 + str_size
    when Element::JSCodeWithScope
      field_size = (pointer + pos).as(Pointer(Int32)).value
      pos += field_size
    when Element::Int32
      pos += 4
    when Element::Timestamp
      pos += 8
    when Element::Int64
      pos += 8
    when Element::Decimal128
      pos += 16
    when Element::MinKey
      # 0
    when Element::MaxKey
      # 0
    else
      raise "Invalid BSON field code. Pos: #{pos}"
    end

    # Return new position
    pos
  end

  private def self.check_overflow!(pos, offset, max_pos)
    raise "Invalid BSON (overflow)" if pos + offset >= max_pos
  end

  protected def self.check_size!(size, min_size = 0, compare_to = nil)
    if size < min_size || (compare_to && size != compare_to)
      raise "Invalid BSON (wrong field size: #{size})"
    end
  end

  private def self.decode_string!(ptr, size = nil)
    if size
      str = String.new(ptr, size)
      raise "Invalid string is not null-terminated: #{str}" unless (ptr + size).value == 0x00
    else
      str = String.new(ptr)
    end
    raise "Invalid utf-8 encoding: #{str}" unless str.valid_encoding?
    str
  end

  # ameba:disable Metrics/CyclomaticComplexity
  protected def self.decode_field!(pointer, pos, header = nil, max_pos = nil)
    if header
      code, key = header
    else
      # Element code
      code = Element.new((pointer + pos).value)
      pos += 1
      # Field name
      key = decode_string!(pointer + pos)
      pos += key.bytesize + 1
    end

    # Switch on element code
    case code
    when Element::Double
      value = (pointer + pos).as(Pointer(Float64)).value
      pos += 8
    when Element::String
      str_size = (pointer + pos).as(Pointer(Int32)).value
      check_size! str_size
      pos += 4
      check_overflow! pos, str_size, max_pos
      value = decode_string!(pointer + pos, str_size - 1)
      check_size! str_size, compare_to: value.bytesize + 1
      pos += str_size
    when Element::Document
      size = (pointer + pos).as(Pointer(Int32)).value
      check_size! size, 5
      check_overflow! pos, size, max_pos
      value = BSON.new(Bytes.new(pointer + pos, size, read_only: true))
      pos += size
    when Element::Array
      size = (pointer + pos).as(Pointer(Int32)).value
      check_size! size, 5
      check_overflow! pos, size, max_pos
      value = BSON.new(Bytes.new(pointer + pos, size, read_only: true))
      pos += size
    when Element::Binary
      size = (pointer + pos).as(Pointer(Int32)).value
      check_size! size
      check_overflow! pos, size, max_pos
      pos += 4
      subtype = Binary::SubType.new((pointer + pos).value)
      pos += 1
      if subtype == Binary::SubType::UUID
        value = UUID.new(Bytes.new(pointer + pos, size, read_only: true))
      elsif subtype == Binary::SubType::Binary_Old
        old_binary_size = (pointer + pos).as(Pointer(Int32)).value
        check_size! old_binary_size, compare_to: size - 4
        value = Bytes.new(pointer + pos + 4, old_binary_size, read_only: true)
      else
        value = Bytes.new(pointer + pos, size, read_only: true)
      end
      pos += size
    when Element::Undefined
      value = Undefined.new
    when Element::ObjectId
      oid = ObjectId.new(Bytes.new(pointer + pos, 12, read_only: true))
      value = oid
      pos += 12
    when Element::Boolean
      bool_value = (pointer + pos).value
      if bool_value != 0 && bool_value != 1
        raise "Invalid BSON bool value: #{bool_value}"
      end
      value = bool_value != 0
      pos += 1
    when Element::DateTime
      value = Time.unix_ms((pointer + pos).as(Pointer(Int64)).value)
      pos += 8
    when Element::Null
      value = nil
    when Element::Regexp
      pattern_size = 0
      loop do
        break if (pointer + pos + pattern_size).value == 0x00
        if (max_pos && (pos + pattern_size) >= max_pos)
          raise "Invalid Regexp field (string overflow): #{key}"
        end
        pattern_size += 1
      end
      check_size! pattern_size
      check_overflow! pos, pattern_size, max_pos
      pattern = decode_string!(pointer + pos, pattern_size)
      pos += pattern_size + 1

      opts_size = 0
      loop do
        break if (pointer + pos + opts_size).value == 0x00
        if (max_pos && (pos + opts_size) >= max_pos)
          raise "Invalid Regexp field (string overflow): #{key}"
        end
        opts_size += 1
      end
      check_size! opts_size
      opts = decode_string!(pointer + pos, opts_size)
      pos += opts_size + 1

      modifiers = Regex::Options::None
      modifiers |= Regex::Options::IGNORE_CASE if opts.index('i')
      modifiers |= Regex::Options::MULTILINE if opts.index('m') || opts.index('s')
      modifiers |= Regex::Options::EXTENDED if opts.index('x')
      modifiers |= Regex::Options::UTF_8 if opts.index('u')

      value = Regex.new(pattern, modifiers)
    when Element::DBPointer
      str_size = (pointer + pos).as(Pointer(Int32)).value
      check_size! str_size
      check_overflow! pos, str_size, max_pos
      pos += 4
      str = decode_string!(pointer + pos, str_size - 1)
      pos += str_size
      oid = ObjectId.new(Bytes.new(pointer + pos, 12, read_only: true))
      pos += 12
      value = DBPointer.new(str, oid)
    when Element::JSCode
      str_size = (pointer + pos).as(Pointer(Int32)).value
      check_size! str_size
      check_overflow! pos, str_size, max_pos
      pos += 4
      value = Code.new(decode_string!(pointer + pos, str_size - 1))
      pos += str_size
    when Element::Symbol
      str_size = (pointer + pos).as(Pointer(Int32)).value
      check_size! str_size
      check_overflow! pos, str_size, max_pos
      pos += 4
      value = Symbol.new(decode_string!(pointer + pos, str_size - 1))
      pos += str_size
    when Element::JSCodeWithScope
      field_size = (pointer + pos).as(Pointer(Int32)).value
      check_size! field_size, 10
      check_overflow! pos, field_size, max_pos
      pos += 4
      str_size = (pointer + pos).as(Pointer(Int32)).value
      check_size! str_size
      check_overflow! pos, str_size, max_pos
      pos += 4
      js_code = decode_string!(pointer + pos, str_size - 1)
      pos += str_size
      doc_size = (pointer + pos).as(Pointer(Int32)).value
      check_size! doc_size, 5
      check_overflow! pos, doc_size, max_pos
      scope = BSON.new(Bytes.new(pointer + pos, doc_size, read_only: true))
      pos += doc_size
      check_size! field_size, str_size + doc_size + 8
      value = Code.new(js_code, scope)
    when Element::Int32
      value = (pointer + pos).as(Pointer(Int32)).value
      pos += 4
    when Element::Timestamp
      i = (pointer + pos).as(Pointer(UInt32)).value
      pos += 4
      t = (pointer + pos).as(Pointer(UInt32)).value
      pos += 4
      value =  Timestamp.new(t, i)
    when Element::Int64
      value = (pointer + pos).as(Pointer(Int64)).value
      pos += 8
    when Element::Decimal128
      bytes = Bytes.new(16)
      bytes.copy_from(pointer + pos, 16)
      value = Decimal128.new(bytes)
      pos += 16
    when Element::MinKey
      value = MinKey.new
    when Element::MaxKey
      value = MaxKey.new
    else
      raise "Invalid BSON field code."
    end

    # Return field data and new position
    { pos, { key, value, code, subtype } }
  end

  def each(&block : ({ String, Value, Element, Binary::SubType? }) -> _)
    pointer = @data.to_unsafe
    size = pointer.as(Pointer(Int32)).value
    pos = 4

    loop do
      if (pointer + pos).value == 0x00
        raise "Invalid BSON size." if pos != size - 1
        break
      end
      raise "Invalid BSON size." if pos >= size

      new_pos, data = BSON.decode_field!(pointer, pos, max_pos: size)
      pos = new_pos

      yield data
    end
  end

  def each
    Iterator.new(self)
  end

  private struct Iterator
    include ::Iterator(BSON)

    @data : Bytes
    @pos = 4

    def initialize(bson : BSON)
      @data = bson.data.clone
    end

    def next
      pointer = @data.to_unsafe

      return Iterator::Stop::INSTANCE if (pointer + @pos).value == 0

      new_pos, data = BSON.decode_field!(pointer, @pos, max_pos: @data.size)
      @pos = new_pos

      data
    end
  end

  def to_h
    hash = Hash(String, Value).new
    self.each { |(key, value)|
      hash[key] = value
    }
    hash
  end

  def validate!
    self.each { |(k,v)|
      { k, v }
    }
  end

  def self.from_json(json : String)
    self.new(JSON::PullParser.new json)
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def to_json(builder : JSON::Builder, *, array = false)
    block = ->() {
      self.each { |(key, value, code, subtype)|
        builder.string(key) unless array
        if code == Element::Array && value.is_a? BSON
          value.to_json(builder, array: true)
        elsif code == Element::Document && value.is_a? BSON
          value.to_json(builder, array: false)
        elsif code == Element::Binary && value.is_a? Bytes
          value.to_canonical_extjson(builder, subtype)
        elsif value.is_a? Int32
          value.to_json(builder)
        elsif value.is_a? Int64
          value.to_json(builder)
        elsif value.is_a? Float64
          if value.nan? || value.infinite?
            value.to_canonical_extjson(builder)
          else
            value.to_json(builder)
          end
        elsif value.is_a? Time && value.year >= 1970 && value.year <= 9999
          value.to_relaxed_extjson(builder)
        elsif value.responds_to? :to_canonical_extjson
          value.to_canonical_extjson(builder)
        else
          builder.scalar(nil)
        end
      }
    }
    if array
      builder.array &block
    else
      builder.object &block
    end
  end

  def to_canonical_extjson(builder : JSON::Builder, *, array = false)
    block = ->() {
      self.each { |(key, value, code, subtype)|
        builder.string(key) unless array
        if code == Element::Array && value.is_a? BSON
          value.to_canonical_extjson(builder, array: true)
        elsif code == Element::Binary && value.is_a? Bytes
          value.to_canonical_extjson(builder, subtype)
        elsif value.responds_to? :to_canonical_extjson
          value.to_canonical_extjson(builder)
        else
          builder.scalar(nil)
        end
      }
    }
    if array
      builder.array &block
    else
      builder.object &block
    end
  end

  def to_canonical_extjson
    io = IO::Memory.new
    builder = JSON::Builder.new io
    builder.start_document
    self.to_canonical_extjson(builder)
    builder.end_document
    io.to_s
  end
end
