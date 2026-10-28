param(
    [switch]$Volumes
)

. "$PSScriptRoot\common.ps1"

$root = Get-ProjectRoot
Import-DotEnv (Join-Path $root '.env') | Out-Null

if ($Volumes) {
    Write-Host '== Deteniendo stack y eliminando volumenes =='
    Invoke-Compose @('down', '--volumes', '--remove-orphans')
} else {
    Write-Host '== Deteniendo stack (los datos se conservan) =='
    Invoke-Compose @('down', '--remove-orphans')
}
