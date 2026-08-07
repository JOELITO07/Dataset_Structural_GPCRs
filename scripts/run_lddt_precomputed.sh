#!/usr/bin/env bash

set -u

PRECOMP_BASE="$HOME/Dataset_Structural_GPCRs/GPCRdb/precomputed"
DB_BASE="$HOME/foldmason_lddt/db"

OUT="$HOME/lddt_precomputed.csv"

THREADS=4

echo "dataset,software,LDDT" > "$OUT"

echo "======================================================"
echo "LDDT PRECOMPUTED"
echo "Precomputed: $PRECOMP_BASE"
echo "DB:          $DB_BASE"
echo "CSV:         $OUT"
echo "======================================================"

total=0
ok=0
failed=0

for dataset_dir in "$PRECOMP_BASE"/*; do

    [ -d "$dataset_dir" ] || continue

    dataset=$(basename "$dataset_dir")
    db="$DB_BASE/$dataset"

    echo
    echo "======================================================"
    echo "Dataset: $dataset"
    echo "======================================================"

    # Comprobar DB
    if ! compgen -G "${db}*" > /dev/null; then
        echo "[SKIP] No existe DB FoldMason para $dataset"
        continue
    fi

    for msa in "$dataset_dir"/*.fasta \
               "$dataset_dir"/*.fa \
               "$dataset_dir"/*.fas; do

        [ -f "$msa" ] || continue

        total=$((total + 1))

        filename=$(basename "$msa")

        # Quitar extensión
        name="${filename%.*}"

        # Quitar _dataset del final
        # Ejemplo:
        # foldmason_classA_001.fasta -> foldmason
        software="${name%_${dataset}}"

        echo "Procesando: $dataset / $software"


	msa_foldmason="$(mktemp --suffix=.fasta)"

	sed '/^>/ s/\.\(pdb\|ent\|cif\|mmcif\)\r*$//' \
	    "$msa" > "$msa_foldmason"

	result="$(
	    foldmason msa2lddt \
        	"$db" \
	        "$msa_foldmason" \
        	--threads "$THREADS" \
	        --only-scoring-cols 0 \
	        2>&1
	)"
	
	status=$?
	rm -f "$msa_foldmason"

        if [ "$status" -ne 0 ]; then
            echo "  [ERROR] FoldMason terminó con código $status"
            failed=$((failed + 1))
            continue
        fi

 	lddt=$(
		 printf '%s\n' "$result" |
		 tr -d '\r' |
		 awk '
		        /Average MSA LDDT:/ {
		        value = $0
            		sub(/^.*Average MSA LDDT:[[:space:]]*/, "", value)
            		gsub(/[[:space:]]/, "", value)
            		print value
            		exit
		        }
		    '
		)

        if [[ "$lddt" =~ ^[0-9]+([.][0-9]+)?$ ]]; then

            echo "$dataset,$software,$lddt" >> "$OUT"

            echo "  [OK] LDDT=$lddt"

            ok=$((ok + 1))

        else

            echo "  [ERROR] No se pudo extraer Average MSA LDDT"
            failed=$((failed + 1))

        fi

    done

done

echo
echo "======================================================"
echo "FINALIZADO"
echo "======================================================"
echo "Procesados correctamente : $ok"
echo "Con error                 : $failed"
echo "Total intentados          : $total"
echo "CSV: $OUT"
echo "======================================================"