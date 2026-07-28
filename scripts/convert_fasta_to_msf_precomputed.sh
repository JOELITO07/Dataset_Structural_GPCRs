#!/usr/bin/env bash

set -u

BASE_DIR="$HOME/Dataset_Structural_GPCRs/GPCRdb/precomputed"

if ! command -v mview >/dev/null 2>&1; then
    echo "ERROR: mview no está disponible en el PATH."
    echo "Comprueba con: which mview"
    exit 1
fi

if [ ! -d "$BASE_DIR" ]; then
    echo "ERROR: no existe el directorio:"
    echo "$BASE_DIR"
    exit 1
fi

echo "======================================================"
echo "Convirtiendo FASTA -> MSF"
echo "Directorio base: $BASE_DIR"
echo "======================================================"

total=0
ok=0
failed=0

while IFS= read -r -d '' fasta; do

    # mismo nombre y misma carpeta
    msf="${fasta%.*}.msf"

    echo
    echo "FASTA: $fasta"
    echo "MSF  : $msf"

    total=$((total + 1))

    if mview \
        -in fasta \
        -out msf \
        "$fasta" \
        > "$msf"; then

        # comprobar que realmente generó contenido
        if [ -s "$msf" ]; then
            echo "[OK]"
            ok=$((ok + 1))
        else
            echo "[ERROR] Archivo MSF vacío."
            rm -f "$msf"
            failed=$((failed + 1))
        fi

    else
        echo "[ERROR] Falló la conversión."
        rm -f "$msf"
        failed=$((failed + 1))
    fi

done < <(
    find "$BASE_DIR" \
        -type f \
        \( -iname "*.fasta" -o -iname "*.fa" -o -iname "*.fas" \) \
        -print0
)

echo
echo "======================================================"
echo "FINALIZADO"
echo "======================================================"
echo "FASTA encontrados : $total"
echo "Convertidos       : $ok"
echo "Errores            : $failed"
echo "======================================================"