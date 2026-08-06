@description('Optional. The location to deploy resources to.')
param location string = resourceGroup().location

@description('Required. The subnet Resource Id.')
param subnetResourceId string

@description('Required. The name of the AKS cluster.')
param aksName string

@description('Required. The Private DNS Zone Resource Id.')
param privateDnsZoneResourceId string

@description('Required. The Log Analytics Workspace Resource Id.')
param logAnalyticsWorkspaceResourceId string

@description('Required. The Managed Identity Resource Id.')
param managedIdentityResourceId string

@description('Required. The Kubelet Managed Identity Resource Id.')
param kubeletIdentityResourceId string

@description('Required. The Kubelet Managed Identity Client Id.')
param kubeletIdentityClientId string

@description('Required. The Kubelet Managed Identity Principal Id.')
param kubeletIdentityPrincipalId string

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
      '${managedIdentityResourceId}': {}
    }
  }
  properties: {
    aadProfile: {
      managed: true
      enableAzureRBAC: false
      adminGroupObjectIDs: [
        'af9b6889-c2d1-4871-8f77-73c4b3ad265d' // Azure Dev Admins group
      ]
    } //this should comply with AKSC-011: Azure Kubernetes Service Clusters should use managed identities

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
        name: 'agentpool01'
        osDiskSizeGB: 128
        count: 2
        enableAutoScaling: true
        minCount: 2
        maxCount: 5
        vmSize: 'standard_b2s_v2'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        maxPods: 110
        availabilityZones: []
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        enableNodePublicIP: false
        enableEncryptionAtHost: false //this should violate with AKSC-005: Temp disks and cache for agent node pools in Azure Kubernetes Service clusters should be encrypted at host
        kubeletDiskType: 'OS'
        orchestratorVersion: '1.32.3'
        vnetSubnetID: subnetResourceId
      }
    ]
    apiServerAccessProfile: {
      disableRunCommand: true //this should comply with AKSC-009: Azure Kubernetes Service Clusters should disable Command Invoke
      enablePrivateCluster: true //this should comply with AKSC-003: Azure Kubernetes Service Private Clusters should be enabled
      enablePrivateClusterPublicFQDN: false
      privateDNSZone: privateDnsZoneResourceId
    }
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      expander: 'random'
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '10m'
      'scale-down-delay-after-delete': '20s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '10m'
      'scale-down-unready-time': '20m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '10s'
      'skip-nodes-with-local-storage': 'true'
      'skip-nodes-with-system-pods': 'true'
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
      nodeOSUpgradeChannel: 'NodeImage'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    workloadAutoScalerProfile: {}
    metricsProfile: {
      costAnalysis: {
        enabled: false
      }
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
    disableLocalAccounts: true //this should comply with AKSC-006: Azure Kubernetes Service Clusters should have local authentication methods disabled
    nodeResourceGroup: '${resourceGroup().name}_aks_${aksName}_nodes'
    dnsPrefix: aksName
    enableRBAC: true
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
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
        securityMonitoring: {
          enabled: true //this should comply with AKSC-004: Azure Kubernetes Service clusters should have Defender profile enabled
        }
      }
    }
    kubernetesVersion: '1.36'
    publicNetworkAccess: 'Disabled'
    supportPlan: 'KubernetesOfficial'
    identityProfile: {
      kubeletIdentity: {
        clientId: kubeletIdentityClientId
        objectId: kubeletIdentityPrincipalId
        resourceId: kubeletIdentityResourceId
      }
    } //this should comply with AKSC-011: Azure Kubernetes Service Clusters should use managed identities
  }
}

output name string = aks.name
output resourceId string = aks.id
output location string = aks.location
