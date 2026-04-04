<#
============================================================
AUTHOR: Tao Yang
DATE: 26/03/2026
NAME: pipeline-policy-int-test-compliance-scan.ps1
VERSION: 2.0.0
COMMENT: Kicking off policy compliance scan using Azure CLI
============================================================
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType 'Leaf' })]
  [string]$testGlobalConfigFilePath,

  [parameter(Mandatory = $true)]
  [string]$complianceScanSubNames
)

#region functions
function getSubFromGlobalConfig {
  [CmdletBinding()]
  param (
    [parameter(Mandatory = $true)]
    [hashtable]$globalConfig,

    [parameter(Mandatory = $true)]
    [string]$subName
  )
  $subsFromGlobalConfig = ($globalConfig.subscriptions)
  Foreach ($item in $subsFromGlobalConfig.GetEnumerator()) {
    if ($item.Key -ieq $subName) {
      $sub = $item.Value
    }
  }
  return $sub
}
#endregion

#region main
#Read the global configuration file
$globalConfig = Get-Content $testGlobalConfigFilePath | ConvertFrom-Json -Depth 10 -AsHashtable

#Get the list of subscriptions defined in the global Configuration file
$subsFromGlobalConfig = $globalConfig.subscriptions

#List of subscriptions to run compliance scan
$subscriptions = ConvertFrom-Json -InputObject $complianceScanSubNames

if ($subscriptions.Count -eq 0) {
  Write-Output "No subscription is required to scan for policy compliance. Skip this step."
} else {
  Write-Output "$($subscriptions.Count) unique subscriptions are required to scan for policy compliance."
  foreach ($sub in $subscriptions) {
    Write-Output "  - $sub"
  }
  Write-Output "Start Policy Compliance Scan"

  foreach ($subName in $subscriptions) {
    Write-Output " -- Get configuration for subscription '$subName' from tests global configuration file"
    $sub = getSubFromGlobalConfig -globalConfig $globalConfig -subName $subName
    if (!$sub) {
      Write-Error "Subscription '$subName' not found in the global configuration file."
      exit 1
    } else {
      Write-Output "    - Start Compliance Scan for subscription '$subName'('$($sub.id)') asynchronously."
    }

    # use Azure CLI to start policy compliance scan because it supports async operation with --no-wait switch. This is not supported by Azure PowerShell
    az policy state trigger-scan --subscription $sub.id --no-wait
  }

  Write-output "Done."
}
#endregion
