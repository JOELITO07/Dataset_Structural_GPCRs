#!/usr/bin/env bash

set -u
set -o pipefail

# Directorio que contiene las carpetas de los datasets
BASE_DIR="${1:-/home/azureuser/Dataset_Structural_GPCRs/GPCRdb/precomputed}"

LOG_FILE="${BASE_DIR}/limpieza_usalign.log"
ERROR_LOG="${BASE_DIR}/limpieza_usalign_errors.log"

procesados=0
correctos=0
errores=0

: > "$LOG_FILE"
: > "$ERROR_LOG"

if [[ ! -d "$BASE_DIR" ]]; then
    echo "ERROR: no existe el directorio:"
    echo "$BASE_DIR"
    exit 1
fi

limpiar_usalign() {
    local input="$1"
    local directory
    local filename
    local base
    local output
    local temporal
    local status
    local sequences
    local lengths

    directory="$(dirname "$input")"
    filename="$(basename "$input")"
    base="${filename%.*}"
    output="${directory}/${base}_clean.fasta"
    temporal="$(mktemp --suffix=.fasta)"

    echo "Procesando: $input"
    echo "Salida:     $output"

    awk '
        BEGIN {
            esperando_secuencia = 0
            numero_secuencias = 0
            errores = 0
        }

        {
            # Eliminar retorno de carro de Windows
            gsub(/\r/, "", $0)
        }

        # Encabezado descriptivo de US-align:
        # > ccr10_human.pdb:A L=362 d0=... TM-score=...
        /^[[:space:]]*>[[:space:]]*[^-[:space:]\\][^[:space:]]*[[:space:]]+L=/ {
            header = $0

            sub(/^[[:space:]]*>[[:space:]\\]*/, "", header)
            sub(/[[:space:]].*$/, "", header)
            gsub(/\\/, "", header)

            # Eliminar identificador de cadena
            sub(/:[A-Za-z0-9]+$/, "", header)

            # Eliminar extensión de estructura
            sub(/\.(pdb|ent|cif|mmcif)$/, "", header)

            if (header == "") {
                print "ERROR: encabezado vacío en línea " NR \
                    > "/dev/stderr"
                errores++
                esperando_secuencia = 0
                next
            }

            print ">" header
            numero_secuencias++
            esperando_secuencia = 1
            next
        }

        # Línea de secuencia de US-align:
        # > \-----MGTEATEQ...
        /^[[:space:]]*>/ && esperando_secuencia {
            sequence = $0

            sub(/^[[:space:]]*>[[:space:]\\]*/, "", sequence)
            gsub(/[[:space:]\\]/, "", sequence)

            # El asterisco aislado de US-align no forma parte de la secuencia
            sub(/\*$/, "", sequence)

            if (sequence == "") {
                print "ERROR: secuencia vacía en línea " NR \
                    > "/dev/stderr"
                errores++
                esperando_secuencia = 0
                next
            }

            if (sequence !~ /^[A-Za-z*-]+$/) {
                print "ERROR: caracteres inválidos en línea " NR \
                    ": " sequence > "/dev/stderr"
                errores++
                esperando_secuencia = 0
                next
            }

            print toupper(sequence)
            esperando_secuencia = 0
            next
        }

        # Aceptar también secuencias sin el símbolo >
        esperando_secuencia {
            sequence = $0
            gsub(/[[:space:]\\]/, "", sequence)
            sub(/\*$/, "", sequence)

            if (sequence ~ /^[A-Za-z*-]+$/ && sequence != "") {
                print toupper(sequence)
                esperando_secuencia = 0
            }
            next
        }

        END {
            if (numero_secuencias == 0) {
                print "ERROR: no se encontraron registros de US-align" \
                    > "/dev/stderr"
                exit 1
            }

            if (esperando_secuencia) {
                print "ERROR: el último encabezado no tiene secuencia" \
                    > "/dev/stderr"
                errores++
            }

            if (errores > 0) {
                exit 1
            }
        }
    ' "$input" > "$temporal"

    status=$?

    if [[ "$status" -ne 0 ]]; then
        echo "[ERROR] No se pudo limpiar: $input"
        echo "$input" >> "$ERROR_LOG"
        rm -f "$temporal"
        return 1
    fi

    sequences="$(grep -c '^>' "$temporal")"

    if [[ "$sequences" -eq 0 ]]; then
        echo "[ERROR] El resultado no contiene secuencias"
        echo "$input: resultado vacío" >> "$ERROR_LOG"
        rm -f "$temporal"
        return 1
    fi

    # Comprobar que cada encabezado tenga exactamente una secuencia
    if ! awk '
        /^>/ {
            if (seen_header && sequence == "")
                exit 1

            seen_header = 1
            sequence = ""
            next
        }

        {
            sequence = sequence $0
        }

        END {
            if (!seen_header || sequence == "")
                exit 1
        }
    ' "$temporal"; then
        echo "[ERROR] Hay encabezados sin secuencia"
        echo "$input: encabezado sin secuencia" >> "$ERROR_LOG"
        rm -f "$temporal"
        return 1
    fi

    # Todas las secuencias de un MSA deben tener la misma longitud
    lengths="$(
        awk '
            /^>/ {
                if (header != "")
                    print length(sequence)

                header = substr($0, 2)
                sequence = ""
                next
            }

            {
                sequence = sequence $0
            }

            END {
                if (header != "")
                    print length(sequence)
            }
        ' "$temporal" |
        sort -nu |
        wc -l
    )"

    if [[ "$lengths" -ne 1 ]]; then
        echo "[ERROR] Las secuencias no tienen la misma longitud"
        echo "$input: longitudes diferentes" >> "$ERROR_LOG"

        awk '
            /^>/ {
                if (header != "")
                    print header, length(sequence)

                header = substr($0, 2)
                sequence = ""
                next
            }

            {
                sequence = sequence $0
            }

            END {
                if (header != "")
                    print header, length(sequence)
            }
        ' "$temporal" >> "$ERROR_LOG"

        rm -f "$temporal"
        return 1
    fi

    mv "$temporal" "$output"

    echo "[OK] $sequences secuencias"
    echo "$input -> $output" >> "$LOG_FILE"

    return 0
}

echo "======================================================"
echo "LIMPIEZA DE ALINEAMIENTOS US-ALIGN"
echo "Directorio: $BASE_DIR"
echo "======================================================"

while IFS= read -r -d '' msa; do
    procesados=$((procesados + 1))

    if limpiar_usalign "$msa"; then
        correctos=$((correctos + 1))
    else
        errores=$((errores + 1))
    fi

    echo
done < <(
    find "$BASE_DIR" \
        -type f \
        \( \
            -iname 'usalign_*.fasta' -o \
            -iname 'usalign_*.fa' -o \
            -iname 'usalign_*.fas' -o \
            -iname 'usalign_*.aln' \
        \) \
        ! -iname '*_clean.fasta' \
        ! -iname '*_clean.fa' \
        ! -iname '*_clean.fas' \
        ! -iname '*_clean.aln' \
        -print0
)

echo "======================================================"
echo "FINALIZADO"
echo "======================================================"
echo "Archivos encontrados : $procesados"
echo "Limpiados             : $correctos"
echo "Con errores           : $errores"
echo "Registro              : $LOG_FILE"
echo "Errores               : $ERROR_LOG"
echo "======================================================"

if [[ "$procesados" -eq 0 ]]; then
    echo "ADVERTENCIA: no se encontraron archivos usalign_*"
    exit 2
fi

if [[ "$errores" -gt 0 ]]; then
    exit 1
fi

exit 0