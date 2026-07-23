#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# CONFIGURACIÓN
###############################################################################

DATASET_ROOT="$HOME/Dataset_Structural_GPCRs/GPCRdb/alphafold_pdb"
RESULT_ROOT="$HOME/FoldMason_results"

FOLDMASON_BIN="$HOME/foldmason/bin/foldmason"

JOBS=4

mkdir -p "$RESULT_ROOT"

###############################################################################
# FUNCIÓN
###############################################################################

run_dataset() {

    DATASET="$1"

    NAME=$(basename "$DATASET")

    OUTDIR="$RESULT_ROOT/$NAME"
    TMPDIR="$OUTDIR/tmp"

    mkdir -p "$OUTDIR"
    mkdir -p "$TMPDIR"

    echo "===================================================="
    echo "Procesando $NAME"
    echo "===================================================="

    /usr/bin/time -v \
        "$FOLDMASON_BIN" easy-msa \
        "$DATASET"/*.pdb \
        "$OUTDIR" \
        "$TMPDIR" \
        > "$OUTDIR/stdout.log" \
        2> "$OUTDIR/time.log"

    echo "Finalizado $NAME"
}

export -f run_dataset
export RESULT_ROOT
export FOLDMASON_BIN

###############################################################################
# EJECUCIÓN EN PARALELO
###############################################################################

find "$DATASET_ROOT" -mindepth 1 -maxdepth 1 -type d \
| sort \
| parallel -j ${JOBS} run_dataset {}

echo "==========================================="
echo "TODOS LOS DATASETS FINALIZADOS"
echo "==========================================="