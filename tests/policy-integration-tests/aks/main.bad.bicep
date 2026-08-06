metadata itemDisplayName = 'Test Template for AKS'
metadata description = 'This template deploys the testing resource for AKS.'
metadata summary = 'Deploys test AKS resource that should violate some policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'aks3'
var aksName = 'aks-${namePrefix}-${serviceShort}-01'
var nsgName = 'nsg-${namePrefix}-${serviceShort}-02'
var virtualNetworkName = 'vnet-${namePrefix}-${serviceShort}-01'
var routeTableName = 'rt-${namePrefix}-${serviceShort}-01'

var addressPrefix = '10.3.0.0/16'

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
    ]
  }
}

resource routeTable 'Microsoft.Network/routeTables@2025-07-01' = {
  name: routeTableName
  location: location
  properties: {
    routes: []
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
        name: 'defaultSubnet'
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
    ]
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2026-05-02-preview' = {
  // This API version should violate AKSC-012: Azure Kubernetes Service Clusters must not be created using a preview ARM API version
  name: aksName
  location: location
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  properties: {
    aadProfile: {}
    //this should violate AKSC-010: Azure Kubernetes Service Clusters should enable Microsoft Entra ID integration

    addonProfiles: {
      azurepolicy: {
        enabled: false //this should violate AKSC-001: Azure Policy Add-on should be enabled on Azure Kubernetes Service clusters
        config: {
          version: 'v2'
        }
      }
    }
    agentPoolProfiles: [
      {
        availabilityZones: [
          '3'
        ]
        count: 1
        enableAutoScaling: true
        //enableEncryptionAtHost: false //this should violate AKSC-005: Temp disks and cache for agent node pools in Azure Kubernetes Service clusters should be encrypted at host

        maxCount: 3
        maxPods: 30
        minCount: 1
        mode: 'System'
        name: 'systempool'
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        osDiskSizeGB: 0
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        vmSize: 'Standard_B2s'
        vnetSubnetID: virtualNetwork.properties.subnets[0].id
      }
    ]
    apiServerAccessProfile: {
      disableRunCommand: false //this should violate AKSC-009: Azure Kubernetes Service Clusters should disable Command Invoke
      enablePrivateCluster: false //this should violate AKSC-003: Azure Kubernetes Service Private Clusters should be enabled
    }
    disableLocalAccounts: false //this should violate AKSC-006: Azure Kubernetes Service Clusters should have local authentication methods disabled
    dnsPrefix: aksName
    enableRBAC: false //this should violate AKSC-007: Role-Based Access Control (RBAC) should be used on Kubernetes Services
    networkProfile: {
      networkPlugin: 'kubenet' //this should violate AKSC-002: Azure Kubernetes Service Clusters should use Azure CNI
    }
    storageProfile: {
      diskCSIDriver: {
        enabled: false //this should violate AKSC-008: Azure Kubernetes Service Clusters should have CSI driver for Azure Disks enabled
      }
      fileCSIDriver: {
        enabled: false //this should violate AKSC-008: Azure Kubernetes Service Clusters should have CSI driver for Azure Files enabled
      }
      snapshotController: {
        enabled: false //this should violate AKSC-008: Azure Kubernetes Service Clusters should have CSI driver for Azure Snapshots enabled
      }
    }
    securityProfile: {
      defender: {
        securityMonitoring: {
          enabled: false //this should violate AKSC-004: Azure Kubernetes Service clusters should have Defender profile enabled
        }
      }
    }

    servicePrincipalProfile: {} //this should violate AKSC-011: Azure Kubernetes Service Clusters should use managed identities
    identityProfile: {} //this should violate AKSC-011: Azure Kubernetes Service Clusters should use managed identities
  }
}

@description('The resource ID of the created Virtual Network Default Subnet.')
output defaultSubnetResourceId string = virtualNetwork.properties.subnets[0].id

@description('The resource ID of the created Virtual Network.')
output virtualNetworkResourceId string = virtualNetwork.id

output name string = aks.name
output resourceId string = aks.id
output location string = aks.location
