#!/usr/bin/env bash
set -Eeuo pipefail

JAR="/home/azureuser/TM-MSAStructAligner.jar"
DATA_ROOT="/home/azureuser/Dataset_Structural_GPCRs/GPCRdb"
OUTPUT_ROOT="/home/azureuser/results_tm_m2structalign"

MAX_EVALUATIONS=10000
POPULATION_SIZE=100
NUMBER_OF_CORES=4
OBSERVER_FREQUENCY=200

DATASETS=(
  "classA_001"
  "classA_001_19"
  "classA_002"
  "classA_002_19"
  "classA_003"
  "classA_003_19"
  "classA_004"
  "classA_004_19"
)

SEEDS=(0 21 42 84 126 168 210 252 294 336)

command -v java >/dev/null 2>&1 || { echo "ERROR: Java no está instalado."; exit 1; }
[[ -f "$JAR" ]] || { echo "ERROR: no se encontró $JAR"; exit 1; }
mkdir -p "$OUTPUT_ROOT/logs"

for dataset in "${DATASETS[@]}"; do
  topology_file="$DATA_ROOT/sequences/tmregions/${dataset}_predicted_topologies.3line"
  distance_dir="$DATA_ROOT/distances/$dataset"
  precomputed_dir="$DATA_ROOT/precomputed/$dataset"

  [[ -f "$topology_file" ]] || { echo "Falta $topology_file; se omite $dataset"; continue; }
  [[ -d "$distance_dir" ]] || { echo "Falta $distance_dir; se omite $dataset"; continue; }
  [[ -d "$precomputed_dir" ]] || { echo "Falta $precomputed_dir; se omite $dataset"; continue; }

  fasta_count=$(find "$precomputed_dir" -maxdepth 1 -type f -iname '*.fasta' | wc -l)
  (( fasta_count >= 2 )) || { echo "Menos de 2 FASTA en $precomputed_dir; se omite"; continue; }

  for seed in "${SEEDS[@]}"; do
    run_id=$(printf "seed_%03d" "$seed")
    run_dir="$OUTPUT_ROOT/ejecuciones/$dataset/$run_id"
    log_dir="$OUTPUT_ROOT/logs/$dataset"
    mkdir -p "$log_dir"

    [[ ! -d "$run_dir" ]] || { echo "Ya existe $run_dir; se omite"; continue; }

    echo "Ejecutando $dataset / $run_id"
    set +e
    /usr/bin/time -v -o "$log_dir/${run_id}.time.log"       java -Xms2g -Xmx12g -jar "$JAR"       "$DATA_ROOT" "$dataset" "$MAX_EVALUATIONS" "$POPULATION_SIZE"       "$NUMBER_OF_CORES" "$OBSERVER_FREQUENCY" "$run_id" "$OUTPUT_ROOT" "$seed"       >"$log_dir/${run_id}.out.log"       2>"$log_dir/${run_id}.err.log"
    code=$?
    set -e

    if (( code == 0 )); then
      echo "FINALIZADA: $dataset / $run_id"
    else
      echo "ERROR $code: $dataset / $run_id"
    fi
  done
done

echo "Todas las ejecuciones asignadas finalizaron."
