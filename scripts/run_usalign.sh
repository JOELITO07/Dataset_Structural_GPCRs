#!/usr/bin/env bash

set -u

# ============================================================
# CONFIGURACIÓN
# ============================================================

USALIGN_BIN="/home/azureuser/USalign"
DATA_ROOT="/home/azureuser/Dataset_Structural_GPCRs/GPCRdb/alphafold_pdb"
RESULTS_ROOT="/home/azureuser/results_usalign"

# Solo existen tres trabajos seleccionados
JOBS=3

mkdir -p "$RESULTS_ROOT"

if [[ ! -x "$USALIGN_BIN" ]]; then
    echo "ERROR: US-align no existe o no es ejecutable:"
    echo "$USALIGN_BIN"
    exit 1
fi

if [[ ! -d "$DATA_ROOT" ]]; then
    echo "ERROR: no existe la carpeta de datasets:"
    echo "$DATA_ROOT"
    exit 1
fi

if ! command -v parallel >/dev/null 2>&1; then
    echo "ERROR: GNU Parallel no está instalado."
    echo "Instálalo con: sudo apt install -y parallel"
    exit 1
fi

# ============================================================
# PROCESAR UN DATASET
# ============================================================

procesar_dataset() {
    local dataset_dir="$1"
    local dataset_name
    local output_dir
    local list_file
    local fasta_file
    local stderr_log
    local time_log
    local number_structures
    local exit_code

    dataset_name="$(basename "$dataset_dir")"
    output_dir="${RESULTS_ROOT}/${dataset_name}"
    list_file="${output_dir}/list.txt"
    fasta_file="${output_dir}/usalign_${dataset_name}.fasta"
    stderr_log="${output_dir}/stderr.log"
    time_log="${output_dir}/time.log"

    mkdir -p "$output_dir"

    # Eliminar indicadores anteriores
    rm -f "${output_dir}/SUCCESS" "${output_dir}/FAILED"

    echo "===================================================="
    echo "Procesando: $dataset_name"
    echo "Entrada:    $dataset_dir"
    echo "Salida:     $output_dir"
    echo "===================================================="

    if [[ ! -d "$dataset_dir" ]]; then
        echo "ERROR: no existe el dataset: $dataset_dir" \
            | tee "$stderr_log"
        touch "${output_dir}/FAILED"
        return 1
    fi

    # list.txt contiene nombres completos, incluida la extensión .pdb
    find "$dataset_dir" \
        -maxdepth 1 \
        -type f \
        -iname "*.pdb" \
        -printf "%f\n" \
    | sort > "$list_file"

    number_structures="$(wc -l < "$list_file")"

    if [[ "$number_structures" -lt 2 ]]; then
        echo "ERROR: $dataset_name contiene menos de dos archivos PDB." \
            | tee "$stderr_log"
        touch "${output_dir}/FAILED"
        return 1
    fi

    echo "Estructuras encontradas: $number_structures"

    /usr/bin/time -v \
        "$USALIGN_BIN" \
        -dir "${dataset_dir}/" "$list_file" \
        -mm 4 \
        -outfmt 1 \
        > "$fasta_file" \
        2> "$time_log"

    exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        echo "Finalizado correctamente: $dataset_name"
        echo "Alineamiento: $fasta_file"
        touch "${output_dir}/SUCCESS"
    else
        echo "ERROR en $dataset_name. Código: $exit_code" \
            | tee "$stderr_log"
        touch "${output_dir}/FAILED"
        return "$exit_code"
    fi
}

export -f procesar_dataset
export USALIGN_BIN
export RESULTS_ROOT

# ============================================================
# EJECUTAR ÚNICAMENTE LOS TRES DATASETS
# ============================================================

printf '%s\0' \
    "$DATA_ROOT/classA_002" \
    "$DATA_ROOT/classA_003" \
    "$DATA_ROOT/classA_004" \
| parallel \
    --null \
    --jobs "$JOBS" \
    --line-buffer \
    procesar_dataset {}

parallel_exit_code=$?

echo
echo "===================================================="

if [[ "$parallel_exit_code" -eq 0 ]]; then
    echo "Los tres datasets finalizaron correctamente."
else
    echo "Una o más ejecuciones terminaron con error."
fi

echo "Resultados: $RESULTS_ROOT"
echo "===================================================="

exit "$parallel_exit_code"