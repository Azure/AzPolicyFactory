<#
======================================================================================
AUTHOR: Tao Yang
DATE: 29/03/2026
NAME: pipeline-map-policy-integration-test-cases.ps1
VERSION: 2.0.0
COMMENT: Map required policy integration test cases based on modified files in the PR
======================================================================================
#>
<#
.SYNOPSIS
Determine which policy integration test cases need to be executed based on the modified files in the PR.

.DESCRIPTION
This script uses git diff command to determine the modified files in the PR.

It then checks if the modified files are in the ignored files list.

If the modified files are not in the ignored files list, it checks if the modified files are in the global test paths.

If any of the modified files are in the global test paths, all test cases will be executed.

If the modified files are not in the global test paths, it will check if the modified files are in the policy definition, initiative, assignment parameter files folder as well as the folders for individual policy integration test.

If the modified files are in the individual test paths, it will determine the required test cases based on the modified files.

.PARAMETER testConfigFilePath
Mandatory. The path of the policy integration test global configuration json file.

.PARAMETER targetGitBranch
Optional. The name of the target git branch. The default value is 'main'.

.PARAMETER testCaseDir
Optional. the path to the policy integration test cases. The default value is 'tests/policy-integration-tests'

.EXAMPLE
./pipeline-map-policy-integration-test-cases.ps1 -testConfigFilePath '..\..\..\tests\policy-integration-tests\.shared\policy_integration_test_config.jsonc'

Extract the deployment parameter information from the json exemption parameter file path.
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string]$testConfigFilePath,

  [parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$targetGitBranch = 'main',

  [parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$testCaseDir = 'tests/policy-integration-tests'
)

#region functions
#Function for reading the policy integration test global configuration file (supports JSONC with comments)
function getTestConfig {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$testConfigFilePath
  )
  $rawContent = Get-Content -Path $testConfigFilePath -Raw
  $testConfig = $rawContent | ConvertFrom-Json -Depth 99
  $testConfig
}

#function to get the name of the current checked out branch (borrowed from CARML)
function getGitBranchName {
  [CmdletBinding()]
  param ()

  # Get branch name from Git
  $BranchName = git branch --show-current

  # If git could not get name, try GitHub variable
  if ([string]::IsNullOrEmpty($BranchName) -and (Test-Path env:GITHUB_REF_NAME)) {
    $BranchName = $env:GITHUB_REF_NAME
  }

  # If git could not get name, try Azure DevOps variable
  if ([string]::IsNullOrEmpty($BranchName) -and (Test-Path env:BUILD_SOURCEBRANCHNAME)) {
    $BranchName = $env:BUILD_SOURCEBRANCHNAME
  }

  return $BranchName
}

#Function for searching definition from all initiatives in the policy initiatives path
function getInitiativesFromDefinition {
  [OutputType([system.array])]
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$definitionName,

    [parameter(Mandatory = $true)]
    [string]$policyInitiativesPath
  )
  $initiatives = @()
  #Get all initiatives in policy initiatives path

  $initiativeFiles = Get-childItem -Path $policyInitiativesPath -Filter '*.json' -Recurse

  Foreach ($file in $initiativeFiles) {
    $initiative = Get-Content $file.FullName -raw | ConvertFrom-Json -Depth 99
    $memberPolicies = $initiative.properties.policyDefinitions
    foreach ($memberPolicy in $memberPolicies) {
      if ($definitionName -ieq $memberPolicy.policyDefinitionId.split("/")[-1]) {
        Write-Verbose "  - Policy Definition '$definitionName' is a member of the initiative '$($initiative.name)' defined in '$($file.FullName)'." -verbose
        $initiatives += $($initiative.name)
        break
      }
    }
  }
  return , $initiatives
}
#function to iterate PSObjects properties based on the property name and path
function getPropertyValue {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [object]$object,

    [parameter(Mandatory = $true)]
    [string]$propertyName
  )
  $propertyValue = $object
  $propertyNames = $propertyName -split '\.'
  foreach ($name in $propertyNames) {
    $propertyValue = $propertyValue.$name
  }
  $propertyValue
}

#Function for reading the parameters from the parameter file of the policy assignment
function getAssignmentFromConfigurationFile {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$filePath
  )
  $fileContent = Get-Content -Path $filePath -Raw

  #Read parameters from parameter file
  $json = (ConvertFrom-Json $fileContent -Depth 99).policyAssignment
  $json
}

