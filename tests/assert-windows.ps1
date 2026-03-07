Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$DefaultLogDir = Join-Path $RepoRoot 'logs'
$LogDir = if ($env:LOG_DIR) { $env:LOG_DIR } else { $DefaultLogDir }
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$SummaryFile = if ($env:SUMMARY_FILE) { $env:SUMMARY_FILE } else { Join-Path $LogDir "assert_windows_$Timestamp.log" }
$Failures = [System.Collections.Generic.List[string]]::new()

function Write-Log {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Write-Host "[$timestamp] $Message"
}

function Add-Failure {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  $Failures.Add($Message) | Out-Null
  Write-Error "ASSERTION FAILED: $Message" -ErrorAction Continue
}

function Test-CommandExists {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CommandName
  )

  return [bool](Get-Command -Name $CommandName -ErrorAction SilentlyContinue)
}

function Assert-Command {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CommandName
  )

  if (-not (Test-CommandExists -CommandName $CommandName)) {
    Add-Failure -Message "Command not found: $CommandName"
  }
}

function Test-ScoopBucket {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BucketName
  )

  $buckets = @(scoop bucket list | ForEach-Object { ($_ -split '\s+')[0] })
  return $buckets -contains $BucketName
}

function Test-ScoopPackageInstalled {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PackageName
  )

  $package = scoop list $PackageName 2>$null | Select-Object -Skip 1 | Select-Object -First 1
  return -not [string]::IsNullOrWhiteSpace($package)
}

function Assert-ScoopPackage {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PackageName
  )

  if (-not (Test-ScoopPackageInstalled -PackageName $PackageName)) {
    Add-Failure -Message "Scoop package missing: $PackageName"
  }
}

function Test-WindowsHost {
  return $env:OS -eq 'Windows_NT'
}

function Main {
  if (-not (Test-WindowsHost)) {
    throw 'This assertion script only supports Windows.'
  }

  New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

  Assert-Command -CommandName 'scoop'

  if (Test-CommandExists -CommandName 'scoop') {
    if (-not (Test-ScoopBucket -BucketName 'extras')) {
      Add-Failure -Message 'Scoop bucket missing: extras'
    }
  }

  $packageCommands = @{
    bat = 'bat'
    fd = 'fd'
    fzf = 'fzf'
    lazygit = 'lazygit'
    neovim = 'nvim'
    ripgrep = 'rg'
    starship = 'starship'
  }

  foreach ($package in $packageCommands.Keys | Sort-Object) {
    Assert-ScoopPackage -PackageName $package
    Assert-Command -CommandName $packageCommands[$package]
  }

  Assert-ScoopPackage -PackageName 'vcredist2022'

  if ($Failures.Count -gt 0) {
    $lines = @("Assertion summary ($($Failures.Count) failures):")
    $lines += $Failures | ForEach-Object { " - $_" }
    $lines += "Summary written to $SummaryFile"
    $lines | Out-File -FilePath $SummaryFile -Encoding utf8
    $lines | ForEach-Object { Write-Host $_ }
    exit 1
  }

  Write-Log 'All Windows assertions passed.'
}

Main
