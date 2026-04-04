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
Test cases:
- DS-026: Configure Diagnostic Settings for Function App (DeployIfNotExists)
- DS-062: Configure Diagnostic Settings for App Services (DeployIfNotExists)
- PEDNS-006: Configure Private DNS Record for Web App Private Endpoint (DeployIfNotExists)
- PEDNS-015: Configure Private DNS Record for Web App Slots Private Endpoint (DeployIfNotExists)
- WEB-001: App Service and function app slots should only be accessible over HTTPS (Deny)
- WEB-002: App Service and Function apps should only be accessible over HTTPS (Deny)
- WEB-003: Function apps should only use approved identity providers for authentication (Deny)
- WEB-004: Prevent cross-subscription Private Link for App Services and Function Apps (Audit)
- WEB-005: Function apps should route application traffic over the virtual network (Deny)
- WEB-006: App Service and Function apps should route configuration traffic over the virtual network (Deny)
- WEB-007: Function apps should route configuration traffic over the virtual network (Deny)
- WEB-008: Function app slots should route configuration traffic over the virtual network (Deny)
- WEB-009: App Service apps should use a SKU that supports private link (Deny)
- WEB-010: Public network access should be disabled for App Services and Function Apps (Deny)
- WEB-011: Public network access should be disabled for App Service and Function App slots (Deny)
#>

#Parse deployment outputs
$functionAppResourceId = $script:bicepDeploymentOutputs.resourceId.value

$crossSubPeWebAppResourceId = $script:bicepDeploymentOutputs.crossSubPeWebAppResourceId.value
$webAppResourceId = $script:bicepDeploymentOutputs.webAppResourceId.value
$functionAppPrivateEndpointName = $script:bicepDeploymentOutputs.functionAppPrivateEndpointName.value
$functionAppPrivateEndpoints = $script:bicepDeploymentOutputs.functionAppPrivateEndpoints.value
$webAppPrivateEndpointName = $script:bicepDeploymentOutputs.webAppPrivateEndpointName.value
$webAppPrivateEndpoints = $script:bicepDeploymentOutputs.webAppPrivateEndpoints.value

#function app
$functionAppPrivateEndpoint = $functionAppPrivateEndpoints | where-object { $_.name -ieq $functionAppPrivateEndpointName }
$functionAppPrivateEndpointResourceId = $functionAppPrivateEndpoint.resourceId
$functionAppPrivateEndpointPrivateDNSZoneGroupId = '{0}{1}' -f $functionAppPrivateEndpointResourceId, $script:GlobalConfig_privateEndpointPrivateDNSZoneGroupIdSuffix
$crossSubPePrivateEndpointConnectionResourceId = $(getResourceViaARMAPI -token $script:token -resourceId "$crossSubPeWebAppResourceId/privateEndpointConnections" -apiVersion $script:GlobalConfig_appServicesAPIVersion).value[0].id
$functionAppDiagnosticSettingsId = "{0}{1}" -f $functionAppResourceId, $script:GlobalConfig_diagnosticSettingsIdSuffix

#web app
$webAppPrivateEndpoint = $webAppPrivateEndpoints | where-object { $_.name -ieq $webAppPrivateEndpointName }
$webAppPrivateEndpointResourceId = $webAppPrivateEndpoint.resourceId
$webAppPrivateEndpointPrivateDNSZoneGroupId = '{0}{1}' -f $webAppPrivateEndpointResourceId, $script:GlobalConfig_privateEndpointPrivateDNSZoneGroupIdSuffix
$webAppSlotPrivateEndpointResourceId = $script:bicepDeploymentOutputs.webAppSlotPrivateEndpointResourceId.value
$webAppSlotPrivateEndpointPrivateDNSZoneGroupId = '{0}{1}' -f $webAppSlotPrivateEndpointResourceId, $script:GlobalConfig_privateEndpointPrivateDNSZoneGroupIdSuffix
$AppServicesDiagnosticSettingsId = "{0}{1}" -f $webAppResourceId, $script:GlobalConfig_diagnosticSettingsIdSuffix
$CrossSubPeAppServicesDiagnosticSettingsId = "{0}{1}" -f $crossSubPeWebAppResourceId, $script:GlobalConfig_diagnosticSettingsIdSuffix

