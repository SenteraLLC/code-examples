# Introduction
Demo app that demonstrates how to perform the OAuth2 authorization code grant workflow that allows
a user to authenticate with FieldAgent and grant the app access to read the user's fields in FieldAgent.

This app is implemented as a small web server that serves up HTML to your browser, and executes the OAuth2 authorization code grant workflow with a FieldAgent server. If the app successfully authenticates with FieldAgent via OAuth2, it will read the user's fields from FieldAgent and display them in the browser.

# Pre-Requisites

## Register Your FieldAgent Client with Sentera

Before running this demo app, you must send a request to devops@sentera.com to register your client app with  Sentera. This will allow your app to connect to FieldAgent via OAuth2 and obtain an access token used to access data in FieldAgent via its GraphQL API.

When you register with Sentera, you will be provided with a client ID and secret for our staging and production environments (a different pair for each environment) that you can specify via the CLIENT_ID and CLIENT_SECRET environment variables to run this demo app.

> We strongly recommend that you develop your API integration against our staging environment first. Once you have it working, then run it against our production environment. Just remember to use the correct client ID and secret pair for the FieldAgent environment you are running against.

## NodeJS

To run this demo app, you need to have node installed. This app has been tested with node v20 but likely works with older versions of node.

This demo app is self-contained and has no dependencies that you need to install before running it.

# Start the Demo App Web Server

```
➜ CLIENT_ID={Your client's id} CLIENT_SECRET={Your client's secret} node app.js
```

## Environment Variables
| Environment Variable | Description | Default Value |
| :------- | :-----------------------| :-------------|
| CLIENT_ID     | The id of your FieldAgent client, provided by Sentera when you register your FieldAgent client | (required) |
| CLIENT_SECRET | The secret for your FieldAgent client, provided by Sentera when you register your FieldAgent Client | (required) |
| CLIENT_SCOPE | The scope of data access your FieldAgent Client is granted | read_fields |
| FIELDAGENT_PROTOCOL | The HTTP protocol of the FieldAgent server| https |
| FIELDAGENT_HOST | The host of the FieldAgent server | apistaging.sentera.com |
| FIELDAGENT_PORT | The port of the FieldAgent server| (can be left empty if no specific port) |


This starts up a web server listening on localhost:8000. By default the demo app will use FieldAgent's staging environment. If you would like to run the demo app against FieldAgent's production environment, specify  the `FIELDAGENT_HOST` environment variable as `api.sentera.com`.

# Run the Demo App

To run the demo, enter http://localhost:8000 in your browser. Click the `Read Fields in FieldAgent` button to start the OAuth2 authorization code grant workflow.

**Client App - Default Page**
![Client App - Default Page](/authentication/images/default-page.png)

**FieldAgent - Login**
![FieldAgent - Login](/authentication/images/fieldagent-login.png)

**FieldAgent - Authorization**
![FieldAgent - Authorization](/authentication/images/fieldagent-authorization.png)

**Client App - Authorization Denied**
![Client App - Authorization Denied](/authentication/images/authorization-denied.png)

**Client App - Fields**
![Client App - Fields](/authentication/images/fields.png)