#Function for getting the test cases that are impacted by the policy assignment based on the 'policyAssignmentIds' defined in the test config file
function getTestCasesFromAssignment {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$assignmentName,

    [parameter(Mandatory = $true)]
    [string]$policyIntegrationTestsPath
  )
  $testsInScope = @()
  $testCases = Get-ChildItem -path $policyIntegrationTestsPath -Depth 1 -Directory

  foreach ($testCase in $testCases) {
    $testConfigFile = join-Path -Path $testCase.FullName -ChildPath 'config.json' -Resolve
    $testConfig = Get-Content -Path $testConfigFile -Raw | ConvertFrom-Json -Depth 99
    $policyAssignmentIds = $testConfig.policyAssignmentIds
    foreach ($policyAssignmentId in $policyAssignmentIds) {
      $assignmentNameFromTestConfig = $policyAssignmentId.split("/")[-1]
      if ($assignmentNameFromTestConfig -ieq $assignmentName) {
        Write-Verbose "   - Test case '$($testCase.Name)' is required for assignment '$assignmentName'." -Verbose
        $testsInScope += $testCase.Name
        break
      }
    }
  }
  return , $testsInScope
}

#Function for getting the assignments that are directly assigning the policy definition or initiative by reading the policy assignment bicep parameter files
function getAssignmentsFromInitiativeOrDefinition {
  [OutputType([System.Array])]
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$definitionName,

    [parameter(Mandatory = $true)]
    [string]$policyAssignmentsPath,

    [parameter(Mandatory = $true)]
    [string]$policyAssignmentConfigurationJsonPathForAssignmentName,

    [parameter(Mandatory = $true)]
    [string]$policyAssignmentConfigurationJsonPathForPolicyDefinitionId
  )
  $assignments = @()
  #Get all initiatives in policy initiatives path

  $assignmentFiles = Get-childItem -Path $policyAssignmentsPath -Recurse
  foreach ($file in $assignmentFiles) {
    $json = getAssignmentFromConfigurationFile -filePath $file.FullName
    $PolicyDefinitionId = getPropertyValue -object $json -propertyName $policyAssignmentConfigurationJsonPathForPolicyDefinitionId
    if ($definitionName -ieq $PolicyDefinitionId.split("/")[-1]) {
      $policyAssignmentName = getPropertyValue -object $json -propertyName $policyAssignmentConfigurationJsonPathForAssignmentName
      Write-Verbose "[$(getCurrentUTCString)]: Policy Assignment '$policyAssignmentName' defined in '$($file.name)' is used to assign definition / initiative '$definitionName'."
      $assignments += $policyAssignmentName
    }

  }

  return , $assignments
}

