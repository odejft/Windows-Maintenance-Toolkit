# ==================================================================================
# MANTENIMIENTO WINDOWS + DELL UPDATE + WINDOWS UPDATE
# Versión estable
# ==================================================================================
 
Clear-Host
 
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "      MANTENIMIENTO PREVENTIVO DEL SISTEMA"
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host ""
 
# -----------------------------------------------------------------------------
# VERIFICAR ADMINISTRADOR
# -----------------------------------------------------------------------------
 
$CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentUser)
 
if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host "Debe ejecutar PowerShell como Administrador." -ForegroundColor Red
    Pause
    Exit
}
 
# -----------------------------------------------------------------------------
# LIMPIAR TEMP USUARIO
# -----------------------------------------------------------------------------
 
Write-Host "Limpiando archivos temporales del usuario..." -ForegroundColor Yellow
 
try {
    if (Test-Path $env:TEMP) {
        Get-ChildItem $env:TEMP -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {}
 
# -----------------------------------------------------------------------------
# LIMPIAR TEMP WINDOWS
# -----------------------------------------------------------------------------
 
Write-Host "Limpiando temporales de Windows..." -ForegroundColor Yellow
 
try {
    if (Test-Path "C:\Windows\Temp") {
        Get-ChildItem "C:\Windows\Temp" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {}
 
# -----------------------------------------------------------------------------
# PAPELERA
# -----------------------------------------------------------------------------
 
Write-Host "Vaciando papelera..." -ForegroundColor Yellow
 
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}
catch {}
 
# -----------------------------------------------------------------------------
# DNS
# -----------------------------------------------------------------------------
 
Write-Host "Limpiando caché DNS..." -ForegroundColor Yellow
 
ipconfig /flushdns | Out-Null
 
# -----------------------------------------------------------------------------
# ESTADO DEL SSD
# -----------------------------------------------------------------------------
 
Write-Host ""
Write-Host "Estado de discos:" -ForegroundColor Green
 
Get-PhysicalDisk |
Select FriendlyName,MediaType,HealthStatus |
Format-Table -AutoSize
 
# -----------------------------------------------------------------------------
# RAM
# -----------------------------------------------------------------------------
 
Write-Host ""
Write-Host "Memoria RAM:" -ForegroundColor Green
 
$SO = Get-CimInstance Win32_OperatingSystem
 
$RAMLibre = [Math]::Round($SO.FreePhysicalMemory / 1MB,2)
$RAMTotal = [Math]::Round($SO.TotalVisibleMemorySize / 1MB,2)
$RAMUsada = [Math]::Round(($RAMTotal - $RAMLibre),2)
 
Write-Host "RAM Total : $RAMTotal GB"
Write-Host "RAM Usada : $RAMUsada GB"
Write-Host "RAM Libre : $RAMLibre GB"
 
# -----------------------------------------------------------------------------
# TOP 10 PROCESOS
# -----------------------------------------------------------------------------
 
Write-Host ""
Write-Host "Top procesos por memoria:" -ForegroundColor Green
 
Get-Process |
Sort-Object WorkingSet -Descending |
Select-Object -First 10 `
ProcessName,
@{
    Name="RAM_MB"
    Expression={[Math]::Round($_.WorkingSet / 1MB,2)}
} |
Format-Table -AutoSize
 
# -----------------------------------------------------------------------------
# OPTIMIZACIÓN SSD
# --------------------------------------------------
Write-Host ""
Write-Host "Optimizando unidad C..." -ForegroundColor Green
 
try {
    Optimize-Volume -DriveLetter C -Verbose
}
catch {
    Write-Host "No fue posible optimizar la unidad." -ForegroundColor Yellow
}
 
# -----------------------------------------------------------------------------
# DELL COMMAND UPDATE
# -----------------------------------------------------------------------------
 
Write-Host ""
Write-Host "Buscando Dell Command Update..." -ForegroundColor Cyan
 
$DellCandidates = @(
    "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe",
    "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"
)
 
$DellPath = $DellCandidates |
Where-Object { Test-Path $_ } |
Select-Object -First 1
 
if ($DellPath)
{
    Write-Host "Dell Command Update encontrado." -ForegroundColor Green
 
    try {
 
        Write-Host "Escaneando actualizaciones Dell..." -ForegroundColor Yellow
& $DellPath /scan
 
        Write-Host "Aplicando actualizaciones Dell..." -ForegroundColor Yellow
& $DellPath /applyUpdates -silent
 
    }
    catch {
        Write-Host "No fue posible ejecutar Dell Command Update." -ForegroundColor Yellow
    }
}
else
{
    Write-Host "Dell Command Update no encontrado." -ForegroundColor Yellow
}
 
# -----------------------------------------------------------------------------
# WINDOWS UPDATE
# -----------------------------------------------------------------------------
 
Write-Host ""
Write-Host "Verificando Windows Update..." -ForegroundColor Cyan
 
if (Get-Module -ListAvailable -Name PSWindowsUpdate)
{
    try {
 
        Import-Module PSWindowsUpdate
 
        Write-Host "Buscando actualizaciones..." -ForegroundColor Yellow
 
        Get-WindowsUpdate
 
        Write-Host "Instalando actualizaciones..." -ForegroundColor Yellow
 
        Install-WindowsUpdate `
            -AcceptAll `
            -IgnoreReboot `
            -ErrorAction SilentlyContinue
 
    }
    catch {
        Write-Host "Error al ejecutar Windows Update." -ForegroundColor Yellow
    }
}
else
{
    Write-Host ""
    Write-Host "PSWindowsUpdate no está instalado." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Instálelo una sola vez con:" -ForegroundColor White
    Write-Host "Install-Module PSWindowsUpdate -Force" -ForegroundColor White
}
 
# -----------------------------------------------------------------------------
# SALUD SMART AVANZADA (SI DISPONIBLE)
# -----------------------------------------------------------------------------
 
Write-Host ""
Write-Host "Información avanzada del SSD:" -ForegroundColor Green
 
try {
    Get-PhysicalDisk |
    Get-StorageReliabilityCounter |
    Select `
    Temperature,
    ReadErrorsTotal,
    WriteErrorsTotal,
    Wear,
    PowerOnHours |
    Format-Table -AutoSize
}
catch {
    Write-Host "No se pudo obtener información SMART avanzada." -ForegroundColor Yellow
}
 
# -----------------------------------------------------------------------------
# REINICIO PENDIENTE
# -----------------------------------------------------------------------------
 
$RebootRequired = Test-Path `
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
 
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "MANTENIMIENTO COMPLETADO" -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
 
if ($RebootRequired)
{
    Write-Host ""
    Write-Host "Windows indica que existe un reinicio pendiente." -ForegroundColor Yellow
}
 
# -----------------------------------------------------------------------------
# REINICIO OPCIONAL
# -----------------------------------------------------------------------------
 
Write-Host ""
 
$Reiniciar = Read-Host "¿Desea reiniciar el equipo ahora? (S/N)"
 
if ($Reiniciar -match '^[Ss]$')
{
    Write-Host ""
    Write-Host "Reinicio programado en 120 segundos." -ForegroundColor Yellow
    Write-Host "Puede cancelarlo ejecutando: shutdown /a" -ForegroundColor Cyan
 
    shutdown.exe /r /t 120 /c "Reinicio posterior al mantenimiento."
}
else
{
    Write-Host ""
    Write-Host "Reinicio cancelado." -ForegroundColor Cyan
    Write-Host "Se recomienda reiniciar más tarde." -ForegroundColor Cyan
}
