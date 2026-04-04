<#
============================================
AUTHOR: Tao Yang
DATE: 22/03/2026
NAME: newAesKey.ps1
VERSION: 1.0.0
COMMENT: Generate AES encryption key and IV
============================================
#>
[CmdletBinding()]
[OutputType([PSCustomObject])]
param (
  [Parameter(Mandatory = $false)]
  [ValidateSet(128, 192, 256)]
  [int]$KeySize = 256,

  [Parameter(Mandatory = $false)]
  [string]$OutputFilePath
)
#load helper functions
$helperFunctionScriptPath = join-path (get-item $PSScriptRoot).parent.parent.tostring() 'pipelines' 'helper' 'helper-functions.ps1'
. $helperFunctionScriptPath

$params = @{
  KeySize = $KeySize
}
if ($PSBoundParameters.ContainsKey('OutputFilePath')) {
  $params.OutputFilePath = $OutputFilePath
}

#Create AES key and IV
$aesKeyInfo = newAesKey @params

$aesKeyInfo
