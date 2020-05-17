require "big"

lib LibGMP
  fun export = __gmpz_export(rop : Void*, countp : Int32*, order : Int32, size : Int32, endian : Int32, nails : Int32, op : MPZ*) : UInt8*
  fun import = __gmpz_import(rop : MPZ*, count : Int32, order : Int32, size : Int32, endian : Int32, nails : Int32, op : Void*) : Void
end

struct BigInt
  # Fetch a copy of the underlying byte representation.
  def bytes
    ptr = LibGMP.export(nil, out size, -1, 1, -1, 0, self)
    slice = Bytes.new(size)
    slice.copy_from(ptr, size)
    slice
  end

  # Initialize from a Byte array.
  def initialize(bytes : Bytes)
    LibGMP.import(out @mpz, bytes.size, -1, 1, -1, 0, bytes)
  end
end

struct BSON
  # 128-bit decimal floating point.
  #
  # NOTE: This implementation has been mostly ported from https://github.com/mongodb/bson-ruby/blob/master/lib/bson/decimal128.rb.
  #
  # **Performance is bad because it relies on a string representation of the value.**
  #
  # See: https://github.com/mongodb/specifications/blob/master/source/bson-decimal128/decimal128.rst
  struct Decimal128

    getter low : BigInt, high : BigInt

    # Infinity mask.
    INFINITY_MASK = 0x7800000000000000.to_big_i
    # NaN mask.
    NAN_MASK = 0x7c00000000000000.to_big_i
    # SNaN mask.
    SNAN_MASK = (1.to_big_i << 57)
    # Signed bit mask.
    SIGN_BIT_MASK = (1.to_big_i << 63)
    # The two highest bits of the 64 high order bits.
    TWO_HIGHEST_BITS_SET = (3.to_big_i << 61)
    # Exponent offset.
    EXPONENT_OFFSET = 6176
    # Minimum exponent.
    MIN_EXPONENT = -6176
    # Maximum exponent.
    MAX_EXPONENT = 6111
    # Maximum digits of precision.
    MAX_DIGITS_OF_PRECISION = 34

    # Regex matching a string representing NaN.
    NAN_REGEX = /^(\-)?(S)?NaN$/i
    # Regex matching a string representing positive or negative Infinity.
    INFINITY_REGEX = /^(\+|\-)?Inf(inity)?$/i
    # Regex for the fraction, including leading zeros.
    SIGNIFICAND_WITH_LEADING_ZEROS_REGEX = /(0*)(\d+)/
    # Regex for separating a negative sign from the significands.
    SIGN_AND_DIGITS_REGEX = /^(\-)?(\S+)/
    # Regex matching a scientific exponent.
    SCIENTIFIC_EXPONENT_REGEX = /E\+?/i
    # Regex for capturing trailing zeros.
    TRAILING_ZEROS_REGEX = /[1-9]*(0+)$/
     # Regex for a valid decimal128 string format.
    VALID_DECIMAL128_STRING_REGEX = /^[\-\+]?(\d+(\.\d*)?|\.\d+)(E[\-\+]?\d+)?$/i

    # String representing a NaN value.
    NAN_STRING = "NaN"
    # String representing an Infinity value.
    INFINITY_STRING = "Infinity"

    # Convert parts representing a Decimal128 into the corresponding bits.
    def initialize(significand : BigInt, exponent : Int32, is_negative : Bool)
      @low, @high = Decimal128.parts_to_bits(significand, exponent, is_negative)
    end

    def initialize(string : String)
      if match = NAN_REGEX.match(string)
        @low = 0.to_big_i
        @high = NAN_MASK
        @high = @high | SIGN_BIT_MASK if match[1]?
        @high = @high | SNAN_MASK if match[2]?
      elsif match = INFINITY_REGEX.match(string)
        @low = 0.to_big_i
        @high = INFINITY_MASK
        @high = @high | SIGN_BIT_MASK if match[1]? == "-"
      else
        raise InvalidString.new unless string =~ VALID_DECIMAL128_STRING_REGEX

        match = SIGN_AND_DIGITS_REGEX.match(string)
        raise InvalidString.new unless match
        _, sign, digits_str = match.to_a
        raise InvalidString.new unless digits_str
        digits, _, scientific_exp = digits_str.partition(SCIENTIFIC_EXPONENT_REGEX)
        before_decimal, _, after_decimal = digits.partition('.')

        significand_str = before_decimal + after_decimal
        match = SIGNIFICAND_WITH_LEADING_ZEROS_REGEX.match(significand_str)
        raise InvalidString.new unless match
        significand_str = match.to_a[2]
        raise InvalidString.new unless significand_str

        exponent = -(after_decimal.size)
        exponent = exponent + scientific_exp.to_i unless scientific_exp.empty?
        exponent, significand_str = Decimal128.round_exact(exponent, significand_str)
        exponent, significand_str = Decimal128.clamp(exponent, significand_str)

        @low, @high = Decimal128.parts_to_bits(significand_str.to_big_i, exponent.to_i, sign == "-")
      end
    end

    def initialize(big_decimal : BigDecimal)
      initialize(big_decimal.to_s)
    end

    def initialize(bytes : Bytes)
      @low = BigInt.new(bytes[..7])
      @high = BigInt.new(bytes[8..])
    end

    def nan?
      @high & NAN_MASK == NAN_MASK
    end

    def negative?
      @high & SIGN_BIT_MASK == SIGN_BIT_MASK
    end

    def infinity?
      @high & INFINITY_MASK == INFINITY_MASK
    end

    def to_s(io : IO)
      return io << NAN_STRING if nan?
      str = infinity? ? INFINITY_STRING : create_string
      str = negative? ? '-' + str : str
      io << str
    end

    def to_big_d
      BigDecimal.new(self.to_s)
    end

    def to_json(builder : JSON::Builder)
      to_canonical_extjson(builder)
    end

    # Serialize to a canonical extended json representation.
    #
    # NOTE: see https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
    def to_canonical_extjson(builder : JSON::Builder)
      builder.object {
        builder.string("$numberDecimal")
        builder.scalar(self.to_s)
      }
    end

    # BSON byte representation.
    def bytes
      low = Bytes.new(8)
      low.copy_from(@low.bytes)
      high = Bytes.new(8)
      high.copy_from(@high.bytes)

      io = IO::Memory.new
      io.write low
      io.write high
      io.to_slice
    end

    class InvalidString < Exception
    end
    class InvalidRange < Exception
    end

    protected def self.parts_to_bits(significand : BigInt, exponent : Int32, is_negative : Bool)
      Decimal128.validate_range!(exponent, significand)
      exponent = exponent.to_big_i + EXPONENT_OFFSET
      high = significand >> 64
      low = (high << 64) ^ significand

      if high >> 49 == 1
        high = high & 0x7fffffffffff
        high |= TWO_HIGHEST_BITS_SET
        high |= (exponent & 0x3fff) << 47
      else
        high |= exponent << 49
      end

      if is_negative
        high |= SIGN_BIT_MASK
      end

      { low, high }
    end

    protected def self.round_exact(exponent, significand)
      if exponent < MIN_EXPONENT
        if significand.to_big_i == 0
          round = MIN_EXPONENT - exponent
          exponent += round
        elsif trailing_zeros = TRAILING_ZEROS_REGEX.match(significand)
          round = [ (MIN_EXPONENT - exponent),
                    trailing_zeros[1].size ].min
          significand = significand[0...-round]
          exponent += round
        end
      elsif significand.size > MAX_DIGITS_OF_PRECISION
        trailing_zeros = TRAILING_ZEROS_REGEX.match(significand)
        if trailing_zeros
          round = [ trailing_zeros[1].size,
                    (significand.size - MAX_DIGITS_OF_PRECISION),
                    (MAX_EXPONENT - exponent)].min
          significand = significand[0...-round]
          exponent += round
        end
      end
      { exponent, significand }
    end

    protected def self.clamp(exponent, significand)
      if exponent > MAX_EXPONENT
        if significand.to_big_i == 0
          adjust = exponent - MAX_EXPONENT
          significand = "0"
        else
          adjust = [ (exponent - MAX_EXPONENT),
                     MAX_DIGITS_OF_PRECISION - significand.size ].min
          significand + "0" * adjust
        end
        exponent -= adjust
      end

      { exponent, significand }
    end

    protected def self.validate_range!(exponent : Int32, significand : BigInt)
      unless valid_significand?(significand) && valid_exponent?(exponent)
        raise InvalidRange.new
      end
    end

    protected def self.valid_significand?(significand : BigInt)
      significand.to_s.size <= MAX_DIGITS_OF_PRECISION
    end

    protected def self.valid_exponent?(exponent : Int32)
      exponent <= MAX_EXPONENT && exponent >= MIN_EXPONENT
    end

    private def create_string
      if use_scientific_notation?
        exp_pos_sign = exponent < 0 ? "" : "+"
        if significand.size > 1
          str = "#{significand[0]}.#{significand[1..-1]}E#{exp_pos_sign}#{scientific_exponent}"
        else
          str = "#{significand}E#{exp_pos_sign}#{scientific_exponent}"
        end
      elsif exponent < 0
        if significand.size > exponent.abs
          decimal_point_index = significand.size - exponent.abs
          str = "#{significand[0..decimal_point_index-1]}.#{significand[decimal_point_index..-1]}"
        else
          left_zero_pad = (exponent + significand.size).abs
          str = "0.#{"0" * left_zero_pad}#{significand}"
        end
      end
      str || significand
    end

    @scientific_exponent : BigInt?
    private def scientific_exponent
      @scientific_exponent ||= (significand.size - 1) + exponent
    end

    private def use_scientific_notation?
      exponent > 0 || scientific_exponent < -6
    end

    @exponent : BigInt?
    private def exponent
      @exponent ||= two_highest_bits_set? ?
          ((@high & 0x1fffe00000000000) >> 47) - Decimal128::EXPONENT_OFFSET :
          ((@high & 0x7fff800000000000) >> 49) - Decimal128::EXPONENT_OFFSET
    end

    @significand : String?
    private def significand
      @significand ||= two_highest_bits_set? ? "0" : bits_to_significand.to_s
    end

    private def bits_to_significand
      significand = @high & 0x1ffffffffffff
      significand = significand << 64
      significand |= @low
      significand
    end

    private def two_highest_bits_set?
      @high & TWO_HIGHEST_BITS_SET == TWO_HIGHEST_BITS_SET
    end
  end
end
