# bson

#### A pure Crystal implementation of the [BSON specification](http://bsonspec.org).

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
# Constructor from a NamedTuple…
bson = BSON.new({
  hello: "world"
})
…or a Hash…
bson = BSON.new({
  "hello" => "world"
})
…or hex binary representation…
bson = BSON.new(BSON.new("160000000268656c6c6f0006000000776f726c640000".hexbytes))
…or JSON.
bson = BSON.new("160000000268656c6c6f0006000000776f726c640000".hexbytes)
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
puts bson["name"].as(BSON).to_canonical_extjson
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

### Convert to other structures

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

## Decimal128

The `Decimal128` code has been hastily copied from the (`bson-ruby`)[https://github.com/mongodb/bson-ruby/blob/master/lib/bson/decimal128.rb] library.
It works, but performance is low because it uses an intermediate String representation.

## Contributing

1. Fork it (<https://github.com/your-github-user/bson/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [elbywan](https://github.com/your-github-user) - creator and maintainer