#Function for getting the required test cases based on the modified files that are in the policy definition, initiative, assignment parameter files folder as well as the folders for individual policy integration test
function getRequiredTestCases {
  [CmdletBinding()]
  param (
    [parameter(ParameterSetName = 'definition', Mandatory = $true)]
    [string]$changeFilePath,

    [parameter(Mandatory = $true)]
    [string]$policyInitiativesPath,

    [parameter(Mandatory = $true)]
    [string]$policyAssignmentsPath,

    [parameter(Mandatory = $true)]
    [string]$gitRoot,

    [parameter(Mandatory = $true)]
    [string]$policyAssignmentConfigurationJsonPathForAssignmentName,

    [parameter(Mandatory = $true)]
    [string]$policyAssignmentConfigurationJsonPathForPolicyDefinitionId
  )
  $resolvedRelativeFilePath = Resolve-Path -Path $changeFilePath -RelativeBasePath $gitRoot
  $assignments = new-object -TypeName System.Collections.ArrayList
  $requiredTestCases = new-object -TypeName System.Collections.ArrayList
  $changeType = ''
  if (isFileInPath -filePath $changeFilePath -paths $policyDefinitionsPath -gitRoot $gitRoot) {
    Write-Verbose "  - File '$changeFilePath' is in the policy definitions path" -Verbose
    $changeType = 'definition'
  } elseif (isFileInPath -filePath $changeFilePath -paths $policyInitiativesPath -gitRoot $gitRoot) {
    Write-Verbose "  - File '$changeFilePath' is in the policy initiatives path" -Verbose
    $changeType = 'initiative'
  } elseif (isFileInPath -filePath $changeFilePath -paths $policyAssignmentsPath -gitRoot $gitRoot) {
    Write-Verbose "  - File '$changeFilePath' is in the policy Assignments path" -Verbose
    $changeType = 'assignment'
  } elseif (isFileInPath -filePath $changeFilePath -paths $policyIntegrationTestsPath -gitRoot $gitRoot) {
    Write-Verbose "  - File '$changeFilePath' is in the policy Integration Tests path" -Verbose
    $changeType = 'integrationTest'
  }
  $policyAssignmentsResolvedPath = Resolve-Path -Path $policyAssignmentsPath -RelativeBasePath $gitRoot
  $policyIntegrationTestsResolvedPath = Resolve-Path -Path $policyIntegrationTestsPath -RelativeBasePath $gitRoot
  $policyInitiativesResolvedPath = Resolve-Path -Path $policyInitiativesPath -RelativeBasePath $gitRoot
  $baseParams = @{
    policyAssignmentsPath                                      = $policyAssignmentsResolvedPath
    policyAssignmentConfigurationJsonPathForAssignmentName     = $policyAssignmentConfigurationJsonPathForAssignmentName
    policyAssignmentConfigurationJsonPathForPolicyDefinitionId = $policyAssignmentConfigurationJsonPathForPolicyDefinitionId
  }
  Switch ($changeType) {
    'definition' {
      $definition = Get-Content -path $resolvedRelativeFilePath -raw | ConvertFrom-Json -Depth 99
      $definitionName = $definition.name
      Write-Verbose "  - policy definition name: $definitionName" -Verbose
      Write-Verbose "  - find all initiatives that definition '$definitionName' is a member of." -Verbose
      $initiatives = getInitiativesFromDefinition -definitionName $definitionName -policyInitiativesPath $policyInitiativesResolvedPath
      Write-Verbose "  - Number of Policy Initiatives found: $($initiatives.count)" -Verbose

      foreach ($initiative in $initiatives) {
        #look for all assignments that are directly assigning the initiative
        Write-Verbose "  - look for all assignments that are directly assigning the initiative '$initiative'." -Verbose
        foreach ($assignment in $(getAssignmentsFromInitiativeOrDefinition @baseParams -definitionName $initiative)) {
          if (!$assignments.Contains($assignment)) {
            $assignments.add($assignment) | Out-Null
          }
        }
      }
      #look for all assignments that are directly assigning the definition
      Write-Verbose "  - look for all assignments that are directly assigning the definition '$definitionName'." -Verbose
      foreach ($assignment in $(getAssignmentsFromInitiativeOrDefinition @baseParams -definitionName $definitionName)) {
        if (!$assignments.Contains($assignment)) {
          $assignments.add($assignment) | Out-Null
        }
      }
    }
    'initiative' {
      $initiative = Get-Content -path $resolvedRelativeFilePath -raw | ConvertFrom-Json -Depth 99
      $initiativeName = $initiative.name
      Write-Verbose "  - policy initiative name: $initiativeName" -Verbose

      Write-Verbose "  - look for all assignments that are directly assigning the initiative '$initiativeName'." -Verbose
      foreach ($assignment in $(getAssignmentsFromInitiativeOrDefinition @baseParams -definitionName $initiativeName)) {
        if (!$assignments.Contains($assignment)) {
          $assignments.add($assignment) | Out-Null
        }
      }
    }
    'assignment' {
      $parametersJson = getAssignmentFromConfigurationFile -filePath $resolvedRelativeFilePath
      $assignmentName = getPropertyValue -object $parametersJson -propertyName $policyAssignmentConfigurationJsonPathForAssignmentName
      Write-Verbose "  - policy assignment name: $assignmentName" -Verbose

      $assignments.add($assignmentName) | Out-Null

    }
    'integrationTest' {
      $testName = (Get-Item -Path $resolvedRelativeFilePath).Directory.Name

      if (!$requiredTestCases.Contains($testName)) {
        $requiredTestCases.add($testName) | Out-Null
      }
    }

  }
  Write-Verbose "  - Number of Policy Assignments found: $($assignments.count)" -Verbose
  if ($assignments.count -gt 0) {
    foreach ($assignment in $assignments) {
      Write-Verbose "  - look for policy integration tests that are required for assignment '$assignment'." -Verbose
      $testCases = getTestCasesFromAssignment -assignmentName $assignment -policyIntegrationTestsPath $policyIntegrationTestsResolvedPath
      foreach ($testCase in $testCases) {
        if (!$requiredTestCases.Contains($testCase)) {
          $requiredTestCases.add($testCase) | Out-Null
        }
      }
    }
  }
  Write-Verbose "  - Number of Policy Integration Tests found: $($requiredTestCases.count)" -Verbose
  return , $requiredTestCases
}

