#!/usr/bin/env bash

BASE="$HOME/Dataset_Structural_GPCRs/GPCRdb/precomputed"
REF_BASE="$HOME/Dataset_Structural_GPCRs/GPCRdb/reference_alignments"
BALI="bali_score"

OUT="$HOME/baliscore_results_precomputed.csv"

echo "dataset,software,SP,TC" > "$OUT"

for dir in "$BASE"/*; do

    [ -d "$dir" ] || continue

    dataset=$(basename "$dir")
    ref="$REF_BASE/${dataset}.msf"

    echo "Dataset: $dataset"

    if [ ! -f "$ref" ]; then
        echo "ERROR: no existe referencia: $ref"
        continue
    fi

    for path in "$dir"/*.msf; do

        [ -f "$path" ] || continue

        fichero=$(basename "$path")

        # Quitar "_<dataset>.msf"
        # Ejemplo:
        # foldmason_classA_001.msf -> foldmason
        software="${fichero%_${dataset}.msf}"

        result=$("$BALI" "$ref" "$path" 2>&1)

        # Salida esperada:
        # foldmason_classA_001.msf 0.773 0.580
        read -r bali_file sp tc <<< "$result"

        if [[ -n "$sp" && -n "$tc" ]]; then

            echo "$dataset,$software,$sp,$tc" >> "$OUT"

            echo "  $software SP=$sp TC=$tc"

        else

            echo "  ERROR procesando: $fichero"
            echo "  Salida BALiScore: $result"

        fi

    done

done

echo
echo "========================================"
echo "Finalizado"
echo "CSV: $OUT"
echo "========================================"