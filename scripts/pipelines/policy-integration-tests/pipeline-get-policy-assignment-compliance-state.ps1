#Requires -Module @{ModuleName="Az.ResourceGraph"; ModuleVersion="0.10.0"}
<#
==============================================================================
AUTHOR: Tao Yang
DATE: 25/06/2024
NAME: pipeline-get-policy-assignment-compliance-state.ps1
VERSION: 1.0.0
COMMENT: Get policy assignment compliacen status using Azure Resource Graph
==============================================================================
#>
[CmdletBinding()]
param (
  [Parameter(Mandatory = $true, ParameterSetName = 'ByPolicyAssignmentId')]
  [string[]]$policyAssignmentId,

  [Parameter(Mandatory = $true, ParameterSetName = 'ByPolicyConfigFile')]
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string]$configFilePath,

  [parameter(Mandatory = $false)]
  [ValidateSet('true', 'false')]
  [string]$wait = 'true',

  [parameter(Mandatory = $false)]
  [ValidateRange(5, 30)]
  [int]$maximumWaitMinutes = 20
)

#region functions
function getComplianceState {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string[]]$policyAssignmentId
  )
  $resourceSearchScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'pipeline-resource-search.ps1'

  #build ARG query
  $arrResourceId = @()
  foreach ($item in $policyAssignmentId) {
    $arrResourceId += "'$item'"
  }
  $strResourceId = $arrResourceId -join ','
  #convert resourceId string to all lower case because the resourceId returned in ARG query is all in lower case
  $strResourceId = $strResourceId.ToLower()
  $ARGQuery = @"
PolicyResources
| where type =~ 'Microsoft.PolicyInsights/PolicyStates'
| extend complianceState = tostring(properties.complianceState)
| extend
  resourceId = tostring(properties.resourceId),
  policyAssignmentId = tolower(tostring(properties.policyAssignmentId)),
  policyAssignmentScope = tostring(properties.policyAssignmentScope),
  policyAssignmentName = tostring(properties.policyAssignmentName),
  policyDefinitionId = tostring(properties.policyDefinitionId),
  policyDefinitionReferenceId = tostring(properties.policyDefinitionReferenceId),
  stateWeight = iff(complianceState == 'NonCompliant', int(300), iff(complianceState == 'Compliant', int(200), iff(complianceState == 'Conflict', int(100), iff(complianceState == 'Exempt', int(50), int(0)))))
| where policyAssignmentId in ($strResourceId)
| summarize max(stateWeight) by resourceId, policyAssignmentId, policyAssignmentScope, policyAssignmentName
| summarize counts = count() by policyAssignmentId, policyAssignmentScope, max_stateWeight, policyAssignmentName
| summarize overallStateWeight = max(max_stateWeight),
nonCompliantCount = sumif(counts, max_stateWeight == 300),
compliantCount = sumif(counts, max_stateWeight == 200),
conflictCount = sumif(counts, max_stateWeight == 100),
exemptCount = sumif(counts, max_stateWeight == 50) by policyAssignmentId, policyAssignmentScope, policyAssignmentName
| extend totalResources = todouble(nonCompliantCount + compliantCount + conflictCount + exemptCount)
| extend compliancePercentage = iff(totalResources == 0, todouble(100), 100 * todouble(compliantCount + exemptCount) / totalResources)
| project policyAssignmentName, policyAssignmentId, scope = policyAssignmentScope,
complianceState = iff(overallStateWeight == 300, 'noncompliant', iff(overallStateWeight == 200, 'compliant', iff(overallStateWeight == 100, 'conflict', iff(overallStateWeight == 50, 'exempt', 'notstarted')))),
compliancePercentage,
compliantCount,
nonCompliantCount,
conflictCount,
exemptCount
"@

  Write-Verbose "Searching policy assignments compliance state using ARG query:" -verbose
  Write-Verbose $argQuery -Verbose
  $complianceState = & $resourceSearchScriptPath -ScopeType 'tenant' -customQuery $argQuery | ConvertFrom-Json
  $complianceState
}

function getPolicAssignment {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string[]]$policyAssignmentId
  )
  $resourceSearchScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'pipeline-resource-search.ps1'

  #build ARG query
  $arrResourceId = @()
  foreach ($item in $policyAssignmentId) {
    $arrResourceId += "'$item'"
  }
  $strResourceId = $arrResourceId -join ','
  #convert resourceId string to all lower case because the resourceId returned in ARG query is all in lower case
  $strResourceId = $strResourceId.ToLower()
  $assignmentARGQuery = @"
PolicyResources
| where type =~ 'Microsoft.Authorization/PolicyAssignments'
| extend policyAssignmentId = tolower(id)
| where policyAssignmentId in ($strResourceId)
"@

  Write-Verbose "Searching policy assignments using ARG query:" -verbose
  Write-Verbose $assignmentARGQuery -Verbose
  $assignments = & $resourceSearchScriptPath -ScopeType 'tenant' -customQuery $assignmentARGQuery | ConvertFrom-Json
  $assignments
}
#endregion

#region main
#load helper functions
$helperFunctionScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'helper' 'helper-functions.ps1'
. $helperFunctionScriptPath

