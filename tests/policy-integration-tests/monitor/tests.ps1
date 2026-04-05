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

$actionGroupName = 'ag01'
$monitorAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_assignmentName`$" }
$actionGroupViolatingResourceContent = @{
  properties = @{
    smsReceivers               = @(
      @{
        countryCode = '7' #Country code for Russia, should violate policy MON-002
        phoneNumber = '2345678901'
      }
    )
    emailReceivers             = @(
      @{
        emailAddress = 'test.user1@outlook.com' #violate policy MON-001
      }
    )
    automationRunbookReceivers = @(
      @{
        automationAccountId = '/subscriptions/62740b7e-8b53-4411-a353-14e023983d78/resourceGroups/rg-mon3-01/providers/Microsoft.Automation/automationAccounts/automationAccount1/webhooks/alert1' #violate policy MON-003
      }
    )
    eventHubReceivers          = @(
      @{
        eventHubNameSpace = '/subscriptions/62740b7e-8b53-4411-a353-14e023983d78/resourceGroups/rg-mon3-01/providers/Microsoft.EventHub/namespaces/eventHub1' #violate policy MON-004
      }
    )
    azureFunctionReceivers     = @(
      @{
        functionAppResourceId = '/subscriptions/62740b7e-8b53-4411-a353-14e023983d78/resourceGroups/rg-mon3-01/providers/Microsoft.Web/sites/functionApp1' #violate policy MON-005
      }
    )
    logicAppReceivers          = @(
      @{
        resourceId = '/subscriptions/62740b7e-8b53-4411-a353-14e023983d78/resourceGroups/rg-mon3-01/providers/Microsoft.Logic/workflows/logicApp1' #violate policy MON-006
      }
    )
    webhookReceivers           = @(
      @{
        serviceUri = 'http://webhookuri1.com' #violate policy MON-007 and MON-008
      }
    )
  }
} | ConvertTo-Json -Depth 99
Write-Output "Action Group Violating Resource Content: `n $actionGroupViolatingResourceContent"
$actionGroupViolatingResourceConfig = @{
  resourceName       = $actionGroupName
  resourceType       = 'Microsoft.Insights/actionGroups'
  apiVersion         = '2024-10-01-preview'
  resourceContent    = $actionGroupViolatingResourceContent
  location           = 'global'
  includeAuditEffect = $true
}
$policyRestrictionViolatingPolicies = @(
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-001'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-002'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-003'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-004'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-005'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-006'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-007'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-008'
    resourceReference           = $actionGroupName
    policyEffect                = 'Deny'
  }
)

$whatIfViolatingPolicies = @(
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-001'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-002'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-003'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-004'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-005'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-006'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-007'
  }
  @{
    policyAssignmentId          = $monitorAssignmentId
    policyDefinitionReferenceId = 'MON-008'
  }
)

#define tests
$tests = @()

$tests += New-ARTWhatIfDeploymentTestConfig 'Policy abiding deployment should succeed' $script:token $script:whatIfComplyBicepTemplatePath $script:testResourceGroupId 'Succeeded' -maxRetry $script:GlobalConfig_whatIfMaxRetry
$tests += New-ARTWhatIfDeploymentTestConfig 'Policy violating deployment should fail' $script:token $script:whatIfViolateBicepTemplatePath $script:testResourceGroupId 'Failed' $whatIfViolatingPolicies -maxRetry $script:GlobalConfig_whatIfMaxRetry
$tests += New-ARTArmPolicyRestrictionTestConfig -testName 'Action Group Configuration should violate deny policies' -token $script:token -deploymentTargetResourceId $script:testResourceGroupId -resourceConfig $actionGroupViolatingResourceConfig -policyViolation $policyRestrictionViolatingPolicies
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
