@description('Optional. The location to deploy resources to.')
param location string = resourceGroup().location

@description('Required. The name of the Virtual Network.')
param virtualNetworkName string

@description('Required. The name of the NSG.')
param nsgName string

@description('Required. The name of the Private DNS Zone.')
param privateDnsZoneName string

@description('Required. The name of the Route Table.')
param routeTableName string

@description('Required. The name of the Managed Identity.')
param managedIdentityName string

@description('Required. The name of the Kubelet Managed Identity.')
param kubeletIdentityName string

var addressPrefix = '10.190.0.0/16'

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-07-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          access: 'Allow'
          description: 'Allow HTTPS Inbound on TCP port 443'
          protocol: 'Tcp'
          sourceAddressPrefix: 'virtualNetwork'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
          direction: 'Inbound'
          priority: 200
        }
      }
      {
        name: 'allow-aksNodeCidr-aksNodeCidr'
        properties: {
          access: 'Allow'
          description: 'Allow HTTPS Inbound on TCP port 443'
          protocol: '*'
          sourceAddressPrefix: addressPrefix
          destinationAddressPrefix: addressPrefix
          sourcePortRange: '*'
          destinationPortRange: '*'
          direction: 'Inbound'
          priority: 210
        }
      }
      {
        name: 'allow-aksNodeCidr-aksPodCidr'
        properties: {
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: addressPrefix
          destinationAddressPrefix: '172.23.0.0/18'
          sourcePortRange: '*'
          destinationPortRange: '*'
          direction: 'Inbound'
          priority: 220
        }
      }
      {
        name: 'allow-aksPodCidr-aksPodCidr'
        properties: {
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '172.23.0.0/18'
          destinationAddressPrefix: '172.23.0.0/18'
          sourcePortRange: '*'
          destinationPortRange: '*'
          direction: 'Inbound'
          priority: 230
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: 'loganalytics'
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource dnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: 'pDnsLink-${virtualNetworkName}-${privateDnsZoneName}'
  location: 'global'
  parent: privateDnsZone
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-07-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'sn-aks-01'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 0)
          networkSecurityGroup: {
            id: nsg.id
          }
          routeTable: {
            id: routeTable.id
          }
        }
      }
      {
        name: 'sn-aks-02'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 1)
          networkSecurityGroup: {
            id: nsg.id
          }
          routeTable: {
            id: routeTable.id
          }
        }
      }
    ]
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview' = {
  name: managedIdentityName
  location: location
}

resource kubeletIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview' = {
  name: kubeletIdentityName
  location: location
}

resource routeTable 'Microsoft.Network/routeTables@2025-07-01' = {
  name: routeTableName
  location: location
  properties: {
    routes: []
  }
}

resource roleAssignmentVNet 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('msi-${location}-${managedIdentity.id}-NetworkContributor-RoleAssignment')
  scope: virtualNetwork
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4d97b98b-1d4f-4787-a291-c67834d212e7'
    ) // Network Contributor
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentPrivateDNSZone 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('msi-${location}-${managedIdentity.id}-PrivateDNSZoneContributor-RoleAssignment')
  scope: privateDnsZone
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b12aa53e-6015-4669-85d0-8515ebb3ae7f'
    ) // Private DNS Zone Contributor Role for AKS Managed Identity.
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentKubeletIdentity 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('msi-${location}-${managedIdentity.id}-ManagedIdentityOperator-RoleAssignment')
  scope: kubeletIdentity
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'f1a07417-d97a-45cb-824c-7a7467783830'
    ) // Managed Identity Operator Role used for Kubelet identity.
    principalType: 'ServicePrincipal'
  }
}

@description('The resource ID of the created Virtual Network Subnet.')
output subnetResourceId string = virtualNetwork.properties.subnets[0].id

@description('The resource ID of the created Private DNS Zone.')
output privateDnsZoneResourceId string = privateDnsZone.id

@description('The resource ID of the created Virtual Network.')
output virtualNetworkResourceId string = virtualNetwork.id

@description('The resource ID of the created Managed Identity.')
output managedIdentityResourceId string = managedIdentity.id

@description('The resource ID of the created Kubelet Managed Identity.')
output kubeletIdentityResourceId string = kubeletIdentity.id

@description('The client ID of the created Kubelet Managed Identity.')
output kubeletIdentityClientId string = kubeletIdentity.properties.clientId

@description('The principal ID of the created Kubelet Managed Identity.')
output kubeletIdentityPrincipalId string = kubeletIdentity.properties.principalId

@description('The resource ID of the created Log Analytics Workspace.')
output logAnalyticsWorkspaceResourceId string = logAnalyticsWorkspace.id