$runtimePlatform = getPipelineType

if ($PSCmdlet.ParameterSetName -eq 'ByPolicyConfigFile') {
  $config = Get-Content $configFilePath -Raw | ConvertFrom-Json
  $policyAssignmentId = $config.policyAssignmentIds
}

$bAllPolicyAssignmentIdValid = $true
Write-Verbose "Make sure all policy assignments exist" -verbose
$assignments = getPolicAssignment -policyAssignmentId $policyAssignmentId
foreach ($item in $policyAssignmentId) {
  if ($assignments.policyAssignmentId -notcontains $item) {
    Write-Warning "  - Policy assignment '$item' does not exist." -ErrorAction Continue
    $bAllPolicyAssignmentIdValid = $false
  } else {
    Write-Verbose "  - Policy assignment '$item' exists." -verbose
  }
}

If ($bAllPolicyAssignmentIdValid -eq $false) {
  Write-Error "Not all policy assignments exist. Exiting..."
  Exit -1
}

if ($wait -eq 'true') {
  $waitStartTime = Get-Date
  $waitMinutesForNewAssignments = 5
  $waitEndTime = $waitStartTime.AddMinutes($maximumWaitMinutes)
  Do {
    $shouldWait = $false
    $complianceState = getComplianceState -policyAssignmentId $policyAssignmentId
    Write-Verbose "$($complianceState.Count) of $($policyAssignmentId.count) policy assignments compliance state returned from ARG query." -Verbose
    #Policy compliance state cannot be queried if there are no existing targeted resources in the assignment scope.
    #In this case, we will check the initial creation date (createdOn metadata) of the policy assignment and make sure we wait for at least 5 minutes from the initial creation date
    #If the policy assignment is previously created and the updated by the pipeline execution, the updatedOn metadata is ignored.
    Foreach ($assignment in $assignments) {
      $initialCreationDate = [datetime]::Parse($assignment.properties.metadata.createdOn)
      $assignmentComplianceState = $complianceState | Where-Object { $_.policyAssignmentId -ieq $assignment.policyAssignmentId }
      $utcNow = (Get-Date).ToUniversalTime()
      $timeDifference = New-TimeSpan -Start $initialCreationDate -End $utcNow
      if (!$assignmentComplianceState) {
        Write-Verbose "Policy assignment '$($assignment.policyAssignmentId)' does not have any compliance state returned from ARG query. Waiting for at least 5 minutes from the initial creation date." -Verbose
        if ($($timeDifference.TotalMinutes -lt $waitMinutesForNewAssignments)) {
          Write-Verbose "  - Initial creation date: $($initialCreationDate)" -Verbose
          Write-Verbose "  - Current date (UTC): $utcNow" -Verbose
          Write-Verbose "  - Waiting for 1 minute from the initial creation date..." -Verbose
          $shouldWait = $true
        } else {
          Write-Verbose "  - Initial creation date: $($initialCreationDate)" -Verbose
          Write-Verbose "  - Current date (UTC): $utcNow" -Verbose
          Write-Verbose "  - Not need to wait..." -Verbose
        }
      } elseif ($assignmentComplianceState -ieq 'notstarted') {
        Write-Verbose "Policy assignment '$($assignment.policyAssignmentId)' has not started compliance scan. Waiting for it to complete compliance scan" -Verbose
        $shouldWait = $true
      }
    }
    if ($shouldWait -eq $true) {
      if ((Get-Date) -gt $waitEndTime) {
        Write-Error "Maximum wait time of $maximumWaitMinutes minutes reached. Exiting..." -ErrorAction Stop
        exit 1
      } else {
        Write-Verbose "Waiting for 1 minute before querying the compliance state again..." -Verbose
        Start-Sleep -Seconds 60
      }
    }

  } Until($shouldWait -eq $false)
} else {
  $complianceState = getComplianceState -policyAssignmentId $policyAssignmentId
}

Write-Output "Policy Assignment Compliance State:"
Foreach ($item in $complianceState) {
  Write-Output "Policy Assignment ID: $($item.policyAssignmentId)"
  Write-Output "  - Name: $($item.policyAssignmentName)"
  Write-Output "  - Compliance State: $($item.complianceState)"
  Write-Output "  - Compliance Percentage: $($item.compliancePercentage)"
  Write-Output "  - Compliant Count: $($item.compliantCount)"
  Write-Output "  - Non-Compliant Count: $($item.nonCompliantCount)"
  Write-Output "  - Conflict Count: $($item.conflictCount)"
  Write-Output "  - Exempt Count: $($item.exemptCount)"
}

if ($runtimePlatform -ieq 'azure devops') {
  Write-Output ('##vso[task.setVariable variable=ComplianceState;isOutput=true]{0}' -f ($complianceState | ConvertTo-Json -Compress))
  Write-Output ('##vso[task.setVariable variable=ComplianceState]{0}' -f ($complianceState | ConvertTo-Json -Compress))
} elseif ($runtimePlatform -ieq 'github actions') {
  Write-Output ('ComplianceState={0}' -f ($complianceState | ConvertTo-Json -Compress)) >> $env:GITHUB_OUTPUT
}


#endregion
