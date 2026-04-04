<#
==================================================================================
AUTHOR: Tao Yang
DATE: 15/07/2025
NAME: pipeline-deploy-destroy-policy-test-terraform-template.ps1
VERSION: 1.0.0
COMMENT: Deploy or destroy test Terraform template for policy integration testing
==================================================================================
#>
[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true, HelpMessage = 'Specify the Test configuration path.')]
  [string]$testConfigFilePath,

  [Parameter(Mandatory = $true, HelpMessage = 'Required. Specify the Terraform file path.')]
  [ValidateNotNullOrEmpty()]
  [string]$terraformPath,

  [parameter(Mandatory = $false, HelpMessage = "Name of the Terraform template file that contains the backend configuration.")]
  [string]$tfBackendConfigFileName = 'backend.tf',

  [parameter(Mandatory = $true, HelpMessage = "Required. The path to the Terraform state file that to be configured in the backend config.")]
  [string]$tfBackendStateFileDirectory,

  [parameter(Mandatory = $false, HelpMessage = "Optional. The file name for the unencrypted terraform state file.")]
  [ValidateNotNullOrEmpty()]
  [string]$tfStateFileName = 'terraform_state.tfstate',

  [parameter(Mandatory = $false, HelpMessage = "Optional. The file name for the encrypted terraform state file.")]
  [ValidateNotNullOrEmpty()]
  [string]$tfEncryptedStateFileName = 'terraform_state.enc',

  [parameter(Mandatory = $false, HelpMessage = "Optional. The file name for the deployment result file.")]
  [ValidateNotNullOrEmpty()]
  [string]$deploymentResultFileName = 'result.json',

  [parameter(Mandatory = $false, HelpMessage = "Optional. he path to non-default workspaces that to be configured in the backend config.")]
  [AllowEmptyString()][AllowNull()]
  [string]$tfWorkspaceDir,

  [Parameter(Mandatory = $true, HelpMessage = "Terraform action (apply or destroy).")]
  [ValidateSet('apply', 'destroy')]
  [string]$tfAction,

  [Parameter(Mandatory = $false, HelpMessage = "Un-initialize Terraform after terraform apply or destroy.")]
  [ValidateSet('true', 'false')]
  [string]$uninitializeTerraform = 'false',

  [parameter(Mandatory = $false, HelpMessage = "Optional. The AES encryption key used to encrypt the Terraform state file.")]
  [string]$aesEncryptionKey,

  [parameter(Mandatory = $false, HelpMessage = "Optional. The AES encryption initialization vector used to encrypt the Terraform state file.")]
  [string]$aesIV
)

#region functions
function createResultFile {
  param (
    [Parameter(Mandatory = $false)]
    [string]$fileName = 'result.json',

    [Parameter(Mandatory = $true)]
    [string]$directory,

    [Parameter(Mandatory = $true)]
    [boolean]$terraformDeployment,

    [Parameter(Mandatory = $false)]
    [string]$provisioningState,

    [Parameter(Mandatory = $false)]
    [string]$deploymentOutputs
  )
  $result = @{
    terraformDeployment = $terraformDeployment
  }
  if ($provisioningState) {
    $result.add('terraformProvisioningState', $provisioningState)
  }
  if ($deploymentOutputs) {
    $result.add('terraformDeploymentOutputs', $deploymentOutputs)
  }
  $result | ConvertTo-Json -Depth 99 | Out-File -FilePath (Join-Path -Path $directory -ChildPath $fileName) -Encoding utf8
}
#endregion

#region main
#load helper functions
$helperFunctionScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'helper' 'helper-functions.ps1'
. $helperFunctionScriptPath
$runtimePlatform = getPipelineType
#Get the test config
$gitRoot = Get-GitRoot
$testGlobalConfigFilePath = join-path $gitRoot 'tests' 'policy-integration-tests' '.shared' 'policy_integration_test_config.jsonc'
Write-Verbose "Loading Global Test configuration from ''$testGlobalConfigFilePath'..." -verbose
$globalTestConfig = getTestConfig -TestConfigFilePath $testGlobalConfigFilePath
Write-Verbose "Loading Local Test configuration from ''$testConfigFilePath'..." -verbose
$localTestConfig = getTestConfig -TestConfigFilePath $testConfigFilePath
$testSubName = $localTestConfig.testSubscription
$testSubId = $globalTestConfig.subscriptions.$testSubName.id

