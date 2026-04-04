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
Test cases:
- PEDNS-012: Configure a private DNS Zone ID for Azure Container Registry (DeployIfNotExists)
- DS-003: Deploy Diagnostic Settings for Container Registry to Log Analytics workspace. (DeployIfNotExists)
- TAG-005: Inherit the tag from the Subscription to Resource Group if missing (appid)
- TAG-006: Inherit the tag from the Subscription to Resource Group if missing (dataclass)
- TAG-007: Inherit the tag from the Subscription to Resource Group if missing (owner)
- TAG-008: Inherit the tag from the Subscription to Resource Group if missing (supportteam)
- TAG-018: Inherit the tag from the Subscription to Resource Group if missing (environment)
- TAG-009: Inherit the tag from the Resource Group to Resources if missing (appid)
- TAG-010: Inherit the tag from the Resource Group to Resources if missing (dataclass)
- TAG-011: Inherit the tag from the Resource Group to Resources if missing (owner)
- TAG-012: Inherit the tag from the Resource Group to Resources if missing (supportteam)
- TAG-019: Inherit the tag from the Resource Group to Resources if missing (environment)
#>

#Parse deployment outputs
$resourceId = $script:bicepDeploymentOutputs.resourceId.value
$diagSettingsPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_diagSettingsAssignmentName`$" }
$peDNSPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_peDNSAssignmentName`$" }
$diagnosticSettingsId = "{0}{1}" -f $resourceId, $script:GlobalConfig_diagnosticSettingsIdSuffix
$privateEndpointResourceId = $script:bicepDeploymentOutputs.privateEndpointResourceId.value
$privateEndpointPrivateDNSZoneGroupId = '{0}{1}' -f $privateEndpointResourceId, $script:GlobalConfig_privateEndpointPrivateDNSZoneGroupIdSuffix

#define tests
$tests = @()

#region Modify / Append Policies

#TAG-005 rg-inherit-tag-from-sub (SolutionID)
$tests += New-ARTPropertyCountTestConfig 'TAG-005: Resource Group Should have appid tag' $script:token $script:bicepDeploymentResult.bicepDeploymentTarget 'tags.appid' 'equals' 1

#TAG-006 rg-inherit-tag-from-sub (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-006: Resource Group Should have dataclass tag' $script:token $script:bicepDeploymentResult.bicepDeploymentTarget 'tags.dataclass' 'equals' 1

#TAG-007 rg-inherit-tag-from-sub (owner)
$tests += New-ARTPropertyCountTestConfig 'TAG-007: Resource Group Should have owner tag' $script:token $script:bicepDeploymentResult.bicepDeploymentTarget 'tags.owner' 'equals' 1

#TAG-008 rg-inherit-tag-from-sub (supportteam)
$tests += New-ARTPropertyCountTestConfig 'TAG-008: Resource Group Should have supportteam tag' $script:token $script:bicepDeploymentResult.bicepDeploymentTarget 'tags.supportteam' 'equals' 1

#TAG-018 rg-inherit-tag-from-sub (environment)
$tests += New-ARTPropertyCountTestConfig 'TAG-018: Resource Group Should have environment tag' $script:token $script:bicepDeploymentResult.bicepDeploymentTarget 'tags.environment' 'equals' 1

#TAG-009 all-inherit-tag-from-rg (SolutionID)
$tests += New-ARTPropertyCountTestConfig 'TAG-009: Resource Should have appid tag' $script:token $resourceId 'tags.appid' 'equals' 1

#TAG-010 all-inherit-tag-from-rg (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-010: Resource Should have dataclass tag' $script:token $resourceId 'tags.dataclass' 'equals' 1

#TAG-011 all-inherit-tag-from-rg (owner)
$tests += New-ARTPropertyCountTestConfig 'TAG-011: Resource Should have owner tag' $script:token $resourceId 'tags.owner' 'equals' 1

#TAG-012 all-inherit-tag-from-rg (supportteam)
$tests += New-ARTPropertyCountTestConfig 'TAG-012: Resource Should have supportteam tag' $script:token $resourceId 'tags.supportteam' 'equals' 1

#TAG-019 all-inherit-tag-from-rg (environment)
$tests += New-ARTPropertyCountTestConfig 'TAG-019: Resource Should have environment tag' $script:token $resourceId 'tags.environment' 'equals' 1

#DeployIfNotExists Policies
$tests += New-ARTResourceExistenceTestConfig 'DS-003: Deploy Diagnostic Settings for Container Registry to Log Analytics workspace.' $script:token $diagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-003: Diagnostic Settings Policy Must Be Compliant' $script:token $resourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-003'
$tests += New-ARTResourceExistenceTestConfig 'PEDNS-012: Private DNS Record for Azure Container Registry PE must exist' $script:token $privateEndpointPrivateDNSZoneGroupId 'exists' $script:GlobalConfig_privateDNSZoneGroupAPIVersion
$tests += New-ARTPolicyStateTestConfig 'PEDNS-012: Private DNS Record Policy Must Be Compliant' $script:token $privateEndpointResourceId $peDNSPolicyAssignmentId 'Compliant' 'PEDNS-012'
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
