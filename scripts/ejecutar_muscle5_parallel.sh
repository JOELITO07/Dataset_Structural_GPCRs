#!/usr/bin/env bash

set -euo pipefail

INPUT_DIR="$HOME/Dataset_Structural_GPCRs/GPCRdb/sequences/fasta"
OUTPUT_BASE="$HOME/muscle_results"
LOG_DIR="$OUTPUT_BASE/logs_muscle5"

MUSCLE_BIN="muscle"

# Número de datasets procesados simultáneamente
JOBS=4

# Hilos utilizados por cada ejecución de MUSCLE
THREADS_PER_JOB=1

mkdir -p "$OUTPUT_BASE" "$LOG_DIR"

if ! command -v "$MUSCLE_BIN" >/dev/null 2>&1; then
    echo "ERROR: MUSCLE5 no está instalado o no está en el PATH."
    echo "Comprueba con: muscle -version"
    exit 1
fi

if ! command -v parallel >/dev/null 2>&1; then
    echo "ERROR: GNU Parallel no está instalado."
    echo "Instálalo con:"
    echo "sudo apt update && sudo apt install -y parallel"
    exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "ERROR: no existe el directorio:"
    echo "$INPUT_DIR"
    exit 1
fi

align_dataset() {
    local input_fasta="$1"
    local dataset
    local output_dir
    local output_fasta
    local log_file

    dataset="$(basename "$input_fasta")"

    # Elimina extensiones FASTA conocidas
    dataset="${dataset%.fasta}"
    dataset="${dataset%.fasta.txt}"
    dataset="${dataset%.fa}"
    dataset="${dataset%.faa}"
    dataset="${dataset%.fas}"
    dataset="${dataset%.fsa}"

    output_dir="$OUTPUT_BASE/$dataset"
    output_fasta="$output_dir/muscle5_${dataset}.fasta"
    log_file="$LOG_DIR/${dataset}.log"

    mkdir -p "$output_dir"

    echo "===================================================="
    echo "Dataset: $dataset"
    echo "Entrada: $input_fasta"
    echo "Salida : $output_fasta"
    echo "===================================================="

    if [[ -s "$output_fasta" ]]; then
        echo "OMITIDO: el resultado ya existe para $dataset"
        return 0
    fi

    if "$MUSCLE_BIN" \
        -align "$input_fasta" \
        -output "$output_fasta" \
        -threads "$THREADS_PER_JOB" \
        >"$log_file" 2>&1; then

        echo "FINALIZADO: $dataset"
    else
        local status=$?
        echo "ERROR: MUSCLE falló para $dataset. Revisa:"
        echo "$log_file"
        rm -f "$output_fasta"
        return "$status"
    fi
}

export -f align_dataset
export OUTPUT_BASE LOG_DIR MUSCLE_BIN THREADS_PER_JOB

find "$INPUT_DIR" -maxdepth 1 -type f \
    \( -iname "*.fasta" \
       -o -iname "*.fasta.txt" \
       -o -iname "*.fa" \
       -o -iname "*.faa" \
       -o -iname "*.fas" \
       -o -iname "*.fsa" \
       -o -iname "*.fatsa" \) \
    -print0 |
    sort -z |
    parallel \
        --null \
        --jobs "$JOBS" \
        --joblog "$LOG_DIR/parallel_joblog.tsv" \
        --bar \
        align_dataset {}

echo
echo "Todos los alineamientos finalizaron."
echo "Resultados: $OUTPUT_BASE"
echo "Registros: $LOG_DIR"