param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent), [string]$PythonPath = 'python', [string]$GestSysRoot = '', [int]$GestSysPort = 3010, [switch]$Supervise)
$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$logRoot = Join-Path $ProjectRoot 'backend\data\runtime-logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$mutex = New-Object System.Threading.Mutex($false, 'Local\SamsysQualityStackSupervisor')
if (-not $mutex.WaitOne(0)) { Write-Output 'Supervisor já está ativo.'; exit 0 }
function Start-NodeService([string]$Name, [int]$Port, [string]$Directory, [string]$Script, [string[]]$ExtraArgs = @()) {
    $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener[0].OwningProcess)"
        $leaf = Split-Path $Script -Leaf
        if ($owner.CommandLine -notlike "*$Script*" -and $owner.CommandLine -notmatch ('(?:^|[\\/\s"])' + [regex]::Escape($leaf) + '(?:[\s"]|$)')) { throw "Porta $Port ocupada por outro processo; não foi terminado." }
        return
    }
    if (-not (Test-Path -LiteralPath $Script)) { throw "Falta $Script" }
    $node = (Get-Command node.exe -ErrorAction Stop).Source
    $args = @('"' + $Script + '"') + $ExtraArgs
    Start-Process -FilePath $node -ArgumentList $args -WorkingDirectory $Directory -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logRoot "$Name.out.log") -RedirectStandardError (Join-Path $logRoot "$Name.err.log") | Out-Null
}
try {
    do {
        try {
            $pgBin = Join-Path $ProjectRoot 'pgportable\pgsql\bin'
            & (Join-Path $pgBin 'pg_isready.exe') -h 127.0.0.1 -p 5432 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                & (Join-Path $pgBin 'pg_ctl.exe') -D (Join-Path $ProjectRoot 'pgdata') -l (Join-Path $logRoot 'postgres.log') -w start | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL não arrancou.' }
            }
            $postgrest = Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue
            if (-not $postgrest) {
                Start-Process -FilePath (Join-Path $pgBin 'postgrest.exe') -ArgumentList ('"' + (Join-Path $ProjectRoot 'postgrest.conf') + '"') -WorkingDirectory $ProjectRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logRoot 'postgrest.out.log') -RedirectStandardError (Join-Path $logRoot 'postgrest.err.log') | Out-Null
            }
            $backend = Join-Path $ProjectRoot 'backend'
            $env:PPT_PYTHON = $PythonPath
            foreach ($service in @(@('auth',3002,'auth-server.js'),@('proxy',8000,'api-proxy.js'),@('storage',3003,'storage-server.js'),@('cv',3006,'cv-processor-server.js'),@('ppt',3007,'ppt-generator.js'))) {
                Start-NodeService $service[0] $service[1] $backend (Join-Path $backend $service[2])
            }
            $frontend = Join-Path $ProjectRoot 'frontend'
            if (-not (Test-Path (Join-Path $frontend 'dist\index.html'))) { throw 'Executa npm run build no frontend antes de arrancar.' }
            Start-NodeService 'frontend' 5178 $frontend (Join-Path $frontend 'node_modules\vite\bin\vite.js') @('preview','--host','127.0.0.1','--port','5178','--strictPort')
            if ($GestSysRoot) {
                $gestRoot = (Resolve-Path -LiteralPath $GestSysRoot).Path
                if ($GestSysPort -in @(3000,3001,3002,3007,5178,8000)) { throw 'Usa uma porta livre, por exemplo 3010, para gestsys.' }
                Start-NodeService 'gestsys' $GestSysPort $gestRoot (Join-Path $gestRoot 'node_modules\vite\bin\vite.js') @('preview','--host','127.0.0.1','--port',"$GestSysPort",'--strictPort')
            }
        } catch {
            Add-Content -LiteralPath (Join-Path $logRoot 'supervisor.log') -Value "$(Get-Date -Format o) $($_.Exception.Message)"
            if (-not $Supervise) { throw }
        }
        if ($Supervise) { Start-Sleep -Seconds 30 }
    } while ($Supervise)
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
