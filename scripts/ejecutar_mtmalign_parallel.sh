
#!/usr/bin/env bash

set -euo pipefail

# Directorio que contiene las subcarpetas de los datasets
BASE_DIR="/home/azureuser/Dataset_Structural_GPCRs/GPCRdb/alphafold_pdb"

# Ejecutable compilado de mTM-align
MTMALIGN_BIN="/home/azureuser/mTM-align/src/mTM-align"

# Carpeta general de resultados
RESULTS_DIR="/home/azureuser/resultados_mtmalign"

# Carpeta general de registros
LOGS_DIR="$RESULTS_DIR/logs"

# Número máximo de ejecuciones simultáneas
JOBS=4

mkdir -p "$RESULTS_DIR"
mkdir -p "$LOGS_DIR"

if [[ ! -x "$MTMALIGN_BIN" ]]; then
    echo "ERROR: no se encontró el ejecutable de mTM-align:"
    echo "$MTMALIGN_BIN"
    exit 1
fi

if ! command -v parallel >/dev/null 2>&1; then
    echo "ERROR: GNU Parallel no está instalado."
    echo "Instálalo con: sudo apt install parallel"
    exit 1
fi

export BASE_DIR
export MTMALIGN_BIN
export RESULTS_DIR
export LOGS_DIR

ejecutar_dataset() {
    INPUT_LIST="$1"

    INPUT_NAME="$(basename "$INPUT_LIST")"

    # input_list_classA_001.txt -> classA_001
    DATASET_NAME="${INPUT_NAME#input_list_}"
    DATASET_NAME="${DATASET_NAME%.txt}"

    OUTPUT_DIR="$RESULTS_DIR/$DATASET_NAME"
    STDERR_LOG="$LOGS_DIR/${DATASET_NAME}.stderr.log"

    mkdir -p "$OUTPUT_DIR"

    NUM_PDB=$(grep -cve '^[[:space:]]*$' "$INPUT_LIST" || true)

    if [[ "$NUM_PDB" -lt 2 ]]; then
        echo "[OMITIDO] $DATASET_NAME: solamente contiene $NUM_PDB PDB"
        return 0
    fi

    echo "[INICIO] $DATASET_NAME — $NUM_PDB estructuras"

    START_TIME=$(date +%s)

    cd "$OUTPUT_DIR"

   /usr/bin/time -v \
    "$MTMALIGN_BIN" \
    -i "$INPUT_LIST" \
    -o "$OUTPUT_DIR/result.pdb" \
    -outdir "$OUTPUT_DIR" \
    > "$OUTPUT_DIR/stdout.log" \
    2> "$OUTPUT_DIR/time_metrics.txt"
    STATUS=$?

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))

    {
        echo
        echo "Dataset: $DATASET_NAME"
        echo "Input list: $INPUT_LIST"
        echo "Número de PDB: $NUM_PDB"
        echo "Tiempo total en segundos: $ELAPSED"
        echo "Código de salida: $STATUS"
    } >> "$TIME_LOG"

    if [[ "$STATUS" -eq 0 ]]; then
        echo "[FINALIZADO] $DATASET_NAME — ${ELAPSED} segundos"
    else
        echo "[ERROR] $DATASET_NAME — código $STATUS" |
            tee -a "$STDERR_LOG"
    fi

    return "$STATUS"
}

export -f ejecutar_dataset

echo "=================================================="
echo "mTM-align en paralelo"
echo "Ejecuciones simultáneas: $JOBS"
echo "Directorio base: $BASE_DIR"
echo "Resultados: $RESULTS_DIR"
echo "=================================================="
echo

find "$BASE_DIR" \
    -maxdepth 1 \
    -type f \
    -name "input_list_*.txt" \
    -print0 |
    sort -z |
    parallel \
        --null \
        --jobs "$JOBS" \
        --joblog "$LOGS_DIR/parallel_joblog.tsv" \
        --eta \
        --line-buffer \
        ejecutar_dataset {}

echo
echo "=================================================="
echo "Todas las ejecuciones terminaron."
echo "Resultados disponibles en:"
echo "$RESULTS_DIR"
echo
echo "Resumen de GNU Parallel:"
echo "$LOGS_DIR/parallel_joblog.tsv"
echo "=================================================="