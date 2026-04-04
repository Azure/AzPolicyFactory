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

#region defining tests
<#
The following policy definitions are tested:.
  - PGS-001: Azure PostgreSQL flexible server should have Microsoft Entra Only Authentication enabled (Deny)
  - PGS-002: Public network access should be disabled for PostgreSQL flexible servers (Deny)
#>

$policyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_assignmentName`$" }

$violatingPolicies = @(
  @{
    policyAssignmentId          = $policyAssignmentId
    policyDefinitionReferenceId = 'PGS-001'
  }
  @{
    policyAssignmentId          = $policyAssignmentId
    policyDefinitionReferenceId = 'PGS-002'
  }
)

#define tests
$tests = @()

#AuditIfNotExists policies

#Deny policies
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy abiding deployment should succeed' $script:token $script:whatIfComplyBicepTemplatePath $script:testResourceGroupId 'Succeeded' -maxRetry $script:GlobalConfig_whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy violating deployment should fail' $script:token $script:whatIfViolateBicepTemplatePath $script:testResourceGroupId 'Failed' $violatingPolicies -maxRetry $script:GlobalConfig_whatIfMaxRetry

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
