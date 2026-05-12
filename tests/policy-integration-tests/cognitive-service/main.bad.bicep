metadata itemDisplayName = 'Test Template for xxx'
metadata description = 'This template deploys the testing resource for xxx.'
metadata summary = 'Deploys test xxx resources that should violate some policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')

var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'cog3'

resource cognitiveService 'Microsoft.CognitiveServices/accounts@2025-12-01' = {
  name: '${namePrefix}${serviceShort}01'
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  //identity: {} //no identity defined, this should violate the policy COG-003
  properties: {
    networkAcls: {
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled' //this should violate the policy COG-002
    disableLocalAuth: false //this should violate the policy COG-001
    allowProjectManagement: true
    customSubDomainName: '${namePrefix}${serviceShort}01'
    userOwnedStorage: [] //no user owned storage defined, this should violate the policy COG-004
  }
}

resource gpt51 'Microsoft.CognitiveServices/accounts/deployments@2025-12-01' = {
  name: 'gpt51'
  parent: cognitiveService
  sku: {
    name: 'GlobalStandard'
    capacity: 1
  }
  properties: {
    model: {
      name: 'gpt-5.1' //this should violate the policy COG-006 since gpt-5.1 is not in the allowed list of models defined in the policy
      format: 'OpenAI'
    }
  }
}

resource grok3 'Microsoft.CognitiveServices/accounts/deployments@2025-12-01' = {
  name: 'grok3'
  parent: cognitiveService
  sku: {
    name: 'GlobalStandard'
    capacity: 1
  }
  properties: {
    model: {
      name: 'grok-3' //this should violate the policy COG-007 since grok-3 is not in the allowed list of models defined in the policy
      format: 'xAI'
    }
  }
}
resource deepseekr1 'Microsoft.CognitiveServices/accounts/deployments@2025-12-01' = {
  name: 'deepseekr1'
  parent: cognitiveService
  properties: {
    model: {
      name: 'DeepSeek-R1'
      format: 'DeepSeek' //this should violate the policy COG-005 since DeepSeek is not in the allowed list of formats defined in the policy
    }
  }
}
