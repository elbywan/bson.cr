There are the following deliberate changes made to the corpus tests in Crystal:

- In "double" tests, lowercased the exponent "E". (ex: 1.2345678921232E+18 -> 1.2345678921232e+18)

- Added the "ignore" flag

Y10K datetime raises an "Invalid time: seconds out of range" error.

- Added the "ignore_json_roundtrip" flag to ignore round trip tests.

Makes up for issues in the Crystal Parser (-0.0 parsed as 0.0, minimum Int64 value raises).

- Slightly modified relaxed_extjson value for some datetime tests because Crystal does not allow 3 fraction digits. (see: https://github.com/crystal-lang/crystal/pull/9283)