# quickstart-frontdoor-private-endpoint-appservice

Azure Bicep Template to deploy Azure Front Door premium with Private Endpoint to your Azure App service.

With a web log analytics workspace, app insights enabled, system-assigned managed identity enabled with vNet integration ready to plug into your SQL backend (drawing of SQL is for illustration of the architecture). PE to the web app direct from Front Door.

### [Blog post with more information](seamlessly-deploy-azure-front-door-premium-with-private-endpoint-to-app-services)

## Azure Architecture

![afd-pe-app-service-architecture](https://rios.engineer/wp-content/uploads/2023/11/afd-webapp-pe-drawing.png "AFD Premium with Private Endpoint to App Services Architecture.")

## Getting started

### Pre-reqs

- Two existing resource groups
- Azure CLI installed
- Authenticated to your tenant: ```az login```

### Deploy

1. Fork the repository
2. Amend the main.bicep file parameters to suit your deployment naming, subscription guid & existing resource group names
3. Deploy:

```javascript
az deployment group create --resource-group 'your-fd-rg-here'  -f .\main.bicep
```

4. Approve your Private Endpoint connection in the Private Link Centre and wait 15~ minutes for Front Door to show the App service splash screen
