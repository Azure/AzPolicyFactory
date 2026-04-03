<#
=============================================================
AUTHOR: Tao Yang
DATE: 22/07/2024
NAME: pipeline-create-pipeline-variables-from-json-file.ps1
VERSION: 1.0.0
COMMENT: Create pipeline variables from a json file
=============================================================
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType 'Leaf' })]
  [string]$jsonFilePath,

  [parameter(Mandatory = $false)]
  [string]$overallJsonVariableName
)
$helperFunctionScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'helper' 'helper-functions.ps1'

#load helper
. $helperFunctionScriptPath
$runtimePlatform = getPipelineType
#Read Json file and create a hashtable
Write-Verbose "Parsing Json file: $jsonFilePath"
$ht = Get-Content -Path $jsonFilePath -raw | ConvertFrom-Json -AsHashtable

foreach ($item in $ht.GetEnumerator()) {
  if ($item.Value -is [System.Array]) {
    $itemValue = $item.Value | ConvertTo-Json -Compress -AsArray
  } else {
    $itemValue = $item.Value
  }
  Write-Verbose "Creating pipeline variable $($item.Key) with value '$itemValue'" -verbose
  if ($runtimePlatform -ieq 'azure devops') {
    Write-Output ('##vso[task.setVariable variable={0};isOutput=true]{1}' -f $item.Key, $itemValue)
    Write-Output ('##vso[task.setVariable variable={0}]{1}' -f $item.Key, $itemValue)
  } elseif ($runtimePlatform -ieq 'github actions') {
    write-output "complianceScanSubNames=$complianceScanSubNames" >> $env:GITHUB_OUTPUT
    Write-Output $('{0}={1}' -f $item.Key, $itemValue) >> $env:GITHUB_OUTPUT
  }

}

if ($PSBoundParameters.ContainsKey('overallJsonVariableName')) {
  $overallJsonValue = Get-Content -Path $jsonFilePath -raw | convertFrom-Json -depth 99 | ConvertTo-Json -Compress  -depth 99
  Write-Verbose "Creating pipeline variable $overallJsonVariableName with overall json content" -verbose
  if ($runtimePlatform -ieq 'azure devops') {
    Write-Output ('##vso[task.setVariable variable={0};isOutput=true]{1}' -f $overallJsonVariableName, $overallJsonValue)
    Write-Output ('##vso[task.setVariable variable={0}]{1}' -f $overallJsonVariableName, $overallJsonValue)
  } elseif ($runtimePlatform -ieq 'github actions') {
    Write-Output $('{0}={1}' -f $overallJsonVariableName, $overallJsonValue) >> $env:GITHUB_OUTPUT
  }
}
