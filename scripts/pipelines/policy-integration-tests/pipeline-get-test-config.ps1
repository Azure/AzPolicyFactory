<#
===================================================================
AUTHOR: Tao Yang
DATE: 30/03/2026
NAME: pipeline-get-test-config.ps1
VERSION: 2.0.0
COMMENT: Get test configurations for policy integration test cases
===================================================================
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType 'Container' })]
  [string]$directory,

  [parameter(Mandatory = $false)]
  [string]$ignoreFileName = '.testignore',

  [parameter(Mandatory = $false)]
  [string]$includedDirectory = ' ',

  [parameter(Mandatory = $true)]
  [int]$policyComplianceStateDelay,

  [parameter(Mandatory = $true)]
  [int]$appendModifyDelay,

  [parameter(Mandatory = $true)]
  [int]$DINEDelay,

  [parameter(Mandatory = $false)]
  [ValidateSet('true', 'false')]
  [string]$skip = 'false', #can't be boolean because pipeline can only pass string

  [parameter(Mandatory = $false)]
  [string]$testLocalConfigFileName = 'config.json',

  [parameter(Mandatory = $false)]
  [string]$testScriptName = 'tests.ps1'
)

#region functions
function getSubDir {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$directory,

    [parameter(Mandatory = $true)]
    [string]$ignoreFileName,

    [parameter(Mandatory = $false)]
    [string]$includedDirectory
  )
  if ($includedDirectory.length -gt 0) {
    #get the specific directory
    Write-Verbose "Searching for the directory '$includedDirectory' in '$directory' that doesn't contain '$ignoreFileName'." -Verbose
    $includedDirs = $includedDirectory -split ',' | ForEach-Object { $_.Trim() }
    $subDirectories = Get-ChildItem -Path $directory -Directory | where-object { $includedDirs -contains $_.Name } | where-object { -not (get-ChildItem $_.FullName -File -Filter $ignoreFileName -Force) }
    if (!$subDirectories) {
      throw "the '$includedDirectory' is not found in '$directory'."
    }
  } else {
    Write-Verbose "Get all sub directories in '$directory'." -Verbose
    $subDirectories = Get-ChildItem -Path $directory -Directory | where-object { -not (get-ChildItem $_.FullName -File -Filter $ignoreFileName -Force) }
  }
  $subDirectories
}

function getConfigForTestCase {
  [OutputType([hashtable])]
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [int]$policyComplianceStateDelay,

    [parameter(Mandatory = $true)]
    [int]$appendModifyDelay,

    [parameter(Mandatory = $true)]
    [int]$DINEDelay,

    [parameter(Mandatory = $true)]
    [string]$directory,

    [parameter(Mandatory = $true)]
    [string]$testLocalConfigFileName,

    [parameter(Mandatory = $true)]
    [string]$testScriptName
  )
  $runComplianceScan = $false

  $testLocalConfigFilePath = join-path $directory $testLocalConfigFileName
  $testScriptPath = join-path $directory $testScriptName
  if (Test-Path $testScriptPath -PathType 'Leaf') {
    $sanitisedTestScriptContent = sanitisePSScript -scriptPath $testScriptPath
  } else {
    Write-Warning "The test script '$testScriptName' is not found in directory '$directory'."
    $sanitisedTestScriptContent = ''
  }
  if (Test-Path $testLocalConfigFilePath -PathType 'Leaf') {
    try {
      $testLocalConfig = Get-Content -Path $testLocalConfigFilePath -Raw | ConvertFrom-Json -Depth 10
      $testSubscription = $testLocalConfig.testSubscription
      Write-Verbose "  - Test Subscription: '$testSubscription'." -Verbose
      $testAppendModifyPolicies = findCommandInScript -scriptContent $sanitisedTestScriptContent -commands $script:AppendModifyPolicyTestCommands
      $testDeployIfNotExistsPolicies = findCommandInScript -scriptContent $sanitisedTestScriptContent -commands $script:DeployIfNotExistPolicyTestCommands
      $testPolicyComplianceState = findCommandInScript -scriptContent $sanitisedTestScriptContent -commands $script:AuditTestCommands
      $testDenyPolicies = findCommandInScript -scriptContent $sanitisedTestScriptContent -commands $script:DenyPolicyTestCommands
      $testPolicyRestrictionAPIs = findCommandInScript -scriptContent $sanitisedTestScriptContent -commands $script:PolicyRestrictionAPICommands
      Write-Verbose "  - Test Append/Modify Policies: '$testAppendModifyPolicies'." -Verbose
      Write-Verbose "  - Test DeployIfNotExists Policies: '$testDeployIfNotExistsPolicies'." -Verbose
      Write-Verbose "  - Test Policy Compliance State: '$testPolicyComplianceState'." -Verbose
      Write-Verbose "  - Test Deny Policies: '$testDenyPolicies'." -Verbose
      Write-Verbose "  - Test Deny or Audit policies using Policy Restriction APIs: '$testPolicyRestrictionAPIs'." -Verbose

      #Calculate the maximum wait time for append, modify and DINE policies
      $waitTimeMinute = 0
      if ($testAppendModifyPolicies) {
        $waitTimeMinute = $appendModifyDelay
      }
      if ($testDeployIfNotExistsPolicies) {
        if ($waitTimeMinute) {
          $waitTimeMinute = [math]::Max($waitTimeMinute, $DINEDelay)
        } else {
          $waitTimeMinute = $DINEDelay
        }
      }
      if ($testPolicyComplianceState) {
        $runComplianceScan = $true
        if ($waitTimeMinute) {
          $waitTimeMinute = [math]::Max($waitTimeMinute, $policyComplianceStateDelay)
        } else {
          $waitTimeMinute = $policyComplianceStateDelay
        }
      }
    } catch {
      Write-Warning "$_.Exception.Message"
    }
  } else {
    Write-Warning "The test local config file '$testLocalConfigFilePath' is not found."
  }

  @{
    waitTimeMinute    = $waitTimeMinute
    runComplianceScan = $runComplianceScan
    testSubscription  = $testSubscription
  }
}
#endregion
#region main
$helperFunctionScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'helper' 'helper-functions.ps1'

