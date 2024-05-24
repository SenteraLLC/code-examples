# Introduction
Examples showing how to use various features within [Sentera's FieldAgent GraphQL API](https://api.sentera.com/api/docs)

## API Credentials
To run these file upload examples, you must first obtain an access token for your FieldAgent user that will be used to authenticate your requests to the FieldAgent GraphQL API. See https://api.sentera.com/api/getting_started/authentication_and_authorization.html for details on obtaining an API access token.

Once you have a valid access token, specify a `FIELDAGENT_ACCESS_TOKEN` environment variable to the command that runs an upload script.

For example, the command below runs the Ruby multipart file upload example against the FieldAgent staging server:
```
$ FIELDAGENT_ACCESS_TOKEN=SFaY5r2CAqoVJtlrbfqC62W1UqJUAdQjlnCjB8eqvJg ruby upsert_feature_set.rb
```

Or alternately, you can paste your FieldAgent access token into a file named `fieldagent_access_token.txt` that is located in the same directory as the code examples.

## FieldAgent Server
These example scripts are pointed at FieldAgent's production server (e.g https://api.sentera.com). To run them against a different FieldAgent server, specify a `FIELDAGENT_SERVER` environment variable to the command that runs an upload script.

For example, the command below runs the Ruby multipart file upload example against the FieldAgent staging server:
```
$ FIELDAGENT_SERVER=https://apistaging.sentera.com ruby upsert_feature_set.rb
```

## Examples
| Language | Run Command                       | Example Command |
| :------- | :---------------------------------|-----------------|
| Ruby     | `$ ruby upsert_feature_set.rb`           | `FIELDAGENT_ACCESS_TOKEN=PAmnCNUyosKShN9K1AEflLOw6T7bA2fRTWTg-vL3P5Y FIELDAGENT_SERVER=https://api.sentera.com SURVEY_SENTERA_ID=mjlmmrw_CO_lk07AcmeOrg_CV_deve_773b47acb_240514_160730  GEOMETRY_PATH="/test_files/test.geojson" FILES_PATH="/test_files" FILE_EXT="*.jpeg" ruby upsert_feature_set.rb` |
| Ruby     | `$ ruby import_feature_set.rb`           | `FIELDAGENT_ACCESS_TOKEN=PAmnCNUyosKShN9K1AEflLOw6T7bA2fRTWTg-vL3P5Y FIELDAGENT_SERVER=https://api.sentera.com SURVEY_SENTERA_ID=mjlmmrw_CO_lk07AcmeOrg_CV_deve_773b47acb_240514_160730  GEOMETRY_PATH="/test_files/test.geojson" FILES_PATH="/test_files" FILE_EXT="*.jpeg" ruby import_feature_set.rb` |
| Ruby     | `$ ruby import_feature_set_legacy.rb`           | `FIELDAGENT_ACCESS_TOKEN=PAmnCNUyosKShN9K1AEflLOw6T7bA2fRTWTg-vL3P5Y FIELDAGENT_SERVER=https://api.sentera.com SURVEY_SENTERA_ID=mjlmmrw_CO_lk07AcmeOrg_CV_deve_773b47acb_240514_160730  GEOMETRY_PATH="/test_files/test.geojson" FILES_PATH="/test_files" FILE_EXT="*.jpeg" ruby import_feature_set_legacy.rb` |
