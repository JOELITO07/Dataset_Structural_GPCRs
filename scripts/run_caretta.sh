#!/usr/bin/env bash

set -u
set -o pipefail

###############################################################################
# Ejecución paralela de Caretta sobre todos los datasets GPCR
###############################################################################

# Carpeta que contiene classA_001, classB1, classC, etc.
INPUT_ROOT="${1:-$HOME/Dataset_Structural_GPCRs/GPCRdb/alphafold_pdb}"

# Carpeta donde se guardarán los resultados
OUTPUT_ROOT="${2:-$HOME/results/caretta}"

# Número máximo de datasets ejecutados simultáneamente
MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-1}"

# Número de hilos utilizados por cada ejecución de Caretta
THREADS_PER_JOB="${THREADS_PER_JOB:-4}"

# Entorno virtual donde está instalado Caretta
VENV_PATH="${VENV_PATH:-$HOME/envs/structalign}"

# 1 = usar --fast; 0 = alineamiento completo
USE_FAST="${USE_FAST:-0}"

###############################################################################
# Validaciones
###############################################################################

if [[ ! -d "$INPUT_ROOT" ]]; then
    echo "ERROR: no existe la carpeta de entrada:"
    echo "  $INPUT_ROOT"
    exit 1
fi

if [[ ! -f "$VENV_PATH/bin/activate" ]]; then
    echo "ERROR: no se encontró el entorno virtual:"
    echo "  $VENV_PATH"
    exit 1
fi

# Activar entorno virtual
# shellcheck disable=SC1091
source "$VENV_PATH/bin/activate"

if ! command -v caretta-cli >/dev/null 2>&1; then
    echo "ERROR: caretta-cli no está disponible en el entorno virtual."
    exit 1
fi

mkdir -p "$OUTPUT_ROOT"
mkdir -p "$OUTPUT_ROOT/logs"
mkdir -p "$OUTPUT_ROOT/status"

###############################################################################
# Configuración de paralelismo
###############################################################################

# Evita que NumPy, BLAS o Numba creen hilos adicionales por cada proceso.
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
export NUMBA_NUM_THREADS="$THREADS_PER_JOB"

###############################################################################
# Lista de datasets
###############################################################################

DATASETS=(
	"classC"
	"classC_19"
)

###############################################################################
# Función para ejecutar un dataset
###############################################################################

run_dataset() {
    local dataset="$1"
    local input_dir="$INPUT_ROOT/$dataset"
    local output_dir="$OUTPUT_ROOT/$dataset"
    local log_file="$OUTPUT_ROOT/logs/${dataset}.log"
    local status_file="$OUTPUT_ROOT/status/${dataset}.success"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Preparando: $dataset"

    if [[ ! -d "$input_dir" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] OMITIDO: no existe $input_dir" \
            | tee "$log_file"
        return 0
    fi

    local pdb_count
    pdb_count=$(find "$input_dir" -maxdepth 1 -type f \
        \( -iname "*.pdb" -o -iname "*.ent" \) | wc -l)

    if [[ "$pdb_count" -lt 2 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] OMITIDO: $dataset tiene $pdb_count PDB; se requieren al menos 2." \
            | tee "$log_file"
        return 0
    fi

    # Permite reanudar el script sin repetir datasets finalizados.
    if [[ -f "$status_file" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] YA COMPLETADO: $dataset"
        return 0
    fi

    

    {
        echo "============================================================"
        echo "Dataset:             $dataset"
        echo "Entrada:             $input_dir"
        echo "Salida:              $output_dir"
        echo "Número de PDB:       $pdb_count"
        echo "Hilos Caretta:       $THREADS_PER_JOB"
        echo "Modo rápido:         $USE_FAST"
        echo "Inicio:              $(date '+%Y-%m-%d %H:%M:%S')"
        echo "============================================================"
    } > "$log_file"

    local command=(
        caretta-cli
        "$input_dir"
        --output "$output_dir"
        --matrix
        --fasta
        --pdb
        --threads "$THREADS_PER_JOB"
    )

    if [[ "$USE_FAST" == "1" ]]; then
        command+=(--fast)
    fi

    if "${command[@]}" >> "$log_file" 2>&1; then
        {
            echo "Dataset: $dataset"
            echo "Estado: completado"
            echo "PDB procesados: $pdb_count"
            echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
        } > "$status_file"

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMPLETADO: $dataset"
    else
        local exit_code=$?

        {
            echo
            echo "ERROR: Caretta terminó con código $exit_code"
            echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
        } >> "$log_file"

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $dataset"
        return "$exit_code"
    fi
}

###############################################################################
# Control de procesos paralelos
###############################################################################

echo "============================================================"
echo "Ejecución paralela de Caretta"
echo "Entrada:            $INPUT_ROOT"
echo "Salida:             $OUTPUT_ROOT"
echo "Datasets paralelos: $MAX_PARALLEL_JOBS"
echo "Hilos por dataset:  $THREADS_PER_JOB"
echo "Inicio:             $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

failed_datasets=()

for dataset in "${DATASETS[@]}"; do

    # Esperar mientras se alcance el máximo de procesos simultáneos.
    while (( $(jobs -rp | wc -l) >= MAX_PARALLEL_JOBS )); do
        sleep 2
    done

    run_dataset "$dataset" &
done

# Esperar la finalización de todos los procesos
wait

###############################################################################
# Resumen final
###############################################################################

summary_file="$OUTPUT_ROOT/caretta_execution_summary.tsv"

printf "dataset\tstatus\tpdb_files\toutput_directory\n" > "$summary_file"

completed=0
failed=0
skipped=0

for dataset in "${DATASETS[@]}"; do
    input_dir="$INPUT_ROOT/$dataset"
    output_dir="$OUTPUT_ROOT/$dataset"
    log_file="$OUTPUT_ROOT/logs/${dataset}.log"
    status_file="$output_dir/CARRETTA_SUCCESS"

    if [[ -d "$input_dir" ]]; then
        pdb_count=$(find "$input_dir" -maxdepth 1 -type f \
            \( -iname "*.pdb" -o -iname "*.ent" \) | wc -l)
    else
        pdb_count=0
    fi

    if [[ -f "$status_file" ]]; then
        status="completed"
        ((completed+=1))
    elif [[ ! -d "$input_dir" || "$pdb_count" -lt 2 ]]; then
        status="skipped"
        ((skipped+=1))
    elif [[ -f "$log_file" ]]; then
        status="failed"
        ((failed+=1))
    else
        status="not_executed"
        ((failed+=1))
    fi

    printf "%s\t%s\t%s\t%s\n" \
        "$dataset" \
        "$status" \
        "$pdb_count" \
        "$output_dir" >> "$summary_file"
done

echo
echo "============================================================"
echo "Ejecución terminada"
echo "Completados: $completed"
echo "Fallidos:    $failed"
echo "Omitidos:    $skipped"
echo "Resumen:     $summary_file"
echo "Logs:        $OUTPUT_ROOT/logs"
echo "Fin:         $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi