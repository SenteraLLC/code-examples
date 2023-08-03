# Introduction
Examples in different languages that demonstrate how to upload a file to [Sentera's FieldAgent platform](https://sentera.com/fieldagent-platform/)

## API Credentials
To run these file upload examples, you must first obtain an access token for your FieldAgent user that will be used to authenticate your requests to the FieldAgent GraphQL API. See https://api.sentera.com/api/getting_started/authentication_and_authorization.html for details on obtaining an API access token.

Once you have a valid access token, specify a `FIELDAGENT_ACCESS_TOKEN` environment variable to the command that runs an upload script.

For example, the command below runs the Ruby multipart file upload example against the FieldAgent staging server:
```
$ FIELDAGENT_ACCESS_TOKEN=SFaY5r2CAqoVJtlrbfqC62W1UqJUAdQjlnCjB8eqvJg ruby multipart_file_upload.rb
```

Or alternately, you can paste your FieldAgent access token into a file named `fieldagent_access_token.txt` that is located in the same directory as the code examples.

## FieldAgent Server
These file upload example scripts are pointed at FieldAgent's production server (e.g https://api.sentera.com). To run them against a different FieldAgent server, specify a `FIELDAGENT_SERVER` environment variable to the command that runs an upload script.

For example, the command below runs the Ruby multipart file upload example against the FieldAgent staging server:
```
$ FIELDAGENT_SERVER=https://apistaging.sentera.com ruby multipart_file_upload.rb
```

## Single PUT Request Workflow
There are three basic steps for uploading a file using a single PUT request, and then using it with Sentera FieldAgent:

1. **Prepare the file upload** - Request credentials for uploading a file to Sentera's cloud storage.
2. **Upload the file** - Upload a file directly to Sentera's cloud storage using a pre-signed upload URL.
3. **Use the file** - Specify the ID of the uploaded file with one of the mutations in [Sentera's GraphQL API](https://api.sentera.com/api/docs/mutation.doc.html) to attach the file to a resource such as a field, survey, feature set, etc.

Full documentation of this workflow can be found [here](https://api.sentera.com/api/getting_started/uploading_files.html)

## Multi-Part Workflow
There are four basic steps for uploading a file in multiple parts, and then using it with Sentera FieldAgent:

1. **Create a multi-part file upload** - Request to begin a multi-part file upload to Sentera's cloud storage.
2. **Upload the file in parts** - Upload parts of a file directly to Sentera's cloud storage by first requesting credentials for uploading a file part, and then uploading the file part using a pre-signed upload URL.
3. **Complete the multi-part file upload** - Request to complete the multi-part file upload with Sentera's cloud storage.
4. **Use the file** - Specify the ID of the uploaded file with one of the mutations in [Sentera's GraphQL API](https://api.sentera.com/api/docs/mutation.doc.html) to attach the file to a resource such as a field, survey, feature set, etc.

Full documentation of this workflow can be found [here](https://api.sentera.com/api/getting_started/uploading_files.html)

## Examples
| Language | Run Command                       | Example Command |
| :------- | :---------------------------------|-----------------|
| Ruby     | `$ ruby file_upload.rb`           | `FIELDAGENT_ACCESS_TOKEN=AKgnGiLNpk1AjppMqWSWbiNMNUYepcP8EalLo_gYRpM FIELDAGENT_SERVER=https://api.sentera.com OWNER_TYPE=SURVEY OWNER_SENTERA_ID=9nfdf02_CO_ytwfAcmeOrg_CV_deve_c49295f37_230411_080321 ruby file_upload.rb` |
| Ruby     | `$ ruby multipart_file_upload.rb` | `FIELDAGENT_ACCESS_TOKEN=AKgnGiLNpk1AjppMqWSWbiNMNUYepcP8EalLo_gYRpM FIELDAGENT_SERVER=https://api.sentera.com PARENT_SENTERA_ID=9nfdf02_CO_ytwfAcmeOrg_CV_deve_c49295f37_230411_080321 ruby multipart_file_upload.rb` |
