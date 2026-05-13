#region generic sections for all tests
#Requires -Modules Az.Accounts, Az.PolicyInsights, Az.Resources
#Requires -Version 7.0

using module AzResourceTest

$helperFunctionScriptPath = (resolve-path -relativeBasePath $PSScriptRoot -path '../../../scripts/pipelines/helper/helper-functions.ps1').Path

#load helper
. $helperFunctionScriptPath

#Run initiate-test script to set environment variables for test configuration and deployment
$globalConfigFilePath = (resolve-path -RelativeBasePath $PSScriptRoot -path '../.shared/policy_integration_test_config.jsonc').Path
$TestDirectory = $PSScriptRoot
Write-Output "Initiating test with global config file: $globalConfigFilePath and test directory: $TestDirectory"
$initiateTestScriptPath = (resolve-path -RelativeBasePath $PSScriptRoot -path '../.shared/initiate-test.ps1').Path
. $initiateTestScriptPath -globalConfigFilePath $globalConfigFilePath -TestDirectory $TestDirectory

# Refer to the ../../docs/policy-integration-test-get-started.md for details on the expected variables to be set by the initiate-test script and the structure of those variables.
#endregion

#region defining tests
<#
The following policy definitions are tested:.
  - COSMOS-001: Azure Cosmos DB accounts should have local authentication disabled (Modify)
  - COSMOS-002: Azure Cosmos DB accounts should have firewall rules (Deny)
  - COSMOS-003: Azure Cosmos DB should disable public network access (Deny)
  - COSMOS-004: Azure Cosmos DB accounts should use customer-managed keys to encrypt data at rest (Audit)
  - COSMOS-005: Azure Cosmos DB key based metadata write access should be disabled (Deny)
  - COSMOS-006: Azure Cosmos DB accounts should have a minimum TLS version (Deny)
  - COSMOS-007: Azure Cosmos DB allowed locations (Deny)
  - DS-014: Configure Diagnostic Setting for Azure Cosmos DB (DeployIfNotExists)
  - PEDNS-017: Private DNS Record for Azure Cosmos DB SQL PE must exist (DeployIfNotExists)
#>

#Parse deployment outputs
$resourceId = $script:bicepDeploymentOutputs.resourceId.value
$diagSettingsPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_diagSettingsAssignmentName`$" }
$peDNSPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_peDNSAssignmentName`$" }
$diagnosticSettingsId = "{0}{1}" -f $resourceId, $script:GlobalConfig_diagnosticSettingsIdSuffix
$cosmosPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_cosmosAssignmentName`$" }
$privateEndpointResourceId = $script:bicepDeploymentOutputs.privateEndpointResourceId.value
$privateEndpointPrivateDNSZoneGroupId = '{0}{1}' -f $privateEndpointResourceId, $script:GlobalConfig_privateEndpointPrivateDNSZoneGroupIdSuffix
$violatingPolicies = @(
  @{
    policyAssignmentId          = $cosmosPolicyAssignmentId
    policyDefinitionReferenceId = 'COSMOS-002'
  }
  @{
    policyAssignmentId          = $cosmosPolicyAssignmentId
    policyDefinitionReferenceId = 'COSMOS-003'
  }
  @{
    policyAssignmentId          = $cosmosPolicyAssignmentId
    policyDefinitionReferenceId = 'COSMOS-005'
  }
  @{
    policyAssignmentId          = $cosmosPolicyAssignmentId
    policyDefinitionReferenceId = 'COSMOS-006'
  }
  @{
    policyAssignmentId          = $cosmosPolicyAssignmentId
    policyDefinitionReferenceId = 'COSMOS-007'
  }
)
#define tests
$tests = @()

#Modify / Append Policies
$tests += New-ARTPropertyCountTestConfig 'COSMOS-001: Local authentication should be disabled' $script:token $resourceId 'properties.disableLocalAuth' 'equals' true

# Audit Policies
$tests += New-ARTPolicyStateTestConfig 'COSMOS-004: Azure Cosmos DB accounts should use customer-managed keys to encrypt data at rest' $script:token $resourceId $cosmosPolicyAssignmentId 'NonCompliant' 'COSMOS-004'

#DeployIfNotExists Policies
$tests += New-ARTResourceExistenceTestConfig 'DS-014: Deploy Diagnostic Settings for Cosmos DB to Log Analytics workspace.' $script:token $diagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-014: Diagnostic Settings Policy Must Be Compliant' $script:token $resourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-014'
$tests += New-ARTResourceExistenceTestConfig 'PEDNS-017: Private DNS Record for Azure Cosmos DB SQL PE must exist' $script:token $privateEndpointPrivateDNSZoneGroupId 'exists' $script:GlobalConfig_privateDNSZoneGroupAPIVersion
$tests += New-ARTPolicyStateTestConfig 'PEDNS-017: Private DNS Record Policy Must Be Compliant' $script:token $privateEndpointResourceId $peDNSPolicyAssignmentId 'Compliant' 'PEDNS-017'

#Deny policies (testing both positive and negative scenarios)
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy abiding deployment should succeed' $script:token $script:whatIfComplyBicepTemplatePath $script:bicepDeploymentResult.bicepDeploymentTarget 'Succeeded' -maxRetry $script:GlobalConfig_whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy violating deployment should fail' $script:token $script:whatIfViolateBicepTemplatePath $script:bicepDeploymentResult.bicepDeploymentTarget 'Failed' $violatingPolicies -maxRetry $script:GlobalConfig_whatIfMaxRetry
#
#endregion

#region Invoke tests - do not modify
$params = @{
  tests         = $tests
  testTitle     = $script:testTitle
  contextTitle  = $script:contextTitle
  testSuiteName = $script:testSuiteName
  OutputFile    = $script:outputFilePath
  OutputFormat  = $script:GlobalConfig_testOutputFormat
}
Test-ARTResourceConfiguration @params

#endregion
