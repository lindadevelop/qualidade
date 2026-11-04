param([string]$PythonPath = 'python', [string]$GestSysRoot = '', [switch]$Remove)
$ErrorActionPreference = 'Stop'
$taskName = 'SamsysQualityStack'
if ($Remove) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue; exit }
$script = Join-Path $PSScriptRoot 'start-stack.ps1'
if (-not (Test-Path -LiteralPath $script)) { throw 'Script de arranque em falta.' }
$arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -File "' + $script + '" -Supervise -PythonPath "' + $PythonPath + '"'
if ($GestSysRoot) { $arguments += ' -GestSysRoot "' + $GestSysRoot + '" -GestSysPort 3010' }
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments -WorkingDirectory (Split-Path $PSScriptRoot -Parent)
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
$principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Stack local SAMSYS Qualidade, com recuperação de processos e logs locais.' -Force | Out-Null
Write-Output "Arranque automático configurado no início de sessão de $currentUser."
