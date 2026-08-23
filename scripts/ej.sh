#!/usr/bin/env bash

set -Eeuo pipefail

EXECUTIONS_DIR="/home/azureuser/results_tm_m2structalign/ejecuciones"

# Carpeta donde se guardarán los ZIP.
OUTPUT_DIR="/home/azureuser/results_tm_m2structalign/ejecuciones"

if [[ ! -d "$EXECUTIONS_DIR" ]]; then
    echo "ERROR: no existe la carpeta:"
    echo "$EXECUTIONS_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

datasets_processed=0
total_msf_deleted=0

echo "Carpeta de entrada: $EXECUTIONS_DIR"
echo "Carpeta de salida:  $OUTPUT_DIR"
echo

# Recorre únicamente las carpetas directamente dentro de ejecuciones.
while IFS= read -r -d '' dataset_dir; do
    dataset_name=$(basename "$dataset_dir")
    zip_file="${OUTPUT_DIR}/${dataset_name}.zip"

    echo "======================================================"
    echo "Dataset: $dataset_name"
    echo "======================================================"

    # Cuenta todos los .msf dentro del dataset y sus semillas.
    msf_count=$(
        find "$dataset_dir" -type f -iname '*.msf' -print0 |
        awk 'BEGIN { RS="\0"; count=0 } { count++ } END { print count }'
    )

    echo "Archivos .msf encontrados: $msf_count"

    if (( msf_count > 0 )); then
        find "$dataset_dir" -type f -iname '*.msf' -print -delete
        echo "Archivos .msf eliminados: $msf_count"
    else
        echo "No existen archivos .msf para eliminar."
    fi

    # Elimina el ZIP anterior exclusivamente para este dataset.
    if [[ -f "$zip_file" ]]; then
        rm -- "$zip_file"
    fi

    echo "Comprimiendo ${dataset_name}..."

    (
        cd "$EXECUTIONS_DIR"
        zip -rq "$zip_file" "$dataset_name"
    )

    if [[ -f "$zip_file" ]]; then
        echo "ZIP generado correctamente:"
        echo "$zip_file"
        du -h "$zip_file"
    else
        echo "ERROR: no se pudo generar $zip_file" >&2
        exit 1
    fi

    datasets_processed=$((datasets_processed + 1))
    total_msf_deleted=$((total_msf_deleted + msf_count))

    echo
done < <(
    find "$EXECUTIONS_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -print0 |
    sort -z
)

echo "======================================================"
echo "PROCESO FINALIZADO"
echo "======================================================"
echo "Datasets procesados:        $datasets_processed"
echo "Total de .msf eliminados:   $total_msf_deleted"
echo "Archivos ZIP guardados en:  $OUTPUT_DIR"