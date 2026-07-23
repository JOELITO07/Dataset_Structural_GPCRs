#!/usr/bin/env bash

set -u

# ============================================================
# CONFIGURACIÓN
# ============================================================

ROOT_DIR="/home/azureuser/resultados_mtmalign"

# true  = solo muestra qué eliminaría
# false = elimina realmente los archivos
DRY_RUN=false

# ============================================================
# VALIDACIÓN
# ============================================================

if [[ ! -d "$ROOT_DIR" ]]; then
    echo "ERROR: No existe la carpeta:"
    echo "  $ROOT_DIR"
    exit 1
fi

echo "============================================================"
echo "Limpieza de archivos PDB intermedios de mTM-align"
echo "Directorio: $ROOT_DIR"
echo "DRY_RUN:    $DRY_RUN"
echo "============================================================"

archivos_encontrados=0
archivos_eliminados=0
bytes_liberados=0
errores=0

# ============================================================
# ELIMINAR ÚNICAMENTE *_pair.pdb
# ============================================================

while IFS= read -r -d '' pdb_file; do

    ((archivos_encontrados += 1))

    # Obtener tamaño antes de eliminar
    file_size=$(stat -c '%s' "$pdb_file" 2>/dev/null || echo 0)

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[SIMULACIÓN] Se eliminaría: $pdb_file"
        ((bytes_liberados += file_size))
        continue
    fi

    if rm -- "$pdb_file"; then
        echo "[ELIMINADO] $pdb_file"
        ((archivos_eliminados += 1))
        ((bytes_liberados += file_size))
    else
        echo "[ERROR] No se pudo eliminar: $pdb_file" >&2
        ((errores += 1))
    fi

done < <(
    find "$ROOT_DIR" \
        -type f \
        -name '*_pair.pdb' \
        -print0
)

# ============================================================
# RESUMEN
# ============================================================

espacio_humano=$(numfmt --to=iec-i --suffix=B "$bytes_liberados" 2>/dev/null \
    || echo "${bytes_liberados} bytes")

echo
echo "============================================================"
echo "RESUMEN"
echo "============================================================"
echo "Archivos *_pair.pdb encontrados: $archivos_encontrados"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "Archivos eliminados:             0 (modo simulación)"
    echo "Espacio que se liberaría:         $espacio_humano"
    echo
    echo "No se eliminó ningún archivo."
    echo "Después de verificar, cambia:"
    echo "  DRY_RUN=true"
    echo "por:"
    echo "  DRY_RUN=false"
else
    echo "Archivos eliminados:             $archivos_eliminados"
    echo "Espacio liberado:                $espacio_humano"
    echo "Errores:                         $errores"
fi

echo
echo "Archivos PDB finales conservados:"
find "$ROOT_DIR" \
    -type f \
    \( -name 'result.pdb' -o -name 'cc.pdb' \) \
    -printf '  %p\n' | sort

echo
echo "Proceso finalizado."