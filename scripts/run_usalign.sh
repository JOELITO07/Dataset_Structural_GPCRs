#!/usr/bin/env bash

set -u

# ============================================================
# CONFIGURACIÓN
# ============================================================

USALIGN_BIN="/home/azureuser/usalign/USalign"

DATA_ROOT="/home/azureuser/Dataset_Structural_GPCRs/GPCRdb/alphafold_pdb"

RESULTS_ROOT="/home/azureuser/results_usalign"

JOBS=4

mkdir -p "$RESULTS_ROOT"

# Verificar ejecutable
if [[ ! -x "$USALIGN_BIN" ]]; then
    echo "ERROR: US-align no existe o no es ejecutable:"
    echo "$USALIGN_BIN"
    exit 1
fi

# Verificar dataset
if [[ ! -d "$DATA_ROOT" ]]; then
    echo "ERROR: No existe la carpeta de datasets:"
    echo "$DATA_ROOT"
    exit 1
fi

# ============================================================
# FUNCIÓN PARA PROCESAR UN DATASET
# ============================================================

procesar_dataset() {

    dataset_dir="$1"
    dataset_name="$(basename "$dataset_dir")"

    output_dir="${RESULTS_ROOT}/${dataset_name}"
    list_file="${output_dir}/list.txt"
    stdout_log="${output_dir}/stdout.log"
    stderr_log="${output_dir}/stderr.log"
    time_log="${output_dir}/time.log"

    mkdir -p "$output_dir"

    echo "===================================================="
    echo "Procesando $dataset_name"
    echo "Entrada: $dataset_dir"
    echo "Salida:  $output_dir"
    echo "===================================================="

    # US-align requiere que list.txt contenga los nombres relativos
    # de los archivos ubicados dentro de dataset_dir
    find "$dataset_dir" \
        -maxdepth 1 \
        -type f \
        \( -iname "*.pdb" -o -iname "*.cif" -o -iname "*.mmcif" \) \
        -printf "%f\n" \
        | sort > "$list_file"

    number_structures=$(wc -l < "$list_file")

    if [[ "$number_structures" -lt 2 ]]; then
        echo "ERROR: $dataset_name contiene menos de dos estructuras." \
            | tee "$stderr_log"
        return 1
    fi

    echo "Estructuras encontradas: $number_structures"

    # La barra final de dataset_dir es necesaria para -dir
    /usr/bin/time -v "$USALIGN_BIN" -dir "${dataset_dir}/" "$list_file" -suffix ".pdb" -mm 4 > "$stdout_log" 2> "$time_log"

    exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        echo "Finalizado correctamente: $dataset_name"
        touch "${output_dir}/SUCCESS"
    else
        echo "ERROR en $dataset_name. Código: $exit_code" \
            | tee "$stderr_log"
        touch "${output_dir}/FAILED"
    fi
}

export -f procesar_dataset
export USALIGN_BIN
export DATA_ROOT
export RESULTS_ROOT

# ============================================================
# BUSCAR Y EJECUTAR DATASETS
# ============================================================

find "$DATA_ROOT" \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    -print0 \
    | sort -z \
    | parallel \
        --null \
        --jobs "$JOBS" \
        --line-buffer \
        procesar_dataset {}

echo
echo "===================================================="
echo "Todas las ejecuciones terminaron"
echo "Resultados: $RESULTS_ROOT"
echo "===================================================="