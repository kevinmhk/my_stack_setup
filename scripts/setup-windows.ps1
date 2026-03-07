Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$DefaultLogDir = Join-Path $RepoRoot 'logs'
$LogDir = if ($env:LOG_DIR) { $env:LOG_DIR } else { $DefaultLogDir }
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile = if ($env:LOG_FILE) { $env:LOG_FILE } else { Join-Path $LogDir "setup_windows_$Timestamp.log" }
$Reminders = [System.Collections.Generic.List[string]]::new()

function Initialize-Logging {
  New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
  Start-Transcript -Path $LogFile -Append | Out-Null
}

function Write-Log {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Write-Host "[$timestamp] $Message"
}

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$ScriptBlock,
    [Parameter(Mandatory = $true)]
    [string]$Description
  )

  Write-Log "+ $Description"
  & $ScriptBlock
}

function Stop-WithError {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  throw $Message
}

function Test-CommandExists {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CommandName
  )

  return [bool](Get-Command -Name $CommandName -ErrorAction SilentlyContinue)
}

function Add-Reminder {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  $Reminders.Add($Message) | Out-Null
}

function Show-Reminders {
  foreach ($message in $Reminders) {
    Write-Host $message -ForegroundColor Yellow
  }
}

function Test-WindowsHost {
  return $env:OS -eq 'Windows_NT'
}

function Assert-Windows {
  if (-not (Test-WindowsHost)) {
    Stop-WithError 'This script only supports Windows.'
  }
}

function Ensure-ExecutionPolicy {
  $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
  if ($currentPolicy -eq 'RemoteSigned') {
    Write-Log 'Execution policy already set to RemoteSigned for CurrentUser.'
    return
  }

  Invoke-Step -Description 'Set PowerShell execution policy to RemoteSigned for CurrentUser' -ScriptBlock {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
  }
}

function Ensure-Scoop {
  if (Test-CommandExists -CommandName 'scoop') {
    Write-Log 'Scoop already installed.'
    return
  }

  Invoke-Step -Description 'Install Scoop from the official bootstrap script' -ScriptBlock {
    Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
  }
}

function Ensure-ScoopBucket {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BucketName
  )

  $buckets = @(scoop bucket list | ForEach-Object { ($_ -split '\s+')[0] })
  if ($buckets -contains $BucketName) {
    Write-Log "Scoop bucket already added: $BucketName"
    return
  }

  Invoke-Step -Description "Add Scoop bucket '$BucketName'" -ScriptBlock {
    scoop bucket add $BucketName
  }
}

function Test-ScoopPackageInstalled {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PackageName
  )

  $package = scoop list $PackageName 2>$null | Select-Object -Skip 1 | Select-Object -First 1
  return -not [string]::IsNullOrWhiteSpace($package)
}

function Install-ScoopPackageIfMissing {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PackageName
  )

  if (Test-ScoopPackageInstalled -PackageName $PackageName) {
    Write-Log "Scoop package already installed: $PackageName"
    return
  }

  if ($PackageName -eq 'vcredist2022') {
    Write-Log 'Installing vcredist2022 may trigger an interactive Windows prompt that requires user approval.'
  }

  Invoke-Step -Description "Install Scoop package '$PackageName'" -ScriptBlock {
    scoop install $PackageName
  }
}

function Install-ScoopPackages {
  $corePackages = @(
    'bat',
    'fd',
    'fzf',
    'lazygit',
    'neovim',
    'ripgrep',
    'starship'
  )
  $runtimePackages = @(
    'vcredist2022'
  )

  foreach ($package in $corePackages) {
    Install-ScoopPackageIfMissing -PackageName $package
  }

  foreach ($package in $runtimePackages) {
    Install-ScoopPackageIfMissing -PackageName $package
  }
}

function Add-ProfileReminder {
  Add-Reminder -Message 'Reminder: update your PowerShell profile with desired initialization such as Starship prompt setup.'
}

function Main {
  $transcriptStarted = $false

  try {
    Assert-Windows
    Initialize-Logging
    $transcriptStarted = $true
    Ensure-ExecutionPolicy
    Ensure-Scoop
    Ensure-ScoopBucket -BucketName 'extras'
    Install-ScoopPackages
    Add-ProfileReminder
    Write-Log 'Windows setup complete.'
    Show-Reminders
  } finally {
    if ($transcriptStarted) {
      Stop-Transcript | Out-Null
    }
  }
}

Main
