<#
==========================================================
AUTHOR: Tao Yang
DATE: 18/07/2024
NAME: pipeline-initiate-policy-integration-tests.ps1
VERSION: 1.0.0
COMMENT: Initiate policy integration tests
==========================================================
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType 'Container' })]
  [string]$testDirectory,

  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string]$testConfigFilePath
)
$helperFunctionScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'helper' 'helper-functions.ps1'

#load helper
. $helperFunctionScriptPath

$runtimePlatform = getPipelineType

#read global configuration for policy integration test
$config = Get-Content $testConfigFilePath | ConvertFrom-Json
try {
  $testBicepTemplateName = $config.testBicepTemplateName
  $testTerraformDirectoryName = $config.testTerraformDirectoryName
  $testTerraformStateFileName = $config.testTerraformStateFileName
  $testTerraformEncryptedStateFileName = $config.testTerraformEncryptedStateFileName
  $testLocalConfigFileName = $config.testLocalConfigFileName
  $initialEvalMaximumWaitTime = $config.initialEvalMaximumWaitTime
  $testScriptName = $config.testScriptName
  $testOutputFilePrefix = $config.testOutputFilePrefix
  $testOutputFormat = $config.testOutputFormat
  $testBicepDeploymentOutputArtifactPrefix = $config.testBicepDeploymentOutputArtifactPrefix
  $testTerraformDeploymentOutputArtifactPrefix = $config.testTerraformDeploymentOutputArtifactPrefix
  $testDeploymentOutputFileName = $config.testDeploymentOutputFileName
  $waitTimeForPolicyComplianceStateAfterDeployment = $config.waitTimeForPolicyComplianceStateAfterDeployment
  $waitTimeForAppendModifyPoliciesAfterDeployment = $config.waitTimeForAppendModifyPoliciesAfterDeployment
  $waitTimeForDeployIfNotExistsPoliciesAfterDeployment = $config.waitTimeForDeployIfNotExistsPoliciesAfterDeployment
} catch {
  write-error $_.Exception.Message
  exit 1
}

#check if there are any tests that need to deploy test Bicep templates
$bBicepDeploymentRequired = $false
$tests = get-childitem -Path $testDirectory -Directory
if ($tests) {
  foreach ($t in $tests) {
    if (test-path $(join-path $t.FullName $testBicepTemplateName)) {
      Write-Verbose "Test $($t.name) contains '$testBicepTemplateName' that needs to be deployed." -verbose
      $bBicepDeploymentRequired = $true
    }
  }
}

#create pipeline output variables
Write-Verbose "Setting pipeline output variables..." -verbose
Write-Verbose "  - Setting testBicepTemplateName to '$testBicepTemplateName'..." -verbose
Write-Verbose "  - Setting testTerraformDirectoryName to '$testTerraformDirectoryName'..." -verbose
Write-Verbose "  - Setting testTerraformStateFileName to '$testTerraformStateFileName'..." -verbose
Write-Verbose "  - Setting testTerraformEncryptedStateFileName to '$testTerraformEncryptedStateFileName'..." -verbose
Write-Verbose "  - Setting testLocalConfigFileName to '$testLocalConfigFileName'..." -verbose
Write-Verbose "  - Setting initialEvalMaximumWaitTime to '$initialEvalMaximumWaitTime'..." -verbose
Write-Verbose "  - Setting initialEvalMaximumWaitTime to '$initialEvalMaximumWaitTime'..." -verbose
Write-Verbose " -- Setting testScriptName to '$testScriptName'..." -verbose
Write-Verbose "  - Setting testOutputFilePrefix to '$testOutputFilePrefix'..." -verbose
Write-Verbose "  - Setting testOutputFormat to '$testOutputFormat'..." -verbose
Write-Verbose "  - Setting testBicepDeploymentOutputArtifactPrefix to '$testBicepDeploymentOutputArtifactPrefix'..." -verbose
Write-Verbose "  - Setting testTerraformDeploymentOutputArtifactPrefix to '$testTerraformDeploymentOutputArtifactPrefix'..." -verbose
Write-Verbose "  - Setting testDeploymentOutputFileName to '$testDeploymentOutputFileName'..." -verbose
Write-Verbose "  - Setting bicepDeploymentRequired to '$bBicepDeploymentRequired'..." -verbose
Write-Verbose "  - Setting waitTimeForPolicyComplianceStateAfterDeployment to '$waitTimeForPolicyComplianceStateAfterDeployment'..." -verbose
Write-Verbose "  - Setting waitTimeForAppendModifyPoliciesAfterDeployment to '$waitTimeForAppendModifyPoliciesAfterDeployment'..." -verbose
Write-Verbose "  - Setting waitTimeForDeployIfNotExistsPoliciesAfterDeployment to '$waitTimeForDeployIfNotExistsPoliciesAfterDeployment'..." -verbose

