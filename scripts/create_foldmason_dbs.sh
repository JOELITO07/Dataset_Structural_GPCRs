#!/usr/bin/env bash

set -u

# Carpetas de datasets que realmente existen en este servidor
EXEC_BASE="$HOME/results_tm_m2structalign/ejecuciones"

# PDB AlphaFold organizados por dataset
PDB_BASE="$HOME/Dataset_Structural_GPCRs/GPCRdb/alphafold_pdb"

# Destino de las DB de FoldMason
DB_BASE="$HOME/foldmason_lddt/db"

THREADS=4

mkdir -p "$DB_BASE"

echo "======================================================"
echo "Creación de bases estructurales FoldMason"
echo "Datasets: $EXEC_BASE"
echo "PDB:      $PDB_BASE"
echo "DB:       $DB_BASE"
echo "======================================================"

total=0
created=0
skipped=0
failed=0

for dataset_dir in "$PDB_BASE"/*; do

    [ -d "$dataset_dir" ] || continue

    dataset=$(basename "$dataset_dir")

    pdb_dir="$PDB_BASE/$dataset"
    db="$DB_BASE/$dataset"

    total=$((total + 1))

    echo
    echo "======================================================"
    echo "Dataset: $dataset"
    echo "PDB:     $pdb_dir"
    echo "DB:      $db"
    echo "======================================================"

    # Comprobar que existe la carpeta de PDB
    if [ ! -d "$pdb_dir" ]; then
        echo "[ERROR] No existe carpeta PDB:"
        echo "        $pdb_dir"
        failed=$((failed + 1))
        continue
    fi

    # Comprobar que realmente contiene PDB
    pdb_count=$(find "$pdb_dir" -type f \
        \( -iname "*.pdb" -o -iname "*.pdb.gz" \
           -o -iname "*.cif" -o -iname "*.cif.gz" \) \
        | wc -l)

    if [ "$pdb_count" -eq 0 ]; then
        echo "[ERROR] No se encontraron estructuras en $pdb_dir"
        failed=$((failed + 1))
        continue
    fi

    echo "Estructuras encontradas: $pdb_count"

    # Si ya existe la DB, no volver a crearla
    if compgen -G "${db}*" > /dev/null; then
        echo "[SKIP] La DB ya existe para $dataset"
        skipped=$((skipped + 1))
        continue
    fi

    echo "Creando DB..."

    if foldmason createdb \
        "$pdb_dir" \
        "$db" \
        --threads "$THREADS"; then

        echo "[OK] DB creada: $dataset"
        created=$((created + 1))

    else

        echo "[ERROR] Falló createdb para $dataset"

        # Limpiar archivos parciales
        rm -f "${db}"*

        failed=$((failed + 1))
    fi

done

echo
echo "======================================================"
echo "FINALIZADO"
echo "======================================================"
echo "Datasets encontrados : $total"
echo "DB creadas           : $created"
echo "DB existentes        : $skipped"
echo "Errores               : $failed"
echo "======================================================"