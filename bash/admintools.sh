#!/bin/bash

# ==========================================
# DATA CENTER ADMIN TOOLS (BASH Version)
# ==========================================

# Colores para la interfaz
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

show_menu() {
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "      DATA CENTER ADMIN TOOLS (BASH)      "
    echo -e "${CYAN}==========================================${NC}"
    echo " 1. Listar usuarios y su último ingreso"
    echo " 2. Ver filesystems/discos (Tamaño y Libre)"
    echo " 3. Listar 10 archivos más grandes en un disco"
    echo " 4. Estadísticas de Memoria y Swap"
    echo " 5. Realizar Backup a USB (con Catálogo)"
    echo " q. Salir"
    echo -e "${CYAN}==========================================${NC}"
}

get_user_logins() {
    echo -e "\n${YELLOW}--- Usuarios y Último Ingreso ---${NC}"
    if command -v lastlog >/dev/null 2>&1; then
        # Filtramos para mostrar solo usuarios que han iniciado sesión o excluir sistémicos sin login
        lastlog | awk 'NR==1 || ($4 != "**Never" && $4 != "logged")'
    else
        echo -e "${GRAY}lastlog no disponible. Usando comando 'last' para los más recientes:${NC}"
        last -n 10
    fi
    read -p "$(echo -e "\nPresione Enter para continuar...")"
}

get_disk_space() {
    echo -e "\n${YELLOW}--- Filesystems / Discos (Valores en Bytes) ---${NC}"
    # df -B1 fuerza la salida en bytes. Se muestran columnas específicas.
    printf "%-20s %-15s %-15s %s\n" "Filesystem" "Tamaño(B)" "Libre(B)" "Montado"
    df -B1 --output=source,size,avail,target | tail -n +2 | awk '{printf "%-20s %-15s %-15s %s\n", $1, $2, $3, $4}'
    read -p "$(echo -e "\nPresione Enter para continuar...")"
}

get_top_files() {
    read -p "Ingrese el punto de montaje o directorio (ej. /): " dir
    if [ -d "$dir" ]; then
        echo -e "\n${YELLOW}Buscando los 10 archivos más grandes en '$dir'...${NC}"
        echo -e "${GRAY}(Esto puede tardar dependiendo del tamaño del disco)${NC}"
        # find busca archivos, du obtiene tamaño en bytes, sort ordena numéricamente descendente
        find "$dir" -type f -exec du -b {} + 2>/dev/null | sort -rn | head -n 10 | awk '{printf "%-15s %s\n", $1, $2}'
    else
        echo -e "${RED}Error: El directorio '$dir' no existe o no es accesible.${NC}"
    fi
    read -p "$(echo -e "\nPresione Enter para continuar...")"
}

get_memory_stats() {
    echo -e "\n${YELLOW}--- Estadísticas de Memoria y Swap ---${NC}"
    
    # Obtener datos de 'free -b' (bytes)
    mem_data=$(free -b | grep Mem)
    mem_total=$(echo $mem_data | awk '{print $2}')
    mem_free=$(echo $mem_data | awk '{print $4}')
    
    # Evitar división por cero
    if [ "$mem_total" -gt 0 ]; then
        mem_free_pct=$(awk "BEGIN {printf \"%.2f\", ($mem_free/$mem_total)*100}")
    else
        mem_free_pct=0
    fi

    swap_data=$(free -b | grep Swap)
    swap_total=$(echo $swap_data | awk '{print $2}')
    swap_used=$(echo $swap_data | awk '{print $3}')
    
    if [ "$swap_total" -gt 0 ]; then
        swap_used_pct=$(awk "BEGIN {printf \"%.2f\", ($swap_used/$swap_total)*100}")
    else
        swap_used_pct=0
    fi

    echo -e "Memoria RAM:"
    echo -e "  Total:      $mem_total bytes"
    echo -e "  Libre:      $mem_free bytes ($mem_free_pct %)"
    echo -e "Swap:"
    echo -e "  Total:      $swap_total bytes"
    echo -e "  En Uso:     $swap_used bytes ($swap_used_pct %)"
    
    read -p "$(echo -e "\nPresione Enter para continuar...")"
}

invoke_backup() {
    read -p "Directorio de origen: " src
    read -p "Directorio de destino (USB): " dst
    
    if [ -d "$src" ] && [ -d "$dst" ]; then
        timestamp=$(date +"%Y%m%d_%H%M%S")
        backup_path="$dst/backup_datacenter_$timestamp"
        
        if mkdir -p "$backup_path" 2>/dev/null; then
            echo -e "\n${GRAY}Copiando archivos...${NC}"
            # Copiar archivos (cp -r)
            cp -r "$src"/* "$backup_path" 2>/dev/null
            
            echo -e "${GRAY}Generando catálogo...${NC}"
            catalog_file="$backup_path/catalogo_archivos.txt"
            echo "CATÁLOGO DE BACKUP - $(date)" > "$catalog_file"
            echo "------------------------------------------" >> "$catalog_file"
            echo "ARCHIVO | FECHA MODIFICACIÓN | TRAYECTORIA COMPLETA" >> "$catalog_file"
            
            # find para listar archivos con su fecha y ruta completa
            find "$backup_path" -type f -printf "%f | %TY-%Tm-%Td %TH:%TM:%TS | %p\n" >> "$catalog_file"
            
            echo -e "${GREEN}Backup finalizado exitosamente en: $backup_path${NC}"
        else
            echo -e "${RED}Error: No se pudo crear el directorio de destino. Verifique permisos.${NC}"
        fi
    else
        echo -e "${RED}Error: Rutas de origen o destino inválidas.${NC}"
    fi
    read -p "$(echo -e "\nPresione Enter para continuar...")"
}

# Verificación de ejecución
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Aviso: Ejecutar como root es recomendado para acceder a todos los archivos y logs.${NC}"
    sleep 1
fi

# Bucle principal
while true; do
    show_menu
    read -p "Seleccione una opción: " opt
    case $opt in
        1) get_user_logins ;;
        2) get_disk_space ;;
        3) get_top_files ;;
        4) get_memory_stats ;;
        5) invoke_backup ;;
        q|Q) echo "Saliendo..."; break ;;
        *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
    esac
done
