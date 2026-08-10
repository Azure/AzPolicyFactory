metadata itemDisplayName = 'Test Template for Cognitive Services'
metadata description = 'This template deploys the testing resource for Cognitive Services.'
metadata summary = 'Deploys test Cognitive Services resources that should comply with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')

var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'cog2'

resource cognitiveService 'Microsoft.CognitiveServices/accounts@2025-12-01' = {
  name: '${namePrefix}${serviceShort}01'
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  } //identity defined, this should comply with the policy COG-003
  properties: {
    networkAcls: {
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled' //this should comply with the policy COG-002
    allowProjectManagement: true
    customSubDomainName: '${namePrefix}${serviceShort}01'
    userOwnedStorage: [
      {
        resourceId: storage.id
      }
    ] //user owned storage defined, this should comply with the policy COG-004
  }
}
resource gpt54 'Microsoft.CognitiveServices/accounts/deployments@2025-12-01' = {
  name: 'gpt54'
  parent: cognitiveService
  sku: {
    name: 'DataZoneStandard' //this should comply with the policy COG-011 since this model must use DataZoneStandard as the deployment type
    capacity: 150
  }
  properties: {
    model: {
      name: 'gpt-5.4'
      format: 'OpenAI'
    }
    raiPolicyName: 'Microsoft.DefaultV2' //this should comply with the policy COG-010 since Microsoft.DefaultV2 is in the allowed list of RAI policies defined in the policy
  }
}

resource grok 'Microsoft.CognitiveServices/accounts/deployments@2025-12-01' = {
  name: 'grok-4-1-fast-reasoning'
  parent: cognitiveService
  sku: {
    name: 'GlobalStandard'
    capacity: 4
  }
  properties: {
    model: {
      name: 'grok-4-1-fast-reasoning'
      format: 'xAI'
      version: '1'
    }
    raiPolicyName: 'Contoso.DefaultV1' //this should comply with the policy COG-010 since Contoso.DefaultV1 is in the allowed list of RAI policies defined in the policy
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2025-08-01' = {
  name: 'sa${namePrefix}${serviceShort}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    networkAcls: {
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled'
    allowCrossTenantReplication: false
    allowedCopyScope: 'AAD'
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}
