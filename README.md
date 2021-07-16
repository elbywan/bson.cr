<div align="center">
  <img src="icon.svg" width="128" height="128" />
  <h1>bson.cr</h1>
  <h3>A pure Crystal implementation of the <a href="http://bsonspec.org">BSON specification</a>.</h3>
  <a href="https://travis-ci.org/elbywan/bson.cr"><img alt="travis-badge" src="https://travis-ci.org/elbywan/bson.cr.svg?branch=master"></a>
  <a href="https://github.com/elbywan/bson.cr/tags"><img alt="GitHub tag (latest SemVer)" src="https://img.shields.io/github/v/tag/elbywan/bson.cr"></a>
  <a href="https://github.com/elbywan/bson.cr/blob/master/LICENSE"><img alt="GitHub" src="https://img.shields.io/github/license/elbywan/bson.cr"></a>
</div>

## Reliability

This library passes the official corpus tests located in the [`mongodb/specifications`](https://github.com/mongodb/specifications) repository.

*A few [minor](https://github.com/elbywan/bson.cr/tree/master/spec/corpus) modifications have been made to the tests to comply with Crystal specifics.*

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     bson:
       github: elbywan/bson.cr
   ```

2. Run `shards install`

## API

[Full API documentation is hosted here.](https://elbywan.github.io/bson.cr/BSON.html)

## Usage

```crystal
require "bson"
```

### Constructors

```crystal
# Create a BSON instance from a NamedTuple…
bson = BSON.new({
  hello: "world"
})

# …or a Hash…
bson = BSON.new({
  "hello" => "world"
})

# …or a hex binary representation…
bytes = "160000000268656c6c6f0006000000776f726c640000".hexbytes
bson = BSON.new(bytes)

# …or an IO…
bson = BSON.new(IO::Memory.new bytes)

# …or JSON data
bson = BSON.from_json(%({
  "hello": "world"
}))

# The BSON binary representation is stored in the data property
puts bson.data.hexstring
# => 160000000268656c6c6f0006000000776f726c640000
```

### Append and fetch values

```crystal
bson = BSON.new({
  hello: "world"
})

# Append values
bson["name"] = BSON.new({
  first_name: "John",
  last_name: "Doe"
})

# Fetch values
puts bson["name"].as(BSON).to_json
# => {"first_name":"John","last_name":"Doe"}
puts bson["404"]?
# => nil

# Append another BSON
other_bson = BSON.new({ other: "field" })
bson.append(other_bson)
puts bson["other"]
# => field
```

### Iterate

```crystal
bson = BSON.new({
  one: 1,
  two: 2.0,
  three: 3
})

# Enumerator
bson.each { |(key, value)|
  puts "#{key}, #{value}"
  # => one, 1
  # => two, 2.0
  # => three, 3
}

# Iterator
puts bson.each.map { |(key, value)|
  value.as(Number) + 1
}.to_a
# => [2, 3.0, 4]
```

### Conversions

```crystal
bson = BSON.new({
  one: 1,
  two: "2",
  binary: Slice[0_u8, 1_u8, 2_u8]
})

pp bson.to_h
# => {"one" => 1, "two" => "2", "binary" => Bytes[0, 1, 2]}

pp bson.each.to_a
# => [{"one", 1, Int32, nil}, {"two", "2", String, nil}, {"binary", Bytes[0, 1, 2], Binary, Generic}]
```

### JSON

```crystal
# Initialize from data in Relaxed Extended Json format.
# See: https://github.com/mongodb/specifications/blob/master/source/extended-json.rst
bson = BSON.new(%({
  "_id": {
       "$oid": "57e193d7a9cc81b4027498b5"
   },
   "Binary": {
       "$binary": {
           "base64": "o0w498Or7cijeBSpkquNtg==",
           "subType": "03"
       }
   },
   string: "String",
   number: 10.1
}))

# Serialize to Relaxed Extended Json format…
puts bson.to_json
# => {"_id":{"$oid":"57e193d7a9cc81b4027498b5"},"Binary":{"$binary":{"base64":"o0w498Or7cijeBSpkquNtg==","subType":"03"}},"string":"String","number":10.1}

# …or Canonical Extended Json.
puts bson.to_canonical_extjson
# => {"_id":{"$oid":"57e193d7a9cc81b4027498b5"},"Binary":{"$binary":{"base64":"o0w498Or7cijeBSpkquNtg==","subType":"03"}},"string":"String","number":{"$numberDouble":"10.1"}}
```

## Serialization

```crystal
class Data
  include BSON::Serializable
  include JSON::Serializable

  property field : String
  property counter : Int32

  property nested : Nested

  class Nested
    include BSON::Serializable
    include JSON::Serializable

    property array : Array(String | Int32)
  end
end

data = Data.from_json(%({
  "field": "value",
  "counter": 0,
  "nested": {
    "array": [
      "element",
      1
    ]
  }
}))

puts data.to_json
# => {"field":"value","counter":0,"nested":{"array":["element",1]}}

puts data.to_bson.data.hexstring
# => 52000000026669656c64000600000076616c75650010636f756e7465720000000000036e65737465640027000000046172726179001b00000002300008000000656c656d656e740010310001000000000000

puts Data.from_bson(data.to_bson).to_json
# => {"field":"value","counter":0,"nested":{"array":["element",1]}}
```

## Validating ObjectIds

You can validate that a provided string is a valid MongoDB ObjectId before instantiating it with `.new()` with:

```crystal
# => true
p BSON::ObjectId.validate("57e193d7a9cc81b4027498b5")

# => false
p BSON::ObjectId.validate("qwerty")

# => false
p BSON::ObjectId.validate("1234567890abcdefghijklmn")
```

## Decimal128

The `Decimal128` code has been hastily copied from the [`bson-ruby`](https://github.com/mongodb/bson-ruby/blob/master/lib/bson/decimal128.rb) library.
It works, but performance is low because it uses an intermediate String representation.

## Contributing

1. Fork it (<https://github.com/elbywan/bson/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [elbywan](https://github.com/elbywan) - creator and maintainer

## Credit

- Icon made by [Vitaly Gorbachev](https://www.flaticon.com/authors/vitaly-gorbachev) from [www.flaticon.com](https://www.flaticon.com).