#Function to get modified files in a git repository based on the default branch
function getModifiedFiles {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$targetGitBranch,

    [parameter(Mandatory = $true)]
    [string]$gitRoot
  )
  $currentWorkingDiretory = $PWD
  #the following commands must be executed when the working dir is in the git root
  Write-verbose "[$(getCurrentUTCString)]: Setting working directory to $gitRoot" -Verbose
  Set-Location -Path $gitRoot
  $ModifiedFiles = new-object -TypeName System.Collections.ArrayList
  #Current branch
  $currentBranch = getGitBranchName
  Write-Verbose "[$(getCurrentUTCString)]: Current branch: $currentBranch" -Verbose
  #Firstly get the names of the modified files
  if (($CurrentBranch -ieq $targetGitBranch)) {
    Write-Verbose "[$(getCurrentUTCString)]: Gathering modified files from the pull request" -Verbose
    $diffFiles = git diff --name-only --diff-filter=AM HEAD^ HEAD
  } else {
    Write-Verbose "[$(getCurrentUTCString)]: Gathering modified files between current branch and $targetGitBranch" -Verbose
    $gitDiffCmd = "git diff --name-only --diff-filter=AM origin/$targetGitBranch"
    $diffFiles = invoke-expression $gitDiffCmd
  }
  Write-Verbose "[$(getCurrentUTCString)]: Total Modified files: $($diffFiles.count)" -Verbose
  #Secondly filter out the file changes that only consists white space and line changes
  foreach ($item in $diffFiles) {
    Write-Verbose "[$(getCurrentUTCString)]: Checking if '$item' has any content changes..." -Verbose
    if (($CurrentBranch -ieq $targetGitBranch)) {
      $gitDiffCmd = "git diff --ignore-all-space --ignore-blank-lines HEAD^ HEAD -- $item"
    } else {
      $gitDiffCmd = "git diff --ignore-all-space --ignore-blank-lines origin/$targetGitBranch -- $item"
    }
    $diff = invoke-expression $gitDiffCmd
    if ($diff.length -gt 0) {
      $ModifiedFiles.add($item) | Out-Null
    }
  }
  #Set working directory back to the original
  Write-Verbose "[$(getCurrentUTCString)]: Setting working directory back to $currentWorkingDiretory" -Verbose
  Set-Location -Path $currentWorkingDiretory
  Write-Verbose "[$(getCurrentUTCString)]: Total Modified files with content changes: $($ModifiedFiles.count)" -Verbose
  return , $ModifiedFiles
}

#Function to check if the file name matches the pattern
function fileNameMatch {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$fileName,

    [parameter(Mandatory = $true)]
    [string[]]$patterns
  )
  $bMatch = $false
  foreach ($pattern in $patterns) {
    #Write-Verbose "  - Check if $fileName matches pattern $pattern" -Verbose
    if ($fileName -like $pattern) {
      $bMatch = $true
      break
    }
  }
  $bMatch
}

#Function to check if the file is in the path
function isFileInPath {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [string]$filePath,

    [parameter(Mandatory = $true)]
    [string[]]$paths,

    [parameter(Mandatory = $true)]
    [string]$gitRoot
  )
  $isInPath = $false
  $resolvedRelativeFilePath = Resolve-Path -Path $filePath -RelativeBasePath $gitRoot -Relative

  foreach ($path in $paths) {
    $relativePath = Resolve-Path -Path $path -RelativeBasePath $gitRoot -Relative
    #Write-Verbose "  - Check if $resolvedRelativeFilePath is in $relativePath" -Verbose

    $isInPath = $resolvedRelativeFilePath -like "$relativePath*"
    if ($isInPath -eq $true) {
      break
    }
  }
  $isInPath
}
#endregion

