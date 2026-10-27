# ==================================================================================
# MANTENIMIENTO WINDOWS + DELL UPDATE + WINDOWS UPDATE
# Revision: actualizaciones habituales y upgrade de Windows 11
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
# WINDOWS UPDATE: PARCHES HABITUALES Y ACTUALIZACIONES DE VERSION
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "Verificando Windows Update..." -ForegroundColor Cyan

$EstadoParches = "No ejecutado"
$EstadoVersion = "No ejecutado"
$VersionWindows = "No disponible"

try {
    $VersionWindows = (Get-ItemProperty `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" `
        -ErrorAction Stop).DisplayVersion
    Write-Host "Version detectada al inicio: $VersionWindows"

    # No modificar directivas ni desbloquear servicios deshabilitados por administracion.
    foreach ($ServiceName in @("wuauserv", "bits")) {
        $Service = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($Service.Status -ne "Running") {
            Start-Service -Name $ServiceName -ErrorAction Stop
        }
    }

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "Instalando PSWindowsUpdate desde PowerShell Gallery..." -ForegroundColor Yellow
        Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
        Install-Module -Name PSWindowsUpdate -Repository PSGallery `
            -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module PSWindowsUpdate -ErrorAction Stop

    # Mantener los parches habituales aunque no exista un cambio de version.
    try {
        Write-Host "Buscando parches y otras actualizaciones (sin Upgrades)..." -ForegroundColor Yellow
        $Updates = @(Get-WindowsUpdate -MicrosoftUpdate -NotCategory "Upgrades" -ErrorAction Stop)
        if ($Updates.Count -gt 0) {
            $Updates | Select-Object Title | Format-Table -AutoSize
            $PatchResults = @(Install-WindowsUpdate -MicrosoftUpdate -NotCategory "Upgrades" `
                -AcceptAll -IgnoreReboot -ErrorAction Stop)
            $PatchResults | Select-Object Result, KB, Title | Format-Table -AutoSize
            $EstadoParches = "Operacion ejecutada; revisar resultados"
        }
        else {
            $EstadoParches = "Sin parches ofrecidos en esta consulta"
        }
    }
    catch {
        $EstadoParches = "Error; revisar salida"
        Write-Warning "Error al procesar parches: $($_.Exception.Message)"
    }

    # Solo buscar cambios de version de Windows 11 en un sistema cliente compatible.
    # La version ofrecida la determina Windows Update, no una cadena fija como 26H2.
    if ($SO.ProductType -eq 1 -and [int]$SO.BuildNumber -ge 22000) {
        try {
            Write-Host "Buscando actualizaciones de version (Upgrades)..." -ForegroundColor Yellow
            $FeatureUpdates = @(Get-WindowsUpdate -MicrosoftUpdate -Category "Upgrades" `
                -Title "Windows 11" -ErrorAction Stop)

            if ($FeatureUpdates.Count -gt 0) {
                $FeatureUpdates | Select-Object Title | Format-Table -AutoSize
                Write-Host "Instalando actualizacion de version ofrecida por Microsoft..." -ForegroundColor Yellow
                $FeatureResults = @(Install-WindowsUpdate -MicrosoftUpdate -Category "Upgrades" `
                    -Title "Windows 11" -AcceptAll -IgnoreReboot -ErrorAction Stop)
                $FeatureResults | Select-Object Result, KB, Title | Format-Table -AutoSize

                $InstalledFeatures = @($FeatureResults | Where-Object { $_.Result -eq "Installed" })
                $FailedFeatures = @($FeatureResults | Where-Object { $_.Result -match "Failed|Aborted|Error" })
                if ($FailedFeatures.Count -gt 0) {
                    $EstadoVersion = "Se reportaron errores; revisar resultados"
                }
                elseif ($InstalledFeatures.Count -gt 0) {
                    $EstadoVersion = "Instalacion reportada; confirmar version tras reiniciar"
                }
                else {
                    $EstadoVersion = "Sin instalacion confirmada; revisar resultados"
                }
            }
            else {
                $EstadoVersion = "Sin actualizacion de version ofrecida en esta consulta"
                Write-Host "No se ofrecio un upgrade. Revisar directivas, compatibilidad y reinicios pendientes." -ForegroundColor Yellow
                Write-Host "Si faltan requisitos o parches, reinicie cuando corresponda y vuelva a ejecutar el script." -ForegroundColor Yellow
            }
        }
        catch {
            $EstadoVersion = "Error; revisar salida"
            Write-Warning "Error al procesar actualizaciones de version: $($_.Exception.Message)"
        }
    }
    else {
        $EstadoVersion = "Omitido: este bloque solo gestiona upgrades de Windows 11 cliente"
    }
}
catch {
    $EstadoParches = "Preparacion de Windows Update incompleta"
    $EstadoVersion = "Preparacion de Windows Update incompleta"
    Write-Warning "No fue posible preparar Windows Update: $($_.Exception.Message)"
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
 
Write-Host "Version de Windows al inicio: $VersionWindows"
Write-Host "Parches: $EstadoParches"
Write-Host "Actualizacion de version: $EstadoVersion"
Write-Host "Revise la salida: el fin del script no garantiza el exito de cada tarea." -ForegroundColor Yellow
Write-Host "Despues de reiniciar, ejecute winver para confirmar la version instalada." -ForegroundColor Cyan

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
