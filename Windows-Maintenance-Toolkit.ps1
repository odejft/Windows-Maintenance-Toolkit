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
# LIMPIEZA AVANZADA DE ARCHIVOS TEMPORALES
# -----------------------------------------------------------------------------

Write-Host "Analizando archivos temporales..." -ForegroundColor Yellow

$EspacioTemporalLiberado = 0

function Obtener-TamanoCarpeta
{
    param(
        [string]$Ruta
    )

    try
    {
        if (Test-Path $Ruta)
        {
            return (
                Get-ChildItem $Ruta `
                -Recurse `
                -Force `
                -File `
                -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum
            ).Sum
        }
    }
    catch {}

    return 0
}

# -------------------------------------------------------------------------
# TEMP DE TODOS LOS USUARIOS
# -------------------------------------------------------------------------

Write-Host "Limpiando temporales de perfiles de usuario..." -ForegroundColor Yellow

$Perfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue

foreach ($Perfil in $Perfiles)
{
    $RutaTemp = Join-Path `
        $Perfil.FullName `
        "AppData\Local\Temp"

    if (Test-Path $RutaTemp)
    {
        $TamanoAntes = Obtener-TamanoCarpeta $RutaTemp

        try
        {
            Get-ChildItem $RutaTemp `
            -Force `
            -ErrorAction SilentlyContinue |
            Remove-Item `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
        }
        catch {}

        $TamanoDespues = Obtener-TamanoCarpeta $RutaTemp

        $EspacioTemporalLiberado += ($TamanoAntes - $TamanoDespues)
    }
}

# -------------------------------------------------------------------------
# TEMP DE WINDOWS
# -------------------------------------------------------------------------

$WindowsTemp = "C:\Windows\Temp"

if (Test-Path $WindowsTemp)
{
    $TamanoAntes = Obtener-TamanoCarpeta $WindowsTemp

    try
    {
        Get-ChildItem $WindowsTemp `
        -Force `
        -ErrorAction SilentlyContinue |
        Remove-Item `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
    }
    catch {}

    $TamanoDespues = Obtener-TamanoCarpeta $WindowsTemp

    $EspacioTemporalLiberado += ($TamanoAntes - $TamanoDespues)
}

# -------------------------------------------------------------------------
# RESULTADO
# -------------------------------------------------------------------------

$GBLiberados = [Math]::Round(
    ($EspacioTemporalLiberado / 1GB),
    2
)

Write-Host ""
Write-Host "Espacio liberado por temporales: $GBLiberados GB" -ForegroundColor Green
Write-Host ""# -----------------------------------------------------------------------------
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

    try
    {
        Write-Host "Escaneando actualizaciones Dell..." -ForegroundColor Yellow

        & $DellPath /scan

        switch ($LASTEXITCODE)
        {
            0
            {
                Write-Host "Actualizaciones Dell detectadas." -ForegroundColor Green

                Write-Host "Aplicando actualizaciones Dell..." -ForegroundColor Yellow

                & $DellPath /applyUpdates -silent
            }

            5
            {
                Write-Host "Existe un reinicio pendiente. Reinicie el equipo y vuelva a ejecutar Dell Command Update." -ForegroundColor Yellow
            }

            500
            {
                Write-Host "No hay actualizaciones Dell disponibles." -ForegroundColor Green
            }

            3000
            {
                Write-Host "El servicio Dell Client Management Service está detenido o presenta problemas." -ForegroundColor Yellow
            }

            Default
            {
                Write-Host "Dell Command Update devolvió el código: $LASTEXITCODE" -ForegroundColor Yellow
            }
        }
    }
    catch
    {
        Write-Host "No fue posible ejecutar Dell Command Update." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}
else
{
    Write-Host "Dell Command Update no encontrado." -ForegroundColor Yellow
}# -----------------------------------------------------------------------------
# VALIDACION Y ACTUALIZACION SEGURA DE VERSION WINDOWS
# -----------------------------------------------------------------------------

Write-Host ""
Write-Host "Verificando versión de Windows..." -ForegroundColor Cyan

$WinInfo = Get-ComputerInfo

$VersionWindows = (
    Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
).DisplayVersion

$EstadoVersion = "Actualizada"

Write-Host "Versión detectada: $VersionWindows"

if ($VersionWindows -ne "26H2")
{
    $EstadoVersion = "Pendiente"

    Write-Host ""
    Write-Host "El equipo no se encuentra en la versión más reciente validada." -ForegroundColor Yellow

    try
    {
        # Asegurar que los servicios estén disponibles
        Write-Host "Validando servicios de Windows Update..." -ForegroundColor Yellow

        Start-Service wuauserv -ErrorAction SilentlyContinue
        Start-Service bits -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 5

        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate))
        {
            Write-Host ""
            Write-Host "PSWindowsUpdate no está instalado. Instalando..." -ForegroundColor Yellow

            Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue

            Install-Module `
                PSWindowsUpdate `
                -Force `
                -AllowClobber `
                -Scope CurrentUser

            Import-Module PSWindowsUpdate
        }
        else
        {
            Import-Module PSWindowsUpdate -Force
        }

        Write-Host ""
        Write-Host "Buscando actualizaciones de versión (Upgrades)..." -ForegroundColor Yellow

        $FeatureUpdates = Get-WindowsUpdate `
            -MicrosoftUpdate `
            -Category "Upgrades" `
            -ErrorAction SilentlyContinue

        if ($FeatureUpdates)
        {
            Write-Host ""
            Write-Host "Actualizaciones disponibles:" -ForegroundColor Green

            $FeatureUpdates |
            Select-Object Title |
            Format-Table -AutoSize

            Write-Host ""
            Write-Host "Instalando actualización de versión ofrecida por Microsoft..." -ForegroundColor Yellow

            Install-WindowsUpdate `
                -MicrosoftUpdate `
                -Category "Upgrades" `
                -AcceptAll `
                -IgnoreReboot `
                -ErrorAction SilentlyContinue

            $EstadoVersion = "Actualizando"

            Write-Host ""
            Write-Host "Proceso de actualización iniciado." -ForegroundColor Green
        }
        else
        {
            Write-Host ""
            Write-Host "Windows Update no reportó actualizaciones de versión." -ForegroundColor Yellow

            Write-Host "Forzando nuevo escaneo..." -ForegroundColor Yellow

            UsoClient StartScan

            Start-Sleep -Seconds 15
        }
    }
    catch
    {
        Write-Host ""
        Write-Host "Error validando o instalando actualización de versión." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}
else
{
    Write-Host "El equipo ya se encuentra en Windows 11 26H2." -ForegroundColor Green
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
