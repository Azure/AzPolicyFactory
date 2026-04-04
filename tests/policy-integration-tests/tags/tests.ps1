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
- TAG-001: Subscription Should have appid tag (deny)
- TAG-002: Subscription Should have dataclass tag with allowed value (deny)
- TAG-003: Subscription Should have owner tag (deny)
- TAG-004: Subscription Should have supportteam tag (deny)
- TAG-005: Inherit the tag from the Subscription to Resource Group if missing (appid)
- TAG-006: Inherit the tag from the Subscription to Resource Group if missing (dataclass)
- TAG-007: Inherit the tag from the Subscription to Resource Group if missing (owner)
- TAG-008: Inherit the tag from the Subscription to Resource Group if missing (supportteam)
- TAG-013: Resource Group Should have required tag value for dataclass tag (deny)
- TAG-014: Resource Should have required tag value for dataclass tag (deny)
- TAG-015: Subscription Should have required tag value for environment tag (deny)
- TAG-016: Resource Group Should have required tag value for environment tag (deny)
- TAG-017: Resource Should have required tag value for environment tag (deny)
- TAG-018: Inherit the tag from the Subscription to Resource Group if missing (environment)
#>

#variables

#Parse deployment outputs
$resourceId = $script:bicepDeploymentOutputs.resourceId.Value #Deployed resource group

#This test case uses non-standard bicep template names for what-if validation because it requires 2 separate templates. The template file names are defined in local config in this case.
$resourceWhatIfFailedTemplatePath = join-path $PSScriptRoot $script:LocalConfig_whatIfViolateBicepTemplateForResourcesName
$rgWhatIfFailedTemplatePath = join-path $PSScriptRoot $script:LocalConfig_whatIfViolateBicepTemplateForRGName

$testSubscriptionResourceId = '/subscriptions/{0}' -f $script:testSubscriptionId
$taggingAssignmentId = $script:LocalConfig_policyAssignmentIds | Where-Object { $_ -imatch "$script:LocalConfig_assignmentName`$" }

$subViolatingPolicies = @(
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-001'
  },
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-002'
  },
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-003'
  },
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-004'
  },
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-015'
  }
)

$rgViolatingPolicies = @(
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-013'
  },
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-016'
  }
)

$resourceViolatingPolicies = @(
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-014'
  },
  @{
    policyAssignmentId          = $taggingAssignmentId
    policyDefinitionReferenceId = 'TAG-017'
  }
)


#test sub update
$subViolatingTags = @{
  appid1       = '10207' #this should violate the policy TAG-001: Subscription Should have required tag (SolutionID)
  owner1       = 'platform-team' #this should violate the policy TAG-003: Subscription Should have required tag (owner)
  dataclass    = 'official-internal' #this should violate the policy TAG-002: Subscription Should have required tag value (dataclass). 'official-internal' is not one of the allowed values
  supportteam1 = 'platform-team' #this should violate the policy TAG-004: Subscription Should have required tag (supportteam)
  environment  = "hell" #this should violate the policy TAG-015: Subscription Should have required tag value (environment). 'hell' is not one of the allowed values
}

$subTagUpdateTestResponse = updateAzResourceTags -resourceId $testSubscriptionResourceId -token $script:token -tags $subViolatingTags -revertBack $true
$subTagUpdatePolicyActualViolations = ($subTagUpdateTestResponse.content | ConvertFrom-Json -depth 10).error.additionalInfo | Where-Object { $_.type -ieq 'policyviolation' }

#define tests
$tests = @()
$tests += New-ARTManualWhatIfTestConfig -testName 'Subscription Tagging Policy violating update should fail' -actualPolicyViolation $subTagUpdatePolicyActualViolations -desiredPolicyViolation $subViolatingPolicies
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Resource Group Tagging Policy violating deployment should fail' -token $script:token -templateFilePath $rgWhatIfFailedTemplatePath -deploymentTargetResourceId $testSubscriptionResourceId -requiredWhatIfStatus 'Failed' -policyViolation $rgViolatingPolicies -maxRetry $script:GlobalConfig_whatIfMaxRetry -azureLocation $script:LocalConfig_location
$tests += New-ARTWhatIfDeploymentTestConfig -testName 'Resource Tagging Policy violating deployment should fail' -token $script:token -templateFilePath $resourceWhatIfFailedTemplatePath -deploymentTargetResourceId $resourceId -requiredWhatIfStatus 'Failed' -policyViolation $resourceViolatingPolicies -maxRetry $script:GlobalConfig_whatIfMaxRetry

#Modify / Append Policies
#TAG-005 rg-inherit-tag-from-sub (appid)
$tests += New-ARTPropertyCountTestConfig 'TAG-005: Resource Group Should have appid tag' $script:token $resourceId 'tags.appid' 'equals' 1

#TAG-006 rg-inherit-tag-from-sub (dataclass)
$tests += New-ARTPropertyCountTestConfig 'TAG-006: Resource Group Should have dataclass tag' $script:token $resourceId 'tags.dataclass' 'equals' 1

#TAG-007 rg-inherit-tag-from-sub (owner)
$tests += New-ARTPropertyCountTestConfig 'TAG-007: Resource Group Should have owner tag' $script:token $resourceId 'tags.owner' 'equals' 1

#TAG-008 rg-inherit-tag-from-sub (supportteam)
$tests += New-ARTPropertyCountTestConfig 'TAG-008: Resource Group Should have supportteam tag' $script:token $resourceId 'tags.supportteam' 'equals' 1

#TAG-018 rg-inherit-tag-from-sub (environment)
$tests += New-ARTPropertyCountTestConfig 'TAG-018: Resource Group Should have environment tag' $script:token $resourceId 'tags.environment' 'equals' 1
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
