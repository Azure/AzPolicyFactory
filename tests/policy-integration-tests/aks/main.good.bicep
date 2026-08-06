metadata itemDisplayName = 'Test Template for AKS'
metadata description = 'This template deploys the testing resource for AKS.'
metadata summary = 'Deploys test AKS resource that should comply with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix
var testSubscription = localConfig.testSubscription
var testSubscriptionConfigJsonPath = format('$.subscriptions[\'{0}\']', testSubscription)
var testSubscriptionConfig = loadJsonContent(
  '../.shared/policy_integration_test_config.jsonc',
  testSubscriptionConfigJsonPath
)
var networkRg = testSubscriptionConfig.networkResourceGroup
var vnetName = testSubscriptionConfig.vNet
var aksSubnetName = testSubscriptionConfig.aksSubnet
// define template specific variables
var serviceShort = 'aks2'
var aksName = 'aks-${namePrefix}-${serviceShort}-01'
var managedIdentityName = 'uami-${namePrefix}-${serviceShort}-01'
var kubeletIdentityName = 'uami-${namePrefix}-${serviceShort}-02'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-07-01' existing = {
  name: vnetName
  scope: resourceGroup(networkRg)
  resource subnet 'subnets' existing = { name: aksSubnetName }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview' = {
  name: managedIdentityName
  location: location
}

resource kubeletIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-05-31-preview' = {
  name: kubeletIdentityName
  location: location
}

resource aks 'Microsoft.ContainerService/managedClusters@2026-05-01' = {
  // This API version should comply with AKSC-012: Azure Kubernetes Service Clusters must not be created using a preview ARM API version
  name: aksName
  location: location
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  } //this should comply with AKSC-011: Azure Kubernetes Service Clusters should use managed identities
  properties: {
    aadProfile: {
      managed: true
      enableAzureRBAC: false
      adminGroupObjectIDs: [
        'af9b6889-c2d1-4871-8f77-73c4b3ad265d' // Azure Dev Admins group
      ]
    } //this should comply with AKSC-010: Azure Kubernetes Service Clusters should enable Microsoft Entra ID integration

    addonProfiles: {
      azurepolicy: {
        enabled: true //this should comply with AKSC-001: Azure Policy Add-on should be enabled on Azure Kubernetes Service clusters
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
        enableEncryptionAtHost: true //this should comply with AKSC-005: Temp disks and cache for agent node pools in Azure Kubernetes Service clusters should be encrypted at host

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
        vnetSubnetID: virtualNetwork::subnet.id
      }
    ]
    apiServerAccessProfile: {
      disableRunCommand: true //this should comply with AKSC-009: Azure Kubernetes Service Clusters should disable Command Invoke
      enablePrivateCluster: true //this should comply with AKSC-003: Azure Kubernetes Service Private Clusters should be enabled
    }
    networkProfile: {
      networkPlugin: 'azure' //this should comply with AKSC-002: Azure Kubernetes Service Clusters should use Azure CNI
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      networkDataplane: 'azure'
      outboundType: 'loadBalancer'
      dnsServiceIP: '172.23.64.10'
      podCidr: '172.23.0.0/18'
      serviceCidr: '172.23.64.0/18'
      loadBalancerSku: 'Standard'
      loadBalancerProfile: {
        managedOutboundIPs: {
          count: 1
        }
        backendPoolType: 'nodeIPConfiguration'
      }
    }

    identityProfile: {
      kubeletIdentity: {
        clientId: kubeletIdentity.properties.clientId
        objectId: kubeletIdentity.properties.principalId
        resourceId: kubeletIdentity.id
      }
    }
    disableLocalAccounts: true //this should comply with AKSC-006: Azure Kubernetes Service Clusters should have local authentication methods disabled
    dnsPrefix: aksName
    enableRBAC: true //this should comply with AKSC-007: Role-Based Access Control (RBAC) should be used on Kubernetes Services
    storageProfile: {
      diskCSIDriver: {
        enabled: true //this should comply with AKSC-008: Azure Kubernetes Service Clusters should have CSI driver for Azure Disks enabled
      }
      fileCSIDriver: {
        enabled: true //this should comply with AKSC-008: Azure Kubernetes Service Clusters should have CSI driver for Azure Files enabled
      }
      snapshotController: {
        enabled: true //this should comply with AKSC-008: Azure Kubernetes Service Clusters should have CSI driver for Azure Snapshots enabled
      }
    }
    securityProfile: {
      defender: {
        securityMonitoring: {
          enabled: true //this should comply with AKSC-004: Azure Kubernetes Service clusters should have Defender profile enabled
        }
      }
    }
  }
}

@description('The resource ID of the created Virtual Network Default Subnet.')
output defaultSubnetResourceId string = virtualNetwork.properties.subnets[0].id

@description('The resource ID of the created Virtual Network.')
output virtualNetworkResourceId string = virtualNetwork.id

output name string = aks.name
output resourceId string = aks.id
output location string = aks.location
