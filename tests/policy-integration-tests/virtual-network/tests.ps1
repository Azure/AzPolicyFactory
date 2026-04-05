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

#variables
#Australia East VNet
$resourceId = $script:bicepDeploymentOutputs.resourceId.value
$resourceName = $script:bicepDeploymentOutputs.name.value

#Australia Southeast VNet
$aseVNetResourceName = $script:bicepDeploymentOutputs.aseVNetName.value
$aseVNetResourceId = $script:bicepDeploymentOutputs.aseVNetResourceId.value

$vnetPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_vnetAssignmentName`$" }
$diagSettingsPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_diagSettingsAssignmentName`$" }
$diagnosticSettingsId = "{0}{1}" -f $resourceId, $script:GlobalConfig_diagnosticSettingsIdSuffix
$aeVnetFlowLogId = '/subscriptions/{0}/resourceGroups/NetworkWatcherRG/providers/microsoft.network/networkwatchers/networkWatcher_australiaeast/flowlogs/{1}-flowlog' -f $script:testSubscriptionId, $resourceName
$aseVnetFlowLogId = '/subscriptions/{0}/resourceGroups/NetworkWatcherRG/providers/microsoft.network/networkwatchers/networkWatcher_australiasoutheast/flowlogs/{1}-flowlog' -f $script:testSubscriptionId, $aseVNetResourceName

#define violating deny policies
$violatingPolicies = @(
  @{
    policyAssignmentId          = $vnetPolicyAssignmentId
    policyDefinitionReferenceId = 'VNET-001'
  }
  @{
    policyAssignmentId          = $vnetPolicyAssignmentId
    policyDefinitionReferenceId = 'VNET-002'
  }
)
#define tests
$tests = @()

#DeployIfNotExists Policies
# DS-020 vnet-config-diag-logs
$tests += New-ARTResourceExistenceTestConfig 'DS-058: Diagnostic Settings for VNet Must Be Configured' $script:token $diagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-058: Diagnostic Settings Policy Must Be Compliant' $script:token $resourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-058'

#VNet Flow logs (Australia East)
$tests += New-ARTPropertyValueTestConfig -testName 'VNET-003: VNet Flow Log must be enabled in Australia East' -token $script:token -resourceId $aeVnetFlowLogId -property 'properties.enabled' -valueType 'boolean' -condition 'equals' -value $true -apiVersion $script:GlobalConfig_vnetFlowLogApiVersion
$tests += New-ARTPropertyCountTestConfig -testName 'VNET-003: VNet Flow Log (Australia East) Must Be Configured to use Log Analytics Workspace' -token $script:token -resourceId $aeVnetFlowLogId -property 'properties.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.workspaceResourceId' -condition 'equals' -count 1  -apiVersion $script:GlobalConfig_vnetFlowLogApiVersion
$tests += New-ARTPropertyValueTestConfig -testName 'VNET-003: VNet Flow Log (Australia East) Traffic Analytics must be enabled' -token $script:token -resourceId $aeVnetFlowLogId -property 'properties.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.enabled' -valueType 'boolean' -condition 'equals' -value $true  -apiVersion $script:GlobalConfig_vnetFlowLogApiVersion
$tests += New-ARTPolicyStateTestConfig 'VNET-003: VNet Flow Log Policy (Australia East) Must Be Compliant' $script:token $resourceId $vnetPolicyAssignmentId 'Compliant' 'VNET-003'

#VNet Flow logs (Australia Southeast)
$tests += New-ARTPropertyValueTestConfig -testName 'VNET-004: VNet Flow Log must be enabled in Australia Southeast' -token $script:token -resourceId $aseVnetFlowLogId -property 'properties.enabled' -valueType 'boolean' -condition 'equals' -value $true -apiVersion $script:GlobalConfig_vnetFlowLogApiVersion
$tests += New-ARTPropertyCountTestConfig -testName 'VNET-004: VNet Flow Log (Australia Southeast) Must Be Configured to use Log Analytics Workspace' -token $script:token -resourceId $aseVnetFlowLogId -property 'properties.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.workspaceResourceId' -condition 'equals' -count 1  -apiVersion $script:GlobalConfig_vnetFlowLogApiVersion
$tests += New-ARTPropertyValueTestConfig -testName 'VNET-004: VNet Flow Log (Australia Southeast) Traffic Analytics must be enabled' -token $script:token -resourceId $aseVnetFlowLogId -property 'properties.flowAnalyticsConfiguration.networkWatcherFlowAnalyticsConfiguration.enabled' -valueType 'boolean' -condition 'equals' -value $true  -apiVersion $script:GlobalConfig_vnetFlowLogApiVersion
$tests += New-ARTPolicyStateTestConfig 'VNET-004: VNet Flow Log Policy (Australia Southeast) Must Be Compliant' $script:token $aseVNetResourceId $vnetPolicyAssignmentId 'Compliant' 'VNET-004'

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
