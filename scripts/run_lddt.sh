#!/usr/bin/env bash

BASE="$HOME/results_tm_m2structalign/ejecuciones"
DB_BASE="$HOME/foldmason_lddt/db"

OUT="$HOME/lddt_tm_m2structalign_servidor3.csv"

echo "dataset,seed,file,LDDT" > "$OUT"

for dataset_dir in "$BASE"/*; do

    [ -d "$dataset_dir" ] || continue

    dataset=$(basename "$dataset_dir")
    db="$DB_BASE/$dataset"

    echo "========================================"
    echo "Dataset: $dataset"
    echo "========================================"

    # FoldMason DB consta de varios archivos, por eso comprobamos
    # que exista al menos algo con ese prefijo.
    if ! compgen -G "${db}*" > /dev/null; then
        echo "ERROR: DB no encontrada para $dataset"
        continue
    fi

    for seed_dir in "$dataset_dir"/*; do

        [ -d "$seed_dir" ] || continue

        seed=$(basename "$seed_dir")

        echo "Seed: $seed"

        for msa in "$seed_dir"/*.fasta; do

            [ -f "$msa" ] || continue

            file=$(basename "$msa")

            echo "  Procesando $file"

            result=$(foldmason msa2lddt "$db"  "$msa" --threads 4 --only-scoring-cols 0  2>&1)
	    status=$?
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

	    if [ "$status" -eq 0 ] && [[ "$lddt" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    		echo "$dataset,$seed,$file,$lddt" >> "$OUT"
    		echo "    LDDT=$lddt"

	   else
	    	echo "    ERROR: no se obtuvo LDDT"
    		echo "    DB:  $db"
    		echo "    MSA: $msa"
    		echo "    Código de salida: $status"

    		# Mostrar solo las líneas importantes, no todos los Column scores
    		printf '%s\n' "$result" |
        		grep -E "Average MSA LDDT|Columns considered|Invalid database|Error|ERROR" |
        		head -20
	fi

        done

    done

done

echo
echo "========================================"
echo "FINALIZADO"
echo "CSV: $OUT"
echo "========================================"