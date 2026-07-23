
#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="/home/azureuser/Dataset_Structural_GPCRs/GPCRdb/alphafold_pdb"

if [[ ! -d "$BASE_DIR" ]]; then
    echo "ERROR: No existe el directorio:"
    echo "$BASE_DIR"
    exit 1
fi

echo "Generando archivos input_list en:"
echo "$BASE_DIR"
echo

TOTAL_DATASETS=0
TOTAL_PDB=0

for DATASET_DIR in "$BASE_DIR"/*; do

    # Procesar únicamente subcarpetas
    [[ -d "$DATASET_DIR" ]] || continue

    DATASET_NAME="$(basename "$DATASET_DIR")"

    # El archivo queda fuera de la subcarpeta, dentro de alphafold_pdb
    INPUT_LIST="$BASE_DIR/input_list_${DATASET_NAME}.txt"

    # Buscar todos los PDB de la subcarpeta actual
    find "$DATASET_DIR" \
        -maxdepth 1 \
        -type f \
        -iname "*.pdb" \
        -print0 |
        sort -z |
        tr '\0' '\n' > "$INPUT_LIST"

    NUM_PDB=$(wc -l < "$INPUT_LIST")

    if [[ "$NUM_PDB" -gt 0 ]]; then
        echo "[OK] $DATASET_NAME"
        echo "     PDB encontrados: $NUM_PDB"
        echo "     Archivo: $INPUT_LIST"

        TOTAL_DATASETS=$((TOTAL_DATASETS + 1))
        TOTAL_PDB=$((TOTAL_PDB + NUM_PDB))
    else
        echo "[AVISO] $DATASET_NAME no contiene archivos PDB"
        rm -f "$INPUT_LIST"
    fi

    echo
done

echo "============================================"
echo "Datasets procesados: $TOTAL_DATASETS"
echo "Total de archivos PDB: $TOTAL_PDB"
echo "============================================"