#Set the environment variable 'ARM_SUBSCRIPTION_ID' to the test subscription id so that terraform can pick it up for authentication
$env:ARM_SUBSCRIPTION_ID = $testSubId
#Check if the terraform directory exists
if (-not (Test-Path -Path $terraformPath )) {
  Write-Output "The specified Terraform path '$terraformPath' does not exist. 'Terraform $tfAction' Skipped."
  if ($tfAction -eq 'apply') {
    #create empty pipeline variable for terraformDeploymentOutputs
    $deploymentOutputs = '{}'
    if ($runtimePlatform -ieq 'azure devops') {
      Write-Output "##vso[task.setvariable variable=terraformDeploymentOutputs]$deploymentOutputs"
      Write-Output "##vso[task.setvariable variable=terraformDeploymentOutputs;isOutput=true]$deploymentOutputs}"
    } elseif ($runtimePlatform -ieq 'github actions') {
      Write-Output "terraformDeploymentOutputs=$deploymentOutputs" >> $env:GITHUB_OUTPUT
    }
    #create an empty folder for the artifact so the publish artifact task does not fail

    if (-not (Test-Path -Path $tfBackendStateFileDirectory)) {
      New-Item -Path $tfBackendStateFileDirectory -ItemType Directory -Force | Out-Null
    }
    #create result file
    createResultFile -fileName $deploymentResultFileName -directory $tfBackendStateFileDirectory -terraformDeployment $false
  }
  exit
}
#Get the test config
$helperFunctionScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'helper' 'helper-functions.ps1'
$tfHelperFunctionScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'helper' 'terraform-helper-functions.ps1'

#load helper functions
. $helperFunctionScriptPath
. $tfHelperFunctionScriptPath

#Convert the uninitializeTerraform parameter to boolean
$uninitializeTerraform = [bool]::Parse($uninitializeTerraform)
$tfBackendStateFilePath = join-path -Path $tfBackendStateFileDirectory -ChildPath $tfStateFileName
$tfEncryptedBackendStateFilePath = join-path -Path $tfBackendStateFileDirectory -ChildPath $tfEncryptedStateFileName
#apply or destroy terraform template
if ($tfAction -ieq 'apply') {
  if (-not (Test-Path -Path $tfBackendStateFileDirectory)) {
    New-Item -Path $tfBackendStateFileDirectory -ItemType Directory -Force | Out-Null
  }

  Write-Verbose "[$(getCurrentUTCString)]: Applying Terraform template at '$terraformPath'." -Verbose
} else {
  if ($aesEncryptionKey -and $aesIV) {
    Write-Verbose "[$(getCurrentUTCString)]: Decrypting Terraform state file at '$tfEncryptedBackendStateFilePath'." -Verbose
    $tfStateFile = Get-item -Path $tfEncryptedBackendStateFilePath -ErrorAction Stop
    $tfStateFileDir = $tfStateFile.DirectoryName
    $decryptedFileName = "$($tfStateFile.BaseName).decrypted.tfstate"
    $decryptedBackupFileName = "$($tfStateFile.BaseName).decrypted.tfstate.backup"
    $decryptedFilePath = Join-Path -Path $tfStateFileDir -ChildPath $decryptedFileName
    $decryptedBackupFilePath = Join-Path -Path $tfStateFileDir -ChildPath $decryptedBackupFileName
    decryptStuff -InputFilePath $tfEncryptedBackendStateFilePath -OutputFilePath $decryptedFilePath -AESKey $aesEncryptionKey -AESIV $aesIV
    $tfBackendStateFilePath = $decryptedFilePath
  }
  Write-Verbose "[$(getCurrentUTCString)]: Destroying resources previously created by Terraform template at '$terraformPath'." -Verbose
}

$params = @{
  tfPath                = $terraformPath
  tfAction              = $tfAction
  backendConfigFileName = $tfBackendConfigFileName
  localBackendPath      = $tfBackendStateFilePath
}
if ($tfWorkspaceDir.length -gt 0) {
  $params.add('localBackendWorkspaceDir', $tfWorkspaceDir)
}
applyDestroyTF @params

#remove the backend config file if it exists
$backendConfigFilePath = join-path $terraformPath $tfBackendConfigFileName
if (Test-Path -Path $backendConfigFilePath -PathType Leaf) {
  Write-Verbose "[$(getCurrentUTCString)]: Removing backend configuration file at '$backendConfigFilePath'." -Verbose
  Remove-Item -Path $backendConfigFilePath -Force -ErrorAction SilentlyContinue
} else {
  Write-Verbose "[$(getCurrentUTCString)]: Backend configuration file '$backendConfigFilePath' does not exist, skipping removal." -Verbose
}

