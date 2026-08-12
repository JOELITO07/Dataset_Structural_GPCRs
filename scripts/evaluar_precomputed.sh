#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="${PROJECT_DIR:-/home/azureuser}"
JAR_FILE="${JAR_FILE:-$PROJECT_DIR/target/TM-MSAStructAligner.jar}"

PRECOMPUTED_DIR="${PRECOMPUTED_DIR:-/home/azureuser/Dataset_Structural_GPCRs/GPCRdb/precomputed}"
REFERENCE_DIR="${REFERENCE_DIR:-/home/azureuser/Dataset_Structural_GPCRs/GPCRdb/reference_alignments}"
TOPOLOGY_DIR="${TOPOLOGY_DIR:-/home/azureuser/Dataset_Structural_GPCRs/GPCRdb/sequences/tmregions}"
OUTPUT_DIR="${OUTPUT_DIR:-/home/azureuser/results_tm_m2structalign/evaluation_precomputed}"

GLOBAL_OUTPUT="${GLOBAL_OUTPUT:-$OUTPUT_DIR/all_precomputed_evaluation.csv}"
GLOB="${GLOB:-*.fasta}"
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

software_from_filename() {
  local dataset="$1"
  local filename="$2"
  local stem

  stem="${filename%.*}"

  # caretta_classA_001.fasta -> caretta
  # mtm_align_classA_001.fasta -> mtm_align
  if [[ "$stem" == *"_${dataset}" ]]; then
    printf '%s\n' "${stem%_${dataset}}"
  else
    printf '%s\n' "$stem"
  fi
}

if [[ ! -f "$JAR_FILE" ]]; then
  error "No existe el JAR: $JAR_FILE"
  exit 1
fi

if [[ ! -d "$PRECOMPUTED_DIR" ]]; then
  error "No existe PRECOMPUTED_DIR: $PRECOMPUTED_DIR"
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

# Un JAR generado antes de incorporar el paquete evaluation no contiene esta
# clase. Esta verificacion produce un mensaje claro antes de procesar datasets.
if command -v jar >/dev/null 2>&1; then
  if ! jar tf "$JAR_FILE" | grep -qx 'org/tm_msaligner/evaluation/EvaluationMain.class'; then
    error "El JAR no contiene $MAIN_CLASS"
    error "Vuelve a generar el JAR desde la version actual de la rama main."
    exit 1
  fi
fi

mkdir -p "$OUTPUT_DIR/by_dataset"

temporary_global="$(mktemp "$OUTPUT_DIR/.all_precomputed_evaluation.XXXXXX")"
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

  log ""
  log "============================================================"
  log "Dataset: $dataset"
  log "MSA precomputed encontrados: $msa_count"

  if [[ "$msa_count" -eq 0 ]]; then
    error "$dataset: no contiene archivos que coincidan con '$GLOB'; se omite."
    failure_count=$((failure_count + 1))
    continue
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
    # Agrega dataset y software al CSV global. La tercera columna original
    # (msa_file) contiene el nombre usado para identificar el software.
    if [[ "$global_header_written" -eq 0 ]]; then
      printf '%s\n' '"dataset","software",relative_path,run_id,msa_file,sequence_count,pair_precision,pair_recall,pair_f1,tm_pair_precision,tm_pair_recall,tm_pair_f1,tm_gap_rate,reference_pairs,test_pairs,correct_pairs,reference_tm_pairs,test_tm_pairs,correct_tm_pairs,tm_gap_count,tm_gap_opportunities' \
        > "$temporary_global"
      global_header_written=1
    fi

    while IFS= read -r csv_row; do
      msa_file="$(printf '%s\n' "$csv_row" | awk -F',' '{value=$3; gsub(/^\"|\"$/, "", value); gsub(/\"\"/, "\"", value); print value}')"
      software="$(software_from_filename "$dataset" "$msa_file")"
      dataset_csv="${dataset//\"/\"\"}"
      software_csv="${software//\"/\"\"}"
      printf '"%s","%s",%s\n' "$dataset_csv" "$software_csv" "$csv_row" \
        >> "$temporary_global"
    done < <(tail -n +2 "$dataset_output")

    success_count=$((success_count + 1))
    total_msa=$((total_msa + msa_count))
  else
    error "$dataset: EvaluationMain termino con error."
    failure_count=$((failure_count + 1))
  fi
done < <(find "$PRECOMPUTED_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

if [[ "$dataset_count" -eq 0 ]]; then
  error "No se encontraron carpetas de datasets dentro de $PRECOMPUTED_DIR"
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
log "Evaluacion precomputed terminada"
log "Datasets encontrados: $dataset_count"
log "Datasets evaluados:   $success_count"
log "Datasets con error:   $failure_count"
log "MSA evaluados:        $total_msa"
log "CSV global:           $GLOBAL_OUTPUT"
log "CSV por dataset:      $OUTPUT_DIR/by_dataset"

if [[ "$failure_count" -gt 0 ]]; then
  exit 1
fi