#policy assignment ids
$appServicesPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_AppServicesAssignmentName`$" }
$diagSettingsPolicyAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_diagSettingsAssignmentName`$" }

$violatingPolicies = @(
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-001'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-002'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-003'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-005'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-006'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-007'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-008'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-009'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-010'
  }
  @{
    policyAssignmentId          = $appServicesPolicyAssignmentId
    policyDefinitionReferenceId = 'WEB-011'
  }
)

#define tests
$tests = @()

#Audit / AuditIfNotExists Policies

$tests += New-ARTPolicyStateTestConfig 'WEB-004: Azure App Service and Function Apps with Cross subscription PE must be non-compliant with policy Prevent cross-subscription Private Link for Azure App Service' $script:token $crossSubPePrivateEndpointConnectionResourceId $appServicesPolicyAssignmentId 'NonCompliant' 'WEB-004'

#DeployIfNotExists Policies
$tests += New-ARTResourceExistenceTestConfig 'DS-062: Premium SKU App Services Diagnostic Settings Must Be Configured' $script:token $AppServicesDiagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-062: Premium SKU App Services Diagnostic Settings Policy Must Be Compliant' $script:token $webAppResourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-062'

$tests += New-ARTResourceExistenceTestConfig 'DS-062: Standard SKU App Services Diagnostic Settings Must Be Configured' $script:token $CrossSubPeAppServicesDiagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-062: Standard SKU App Services Diagnostic Settings Policy Must Be Compliant' $script:token $crossSubPeWebAppResourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-062'

$tests += New-ARTResourceExistenceTestConfig 'DS-062: Premium SKU App Services Diagnostic Settings Must Be Configured' $script:token $AppServicesDiagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-062: Premium SKU App Services Diagnostic Settings Policy Must Be Compliant' $script:token $webAppResourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-062'

$tests += New-ARTResourceExistenceTestConfig 'DS-062: Standard SKU App Services Diagnostic Settings Must Be Configured' $script:token $CrossSubPeAppServicesDiagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-062: Standard SKU App Services Diagnostic Settings Policy Must Be Compliant' $script:token $crossSubPeWebAppResourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-062'

$tests += New-ARTResourceExistenceTestConfig 'DS-026: Function App Diagnostic Settings Must Be Configured' $script:token $functionAppDiagnosticSettingsId 'exists' $script:GlobalConfig_diagnosticSettingsAPIVersion
$tests += New-ARTPolicyStateTestConfig 'DS-026: Function App Diagnostic Settings Policy Must Be Compliant' $script:token $functionAppResourceId $diagSettingsPolicyAssignmentId 'Compliant' 'DS-026'

$tests += New-ARTResourceExistenceTestConfig 'PEDNS-006: Private DNS Record for Function App PE must exist' $script:token $functionAppPrivateEndpointPrivateDNSZoneGroupId 'exists' $script:GlobalConfig_privateDNSZoneGroupAPIVersion
$tests += New-ARTResourceExistenceTestConfig 'PEDNS-006: Private DNS Record for Web App PE must exist' $script:token $webAppPrivateEndpointPrivateDNSZoneGroupId 'exists' $script:GlobalConfig_privateDNSZoneGroupAPIVersion
$tests += New-ARTResourceExistenceTestConfig 'PEDNS-015: Private DNS Record for Web App Slot PE must exist' $script:token $webAppSlotPrivateEndpointPrivateDNSZoneGroupId 'exists' $script:GlobalConfig_privateDNSZoneGroupAPIVersion

#Deny policies
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Policy violating deployment should fail' -token $script:token -templateFilePath $script:whatIfViolateBicepTemplatePath -deploymentTargetResourceId $script:testResourceGroupId -requiredWhatIfStatus 'Failed' -policyViolation $violatingPolicies -maxRetry $script:GlobalConfig_whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Policy abiding deployment should succeed' -token $script:token -templateFilePath $script:whatIfComplyBicepTemplatePath -deploymentTargetResourceId $script:testResourceGroupId -requiredWhatIfStatus 'Succeeded' -maxRetry $script:GlobalConfig_whatIfMaxRetry
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
