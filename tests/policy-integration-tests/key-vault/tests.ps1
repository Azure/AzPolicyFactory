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

# Refer to the ../README.md for details on the expected variables to be set by the initiate-test script and the structure of those variables.
#endregion

#region test specific configuration and tests
<#
The following policy definitions are tested:
  - Resource Group inherit the 'dataclass' tag from subscription
  - Resource Group inherit the 'owner' tag from subscription
  - Azure Key Vault should disable public network access (Audit)
  - Key Vault should have purge protection enabled (Modify)
  - Private DNS Record for Key Vault PE must exist (DeployIfNotExists)
  - Diagnostic Settings for Key Vault Must Be Configured (DeployIfNotExists)
  - KeyVault permission model should be configured to use Azure RBAC (Deny)
#>

#Parse Deployment outputs
$resourceId = $script:bicepDeploymentOutputs.resourceId.Value
$resourceName = ($resourceId -split ('/'))[-1]
$privateEndpointResourceId = $script:bicepDeploymentOutputs.privateEndpointResourceId.value
#prepare other variables needed for tests
$privateDNSSubscriptionId = $script:GlobalConfig_subscriptions.$script:GlobalConfig_privateDNSSubscription.id
$privateDNSResourceGroup = $script:GlobalConfig_privateDNSResourceGroup
$keyVaultPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_assignmentName`$" }
$diagSettingsPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_diagSettingsAssignmentName`$" }
$peDNSPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_peDNSAssignmentName`$" }
$diagnosticSettingsId = "{0}{1}" -f $resourceId, $script:GlobalConfig_diagnosticSettingsIdSuffix
$kvPrivateDNSARecordId = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net/A/{2}" -f $privateDNSSubscriptionId, $privateDNSResourceGroup, $resourceName

#define violating deny policies
$violatingPolicies = @(
  @{
    policyAssignmentId          = $keyVaultPolicyAssignmentId
    policyDefinitionReferenceId = 'KV-003' #KV-003: KeyVault permission model should be configured to use Azure RBAC
  }
)

#define tests
$tests = @()
#Modify / Append Policies

#TAG-006 rg-inherit-tag-from-sub (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-006: Resource Group Should have dataclass tag' $script:token $script:bicepDeploymentResult.bicepDeploymentTarget 'tags.dataclass' 'equals' 1
$tests += New-ARTPropertyCountTestConfig 'TAG-007: Resource Group Should have owner tag' $script:token $script:bicepDeploymentResult.bicepDeploymentTarget 'tags.owner' 'equals' 1
$tests += New-ARTPropertyValueTestConfig 'KV-002: Key Vault should have purge protection enabled' $script:token $resourceId 'boolean' 'properties.enablePurgeProtection' 'equals' $true

#Audit / AuditIfNotExists policies
$tests += New-ARTPolicyStateTestConfig 'KV-004: Azure Key Vault should disable public network access' $script:token $resourceId $keyVaultPolicyAssignmentId 'NonCompliant' 'KV-004'

#DeployIfNotExists Policies
$tests += New-ARTResourceExistenceTestConfig 'PEDNS-005: Private DNS Record for Key Vault PE must exist' $script:token $kvPrivateDNSARecordId 'exists'
$tests += New-ARTPolicyStateTestConfig 'PEDNS-005: Private DNS Record Policy Must Be Compliant' $script:token $privateEndpointResourceId $peDNSPolicyAssignmentId 'Compliant' 'PEDNS-005'
$tests += New-ARTResourceExistenceTestConfig 'DS-029: Diagnostic Settings for Key Vault Must Be Configured' $script:token $diagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-029: Diagnostic Settings Policy Must Be Compliant' $script:token $resourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-029'

#Deny policies (testing both positive and negative scenarios)
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy abiding deployment should succeed' $script:token $script:whatIfComplyBicepTemplatePath $script:bicepDeploymentResult.bicepDeploymentTarget 'Succeeded' -maxRetry $script:GlobalConfig_whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy violating deployment should fail' $script:token $script:whatIfViolateBicepTemplatePath $script:bicepDeploymentResult.bicepDeploymentTarget 'Failed' $violatingPolicies -maxRetry $script:GlobalConfig_whatIfMaxRetry
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
