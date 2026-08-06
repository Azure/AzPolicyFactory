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
  - List the policy definitions being tested here.
#>
$resourceId = $script:bicepDeploymentOutputs.resourceId.value
$diagSettingsPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_diagSettingsAssignmentName`$" }
$peDNSPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_peDNSAssignmentName`$" }
$diagnosticSettingsId = "{0}{1}" -f $resourceId, $script:GlobalConfig_diagnosticSettingsIdSuffix
$aksControlPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_aksControlAssignmentName`$" }
$violatingPolicies = @(
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-001'
  }
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-002'
  }
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-003'
  }
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-004'
  }
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-005'
  }
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-006'
  }
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-007'
  }
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-008'
  }
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-009'
  }
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-010'
  }
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-011'
  },
  @{
    policyAssignmentId          = $aksControlPolicyAssignmentId
    policyDefinitionReferenceId = 'AKSC-012'
  }

)
#define tests
$tests = @()

#DeployIfNotExists Policies
$tests += New-ARTResourceExistenceTestConfig 'DS-004: Deploy Diagnostic Settings for Cognitive Service to Log Analytics workspace.' $script:token $diagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-004: Diagnostic Settings Policy Must Be Compliant' $script:token $resourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-004'

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
