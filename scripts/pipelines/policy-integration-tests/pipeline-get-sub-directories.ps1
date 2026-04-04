<#
=================================================================
AUTHOR: Tao Yang
DATE: 23/10/2024
NAME: pipeline-get-sub-directories.ps1
VERSION: 1.1.0
COMMENT: Get all sub directories in the specified directory
=================================================================
#>
[CmdletBinding()]
param (
  [parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType 'Container' })]
  [string]$directory,

  [parameter(Mandatory = $false)]
  [string]$ignoreFileName = '.testignore',

  [parameter(Mandatory = $false)]
  [string]$includedDirectory = '',

  [parameter(Mandatory = $false)]
  [validateSet('true', 'false')]
  [string]$skip = 'false' #can't be boolean because pipeline can only pass string
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
  Write-Verbose "Searching for the directory '$includedDirectory' in '$directory' that doesn't contain '$ignoreFileName'." -Verbose
  if ($includedDirectory.length -gt 0) {
    #get the specific directory
    $includedDirs = ($includedDirectory -split ',') | ForEach-Object { $_.Trim() }
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
#endregion
#region main
$helperFunctionScriptPath = join-path (get-item $PSScriptRoot).parent.tostring() 'helper' 'helper-functions.ps1'

#load helper
. $helperFunctionScriptPath

$runtimePlatform = getPipelineType
$subDirectoryTable = [Ordered]@{}
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

  $i = 1

  $subDirectories = getSubDir -directory $directory -ignoreFileName $ignoreFileName -includedDirectory $includedDirectory
  Write-Verbose "Found $($subDirectories.Count) sub directories in '$directory'." -Verbose
  if ($subDirectories) {
    Foreach ($folder in $subDirectories) {
      $relativePath = Get-GitRelativeFilePath -path $folder.FullName
      $key = "$($folder.Name)"
      $subDirectoryTable[$key] += @{
        matrixSubDirName         = $folder.Name
        matrixSubDirRelativePath = $relativePath
        matrixSubDirFullPath     = $folder.FullName
        matrixKey                = $key
      }
      $i++
    }
    Write-Output "Found $($subDirectoryTable.Count) sub directories in '$directory'."
    $subDirectoryTable.GetEnumerator() | ForEach-Object {
      Write-Output "Directory Name: $($_.value.matrixSubDirName), Relative Path: $($_.value.matrixSubDirRelativePath)"
    }
  } else {
    Write-Error "no sub directory in '$directory."
    Exit 1
  }
}
#Create pipeline output variables
if ($runtimePlatform -ieq 'azure devops') {
  Write-Output ('##vso[task.setVariable variable={0};isOutput=true]{1}' -f 'SubDirCount', $($subDirectories.Count))
  #Output Hashtable to ADO Pipeline as a Variable.
  Write-Output ('##vso[task.setVariable variable=SubDirectories;isOutput=true]{0}' -f ($subDirectoryTable | ConvertTo-Json -Compress))
  Write-Output "SubDirCount: $($subDirectories.Count)"
  Write-Output "SubDirectories: $($subDirectoryTable | ConvertTo-Json -Compress)"
} elseif ($runtimePlatform -ieq 'github actions') {
  # Convert ordered hashtable to array for GitHub Actions matrix compatibility
  $subDirectoryArray = @($subDirectoryTable.Values)
  if ($subDirectoryArray.Count -eq 0) {
    $subDirectories_json = "[]"
  } elseif ($subDirectoryArray.Count -eq 1) {
    $subDirectories_json = '[' + ($subDirectoryArray | ConvertTo-Json -Depth 5 -Compress) + ']'
  } else {
    $subDirectories_json = $subDirectoryArray | ConvertTo-Json -Depth 5 -Compress
  }
  Add-Content -Path $env:GITHUB_OUTPUT -Value "SubDirCount=$($subDirectories.Count)"
  Add-Content -Path $env:GITHUB_OUTPUT -Value "SubDirectories=$subDirectories_json"
  Write-Output "SubDirCount: $($subDirectories.Count)"
  Write-Output "SubDirectories: $subDirectories_json"
} else {
  Write-Output "SubDirCount: $($subDirectories.Count)"
  Write-Output "SubDirectories: $($subDirectoryTable | ConvertTo-Json)"
}
#endregion
