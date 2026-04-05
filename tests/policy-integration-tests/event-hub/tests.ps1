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

#Parse deployment outputs
$resourceId = $script:bicepDeploymentOutputs.resourceId.value
$eventHubNoPeResourceId = $script:bicepDeploymentOutputs.eventHubNoPEResourceId.value
$diagSettingsPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_diagSettingsAssignmentName`$" }
$peDNSPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_peDNSAssignmentName`$" }
$diagnosticSettingsId = "{0}{1}" -f $resourceId, $script:GlobalConfig_diagnosticSettingsIdSuffix
$ehPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_eventHubAssignmentName`$" }
$privateEndpointResourceId = $script:bicepDeploymentOutputs.privateEndpointResourceId.value
$privateEndpointPrivateDNSZoneGroupId = '{0}{1}' -f $privateEndpointResourceId, $script:GlobalConfig_privateEndpointPrivateDNSZoneGroupIdSuffix

$violatingPolicies = @(
  @{
    policyAssignmentId          = $ehPolicyAssignmentId
    policyDefinitionReferenceId = 'EH-001'
  }
  @{
    policyAssignmentId          = $ehPolicyAssignmentId
    policyDefinitionReferenceId = 'EH-002'
  }
  @{
    policyAssignmentId          = $ehPolicyAssignmentId
    policyDefinitionReferenceId = 'EH-003'
  }
)
#define tests
$tests = @()

#region Audit Policies
$tests += New-ARTPolicyStateTestConfig 'EH-004: Event Hub Namespace use CMK encryption' $script:token $resourceId $ehPolicyAssignmentId 'NonCompliant' 'EH-004'
$tests += New-ARTPolicyStateTestConfig 'EH-005: Event Hub Namespace should use Private Endpoint' $script:token $eventHubNoPeResourceId $ehPolicyAssignmentId 'NonCompliant' 'EH-005'

#DeployIfNotExists Policies
$tests += New-ARTResourceExistenceTestConfig 'DS-022: Deploy Diagnostic Settings for Container Registry to Log Analytics workspace.' $script:token $diagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-022: Diagnostic Settings Policy Must Be Compliant' $script:token $resourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-022'
$tests += New-ARTResourceExistenceTestConfig 'PEDNS-007: Private DNS Record for Azure Container Registry PE must exist' $script:token $privateEndpointPrivateDNSZoneGroupId 'exists' $script:GlobalConfig_privateDNSZoneGroupAPIVersion
$tests += New-ARTPolicyStateTestConfig 'PEDNS-007: Private DNS Record Policy Must Be Compliant' $script:token $privateEndpointResourceId $peDNSPolicyAssignmentId 'Compliant' 'PEDNS-007'

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
