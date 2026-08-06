metadata itemDisplayName = 'Test Template for AKS'
metadata description = 'This template deploys the testing resource for AKS.'
metadata summary = 'Deploys test AKS resource'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'aks1'
var aksName = 'aks-${namePrefix}-${serviceShort}-01'
var nsgName = 'nsg-${namePrefix}-${serviceShort}-01'
var virtualNetworkName = 'vnet-${namePrefix}-${serviceShort}-01'
var uamiName = 'uami-${namePrefix}-${serviceShort}-01'
var kubeletIdentityName = 'uami-${namePrefix}-${serviceShort}-02'
var routeTableName = 'rt-${namePrefix}-${serviceShort}-01'
var privateDnsZoneName = 'privatelink.${replace(location, ' ', '')}.azmk8s.io'

module nestedDependencies 'main.test.dependencies.bicep' = {
  name: '${uniqueString(deployment().name, location)}-nestedDependencies'
  params: {
    location: location
    virtualNetworkName: virtualNetworkName
    nsgName: nsgName
    privateDnsZoneName: privateDnsZoneName
    managedIdentityName: uamiName
    kubeletIdentityName: kubeletIdentityName
    routeTableName: routeTableName
  }
}

module aks 'main.test.aks.bicep' = {
  name: '${uniqueString(deployment().name, location)}-aks'
  params: {
    location: location
    aksName: aksName
    privateDnsZoneResourceId: nestedDependencies.outputs.privateDnsZoneResourceId
    subnetResourceId: nestedDependencies.outputs.subnetResourceId
    kubeletIdentityResourceId: nestedDependencies.outputs.kubeletIdentityResourceId
    kubeletIdentityClientId: nestedDependencies.outputs.kubeletIdentityClientId
    kubeletIdentityPrincipalId: nestedDependencies.outputs.kubeletIdentityPrincipalId
    managedIdentityResourceId: nestedDependencies.outputs.managedIdentityResourceId
    logAnalyticsWorkspaceResourceId: nestedDependencies.outputs.logAnalyticsWorkspaceResourceId
  }
}

output name string = aks.outputs.name
output resourceId string = aks.outputs.resourceId
output location string = aks.outputs.location

output SubnetResourceId string = nestedDependencies.outputs.subnetResourceId
output virtualNetworkResourceId string = nestedDependencies.outputs.virtualNetworkResourceId
