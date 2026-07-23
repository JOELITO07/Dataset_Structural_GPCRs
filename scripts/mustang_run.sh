#!/bin/bash

###############################################################################
# Ejecutar MUSTANG en paralelo para todos los datasets GPCR
###############################################################################

ROOT="/home/azureuser/Dataset_Structural_GPCRs"

INPUT_DIR="${ROOT}/GPCRdb/alphafold_pdb"
OUTPUT_DIR="${ROOT}/GPCRdb/Mustang"

MUSTANG_BIN="/home/azureuser/MUSTANG/bin/mustang"

# Número máximo de procesos simultáneos
JOBS=4

mkdir -p "${OUTPUT_DIR}"

###############################################################################
# Función para procesar un dataset
###############################################################################

run_mustang() {

    desc="$1"

    filename=$(basename "${desc}")

    # Quitar el sufijo _mustang
    dataset="${filename%_mustang}"

    outdir="${OUTPUT_DIR}/${dataset}"
    prefix="${outdir}/${dataset}"

    mkdir -p "${outdir}"

    log_file="${outdir}/${dataset}.log"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando ${dataset}"

    "${MUSTANG_BIN}" \
        -f "${desc}" \
        -o "${prefix}" \
        -F fasta \
        -s ON \
        -r ON \
        > "${log_file}" 2>&1

    status=$?

    if [ "${status}" -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finalizado correctamente: ${dataset}"
        touch "${outdir}/COMPLETED"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR en ${dataset}. Revisar: ${log_file}"
        touch "${outdir}/FAILED"
    fi

    return "${status}"
}

export ROOT
export INPUT_DIR
export OUTPUT_DIR
export MUSTANG_BIN
export -f run_mustang

echo "==========================================================="
echo "EJECUCIÓN PARALELA DE MUSTANG"
echo "Procesos simultáneos: ${JOBS}"
echo "==========================================================="


find "${INPUT_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "*_mustang" \
    -print0 |
parallel \
    -0 \
    -j "${JOBS}" \
    --line-buffer \
    --joblog "${OUTPUT_DIR}/parallel_joblog.tsv" \
    run_mustang {}

echo ""
echo "==========================================================="
echo "TODOS LOS DATASETS HAN SIDO PROCESADOS"
echo "Registro general:"
echo "${OUTPUT_DIR}/parallel_joblog.tsv"
echo "==========================================================="