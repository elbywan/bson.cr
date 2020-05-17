There are the following deliberate changes made to the corpus tests in Crystal:

- Added the "ignore_json_roundtrip" flag to make up for issues in the Crystal Parser (-0.0 parsed as 0.0, minimum Int64 value raises).