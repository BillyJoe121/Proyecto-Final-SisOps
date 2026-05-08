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
    Write-Host " 1. Listar usuarios y su último ingreso"
    Write-Host " 2. Ver filesystems/discos (Tamaño y Libre)"
    Write-Host " 3. Listar 10 archivos más grandes en un disco"
    Write-Host " 4. Estadísticas de Memoria y Swap"
    Write-Host " 5. Realizar Backup a USB (con Catálogo)"
    Write-Host " Q. Salir"
    Write-Host "==========================================" -ForegroundColor Cyan
}

function Get-UserLogins {
    Write-Host "`n--- Usuarios y Último Ingreso ---" -ForegroundColor Yellow
    try {
        Get-LocalUser | Select-Object Name, @{Name="UltimoLogin"; Expression={if($_.LastLogon){$_.LastLogon}else{"Nunca"}}} | Format-Table -AutoSize
    } catch {
        Write-Host "Error al obtener usuarios: $($_.Exception.Message)" -ForegroundColor Red
    }
    Read-Host "`nPresione Enter para continuar..."
}

function Get-DiskSpace {
    Write-Host "`n--- Filesystems / Discos ---" -ForegroundColor Yellow
    Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID, 
        @{Name="Size(Bytes)"; Expression={"{0:N0}" -f $_.Size}}, 
        @{Name="FreeSpace(Bytes)"; Expression={"{0:N0}" -f $_.FreeSpace}} | Format-Table -AutoSize
    Read-Host "`nPresione Enter para continuar..."
}

function Get-TopFiles {
    $path = Read-Host "`nEspecifique la letra del disco o ruta completa (ej. C:\)"
    if (Test-Path $path) {
        Write-Host "`nEscaneando... Esto puede demorar varios minutos según el tamaño del disco." -ForegroundColor Gray
        try {
            $files = Get-ChildItem -Path $path -File -Recurse -ErrorAction SilentlyContinue | 
                     Sort-Object Length -Descending | 
                     Select-Object -First 10
            
            if ($files) {
                $files | Select-Object FullName, @{Name="Size(Bytes)"; Expression={"{0:N0}" -f $_.Length}} | Format-Table -AutoSize
            } else {
                Write-Host "No se encontraron archivos en la ruta especificada." -ForegroundColor Cyan
            }
        } catch {
            Write-Host "Ocurrió un error durante el escaneo: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "La ruta '$path' no es válida o no existe." -ForegroundColor Red
    }
    Read-Host "`nPresione Enter para continuar..."
}

function Get-MemoryStats {
    Write-Host "`n--- Memoria y Swap ---" -ForegroundColor Yellow
    $os = Get-CimInstance Win32_OperatingSystem
    
    $totalMem = $os.TotalVisibleMemorySize * 1024
    $freeMem = $os.FreePhysicalMemory * 1024
    $freeMemPct = [Math]::Round(($freeMem / $totalMem) * 100, 2)
    
    $totalSwap = $os.TotalSwapSpaceSize * 1024
    $freeSwap = $os.FreeSpaceInPagingFiles * 1024
    
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
            
            Write-Host "`nCopiando archivos... por favor espere." -ForegroundColor Gray
            Copy-Item -Path "$source\*" -Destination $backupDir -Recurse -Force -ErrorAction SilentlyContinue
            
            Write-Host "Generando catálogo de archivos..." -ForegroundColor Gray
            $catalogoPath = Join-Path $backupDir "catalogo_backup.txt"
            $header = "NOMBRE DEL ARCHIVO | FECHA ULTIMA MODIFICACION | RUTA COMPLETA"
            $separator = "=" * 80
            $header | Out-File $catalogoPath
            $separator | Out-File $catalogoPath -Append
            
            Get-ChildItem -Path $backupDir -Recurse -File | 
                Select-Object @{Name="Info"; Expression={"$($_.Name) | $($_.LastWriteTime) | $($_.FullName)"}} | 
                Select-Object -ExpandProperty Info | 
                Out-File $catalogoPath -Append
            
            Write-Host "`nBackup completado exitosamente en: $backupDir" -ForegroundColor Green
            Write-Host "Catálogo creado en: $catalogoPath" -ForegroundColor Green
        } catch {
            Write-Host "Error durante el backup: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Rutas de origen o destino no válidas." -ForegroundColor Red
    }
    Read-Host "`nPresione Enter para continuar..."
}

# Inicio del Programa
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ADVERTENCIA: Algunas funciones requieren privilegios de Administrador." -ForegroundColor Yellow
}

do {
    Show-Menu
    $choice = Read-Host "`nOpción"
    switch ($choice) {
        "1" { Get-UserLogins }
        "2" { Get-DiskSpace }
        "3" { Get-TopFiles }
        "4" { Get-MemoryStats }
        "5" { Invoke-Backup }
        "Q" { break }
        default { Write-Host "Opción no reconocida." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne "Q")