#region main

#output variables
$requiredTestCases = new-object -TypeName System.Collections.ArrayList

#load helper functions
$helperFunctionScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'helper' 'helper-functions.ps1'
#load helper
. $helperFunctionScriptPath

$runtimePlatform = getPipelineType
$gitRoot = Get-GitRoot
$gitVersion = git --version
Write-Verbose $gitVersion -Verbose
#Get test config
$testConfig = Get-Content -Path $testConfigFilePath -Raw | ConvertFrom-Json -Depth 99
if ($null -eq $testConfig.testTriggers) {
  Throw "The 'testTriggers' section is missing from the test configuration file '$testConfigFilePath'. Please ensure the file contains a valid 'TestTriggers' section."
}
$localTestConfigFileName = $testConfig.testLocalConfigFileName
#Get test ignored files
$testIgnoredFiles = $testConfig.testTriggers.IgnoredFiles
Write-Verbose "[$(getCurrentUTCString)]: Test ignored files:" -Verbose
Foreach ($ignoredFile in $testIgnoredFiles) {
  Write-Verbose "  - $ignoredFile" -Verbose
}

#Get paths that will trigger all tests
$globalTestPaths = $testConfig.testTriggers.GlobalTestPaths
Write-Verbose "[$(getCurrentUTCString)]: File Paths that will trigger all tests:" -Verbose
Foreach ($globalTestPath in $globalTestPaths) {
  Write-Verbose "  - $globalTestPath" -Verbose
}

#Get the policy assignment parameter json path for assignment name
$policyAssignmentConfigurationJsonPathForAssignmentName = $testConfig.testTriggers.policyAssignmentConfigurationJsonPathForAssignmentName
Write-Verbose "[$(getCurrentUTCString)]: Policy Assignment Configuration JSON path for Assignment Name: '$policyAssignmentConfigurationJsonPathForAssignmentName'." -verbose

#Get the policy assignment parameter json path for policy definition ID
$policyAssignmentConfigurationJsonPathForPolicyDefinitionId = $testConfig.testTriggers.policyAssignmentConfigurationJsonPathForPolicyDefinitionId
Write-Verbose "[$(getCurrentUTCString)]: Policy Assignment Configuration JSON path for Assignment Policy Definition ID: '$policyAssignmentConfigurationJsonPathForPolicyDefinitionId'." -verbose

#Get paths that will trigger specific tests
$policyDefinitionsPath = Resolve-Path -Path $testConfig.testTriggers.PolicyDefinitionsPath -RelativeBasePath $gitRoot -Relative
Write-Verbose "[$(getCurrentUTCString)]: Policy Definitions Path: '$policyDefinitionsPath'." -Verbose

$policyInitiativesPath = Resolve-Path -Path $testConfig.testTriggers.PolicyInitiativesPath -RelativeBasePath $gitRoot -Relative
Write-Verbose "[$(getCurrentUTCString)]: Policy Initiatives Path: '$policyInitiativesPath'." -Verbose

$policyAssignmentsPath = Resolve-Path -Path $testConfig.testTriggers.PolicyAssignmentsPath -RelativeBasePath $gitRoot -Relative
Write-Verbose "[$(getCurrentUTCString)]: Policy Assignments Path: '$policyAssignmentsPath'." -Verbose

$policyIntegrationTestsPath = Resolve-Path -Path $testConfig.testTriggers.policyIntegrationTestsPath -RelativeBasePath $gitRoot -Relative
Write-Verbose "[$(getCurrentUTCString)]: Policy Integration Tests Path: '$policyIntegrationTestsPath'."

#Get modified files
$modifiedFiles = getModifiedFiles -targetGitBranch $targetGitBranch -gitRoot $gitRoot
Write-Verbose "[$(getCurrentUTCString)]: Modified files:" -Verbose
Foreach ($file in $modifiedFiles) {
  Write-Verbose "  - $file" -Verbose
}

