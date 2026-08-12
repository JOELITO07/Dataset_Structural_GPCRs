#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="${PROJECT_DIR:-/home/azureuser}"
JAR_FILE="${JAR_FILE:-$PROJECT_DIR/TM-MSAStructAligner.jar}"
EXECUTIONS_DIR="${EXECUTIONS_DIR:-/home/azureuser/results_tm_m2structalign/ejecuciones}"
REFERENCE_DIR="${REFERENCE_DIR:-/home/azureuser/Dataset_Structural_GPCRs/GPCRdb/reference_alignments}"
TOPOLOGY_DIR="${TOPOLOGY_DIR:-/home/azureuser/Dataset_Structural_GPCRs/GPCRdb/sequences/tmregions}"
OUTPUT_DIR="${OUTPUT_DIR:-/home/azureuser/results_tm_m2structalign/evaluation}"

GLOBAL_OUTPUT="${GLOBAL_OUTPUT:-$OUTPUT_DIR/all_datasets_evaluation.csv}"
GLOB="${GLOB:-MSA*.fasta}"
EXPECTED_SEEDS="${EXPECTED_SEEDS:-10}"
JAVA_BIN="${JAVA_BIN:-java}"
MAIN_CLASS="org.tm_msaligner.evaluation.EvaluationMain"

log() {
  printf '%s\n' "$*"
}

error() {
  printf 'ERROR: %s\n' "$*" >&2
}

find_reference() {
  local dataset="$1"
  local candidate

  for candidate in \
    "$REFERENCE_DIR/${dataset}.fasta" \
    "$REFERENCE_DIR/${dataset}.fa" \
    "$REFERENCE_DIR/$dataset/${dataset}.fasta" \
    "$REFERENCE_DIR/$dataset/reference.fasta"
  do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

find_topology() {
  local dataset="$1"
  local candidate

  for candidate in \
    "$TOPOLOGY_DIR/${dataset}_predicted_topologies.3line" \
    "$TOPOLOGY_DIR/$dataset/${dataset}_predicted_topologies.3line" \
    "$TOPOLOGY_DIR/$dataset/predicted_topologies.3line"
  do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

if [[ ! -f "$JAR_FILE" ]]; then
  error "No existe el JAR: $JAR_FILE"
  exit 1
fi

if [[ ! -d "$EXECUTIONS_DIR" ]]; then
  error "No existe EXECUTIONS_DIR: $EXECUTIONS_DIR"
  exit 1
fi

if [[ ! -d "$REFERENCE_DIR" ]]; then
  error "No existe REFERENCE_DIR: $REFERENCE_DIR"
  exit 1
fi

if [[ ! -d "$TOPOLOGY_DIR" ]]; then
  error "No existe TOPOLOGY_DIR: $TOPOLOGY_DIR"
  exit 1
fi

if ! command -v "$JAVA_BIN" >/dev/null 2>&1; then
  error "No se encontro Java: $JAVA_BIN"
  exit 1
fi

mkdir -p "$OUTPUT_DIR/by_dataset"
temporary_global="$(mktemp "$OUTPUT_DIR/.all_datasets_evaluation.XXXXXX")"
trap 'rm -f "$temporary_global"' EXIT

dataset_count=0
success_count=0
failure_count=0
total_msa=0
global_header_written=0

while IFS= read -r -d '' dataset_dir; do
  dataset_count=$((dataset_count + 1))
  dataset="$(basename "$dataset_dir")"

  msa_count="$(find "$dataset_dir" -type f -name "$GLOB" -printf '.' | wc -c)"
  seed_count="$(find "$dataset_dir" -type f -name "$GLOB" -printf '%h\n' | sort -u | wc -l)"

  log ""
  log "============================================================"
  log "Dataset: $dataset"
  log "MSA encontrados: $msa_count | semillas detectadas: $seed_count"

  if [[ "$msa_count" -eq 0 ]]; then
    error "$dataset: no contiene archivos que coincidan con '$GLOB'; se omite."
    failure_count=$((failure_count + 1))
    continue
  fi

  if [[ "$seed_count" -ne "$EXPECTED_SEEDS" ]]; then
    printf 'ADVERTENCIA: %s tiene %s semillas; se esperaban %s. Se evaluaran las disponibles.\n' \
      "$dataset" "$seed_count" "$EXPECTED_SEEDS" >&2
  fi

  if ! reference="$(find_reference "$dataset")"; then
    error "$dataset: no se encontro el MSA de referencia en $REFERENCE_DIR"
    failure_count=$((failure_count + 1))
    continue
  fi

  if ! topology="$(find_topology "$dataset")"; then
    error "$dataset: no se encontro la topologia .3line en $TOPOLOGY_DIR"
    failure_count=$((failure_count + 1))
    continue
  fi

  dataset_output="$OUTPUT_DIR/by_dataset/${dataset}_evaluation.csv"

  if "$JAVA_BIN" -cp "$JAR_FILE" "$MAIN_CLASS" \
      --reference "$reference" \
      --topology "$topology" \
      --msa-root "$dataset_dir" \
      --output "$dataset_output" \
      --glob "$GLOB"
  then
    dataset_csv="${dataset//\"/\"\"}"

    if [[ "$global_header_written" -eq 0 ]]; then
      awk -v dataset="$dataset_csv" '
        NR == 1 { print "\"dataset\"," $0; next }
        { print "\"" dataset "\"," $0 }
      ' "$dataset_output" > "$temporary_global"
      global_header_written=1
    else
      awk -v dataset="$dataset_csv" '
        NR > 1 { print "\"" dataset "\"," $0 }
      ' "$dataset_output" >> "$temporary_global"
    fi

    success_count=$((success_count + 1))
    total_msa=$((total_msa + msa_count))
  else
    error "$dataset: EvaluationMain termino con error."
    failure_count=$((failure_count + 1))
  fi
done < <(find "$EXECUTIONS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

if [[ "$dataset_count" -eq 0 ]]; then
  error "No se encontraron carpetas de datasets dentro de $EXECUTIONS_DIR"
  exit 1
fi

if [[ "$success_count" -eq 0 ]]; then
  error "No se pudo evaluar ningun dataset."
  exit 1
fi

mv -f "$temporary_global" "$GLOBAL_OUTPUT"
trap - EXIT

log ""
log "============================================================"
log "Evaluacion terminada"
log "Datasets encontrados: $dataset_count"
log "Datasets evaluados:   $success_count"
log "Datasets con error:   $failure_count"
log "MSA evaluados:        $total_msa"
log "CSV global:           $GLOBAL_OUTPUT"
log "CSV por dataset:      $OUTPUT_DIR/by_dataset"

if [[ "$failure_count" -gt 0 ]]; then
  exit 1
fi