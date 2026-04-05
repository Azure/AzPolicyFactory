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

#region test specific configuration and tests
$storageAccountId = $script:terraformDeploymentOutputs.storage_account_id.value
$storageAccountName = ($storageAccountId -split ('/'))[-1]
$privateEndpointResourceId = $script:terraformDeploymentOutputs.storage_account_blob_pe_id.value
Write-Verbose "Storage Account Id: $storageAccountId" -verbose
$privateDNSSubscriptionId = $script:GlobalConfig_subscriptions.$script:GlobalConfig_privateDNSSubscription.id
$privateDNSResourceGroup = $script:GlobalConfig_privateDNSResourceGroup
$storagePolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_storageAccountAssignmentName`$" }
$diagSettingsPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_diagSettingsAssignmentName`$" }
$peDNSPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_peDNSAssignmentName`$" }
$diagnosticSettingsId = "{0}{1}" -f $storageAccountId, $script:GlobalConfig_diagnosticSettingsIdSuffix
$blobPrivateDNSARecordId = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net/A/{2}" -f $privateDNSSubscriptionId, $privateDNSResourceGroup, $storageAccountName

$violatingPolicies = @(
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-006'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-007'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Audit'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-009'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-010'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-012'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $storagePolicyAssignmentId
    policyDefinitionReferenceId = 'STG-008'
    resourceReference           = 'azapi_resource.storage_account'
    policyEffect                = 'Deny'
  }

)
#define tests
$tests = @()

#Modify / Append Policies
#TAG-010 all-inherit-tag-from-rg (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-010: Resource Should have dataclass tag' $script:token $storageAccountId 'tags.dataclass' 'equals' 1

#TAG-011 all-inherit-tag-from-rg (owner)
$tests += New-ARTPropertyCountTestConfig 'TAG-011: Resource Should have owner tag' $script:token $storageAccountId 'tags.owner' 'equals' 1

#DeployIfNotExists Policies
$tests += New-ARTResourceExistenceTestConfig 'DS-052: Diagnostic Settings Must Be Configured' $script:token $diagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-052: Diagnostic Settings Policy Must Be Compliant' $script:token $storageAccountId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-052'

$tests += New-ARTResourceExistenceTestConfig 'PEDNS-002: Private DNS Record for Storage Blob must exist' $script:token $blobPrivateDNSARecordId 'exists'
$tests += New-ARTPolicyStateTestConfig 'PEDNS-002: Private DNS Record Policy Must Be Compliant' $script:token $privateEndpointResourceId $peDNSPolicyAssignmentId 'Compliant' 'PEDNS-002'

#Deny policies
$tests += New-ARTTerraformPolicyRestrictionTestConfig -testName 'Violating Audit and Deny Policies should be detected from test Terraform template' -token $script:token -terraformDirectory $script:terraformViolateDirectoryPath -policyViolation $violatingPolicies
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
