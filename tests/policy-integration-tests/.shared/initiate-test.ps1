#Requires -Modules Az.Resources
#Requires -Version 7.0


<#
=======================================================
AUTHOR: Tao Yang
DATE: 14/03/2026
NAME: initiate-test.ps1
VERSION: 1.0.0
COMMENT: Initiate test for policy integration testing
=======================================================
#>

[CmdletBinding()]
Param (

  [Parameter(Mandatory = $true, HelpMessage = 'Specify the global configuration file path.')]
  [string]$globalConfigFilePath,

  [Parameter(Mandatory = $true, HelpMessage = 'Specify the test directory.')]
  [string]$TestDirectory
)

#Get the variable values passed in from the pipeline (via environment variables) and set them as script level variables for later use in test scripts
$script:bicepDeploymentResult = $env:bicepDeploymentResult | ConvertFrom-Json -Depth 99
$script:terraformDeploymentResult = $env:terraformDeploymentResult | ConvertFrom-Json -Depth 99
$script:outputFilePath = $env:outputFilePath
$script:outputFormat = $env:outputFormat

Write-Verbose "The following variables are passed in from pipeline and set as script level variables for later use in test scripts:" -verbose
Write-Verbose "bicepDeploymentResult:" -verbose
Write-Verbose $($script:bicepDeploymentResult | ConvertTo-Json -Depth 99) -verbose
Write-Verbose "terraformDeploymentResult:" -verbose
Write-Verbose $($script:terraformDeploymentResult | ConvertTo-Json -Depth 99) -verbose
Write-Verbose "outputFilePath: $script:outputFilePath" -verbose
Write-Verbose "outputFormat: $script:outputFormat" -verbose

#if bicepDeploymentResult contains the bicepDeploymentOutputs and bicepProvisioningState properties, set them as script level variables for later use in test scripts, otherwise set them to $null
if ($null -ne $script:bicepDeploymentResult.PSObject.Properties['bicepDeploymentOutputs']) {
  $script:bicepDeploymentOutputs = $script:bicepDeploymentResult.bicepDeploymentOutputs | ConvertFrom-Json -Depth 99
} else {
  $script:bicepDeploymentOutputs = [PSCustomObject]@{}
}

if ($null -ne $script:bicepDeploymentResult.PSObject.Properties['bicepProvisioningState']) {
  $script:bicepProvisioningState = $script:bicepDeploymentResult.bicepProvisioningState
  Write-Verbose "bicepProvisioningState: $script:bicepProvisioningState" -verbose
} else {
  $script:bicepProvisioningState = $null
}
Write-Verbose "bicepDeploymentOutputs:" -verbose
Write-Verbose $($script:bicepDeploymentOutputs | ConvertTo-Json -Depth 99) -verbose


#if terraformDeploymentResult contains the terraformDeploymentOutputs and terraformProvisioningState properties, set them as script level variables for later use in test scripts, otherwise set them to $null
if ($null -ne $script:terraformDeploymentResult.PSObject.Properties['terraformDeploymentOutputs']) {
  $script:terraformDeploymentOutputs = $script:terraformDeploymentResult.terraformDeploymentOutputs | ConvertFrom-Json -Depth 99
} else {
  $script:terraformDeploymentOutputs = [PSCustomObject]@{}
}

if ($null -ne $script:terraformDeploymentResult.PSObject.Properties['terraformProvisioningState']) {
  $script:terraformProvisioningState = $script:terraformDeploymentResult.terraformProvisioningState
  Write-Verbose "terraformProvisioningState: $script:terraformProvisioningState" -verbose
} else {
  $script:terraformProvisioningState = $null
}

Write-Verbose "terraformDeploymentOutputs:" -verbose
Write-Verbose $($script:terraformDeploymentOutputs | ConvertTo-Json -Depth 99) -verbose


#load helper functions
$helperFunctionScriptPath = (resolve-path -relativeBasePath $PSScriptRoot -path '../../../scripts/pipelines/helper/helper-functions.ps1').Path
. $helperFunctionScriptPath

$globalConfigVariableNamePrefix = 'GlobalConfig_'
$localConfigVariableNamePrefix = 'LocalConfig_'

#Generate Azure oauth token
$script:token = (az account get-access-token --resource https://management.azure.com/ --query accessToken -o tsv)

If (-not $script:token) {
  throw "Failed to acquire Azure access token. Please sign in to Azure using Azure CLI."
}

#load Global config
$globalTestConfig = getTestConfig -TestConfigFilePath $globalConfigFilePath

#create an variable for each config from global config for later use in test scripts
Write-Output "Loading global config from file: $globalConfigFilePath"
foreach ($config in $globalTestConfig.GetEnumerator()) {
  $name = $globalConfigVariableNamePrefix + $config.Key
  # Set variable
  Set-Variable -Name $name -Value $config.Value -Scope Script
}

#load Local config
$testLocalConfigFileName = $script:GlobalConfig_testLocalConfigFileName
$localConfigFilePath = Join-Path $TestDirectory $testLocalConfigFileName
$localTestConfig = getTestConfig -TestConfigFilePath $localConfigFilePath

#create an variable for each config from local config for later use in test scripts
Write-Output "Loading local config from file: $localConfigFilePath"
foreach ($config in $localTestConfig.GetEnumerator()) {

  $name = $localConfigVariableNamePrefix + $config.Key
  # Set variable
  Set-Variable -Name $name -Value $config.Value -Scope Script
}
#Tags for resource group
if (!$script:LocalConfig_tagsForResourceGroup) {
  $script:LocalConfig_tagsForResourceGroup = $false
}

#Additional calculated variables
$script:whatIfComplyBicepTemplatePath = Join-Path $TestDirectory $script:GlobalConfig_whatIfComplyBicepTemplateName
$script:whatIfViolateBicepTemplatePath = Join-Path $TestDirectory $script:GlobalConfig_whatIfViolateBicepTemplateName
$script:terraformBackendStateFileDirectory = Join-Path $TestDirectory 'tf-state'
$script:terraformViolateDirectoryPath = Join-Path $TestDirectory $script:GlobalConfig_terraformViolateDirectoryName
$script:terraformComplyDirectoryPath = Join-Path $TestDirectory $script:GlobalConfig_terraformComplyDirectoryName
$script:testTerraformDirectoryPath = join-path $TestDirectory $script:GlobalConfig_testTerraformDirectoryName
$script:testTitle = "$script:LocalConfig_testName Configuration Test"
$script:contextTitle = "$script:LocalConfig_testName Configuration"
$script:testSuiteName = $script:LocalConfig_testName
$testSubscriptionName = $script:LocalConfig_testSubscription

Write-Verbose "Test Subscription Name: $testSubscriptionName" -Verbose
$script:testSubscriptionId = $script:GlobalConfig_subscriptions.$testSubscriptionName.id
Write-Verbose "Test Subscription ID: $script:testSubscriptionId" -Verbose
$script:testSubscriptionConfig = $script:GlobalConfig_subscriptions.$testSubscriptionName

#Set the environment variable 'ARM_SUBSCRIPTION_ID' to the test subscription id so that terraform can pick it up for authentication
$env:ARM_SUBSCRIPTION_ID = $script:testSubscriptionId

if ($script:LocalConfig_testResourceGroup.length -gt 0) {
  $script:testResourceGroupId = '/subscriptions/{0}/resourceGroups/{1}' -f $script:testSubscriptionId, $script:LocalConfig_testResourceGroup
  Write-Verbose "Test Resource Group ID: $script:testResourceGroupId" -Verbose
}
