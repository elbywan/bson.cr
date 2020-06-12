REFERENCE_BYTES = ("68010000075f69640057e193d7a9cc81b4027498b50e53796d626f6c000700000073796d626f6c0002537472696e670007000000737472696e670012496e743634002a0000000000000001446f75626c6500f6285c8fc235454013446563696d616c00d20400000000000000000000000040300542696e61727955736572446566696e6564000500000080010203040503537562646f63756d656e74001200000002666f6f00040000006261720000044172726179003c00000012300001000000000000001231000200000000000000123200030000000000000012330004000000000000001234000500000000000000001154696d657374616d7000010000002a0000000b526567756c617245787072657373696f6e00666f6f2a00697800094461746574696d6545706f6368000000000000000000085472756500010846616c73650000ff4d696e6b6579007f4d61786b6579000a4e756c6c0006556e646566696e65640000".hexbytes)

REFERENCE_JSON = %({
  "_id": {
    "$oid": "57e193d7a9cc81b4027498b5"
  },
  "Symbol": {
    "$symbol": "symbol"
  },
  "String": "string",
  "Int64": 42,
  "Double": 42.42,
  "Decimal": {
    "$numberDecimal": "1234"
  },
  "BinaryUserDefined": {
    "$binary": {
      "base64": "AQIDBAU=",
      "subType": "80"
    }
  },
  "Subdocument": {
    "foo": "bar"
  },
  "Array": [1, 2, 3, 4, 5],
  "Timestamp": {
    "$timestamp": { "t": 42, "i": 1 }
  },
  "RegularExpression": {
    "$regularExpression": {
      "pattern": "foo*",
      "options": "ix"
    }
  },
  "DatetimeEpoch": {
    "$date": "1970-01-01T00:00:00.000Z"
  },
  "True": true,
  "False": false,
  "Minkey": {
    "$minKey": 1
  },
  "Maxkey": {
    "$maxKey": 1
  },
  "Null": null,
  "Undefined": {
    "$undefined": true
  }
})

REFERENCE_TUPLE = {
  "_id":               BSON::ObjectId.new("57e193d7a9cc81b4027498b5"),
  "Symbol":            BSON::Symbol.new("symbol"),
  "String":            "string",
  "Int64":             42_i64,
  "Double":            42.42,
  "Decimal":           BSON::Decimal128.new("1234"),
  "BinaryUserDefined": BSON::Binary.new(:user_defined, Base64.decode("AQIDBAU=")),
  "Subdocument":       BSON.new({
    "foo": "bar",
  }),
  "Array":             [1, 2, 3, 4, 5].map(&.to_i64),
  "Timestamp":         BSON::Timestamp.new(42, 1),
  "RegularExpression": /foo*/ix,
  "DatetimeEpoch":     Time::UNIX_EPOCH,
  "True":              true,
  "False":             false,
  "Minkey":            BSON::MinKey.new,
  "Maxkey":            BSON::MaxKey.new,
  "Null":              nil,
  "Undefined":         BSON::Undefined.new,
}
