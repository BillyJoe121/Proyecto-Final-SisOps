# Proyecto Final - Sistemas Operativos

Este proyecto contiene dos herramientas de administración para Data Centers, una desarrollada en **PowerShell** y otra en **BASH**.

## Requisitos
- **Windows**: PowerShell 5.1 o superior.
- **Linux**: BASH, comandos `df`, `free`, `lastlog`, `find`.

## Estructura
- `/powershell/AdminTools.ps1`: Script para entornos Windows.
- `/bash/admintools.sh`: Script para entornos Linux/Unix.

## Uso
### PowerShell
1. Abre una terminal de PowerShell como Administrador.
2. Navega a la carpeta `powershell`.
3. Ejecuta: `.\AdminTools.ps1`

### BASH
1. Abre una terminal.
2. Navega a la carpeta `bash`.
3. Otorga permisos de ejecución: `chmod +x admintools.sh`
4. Ejecuta: `./admintools.sh`

## Funcionalidades
1. Reporte de usuarios y último login.
2. Espacio en discos/filesystems (en bytes).
3. Top 10 archivos más grandes por ruta.
4. Estadísticas de Memoria RAM y Swap (Bytes y %).
5. Backup de directorios con generación de catálogo automático.