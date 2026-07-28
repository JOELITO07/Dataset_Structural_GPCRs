#!/usr/bin/env bash

BASE="$HOME/results_tm_m2structalign/ejecuciones"
REF_BASE="$HOME/Dataset_Structural_GPCRs/GPCRdb/reference_alignments"
BALI="bali_score"

# Archivo CSV de salida
OUT="$BASE/baliscore_results.csv"

# Cabecera
echo "dataset,seed,file,SP,TC" > "$OUT"

for dir in "$BASE"/*; do

    [ -d "$dir" ] || continue

    dataset=$(basename "$dir")
    ref="$REF_BASE/${dataset}.msf"

    echo "$dataset"

    cd "$dir" || continue

    if [ ! -f "$ref" ]; then
        echo "ERROR: no existe referencia para $dataset"
        cd "$BASE" || exit 1
        continue
    fi

    for seed in *; do

        [ -d "$seed" ] || continue

        echo "$seed"

        cd "$seed" || continue

        for path in *.msf; do

            [ -f "$path" ] || continue

            i=$(basename "$path")

            # BALiScore devuelve:
            # MSASol0.msf 0.784 0.650

            result=$("$BALI" "$ref" "$path")

            # Mostrar también en pantalla/log
            echo "$result"

            # Extraer:
            # nombre SP TC
            read -r filename sp tc <<< "$result"

            # Guardar CSV
            echo "$dataset,$seed,$i,$sp,$tc" >> "$OUT"

        done

        cd ..

    done

    cd ..

done

echo "Finalizado."
echo "CSV generado en:"
echo "$OUT"