targetScope = 'resourceGroup'

metadata name = 'Quickstart Template AFD to Web App'
metadata description = 'Azure Front Door Premium + WAF with Private Link to Azure App Bicep template'

// Change the below params to suit your deployment needs
// Go to the modules to amend IP schema, app plan sku/app code stack etc.
@description('Azure UK South region.')
param location string = resourceGroup().location

@description('Web App resource group name.')
param rg_web_workload string = 'rg-webapp-prod'

@description('Workload / corp / core landing zone subid.')
param workloadsSubId string = '00000000-0000-0000-0000-000000000000'

@description('Log analytics workspace name.')
param alaName string = 'ala-workspace-name'

@description('App service application insights name.')
param appInsightsName string = 'appinsights-name'

@description('Azure app service name.')
param webAppName string = 'webapp-001'

@description('Time date now for tag creation and unique names.')
param timeNow string = utcNow('u')

@description('Azure tags for the resources.')
param Tags object = {
  ApplicationName: 'Web App'
  Owner: 'Contoso'
  CostCentre: 'N/A'
  Env: 'Production'
  Created: timeNow
}

@description('The name of the Front Door endpoint to create. This must be globally unique.')
param afdWebEndpoint string = 'afd-${uniqueString(resourceGroup().id)}'

@description('The name of the SKU to use when creating the Front Door profile.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param frontDoorSkuName string = 'Premium_AzureFrontDoor'

@description('The WAF policy mode. In "Prevention" mode, the WAF will block requests it detects as malicious. In "Detection" mode, the WAF will not block requests and will simply log the request.')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

var frontDoorProfileName = 'afdpremium-web'
var frontDoorOriginGroupName = 'webapp-origin-group'
var frontDoorOriginName = 'webapp-origin-group'
var frontDoorRouteName = 'webapp-route'
var securityPolicyName = 'wafSecurityPolicy'
var wafPolicyName = 'wafPolicy'

///////////////
// Resources //
///////////////

// Azure App Service components

// vNet for integration
module vnet 'br/public:network/virtual-network:1.1.3' = {
  name: '${uniqueString(deployment().name, location)}-webVnet'
  scope: resourceGroup(workloadsSubId, rg_web_workload)
  params: {
    name: 'webapp-vnet'
    addressPrefixes: [
      '10.1.0.0/21'
    ]
    subnets: [
      {
        name: 'webapp-snet' // note: for each web app created with vnet integration it needs its own subnet. Change name accordingly if this is too generic
        addressPrefix: '10.1.1.0/24'
        delegations: [
          {
            name: 'Microsoft.Web.serverFarms'
            properties: {
              serviceName: 'Microsoft.Web/serverFarms'
            }
          }
        ]
      }
    ]
    tags: Tags
  }
}

// Log Analytics workspace
module logAnalytics 'br/public:storage/log-analytics-workspace:1.0.3' = {
  name: '${uniqueString(deployment().name, location)}-ala'
  scope: resourceGroup(rg_web_workload)
  params: {
    name: alaName
    location: location
    tags: Tags
  }
}

// Application Insight
module appInsights 'modules/appInsights/appinsights.bicep' = {
  name: '${uniqueString(deployment().name, location)}-appInsights'
  scope: resourceGroup(workloadsSubId, rg_web_workload)
  params: {
    name: appInsightsName
    location: location
    workspaceResourceId: logAnalytics.outputs.id
    kind: 'web'
    applicationType: 'web'
    tags: Tags
  }
}

// Azure App Plan
module webAppPlan 'modules/webApp/appPlan.bicep' = {
  name: '${uniqueString(deployment().name, location)}-appPlan'
  scope: resourceGroup(workloadsSubId, rg_web_workload)
  params: {
    name: 'appPlan'
    location: location
    sku: {
      name: 'S1'
    }
    kind: 'App'
    tags: Tags
  }
}

// Web App resource
module webApp 'modules/webApp/webApp.bicep' = {
  name: '${uniqueString(deployment().name, location)}-webApp'
  scope: resourceGroup(workloadsSubId, rg_web_workload)
  params: {
    name: webAppName
    location: location
    kind: 'app'
    serverFarmResourceId: webAppPlan.outputs.resourceId
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    appInsightResourceId: appInsights.outputs.resourceId
    virtualNetworkSubnetId: vnet.outputs.subnetResourceIds[0]
    siteConfig: {
      use32BitWorkerProcess: false
      detailedErrorLoggingEnabled: true
      httpLoggingEnabled: true
      requestTracingEnabled: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: true
      windowsFxVersion: 'ASPNET|4.8' // run az webapp list-runtimes to view available versions
      // linuxFxversion:
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'

        }
      ]
    }
    appSettingsKeyValuePairs: {
      WEBSITE_HTTPLOGGING_RETENTION_DAYS: 7
    }
    managedIdentities: {
      systemAssigned: true
    }
    tags: Tags
  }
}


// Front Door resource
resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorProfileName
  location: 'global'
  sku: {
    name: frontDoorSkuName
  }
  dependsOn: [
    webApp
    webAppPlan
  ]
  tags: Tags
}

// Front Door endpoint(s)
resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: afdWebEndpoint
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

// Front Door origin group
resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100
    }
  }
}

// Front Door origin backend - Azure Web App 
resource frontDoorOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2022-11-01-preview' = {
  name: frontDoorOriginName
  parent: frontDoorOriginGroup
  properties: {
    hostName: webApp.outputs.defaultHostname
    httpPort: 80
    httpsPort: 443
    originHostHeader: webApp.outputs.defaultHostname
    priority: 1
    weight: 1000
    sharedPrivateLinkResource: {
      groupId: 'sites'
      privateLink: {
        id: webApp.outputs.resourceId
      }
      privateLinkLocation: location
      requestMessage: 'AFD PE to Web App'
      status: 'Pending'
    }
  }
}

// Front Door route 
resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: frontDoorRouteName
  parent: frontDoorEndpoint
  dependsOn: [
    frontDoorOrigin
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

// WAF Policy with DRS 2.1 and Bot Manager 1.0
resource wafPolicy 'Microsoft.Network/frontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: wafPolicyName
  location: 'Global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: wafMode
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleSetAction: 'Block'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleSetAction: 'Block'
        }
      ]
    }
  }
}

// Attach WAF Policy to endpoint
resource cdn_waf_security_policy 'Microsoft.Cdn/profiles/securitypolicies@2021-06-01' = {
  parent: frontDoorProfile
  name: securityPolicyName
  properties: {
    parameters: {
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
            id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
      type: 'WebApplicationFirewall'
    }
  }
}

// Output FQDNs
output appServiceHostName string = webApp.outputs.defaultHostname
output frontDoorEndpointHostName string = frontDoorEndpoint.properties.hostName
