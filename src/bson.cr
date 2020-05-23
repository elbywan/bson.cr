require "json"
require "base64"
require "./bson/helpers/*"
require "./bson/*"
require "./bson/ext/*"

# **BSON is a binary format in which zero or more ordered key/value pairs are stored as a single entity.**
#
# BSON [bee · sahn], short for Bin­ary JSON, is a bin­ary-en­coded seri­al­iz­a­tion of JSON-like doc­u­ments.
# Like JSON, BSON sup­ports the em­bed­ding of doc­u­ments and ar­rays with­in oth­er doc­u­ments and ar­rays.
# BSON also con­tains ex­ten­sions that al­low rep­res­ent­a­tion of data types that are not part of the JSON spec.
# For ex­ample, BSON has a Date type and a BinData type.
#
# [See: http://bsonspec.org/](http://bsonspec.org/)
#
# ```
# require "bson"
#
# data = BSON.new({
#   hello: "world",
#   time:  Time.utc,
#   name:  BSON.new({
#     first_name: "John",
#     last_name:  "Doe",
#   }),
#   fruits: ["Orange", "Banana"],
# })
#
# puts data.to_json
# # => {"hello":"world","time":{"$date":"2020-05-18T07:32:13.621000000Z"},"name":{"first_name":"John","last_name":"Doe"},"fruits":["Orange","Banana"]}
# ```
struct BSON
  # Underlying bytes
  getter data

  include Enumerable(Item)
  include Iterable(Item)
  include Comparable(BSON)

  # Allocate a BSON instance from a byte array.
  #
  # NOTE: The byte array is cloned.
  #
  # ```
  # data = "160000000378000E0000000261000200000062000000".hexbytes
  # io = IO::Memory.new(data)
  # bson = BSON.new(io)
  # puts bson.to_json # => {"x":{"a":"b"}}
  # ```
  def initialize(data : Bytes? = nil, validate? = false)
    if d = data
      size = data[0..4].to_unsafe.as(Pointer(Int32)).value
      Decoder.check_size! data.size, 5, size
      @data = d.clone
    else
      @data = Bytes.new(5)
      @data.to_unsafe.as(Pointer(Int32)).value = 5
    end
  end

  # Allocate a BSON instance from an IO
  #
  # ```
  # data = "160000000378000E0000000261000200000062000000".hexbytes
  # bson = BSON.new(data)
  # puts bson.to_json # => {"x":{"a":"b"}}
  # ```
  def initialize(io : IO)
    size = Int32.from_io(io, IO::ByteFormat::LittleEndian)
    Decoder.check_size! size, 5
    @data = Bytes.new(size)
    @data.to_unsafe.as(Pointer(Int32)).copy_from(pointerof(size), 4)
    io.read_fully(@data[4..])
  end

  # Allocate a BSON instance from a NamedTuple.
  #
  # ```
  # puts BSON.new({
  #   hello: "world",
  # }).to_json # => {"hello":"world"}
  # ```
  def initialize(tuple : NamedTuple)
    builder = Builder.new
    tuple.each { |key, value|
      builder["#{key}"] = value
    }
    @data = builder.to_bson
  end

  # Allocate a BSON instance from a Hash.
  #
  # ```
  # puts BSON.new({
  #   "hello" => "world",
  # }).to_json # => {"hello":"world"}
  # ```
  def initialize(h : Hash)
    builder = Builder.new
    h.each { |key, value|
      builder["#{key}"] = value
    }
    @data = builder.to_bson
  end

  # No-op
  def self.new(bson : BSON)
    bson
  end

  # Allocate a BSON instance from an Array.
  #
  # ```
  # puts BSON.new([1, 2, 3]).to_json # => [1,2,3]
  # ```
  def initialize(ary : Array)
    builder = Builder.new
    ary.each_with_index { |value, index|
      builder["#{index}"] = value
    }
    @data = builder.to_bson
  end

  protected def initialize(pull : JSON::PullParser)
    builder = Builder.new
    is_array = pull.kind.begin_array?

    if is_array
      index = 0
      pull.read_array do
        Decoder.decode_json_key(pull.kind, index.to_s, builder, pull)
        index += 1
      end
    else
      pull.read_object do |key|
        kind = pull.kind
        Decoder.decode_json_key(kind, key, builder, pull)
      end
    end

    @data = builder.to_bson
  end

  # Append a key/value pair.
  #
  # ```
  # bson = BSON.new
  # bson["key"] = "value"
  # puts bson.to_json # => {"key":"value"}
  # ```
  def []=(key : String | ::Symbol, value)
    io = IO::Memory.new
    io.write @data[4...-1]
    builder = Builder.new(io)
    if value.responds_to? :to_bson
      builder[key.to_s] = value.to_bson
    else
      builder[key.to_s] = value
    end
    @data = builder.to_bson
  end

  # Append one or more key/value pairs.
  #
  # NOTE: more efficient for appending multiple values than calling `[]=` individually.
  #
  # ```
  # bson = BSON.new
  # bson.append(key: "value", key2: "value2")
  # puts bson.to_json # => {"key":"value","key2":"value2"}
  # ```
  def append(**args)
    size = @data.to_unsafe.as(Pointer(Int32)).value
    io = IO::Memory.new(size)
    io.write @data[4...-1]
    builder = Builder.new(io)
    args.each { |key, value|
      builder["#{key}"] = value
    }
    @data = builder.to_bson
  end

  # Append the contents of another BSON instance.
  #
  # ```
  # bson = BSON.new
  # other_bson = BSON.new({ key: "value", key2: "value2"})
  # bson.append(other_bson)
  # puts bson.to_json # => {"key":"value","key2":"value2"}
  # ```
  def append(other : BSON)
    size = @data.to_unsafe.as(Pointer(Int32)).value
    io = IO::Memory.new(size)
    io.write @data[4...-1]
    builder = Builder.new(io)
    other.each { |(key, value)|
      builder["#{key}"] = value
    }
    @data = builder.to_bson
  end

  # Return the element with the given key, or `nil` if the key is not present.
  #
  # ```
  # bson = BSON.new({key: "value"})
  # puts bson["key"]?  # => "value"
  # puts bson["nope"]? # => nil
  # ```
  def []?(key : String | ::Symbol) : Value?
    fetch(key)[0]
  end

  # Return the element with the given key.
  #
  # NOTE: Will raise if the key is not found.
  #
  # ```
  # bson = BSON.new({ key: "value" })
  # puts bson["key"] # =>"value"
  # puts bson["nope"] # => Unhandled exception: Missing bson key: nope (Exception)
  def [](key : String | ::Symbol) : Value
    value, found = fetch(key)
    raise "Missing bson key: #{key}" unless found
    value
  end

  private def fetch(key : String | ::Symbol)
    key = key.to_s
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
        _, data = Decoder.decode_field!(pointer, pos, {code, field}, max_pos: size)
        return {data[1], true}
      else
        pos = Decoder.skip_field(code, pointer, pos, max_pos: size)
      end
    end

    return {nil, false}
  end

  # Compare with another BSON value.
  #
  # ```
  # puts BSON.new({a: 1}) <=> BSON.new({a: 1}) # => 0
  # puts BSON.new({a: 1}) <=> BSON.new({b: 2}) # => -1
  # ```
  def <=>(other : BSON)
    self.data <=> other.data
  end

  # Yield each key/value pair to the block.
  #
  # NOTE: Underlying BSON code as well as the binary subtype are also yielded to the block as additional arguments.
  #
  # ```
  # BSON.new({
  #   a: 1,
  #   b: "2",
  #   c: Slice[0_u8, 1_u8, 2_u8],
  # }).each { |(key, value, code, binary_subtype)|
  #   puts "#{key} => #{value}, code: #{code}, subtype: #{binary_subtype}"
  # # a => 1, code: Int32, subtype:
  # # b => 2, code: String, subtype:
  # # c => Bytes[0, 1, 2], code: Binary, subtype: Generic
  # }
  # ```
  def each(&block : Item -> _)
    pointer = @data.to_unsafe
    size = pointer.as(Pointer(Int32)).value
    pos = 4

    loop do
      if (pointer + pos).value == 0x00
        raise "Invalid BSON size." if pos != size - 1
        break
      end
      raise "Invalid BSON size." if pos >= size

      new_pos, data = Decoder.decode_field!(pointer, pos, max_pos: size)
      pos = new_pos

      yield data
    end
  end

  # Returns an Iterator over each key/value pair.
  def each
    Iterator.new(self)
  end

  private struct Iterator
    include ::Iterator(Item)

    @data : Bytes
    @pos = 4

    def initialize(bson : BSON)
      @data = bson.data.clone
    end

    def next
      pointer = @data.to_unsafe

      return Iterator::Stop::INSTANCE if (pointer + @pos).value == 0

      new_pos, data = Decoder.decode_field!(pointer, @pos, max_pos: @data.size)
      @pos = new_pos

      data
    end
  end

  # Returns a Hash representation.
  #
  # NOTE: This function is recursive and will convert nested BSON to hash objects.
  #
  # ```
  # bson = BSON.new({
  #   a: 1,
  #   b: "2",
  #   c: {
  #     d: 1,
  #   },
  # })
  # pp bson.to_h # => {"a" => 1, "b" => "2", "c" => { "d" => 1}}
  # ```
  def to_h
    hash = Hash(String, RecursiveValue).new
    self.each { |(key, value, code)|
      value = value.as(RecursiveValue)
      if value.is_a? BSON
        if code.array?
          hash[key] = value.to_h_array
        else
          hash[key] = value.to_h
        end
      else
        hash[key] = value
      end
    }
    hash
  end

  protected def to_h_array
    self.map { |_, value, code|
      value = value.as(RecursiveValue)
      if value.is_a? BSON
        if code.array?
          value.to_h_array
        else
          value.to_h
        end
      else
        value
      end
    }
  end

  # Validate that the BSON is well-formed.
  #
  # ```
  # bson = BSON.new("140000000461000D0000001030000A0000000000".hexbytes)
  # bson.validate!
  # # => Unhandled exception: Invalid BSON (overflow) (Exception)
  # ```
  def validate!
    self.each { |(k, v)|
      {k, v}
    }
  end

  # Allocate a BSON instance from a relaxed extended json representation.
  #
  # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
  #
  # ```
  # bson = BSON.from_json(%({
  #   "_id": {
  #     "$oid": "57e193d7a9cc81b4027498b5"
  #   },
  #   "String": "string",
  #   "Int": 42,
  #   "Double": -1.0
  # }))
  # puts bson.to_json # => {"_id":{"$oid":"57e193d7a9cc81b4027498b5"},"String":"string","Int":42,"Double":-1.0}
  # ```
  def self.from_json(json : String)
    self.new(JSON::PullParser.new json)
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def to_json(builder : JSON::Builder, *, array = false)
    block = ->{
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

  protected def to_canonical_extjson(builder : JSON::Builder, *, array = false)
    block = ->{
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

  # Serialize this BSON instance into a canonical extended json representation.
  #
  # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
  # ```
  # bson = BSON.from_json(%({
  #   "Int": 42,
  #   "Double": -1.0
  # }))
  # puts bson.to_canonical_extjson # => {"Int":{"$numberLong":"42"},"Double":{"$numberDouble":"-1.0"}}
  # ```
  def to_canonical_extjson
    io = IO::Memory.new
    builder = JSON::Builder.new io
    builder.start_document
    self.to_canonical_extjson(builder)
    builder.end_document
    io.to_s
  end
end
