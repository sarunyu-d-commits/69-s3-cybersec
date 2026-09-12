#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$envFile = Join-Path $root ".env"
$composeFile = Join-Path $root "docker-compose.yaml"

if (-not (Test-Path $envFile)) { throw ".env not found: $envFile" }
if (-not (Test-Path $composeFile)) { throw "docker-compose.yaml not found: $composeFile" }

$container = (docker compose -f $composeFile ps --format "{{.Name}}" db 2>$null | Select-Object -First 1).Trim()
if (-not $container) { $container = "69-s3-db" }
Write-Host "db container: $container"

$env = @{}
Get-Content -LiteralPath $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.+)$') { $env[$matches[1].Trim()] = $matches[2].Trim() }
}

$dbUser = $env["DATABASE_USER"]
$dbName = $env["DATABASE_DB"]
if (-not $dbUser -or -not $dbName) { throw "DATABASE_USER / DATABASE_DB missing in .env" }

$running = (docker inspect -f "{{.State.Running}}" $container 2>$null).Trim()
if ($running -ne "true") { throw "db container '$container' is not running. Run 'docker compose up -d' first." }

$q = {
    param($sql)
    $r = docker exec $container psql -U $dbUser -d $dbName -tAc $sql
    if ($r) { ($r | Select-Object -First 1).Trim() } else { "" }
}

$adminToken = & $q "SELECT reset_password_token FROM admin_users WHERE reset_password_token IS NOT NULL ORDER BY updated_at DESC LIMIT 1;"
$userToken  = & $q "SELECT reset_password_token FROM up_users WHERE reset_password_token IS NOT NULL ORDER BY updated_at DESC LIMIT 1;"

$lines = Get-Content -LiteralPath $envFile | Where-Object {
    $_ -notmatch '^\s*ADMIN_RESET_TOKEN=' -and $_ -notmatch '^\s*USER_RESET_TOKEN='
}
$lines += "ADMIN_RESET_TOKEN=$adminToken"
$lines += "USER_RESET_TOKEN=$userToken"
Set-Content -LiteralPath $envFile -Value $lines -Encoding ascii

Write-Host "admin: $(if ($adminToken) { $adminToken } else { '(none)' })"
Write-Host "user : $(if ($userToken) { $userToken } else { '(none)' })"