if ($runtimePlatform -ieq 'azure devops') {

  Write-Output ('##vso[task.setVariable variable=testBicepTemplateName;isOutput=true]{0}' -f $testBicepTemplateName)
  Write-Output ('##vso[task.setVariable variable=testBicepTemplateName]{0}' -f $testBicepTemplateName)

  Write-Output ('##vso[task.setVariable variable=testTerraformDirectoryName;isOutput=true]{0}' -f $testTerraformDirectoryName)
  Write-Output ('##vso[task.setVariable variable=testTerraformDirectoryName]{0}' -f $testTerraformDirectoryName)

  Write-Output ('##vso[task.setVariable variable=testTerraformStateFileName;isOutput=true]{0}' -f $testTerraformStateFileName)
  Write-Output ('##vso[task.setVariable variable=testTerraformStateFileName]{0}' -f $testTerraformStateFileName)

  Write-Output ('##vso[task.setVariable variable=testTerraformEncryptedStateFileName;isOutput=true]{0}' -f $testTerraformEncryptedStateFileName)
  Write-Output ('##vso[task.setVariable variable=testTerraformEncryptedStateFileName]{0}' -f $testTerraformEncryptedStateFileName)

  Write-Output ('##vso[task.setVariable variable=testLocalConfigFileName;isOutput=true]{0}' -f $testLocalConfigFileName)
  Write-Output ('##vso[task.setVariable variable=testLocalConfigFileName]{0}' -f $testLocalConfigFileName)

  Write-Output ('##vso[task.setVariable variable=initialEvalMaximumWaitTime;isOutput=true]{0}' -f $initialEvalMaximumWaitTime)
  Write-Output ('##vso[task.setVariable variable=initialEvalMaximumWaitTime]{0}' -f $initialEvalMaximumWaitTime)

  Write-Output ('##vso[task.setVariable variable=testScriptName;isOutput=true]{0}' -f $testScriptName)
  Write-Output ('##vso[task.setVariable variable=testScriptName]{0}' -f $testScriptName)

  Write-Output ('##vso[task.setVariable variable=testOutputFilePrefix;isOutput=true]{0}' -f $testOutputFilePrefix)
  Write-Output ('##vso[task.setVariable variable=testOutputFilePrefix]{0}' -f $testOutputFilePrefix)

  Write-Output ('##vso[task.setVariable variable=testOutputFormat;isOutput=true]{0}' -f $testOutputFormat)
  Write-Output ('##vso[task.setVariable variable=testOutputFormat]{0}' -f $testOutputFormat)

  Write-Output ('##vso[task.setVariable variable=testBicepDeploymentOutputArtifactPrefix;isOutput=true]{0}' -f $testBicepDeploymentOutputArtifactPrefix)
  Write-Output ('##vso[task.setVariable variable=testBicepDeploymentOutputArtifactPrefix]{0}' -f $testBicepDeploymentOutputArtifactPrefix)

  Write-Output ('##vso[task.setVariable variable=testTerraformDeploymentOutputArtifactPrefix;isOutput=true]{0}' -f $testTerraformDeploymentOutputArtifactPrefix)
  Write-Output ('##vso[task.setVariable variable=testTerraformDeploymentOutputArtifactPrefix]{0}' -f $testTerraformDeploymentOutputArtifactPrefix)

  Write-Output ('##vso[task.setVariable variable=testDeploymentOutputFileName;isOutput=true]{0}' -f $testDeploymentOutputFileName)
  Write-Output ('##vso[task.setVariable variable=testDeploymentOutputFileName]{0}' -f $testDeploymentOutputFileName)

  Write-Output ('##vso[task.setVariable variable=bicepDeploymentRequired;isOutput=true]{0}' -f $bBicepDeploymentRequired)
  Write-Output ('##vso[task.setVariable variable=bicepDeploymentRequired]{0}' -f $bBicepDeploymentRequired)

  Write-Output ('##vso[task.setVariable variable=waitTimeForPolicyComplianceStateAfterDeployment;isOutput=true]{0}' -f $waitTimeForPolicyComplianceStateAfterDeployment)
  Write-Output ('##vso[task.setVariable variable=waitTimeForPolicyComplianceStateAfterDeployment]{0}' -f $waitTimeForPolicyComplianceStateAfterDeployment)

  Write-Output ('##vso[task.setVariable variable=waitTimeForAppendModifyPoliciesAfterDeployment;isOutput=true]{0}' -f $waitTimeForAppendModifyPoliciesAfterDeployment)
  Write-Output ('##vso[task.setVariable variable=waitTimeForAppendModifyPoliciesAfterDeployment]{0}' -f $waitTimeForAppendModifyPoliciesAfterDeployment)

  Write-Output ('##vso[task.setVariable variable=waitTimeForDeployIfNotExistsPoliciesAfterDeployment;isOutput=true]{0}' -f $waitTimeForDeployIfNotExistsPoliciesAfterDeployment)
  Write-Output ('##vso[task.setVariable variable=waitTimeForDeployIfNotExistsPoliciesAfterDeployment]{0}' -f $waitTimeForDeployIfNotExistsPoliciesAfterDeployment)
} elseif ($runtimePlatform -ieq 'github actions') {
  Write-Output "testBicepTemplateName=$testBicepTemplateName" >> $env:GITHUB_OUTPUT
  Write-Output "testTerraformDirectoryName=$testTerraformDirectoryName" >> $env:GITHUB_OUTPUT
  Write-Output "testTerraformStateFileName=$testTerraformStateFileName" >> $env:GITHUB_OUTPUT
  Write-Output "testTerraformEncryptedStateFileName=$testTerraformEncryptedStateFileName" >> $env:GITHUB_OUTPUT
  Write-Output "testLocalConfigFileName=$testLocalConfigFileName" >> $env:GITHUB_OUTPUT
  Write-Output "initialEvalMaximumWaitTime=$initialEvalMaximumWaitTime" >> $env:GITHUB_OUTPUT
  Write-Output "testScriptName=$testScriptName" >> $env:GITHUB_OUTPUT
  Write-Output "testOutputFilePrefix=$testOutputFilePrefix" >> $env:GITHUB_OUTPUT
  Write-Output "testOutputFormat=$testOutputFormat" >> $env:GITHUB_OUTPUT
  Write-Output "testBicepDeploymentOutputArtifactPrefix=$testBicepDeploymentOutputArtifactPrefix" >> $env:GITHUB_OUTPUT
  Write-Output "testTerraformDeploymentOutputArtifactPrefix=$testTerraformDeploymentOutputArtifactPrefix" >> $env:GITHUB_OUTPUT
  Write-Output "testDeploymentOutputFileName=$testDeploymentOutputFileName" >> $env:GITHUB_OUTPUT
  Write-Output "bicepDeploymentRequired=$bBicepDeploymentRequired" >> $env:GITHUB_OUTPUT
  Write-Output "waitTimeForPolicyComplianceStateAfterDeployment=$waitTimeForPolicyComplianceStateAfterDeployment" >> $env:GITHUB_OUTPUT
  Write-Output "waitTimeForAppendModifyPoliciesAfterDeployment=$waitTimeForAppendModifyPoliciesAfterDeployment" >> $env:GITHUB_OUTPUT
  Write-Output "waitTimeForDeployIfNotExistsPoliciesAfterDeployment=$waitTimeForDeployIfNotExistsPoliciesAfterDeployment" >> $env:GITHUB_OUTPUT

}
