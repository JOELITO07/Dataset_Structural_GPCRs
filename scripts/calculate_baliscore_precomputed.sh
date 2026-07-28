#!/usr/bin/env bash

BASE="$HOME/Dataset_Structural_GPCRs/GPCRdb/precomputed"
REF_BASE="$HOME/Dataset_Structural_GPCRs/GPCRdb/reference_alignments"
BALI="bali_score"

for dir in "$BASE"/*; do

    [ -d "$dir" ] || continue

    dataset=$(basename "$dir")

    ref="$REF_BASE/${dataset}.msf"

    cd "$dir"

    echo "$dataset"

    if [ ! -f "$ref" ]; then
        echo "ERROR: no existe referencia para $dataset"
        continue
    fi

    for path in *.msf; do

         # solo nombre del fichero
        i=$(basename "$path")

        "$BALI" "$ref" "$path"
       
    done
    cd ..
done

echo
echo "Finalizado."