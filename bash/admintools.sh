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
    echo -e "\n${YELLOW}--- Usuarios del Sistema y Último Ingreso ---${NC}"
    printf "%-20s %s\n" "USUARIO" "ÚLTIMO INGRESO"
    echo "------------------------------------------------------------"
    while IFS=: read -r usuario _ uid _ _ _ _; do
        if [ "$uid" -ge 1000 ] || [ "$uid" -eq 0 ]; then
            ultimo=$(lastlog -u "$usuario" | tail -n 1 | awk '{$1=""; print $0}')
            printf "%-20s %s\n" "$usuario" "$ultimo"
        fi
    done < /etc/passwd
    read -p "$(echo -e "\nPresione Enter para continuar...")"
}

get_disk_space() {
    echo -e "\n${YELLOW}--- Filesystems / Discos (Valores en Bytes) ---${NC}"
    printf "%-25s %-15s %-15s %-15s %-10s %s\n" "Filesystem" "Tamaño(B)" "Usado(B)" "Libre(B)" "Uso%" "Montado"
    echo "---------------------------------------------------------------------------------------------------"
    df -B1 --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | tail -n +2 | \
    while read -r fs tamano usado libre porcentaje montado; do
        printf "%-25s %-15s %-15s %-15s %-10s %s\n" "$fs" "$tamano" "$usado" "$libre" "$porcentaje" "$montado"
    done
    read -p "$(echo -e "\nPresione Enter para continuar...")"
}

get_top_files() {
    read -p "Ingrese el punto de montaje o directorio (ej. /): " dir
    if [ -d "$dir" ]; then
        echo -e "\n${YELLOW}Buscando los 10 archivos más grandes en '$dir'...${NC}"
        echo ""
        echo -e "${GRAY}(Esto puede tardar dependiendo del tamaño del disco)${NC}"
        printf "%-12s  %s\n" "TAMAÑO" "ARCHIVO"
        echo "-----------------------------------------------------------"
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
    mem_free=$(echo $mem_data | awk '{print $7}')
    
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
            cp -a "$src/." "$backup_path/" 2>/dev/null
            
            echo -e "${GRAY}Generando catálogo...${NC}"
            catalog_file="$backup_path/catalogo_archivos.txt"
            echo "CATÁLOGO DE BACKUP - $(date)" > "$catalog_file"
            echo "------------------------------------------" >> "$catalog_file"
            echo "ARCHIVO | FECHA MODIFICACIÓN | TRAYECTORIA COMPLETA" >> "$catalog_file"
            
            # Se genera el catálogo desde el ORIGEN para registrar las fechas reales
            find "$src" -type f -printf "%f | %TY-%Tm-%Td %TH:%TM:%TS | %p\n" >> "$catalog_file"
            
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
