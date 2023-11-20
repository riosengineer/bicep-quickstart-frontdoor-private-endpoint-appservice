# quickstart-frontdoor-private-endpoint-appservice 🚪

Azure Bicep Template to deploy Azure Front Door premium with Private Endpoint to your Azure App service.

With a web log analytics workspace, app insights enabled, system-assigned managed identity enabled with vNet integration. PE to the web app direct from Front Door.

### [Blog post with more information](https://rios.engineer/seamlessly-deploy-azure-front-door-premium-with-private-endpoint-to-app-services)

## Azure Architecture ☁️

![afd-pe-app-service-architecture-draw](https://rios.engineer/wp-content/uploads/2023/11/afd-webapp-pe-drawing.png? "AFD Premium with Private Endpoint to App Services Architecture.")

## Getting started 🎬

### Pre-reqs

- Two existing resource groups
- Azure CLI installed
- Authenticated to your tenant: ```az login```

### Deploy 🚀

> [!WARNING]  
> This deploys many resources, including Azure Front Door Premium which can be costly if left running for the month (circa $300+). Do not leave running if you don't want to incur charges. Delete as soon as possible post deployment if you're just testing.

1. Fork the repository
2. Amend the main.bicep file parameters to suit your deployment naming, subscription guid for the app service location & existing resource group names
3. Deploy (will deploy Front Door to here only and use the Bicep scopes for everything else):

```javascript
az deployment group create --resource-group 'your-fd-rg-here'  -f .\main.bicep
```

4. Approve your Private Endpoint connection in the Private Link Centre and wait 15~ minutes for Front Door to show the App service splash screen
