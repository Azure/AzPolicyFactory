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
#variables
$resourceId = $script:bicepDeploymentOutputs.resourceId.value
$whatIfFailedTemplatePathNsg = join-path $PSScriptRoot 'main.bad.nsg.bicep'
$whatIfFailedTemplatePathNsgRule = join-path $PSScriptRoot 'main.bad.nsg.rule.bicep'
$whatIfSuccessTemplatePathNsg = join-path $PSScriptRoot 'main.good.nsg.bicep'
$whatIfSuccessTemplatePathNsgRule = join-path $PSScriptRoot 'main.good.nsg.rule.bicep'
$nsgAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_nsgAssignmentName`$" }
$diagSettingsPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_diagSettingsAssignmentName`$" }
$diagnosticSettingsId = "{0}{1}" -f $resourceId, $script:GlobalConfig_diagnosticSettingsIdSuffix

$violatingPolicies = @(
  @{
    policyAssignmentId          = $nsgAssignmentId
    policyDefinitionReferenceId = 'NSG-003'
  }
  @{
    policyAssignmentId          = $nsgAssignmentId
    policyDefinitionReferenceId = 'NSG-004'
  }
)

#define tests
$tests = @()

#DeployIfNotExists Policies
$tests += New-ARTResourceExistenceTestConfig 'DS-038: Diagnostic Settings Must Be Configured' $script:token $diagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-038: Diagnostic Settings Policy Must Be Compliant' $script:token $resourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-038'

#Deny policies
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Policy violating deployment for NSG should fail' -token $script:token -templateFilePath $whatIfFailedTemplatePathNsg -deploymentTargetResourceId $script:bicepDeploymentResult.bicepDeploymentTarget -requiredWhatIfStatus 'Failed' -policyViolation $violatingPolicies -maxRetry $script:GlobalConfig_whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Policy violating deployment for NSG Rules should fail' -token $script:token -templateFilePath $whatIfFailedTemplatePathNsgRule -deploymentTargetResourceId $script:bicepDeploymentResult.bicepDeploymentTarget -requiredWhatIfStatus 'Failed' -policyViolation $violatingPolicies -maxRetry $script:GlobalConfig_whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Policy abiding deployment for NSG should succeed' -token $script:token -templateFilePath $whatIfSuccessTemplatePathNsg -deploymentTargetResourceId $script:bicepDeploymentResult.bicepDeploymentTarget -requiredWhatIfStatus 'Succeeded' -maxRetry $script:GlobalConfig_whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Policy abiding deployment for NSG Rule should succeed' -token $script:token -templateFilePath $whatIfSuccessTemplatePathNsgRule -deploymentTargetResourceId $script:bicepDeploymentResult.bicepDeploymentTarget -requiredWhatIfStatus 'Succeeded' -maxRetry $script:GlobalConfig_whatIfMaxRetry
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
