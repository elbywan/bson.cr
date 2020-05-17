# bson

A pure Crystal implementation of the [BSON specification](http://bsonspec.org).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     bson:
       github: elbywan/bson.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "bson"

bson = BSON.new({
  null: nil,
  string: "text",
  int: 20,
  array: [1, 2, 3],
  document: BSON.new({
    a: 1
  }),
  binary: Bytes[0, 1, 2, 3],
  uuid: UUID.new,
  oid: BSON::ObjectId.new,
  bool_true: true,
  bool_false: false,
  date_time: Time.parse_iso8601("2012-12-24T12:15:30.501Z"),
  regex: /abc/imx
})


bson.each { |(key, value)|
  puts key, value
}

puts bson["string"]
puts bson["some_key"]?
puts bson.to_canonical_extended_json

json = bson.to_json
puts json
BSON.from_json(json)

puts bson.to_h

# and more…
```

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/bson/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [elbywan](https://github.com/your-github-user) - creator and maintainer
