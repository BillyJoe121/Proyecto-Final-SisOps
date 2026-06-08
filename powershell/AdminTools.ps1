<#
.SYNOPSIS
    Data Center Admin Tool - PowerShell Version
.DESCRIPTION
    Herramienta integral para administración de servidores Windows.
    Incluye gestión de usuarios, discos, archivos grandes, memoria y backups.
#>

function Show-Menu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "   DATA CENTER ADMIN TOOLS (PowerShell)   " -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " 1. Listar usuarios y su ultimo ingreso"
    Write-Host " 2. Ver filesystems/discos (Tamano y Libre)"
    Write-Host " 3. Listar 10 archivos mas grandes en un disco"
    Write-Host " 4. Estadisticas de Memoria y Swap"
    Write-Host " 5. Realizar Backup a USB (con Catalogo)"
    Write-Host " Q. Salir"
    Write-Host "==========================================" -ForegroundColor Cyan
}

function Get-UserLogins {
    Write-Host "`n--- Usuarios y Ultimo Ingreso ---" -ForegroundColor Yellow
    try {
        # Solo cuentas habilitadas (equivalente a filtrar usuarios reales en Linux)
        Get-LocalUser | Where-Object { $_.Enabled } |
            Select-Object Name, @{Name="UltimoLogin"; Expression={if($_.LastLogon){$_.LastLogon}else{"Nunca"}}} |
            Format-Table -AutoSize
    } catch {
        Write-Host "Error al obtener usuarios: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "`nPresione Enter para continuar..."
}

function Get-DiskSpace {
    Write-Host "`n--- Filesystems / Discos (Valores en Bytes) ---" -ForegroundColor Yellow
    Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID,
        @{Name="Size(Bytes)"; Expression={"{0:N0}" -f $_.Size}},
        @{Name="Used(Bytes)"; Expression={"{0:N0}" -f ($_.Size - $_.FreeSpace)}},
        @{Name="FreeSpace(Bytes)"; Expression={"{0:N0}" -f $_.FreeSpace}},
        @{Name="Uso%"; Expression={ if($_.Size -gt 0){ [Math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 2) } else { 0 } }} |
        Format-Table -AutoSize
    Read-Host "`nPresione Enter para continuar..."
}

function Get-TopFiles {
    $path = Read-Host "`nEspecifique la letra del disco o ruta completa (ej. C:\)"
    if (Test-Path $path) {
        Write-Host "`nEscaneando... Esto puede demorar varios minutos segun el tamano del disco." -ForegroundColor Gray
        try {
            $files = Get-ChildItem -Path $path -File -Recurse -Force -ErrorAction SilentlyContinue |
                     Sort-Object Length -Descending |
                     Select-Object -First 10

            if ($files) {
                $files | Select-Object @{Name="Size(Bytes)"; Expression={"{0:N0}" -f $_.Length}}, FullName | Format-Table -AutoSize
            } else {
                Write-Host "No se encontraron archivos en la ruta especificada." -ForegroundColor Cyan
            }
        } catch {
            Write-Host "Ocurrio un error durante el escaneo: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "La ruta '$path' no es valida o no existe." -ForegroundColor Red
    }
    Read-Host "`nPresione Enter para continuar..."
}

function Get-MemoryStats {
    Write-Host "`n--- Estadisticas de Memoria y Swap ---" -ForegroundColor Yellow
    $os = Get-CimInstance Win32_OperatingSystem

    $totalMem = [int64]$os.TotalVisibleMemorySize * 1024
    $freeMem  = [int64]$os.FreePhysicalMemory * 1024
    if ($totalMem -gt 0) {
        $freeMemPct = [Math]::Round(($freeMem / $totalMem) * 100, 2)
    } else {
        $freeMemPct = 0
    }

    $totalSwap = [int64]$os.SizeStoredInPagingFiles * 1024
    $freeSwap  = [int64]$os.FreeSpaceInPagingFiles * 1024

    if ($totalSwap -gt 0) {
        $usedSwap = $totalSwap - $freeSwap
        $usedSwapPct = [Math]::Round(($usedSwap / $totalSwap) * 100, 2)
    } else {
        $usedSwap = 0
        $usedSwapPct = 0
    }

    Write-Output "Memoria RAM:"
    Write-Output "  Total:      $( "{0:N0}" -f $totalMem) bytes"
    Write-Output "  Libre:      $( "{0:N0}" -f $freeMem) bytes ($freeMemPct %)"
    Write-Output "Swap:"
    Write-Output "  Total:      $( "{0:N0}" -f $totalSwap) bytes"
    Write-Output "  En Uso:     $( "{0:N0}" -f $usedSwap) bytes ($usedSwapPct %)"

    Read-Host "`nPresione Enter para continuar..."
}

function Invoke-Backup {
    $source = Read-Host "`nDirectorio de origen (ej. C:\MisDocumentos)"
    $dest = Read-Host "Directorio de destino USB (ej. D:\)"

    if ((Test-Path $source) -and (Test-Path $dest)) {
        try {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupDir = Join-Path $dest "Backup_$timestamp"
            New-Item -ItemType Directory -Path $backupDir -ErrorAction Stop | Out-Null

            Write-Host "`nCopiando archivos (incluye ocultos)... por favor espere." -ForegroundColor Gray
            Copy-Item -Path "$source\*" -Destination $backupDir -Recurse -Force -ErrorAction SilentlyContinue

            Write-Host "Generando catalogo de archivos..." -ForegroundColor Gray
            $catalogoPath = Join-Path $backupDir "catalogo_backup.txt"
            $header = "NOMBRE DEL ARCHIVO | FECHA ULTIMA MODIFICACION | RUTA COMPLETA"
            $separator = "=" * 80
            $header    | Out-File $catalogoPath
            $separator | Out-File $catalogoPath -Append

            Get-ChildItem -Path $source -Recurse -File -Force |
                Select-Object @{Name="Info"; Expression={"$($_.Name) | $($_.LastWriteTime) | $($_.FullName)"}} |
                Select-Object -ExpandProperty Info |
                Out-File $catalogoPath -Append

            Write-Host "`nBackup completado exitosamente en: $backupDir" -ForegroundColor Green
            Write-Host "Catalogo creado en: $catalogoPath" -ForegroundColor Green
        } catch {
            Write-Host "Error durante el backup: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Rutas de origen o destino no validas." -ForegroundColor Red
    }
    Read-Host "`nPresione Enter para continuar..."
}

# Inicio del Programa
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ADVERTENCIA: Algunas funciones requieren privilegios de Administrador." -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}

do {
    Show-Menu
    $choice = Read-Host "`nOpcion"
    switch ($choice) {
        "1" { Get-UserLogins }
        "2" { Get-DiskSpace }
        "3" { Get-TopFiles }
        "4" { Get-MemoryStats }
        "5" { Invoke-Backup }
        "Q" { break }
        default { Write-Host "Opcion no reconocida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne "Q")
