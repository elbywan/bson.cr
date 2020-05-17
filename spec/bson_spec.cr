require "./spec_helper"
require "base64"

describe BSON do
  describe "corpus tests" do
    {% begin %}
    {%
      files = %w(
        array
        binary
        boolean
        code_w_scope
        code
        datetime
        dbpointer
        dbref
        decimal128-1
        decimal128-2
        decimal128-3
        decimal128-4
        decimal128-5
        document
        double
        int32
        int64
        maxkey
        minkey
        multi-type-deprecated
        multi-type
        null
        oid
        regex
        string
        symbol
        timestamp
        top
        undefined
      )
    %}
    {% for file in files %}
      describe {{file}} do
        Runner::Corpus.run({{file}})
      end
    {% end %}
    {% end %}
  end
end