#load helper
. $helperFunctionScriptPath

$runtimePlatform = getPipelineType
#Different Command names for different policy effect tests
$script:DenyPolicyTestCommands = @('New-ARTWhatIfDeploymentTestConfig', 'New-ARTManualWhatIfTestConfig')
$script:AppendModifyPolicyTestCommands = @('New-ARTPropertyCountTestConfig', 'New-ARTPropertyValueTestConfig')
$script:DeployIfNotExistPolicyTestCommands = @('New-ARTResourceExistenceTestConfig')
$script:AuditTestCommands = @('New-ARTPolicyStateTestConfig')
$script:PolicyRestrictionAPICommands = @('New-ARTArmPolicyRestrictionTestConfig', 'New-ARTTerraformPolicyRestrictionTestConfig')
$testDelayStartMinutes = 0
$complianceScanSubNames = @()
If ($skip -ieq 'true') {
  Write-Output "The skip test parameter is set to true. no tests required."
} else {
  Write-Verbose "directory: $directory" -Verbose

  #check if the included directory is specified as * which means all sub directories
  if ($includedDirectory -eq '*') {
    $includedDirectory = ''
  }
  $includedDirectory = $includedDirectory.trim()
  $ignoreFileName = $ignoreFileName.trim()

  $subDirectories = getSubDir -directory $directory -ignoreFileName $ignoreFileName -includedDirectory $includedDirectory
  $runComplianceScan = $false
  if ($subDirectories) {
    Foreach ($folder in $subDirectories) {
      Write-Verbose "Checking test configuration for test case in directory '$($folder.name)'..." -verbose
      $getTestConfigParams = @{
        directory                  = $folder.FullName
        testLocalConfigFileName    = $testLocalConfigFileName
        testScriptName             = $testScriptName
        policyComplianceStateDelay = $policyComplianceStateDelay
        appendModifyDelay          = $appendModifyDelay
        DINEDelay                  = $DINEDelay
      }
      $testConfig = getConfigForTestCase @getTestConfigParams
      Write-Verbose "  - Test delay Start value for test '$($folder.name)' is $($testConfig.waitTimeMinute)." -verbose
      Write-Verbose "  - Test '$($folder.name)' requirement for the compliance scan is $($testConfig.runComplianceScan)." -verbose
      if ($testConfig.waitTimeMinute -gt $testDelayStartMinutes) {
        $testDelayStartMinutes = $testConfig.waitTimeMinute
      }
      if ($testConfig.runComplianceScan -eq $true) {
        $runComplianceScan = $true
        $complianceScanSubNames += $testConfig.testSubscription
      }

    }
  } else {
    Write-Error "no sub directory in '$directory."
    Exit 1
  }
}
#deduplicate the compliance scan subscription names
$complianceScanSubNames = $complianceScanSubNames | Select-Object -Unique
$complianceScanSubNames = $(ConvertTo-Json -InputObject $complianceScanSubNames -Compress)
Write-Verbose "Run Compliance Scan: $runComplianceScan." -verbose

if ($runComplianceScan) {
  Write-Verbose "The subscription names that require compliance scan are: $complianceScanSubNames." -verbose
}
#Output Hashtable to ADO Pipeline as a Variable.
Write-Verbose "Delay start for all tests will be $testDelayStartMinutes minutes." -verbose
Write-Verbose "Run Compliance Scan: $($testConfig.runComplianceScan)" -verbose
if ($runtimePlatform -ieq 'azure devops') {
  Write-Output ('##vso[task.setVariable variable={0};isOutput=true]{1}' -f 'testDelayStartMinutes', $testDelayStartMinutes)
  Write-Output ('##vso[task.setVariable variable={0}]{1}' -f 'testDelayStartMinutes', $testDelayStartMinutes)
  Write-Output ('##vso[task.setVariable variable={0};isOutput=true]{1}' -f 'runComplianceScan', $runComplianceScan)
  Write-Output ('##vso[task.setVariable variable={0}]{1}' -f 'runComplianceScan', $runComplianceScan)
  Write-Output ('##vso[task.setVariable variable={0};isOutput=true]{1}' -f 'complianceScanSubNames', $complianceScanSubNames)
  Write-Output ('##vso[task.setVariable variable={0}]{1}' -f 'complianceScanSubNames', $complianceScanSubNames)
} elseif ($runtimePlatform -ieq 'github actions') {
  Add-Content -Path $env:GITHUB_OUTPUT -Value "testDelayStartMinutes=$testDelayStartMinutes"
  Add-Content -Path $env:GITHUB_OUTPUT -Value "runComplianceScan=$runComplianceScan"
  Add-Content -Path $env:GITHUB_OUTPUT -Value "complianceScanSubNames=$complianceScanSubNames"
} else {
  Write-Output "testDelayStartMinutes: $testDelayStartMinutes"
  Write-Output "runComplianceScan: $runComplianceScan"
  Write-Output "complianceScanSubNames: $complianceScanSubNames"
}
#endregion