#check if the modified files are in the ignored files
Write-Verbose "[$(getCurrentUTCString)]: Checking if the modified files are in the ignored files..." -Verbose
$ignoredFiles = @()
foreach ($file in $modifiedFiles) {
  #Write-Verbose "Checking if file '$file' is in the ignored files..." -Verbose
  $fileName = Split-Path -Path $file -Leaf
  $isIgnored = fileNameMatch -fileName $fileName -patterns $testIgnoredFiles
  if ($isIgnored) {
    Write-Verbose " - File '$file' is in the ignored files" -Verbose
    $ignoredFiles += $file
  } else {
    Write-Verbose " - File '$file' is not in the ignored files" -Verbose
  }
}
foreach ($ignoredFile in $ignoredFiles) {
  Write-Verbose "[$(getCurrentUTCString)]: Removing ignored file '$ignoredFile' from the modified files" -Verbose
  $modifiedFiles.Remove($ignoredFile)
}
#Check if the modified files are in the global test paths
Write-Verbose "[$(getCurrentUTCString)]: Process all modified files." -Verbose
$i = 1
Foreach ($file in $modifiedFiles) {
  Write-Verbose " - [$i/$($modifiedFiles.count)] - '$file'" -Verbose
  $isInGlobalTestPath = isFileInPath -filePath $file -paths $globalTestPaths -gitRoot $gitRoot
  if ($isInGlobalTestPath) {
    Write-Verbose "  - File '$file' is in the global test paths. all tests will be executed. No need to process the rest of the modified files." -Verbose
    $requiredTestCases.clear()
    $requiredTestCases.add('*') | Out-Null
    break
  } else {
    Write-Verbose "  - File '$file' is not in the global test paths. Will Check if individual tests need to be executed." -Verbose
    $getRequiredTestCasesParams = @{
      changeFilePath                                             = $file
      policyIntegrationTestsPath                                 = $policyIntegrationTestsPath
      policyInitiativesPath                                      = $policyInitiativesPath
      policyAssignmentsPath                                      = $policyAssignmentsPath
      gitRoot                                                    = $gitRoot
      policyAssignmentConfigurationJsonPathForAssignmentName     = $policyAssignmentConfigurationJsonPathForAssignmentName
      policyAssignmentConfigurationJsonPathForPolicyDefinitionId = $policyAssignmentConfigurationJsonPathForPolicyDefinitionId
    }
    $testCases = getRequiredTestCases @getRequiredTestCasesParams
    foreach ($testCase in $testCases) {
      if (!$requiredTestCases.contains($testCase)) {
        Write-Verbose "   - Adding test case '$testCase' to the required test cases." -Verbose
        $requiredTestCases.add($testCase) | Out-Null
      } else {
        Write-Verbose "   - Test case '$testCase' is already added previously." -Verbose
      }
    }

  }
  $i++
}

if ($requiredTestCases.Count -gt 0) {
  $shouldSkipTest = $false
  $strRequiredTestCases = $requiredTestCases -join ","
} else {
  $shouldSkipTest = $true
  $strRequiredTestCases = '_NONE_'
}
Write-Output "[$(getCurrentUTCString)]: Test Execution should be skipped: $shouldSkipTest"
Write-Output "[$(getCurrentUTCString)]: Required Test Cases:"
Foreach ($testCase in $requiredTestCases) {
  Write-Output "  - $testCase"
}
#convert $requiredTestCases to string
Write-Verbose "[$(getCurrentUTCString)]: Creating pipeline variable 'shouldSkipTest' with value '$shouldSkipTest'" -verbose
Write-Verbose "[$(getCurrentUTCString)]: Creating pipeline variable 'requiredTestCases' with value '$strRequiredTestCases'" -verbose

if ($runtimePlatform -ieq 'azure devops') {
  Write-Output ('##vso[task.setVariable variable={0};isOutput=true]{1}' -f 'shouldSkipTest', $shouldSkipTest)
  Write-Output ('##vso[task.setVariable variable={0}]{1}' -f 'shouldSkipTest', $shouldSkipTest)

  Write-Output ('##vso[task.setVariable variable={0};isOutput=true]{1}' -f 'requiredTestCases', $strRequiredTestCases)
  Write-Output ('##vso[task.setVariable variable={0}]{1}' -f 'requiredTestCases', $strRequiredTestCases)
} elseif ($runtimePlatform -ieq 'github actions') {
  write-output "shouldSkipTest=$shouldSkipTest" >> $env:GITHUB_OUTPUT
  write-output "requiredTestCases=$strRequiredTestCases" >> $env:GITHUB_OUTPUT
}

#endregion