#If terraform apply, parse the terraform output and store as the pipeline variable
if ($tfAction -eq 'apply') {
  $provisioningState = $script:tfExitCode ? 'Succeeded' : 'Failed'

  Write-Verbose "[$(getCurrentUTCString)]: Parsing Terraform output." -Verbose
  $tfState = Get-Content -path $tfBackendStateFilePath -raw | ConvertFrom-Json -depth 99
  $deploymentOutputs = $tfState.outputs | ConvertTo-Json -depth 99 -EnumsAsString -EscapeHandling 'EscapeNonAscii' -Compress
  createResultFile -fileName $deploymentResultFileName -directory $tfBackendStateFileDirectory -terraformDeployment $true -provisioningState $provisioningState -deploymentOutputs $deploymentOutputs
  if ($runtimePlatform -ieq 'azure devops') {
    Write-Output "##vso[task.setvariable variable=terraformDeploymentOutputs]$deploymentOutputs"
    Write-Output "##vso[task.setvariable variable=terraformDeploymentOutputs;isOutput=true]$deploymentOutputs"
  } elseif ($runtimePlatform -ieq 'github actions') {
    Write-Output "terraformDeploymentOutputs=$deploymentOutputs" >> $env:GITHUB_OUTPUT
  }
  $tfStateFile = Get-item -Path $tfBackendStateFilePath -ErrorAction Stop
  $tfStateFileDir = $tfStateFile.DirectoryName

  #encrypt the Terraform state file after terraform apply if AES key and IV are provided
  if ($aesEncryptionKey -and $aesIV) {
    Write-Verbose "[$(getCurrentUTCString)]: Encrypting Terraform state file at '$tfBackendStateFilePath'." -Verbose
    encryptStuff -InputFilePath $tfBackendStateFilePath -OutputFilePath $tfEncryptedBackendStateFilePath -AESKey $aesEncryptionKey -AESIV $aesIV
    Write-Verbose "[$(getCurrentUTCString)]: Delete original terraform state file at '$tfBackendStateFilePath'." -Verbose
    Remove-Item -Path $tfBackendStateFilePath -Force -ErrorAction SilentlyContinue
    if ($runtimePlatform -ieq 'azure devops') {
      Write-Output "##vso[task.setVariable variable=tfStateFileName]$tfEncryptedStateFileName"
      Write-Output "##vso[task.setVariable variable=tfStateFileName;isOutput=true]$tfEncryptedStateFileName"
      Write-Output "##vso[task.setVariable variable=tfStateFilePath]$tfEncryptedBackendStateFilePath"
      Write-Output "##vso[task.setVariable variable=tfStateFilePath;isOutput=true]$tfEncryptedBackendStateFilePath"
    } elseif ($runtimePlatform -ieq 'github actions') {
      Write-Output "tfStateFileName=$tfEncryptedStateFileName" >> $env:GITHUB_OUTPUT
      Write-Output "tfStateFilePath=$tfEncryptedBackendStateFilePath" >> $env:GITHUB_OUTPUT
    }
  } else {
    $tfStateFileName = $tfStateFile.Name
    if ($runtimePlatform -ieq 'azure devops') {
      Write-Output "##vso[task.setVariable variable=tfStateFileName]$tfStateFileName"
      Write-Output "##vso[task.setVariable variable=tfStateFileName;isOutput=true]$tfStateFileName"
      Write-Output "##vso[task.setVariable variable=tfStateFilePath]$tfBackendStateFilePath"
      Write-Output "##vso[task.setVariable variable=tfStateFilePath;isOutput=true]$tfBackendStateFilePath"
    } elseif ($runtimePlatform -ieq 'github actions') {
      Write-Output "tfStateFileName=$tfStateFileName" >> $env:GITHUB_OUTPUT
      Write-Output "tfStateFilePath=$tfBackendStateFilePath" >> $env:GITHUB_OUTPUT
    }
  }
}

#remove the decrypted state file if it exists
if ($tfAction -eq 'destroy' -and $decryptedFilePath) {
  Write-Verbose "[$(getCurrentUTCString)]: Removing decrypted Terraform state file at '$decryptedFilePath'." -Verbose
  Remove-Item -Path $decryptedFilePath -Force -ErrorAction SilentlyContinue
  if ((Test-Path -Path $decryptedBackupFilePath -PathType Leaf)) {
    Write-Verbose "[$(getCurrentUTCString)]: Removing decrypted Terraform state backup file at '$decryptedBackupFilePath'." -Verbose
    Remove-Item -Path $decryptedBackupFilePath -Force -ErrorAction SilentlyContinue
  }
}

if ($uninitializeTerraform) {
  Write-Verbose "[$(getCurrentUTCString)]: Uninitializing Terraform at '$terraformPath'." -Verbose
  uninitializeTFProject -tfPath $terraformPath
}

Write-Output "Done."
#endregion
