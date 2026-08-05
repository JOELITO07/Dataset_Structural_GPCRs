from __future__ import annotations

import csv
import re
from pathlib import Path


# ============================================================
# CONFIGURACIÓN
# ============================================================

FASTA_BASE = Path(
    r"C:\GDrive2026\TM-MSA\Datasets\GPCRdb\sequences\fasta"
)

PDB_BASE = Path(
    r"C:\GDrive2026\TM-MSA\Datasets\GPCRdb\alphafold_pdb"
)

OUTPUT_DIR = Path(
    r"C:\GDrive2026\TM-MSA\Datasets\GPCRdb\missing_pdb_by_family"
)

REPORT_CSV = Path(
    r"C:\GDrive2026\TM-MSA\Datasets\GPCRdb\missing_pdb_report.csv"
)

# Extensiones FASTA aceptadas
FASTA_EXTENSIONS = {".fasta", ".fa", ".fas"}

# Extensiones estructurales aceptadas
PDB_EXTENSIONS = {
    ".pdb"
}

# Si es True, compara ignorando mayúsculas/minúsculas.
CASE_INSENSITIVE = True


# ============================================================
# FUNCIONES
# ============================================================

def normalize_identifier(identifier: str) -> str:
    """
    Normaliza un identificador para poder comparar encabezados FASTA
    con nombres de archivos PDB.

    Ejemplos:
        5ht1a_human              -> 5ht1a_human
        5HT1A_HUMAN              -> 5ht1a_human
        sp|P08908|5HT1A_HUMAN    -> 5ht1a_human
        5ht1a_human.pdb          -> 5ht1a_human
    """
    identifier = identifier.strip()

    # Quitar el símbolo inicial del encabezado FASTA
    identifier = identifier.lstrip(">")

    # Usar solamente el primer campo antes de espacios
    identifier = identifier.split()[0]

    # Si el encabezado tiene formato sp|P08908|5HT1A_HUMAN
    if "|" in identifier:
        parts = identifier.split("|")

        # Preferimos el último elemento, que suele ser el nombre de entrada.
        nonempty_parts = [part for part in parts if part]

        if nonempty_parts:
            identifier = nonempty_parts[-1]

    identifier = Path(identifier).name

    # Quitar extensiones dobles primero
    lower_identifier = identifier.lower()

    for suffix in (
        ".pdb.gz",
        ".cif.gz",
        ".mmcif.gz",
        ".pdb",
        ".cif",
        ".mmcif",
        ".fasta",
        ".fa",
        ".fas",
    ):
        if lower_identifier.endswith(suffix):
            identifier = identifier[: -len(suffix)]
            break

    # Limpiar caracteres poco habituales
    identifier = re.sub(r"[^A-Za-z0-9_.-]+", "_", identifier)
    identifier = identifier.strip("._-")

    if CASE_INSENSITIVE:
        identifier = identifier.lower()

    return identifier


def read_fasta_identifiers(fasta_path: Path) -> list[tuple[str, str]]:
    """
    Devuelve una lista de pares:

        (identificador_original, identificador_normalizado)
    """
    identifiers: list[tuple[str, str]] = []

    with fasta_path.open(
        "r",
        encoding="utf-8-sig",
        errors="replace",
    ) as handle:
        for line in handle:
            line = line.strip()

            if not line.startswith(">"):
                continue

            original_header = line[1:].strip()
            normalized = normalize_identifier(original_header)

            if normalized:
                identifiers.append((original_header, normalized))

    return identifiers


def remove_structural_extension(filename: str) -> str:
    """
    Quita extensiones como .pdb, .pdb.gz, .cif o .mmcif.
    """
    lower_name = filename.lower()

    for suffix in (
        ".pdb.gz",
        ".cif.gz",
        ".mmcif.gz",
        ".pdb",
        ".cif",
        ".mmcif",
    ):
        if lower_name.endswith(suffix):
            return filename[: -len(suffix)]

    return filename


def is_structure_file(path: Path) -> bool:
    """
    Comprueba si un archivo parece una estructura PDB/mmCIF.
    """
    lower_name = path.name.lower()

    return any(
        lower_name.endswith(extension)
        for extension in PDB_EXTENSIONS
    )


def read_pdb_identifiers(
    pdb_dir: Path,
) -> dict[str, list[Path]]:
    """
    Devuelve:

        identificador_normalizado -> lista de archivos encontrados
    """
    structures: dict[str, list[Path]] = {}

    if not pdb_dir.is_dir():
        return structures

    for path in pdb_dir.rglob("*"):
        if not path.is_file():
            continue

        if not is_structure_file(path):
            continue

        base_name = remove_structural_extension(path.name)
        normalized = normalize_identifier(base_name)

        if normalized:
            structures.setdefault(normalized, []).append(path)

    return structures


def main() -> None:
    if not FASTA_BASE.is_dir():
        raise SystemExit(
            f"ERROR: no existe la carpeta FASTA:\n{FASTA_BASE}"
        )

    if not PDB_BASE.is_dir():
        raise SystemExit(
            f"ERROR: no existe la carpeta de PDB:\n{PDB_BASE}"
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_CSV.parent.mkdir(parents=True, exist_ok=True)

    fasta_files = sorted(
        path
        for path in FASTA_BASE.iterdir()
        if path.is_file()
        and path.suffix.lower() in FASTA_EXTENSIONS
    )

    if not fasta_files:
        raise SystemExit(
            f"ERROR: no se encontraron archivos FASTA en:\n{FASTA_BASE}"
        )

    report_rows: list[dict[str, str | int]] = []

    total_families = 0
    total_sequences = 0
    total_present = 0
    total_missing = 0
    total_extra = 0

    print("========================================================")
    print("COMPARACIÓN FASTA vs PDB")
    print("========================================================")
    print(f"FASTA: {FASTA_BASE}")
    print(f"PDB:   {PDB_BASE}")
    print(f"OUT:   {OUTPUT_DIR}")
    print("========================================================")

    for fasta_path in fasta_files:
        family = fasta_path.stem
        pdb_dir = PDB_BASE / family

        total_families += 1

        print()
        print("--------------------------------------------------------")
        print(f"Familia: {family}")
        print(f"FASTA:   {fasta_path}")
        print(f"PDB dir: {pdb_dir}")
        print("--------------------------------------------------------")

        fasta_entries = read_fasta_identifiers(fasta_path)
        pdb_entries = read_pdb_identifiers(pdb_dir)

        fasta_ids = {
            normalized
            for _, normalized in fasta_entries
        }

        pdb_ids = set(pdb_entries.keys())

        missing_ids = sorted(fasta_ids - pdb_ids)
        present_ids = sorted(fasta_ids & pdb_ids)
        extra_ids = sorted(pdb_ids - fasta_ids)

        total_sequences += len(fasta_ids)
        total_present += len(present_ids)
        total_missing += len(missing_ids)
        total_extra += len(extra_ids)

        if not pdb_dir.is_dir():
            family_status = "PDB_FOLDER_MISSING"
            print("[ERROR] No existe la carpeta de la familia.")
        elif missing_ids:
            family_status = "INCOMPLETE"
        else:
            family_status = "COMPLETE"

        print(f"Secuencias en FASTA : {len(fasta_ids)}")
        print(f"PDB encontrados     : {len(pdb_ids)}")
        print(f"Coincidentes        : {len(present_ids)}")
        print(f"PDB faltantes       : {len(missing_ids)}")
        print(f"PDB adicionales     : {len(extra_ids)}")

        original_header_by_id: dict[str, str] = {}

        for original_header, normalized in fasta_entries:
            original_header_by_id.setdefault(
                normalized,
                original_header,
            )

        missing_file = OUTPUT_DIR / f"{family}_missing.txt"

        with missing_file.open(
            "w",
            encoding="utf-8",
        ) as handle:
            for missing_id in missing_ids:
                handle.write(f"{missing_id}\n")

        if missing_ids:
            print("Faltantes:")

            for missing_id in missing_ids:
                print(f"  - {missing_id}")

                report_rows.append(
                    {
                        "dataset": family,
                        "sequence_id": missing_id,
                        "original_fasta_header": (
                            original_header_by_id.get(
                                missing_id,
                                "",
                            )
                        ),
                        "status": "MISSING",
                        "pdb_file": "",
                        "pdb_folder": str(pdb_dir),
                        "family_status": family_status,
                    }
                )
        else:
            print("[OK] No faltan PDB.")

        # Registrar también los presentes
        for present_id in present_ids:
            paths = pdb_entries.get(present_id, [])

            report_rows.append(
                {
                    "dataset": family,
                    "sequence_id": present_id,
                    "original_fasta_header": (
                        original_header_by_id.get(
                            present_id,
                            "",
                        )
                    ),
                    "status": "PRESENT",
                    "pdb_file": " | ".join(
                        str(path) for path in paths
                    ),
                    "pdb_folder": str(pdb_dir),
                    "family_status": family_status,
                }
            )

        # Registrar PDB que no están en el FASTA
        for extra_id in extra_ids:
            paths = pdb_entries.get(extra_id, [])

            report_rows.append(
                {
                    "dataset": family,
                    "sequence_id": extra_id,
                    "original_fasta_header": "",
                    "status": "EXTRA_PDB",
                    "pdb_file": " | ".join(
                        str(path) for path in paths
                    ),
                    "pdb_folder": str(pdb_dir),
                    "family_status": family_status,
                }
            )

    report_columns = [
        "dataset",
        "sequence_id",
        "original_fasta_header",
        "status",
        "pdb_file",
        "pdb_folder",
        "family_status",
    ]

    with REPORT_CSV.open(
        "w",
        encoding="utf-8-sig",
        newline="",
    ) as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=report_columns,
        )

        writer.writeheader()
        writer.writerows(report_rows)

    summary_file = OUTPUT_DIR / "summary_by_family.csv"

    with summary_file.open(
        "w",
        encoding="utf-8-sig",
        newline="",
    ) as handle:
        writer = csv.writer(handle)

        writer.writerow(
            [
                "dataset",
                "fasta_sequences",
                "pdb_identifiers",
                "present",
                "missing",
                "extra_pdb",
                "status",
            ]
        )

        for fasta_path in fasta_files:
            family = fasta_path.stem
            pdb_dir = PDB_BASE / family

            fasta_entries = read_fasta_identifiers(
                fasta_path
            )

            pdb_entries = read_pdb_identifiers(
                pdb_dir
            )

            fasta_ids = {
                normalized
                for _, normalized in fasta_entries
            }

            pdb_ids = set(pdb_entries.keys())

            missing = fasta_ids - pdb_ids
            present = fasta_ids & pdb_ids
            extra = pdb_ids - fasta_ids

            if not pdb_dir.is_dir():
                status = "PDB_FOLDER_MISSING"
            elif missing:
                status = "INCOMPLETE"
            else:
                status = "COMPLETE"

            writer.writerow(
                [
                    family,
                    len(fasta_ids),
                    len(pdb_ids),
                    len(present),
                    len(missing),
                    len(extra),
                    status,
                ]
            )

    print()
    print("========================================================")
    print("FINALIZADO")
    print("========================================================")
    print(f"Familias procesadas : {total_families}")
    print(f"Secuencias FASTA    : {total_sequences}")
    print(f"PDB encontrados     : {total_present}")
    print(f"PDB faltantes       : {total_missing}")
    print(f"PDB adicionales     : {total_extra}")
    print(f"Reporte completo    : {REPORT_CSV}")
    print(f"Resumen por familia : {summary_file}")
    print(f"Listas faltantes    : {OUTPUT_DIR}")
    print("========================================================")


if __name__ == "__main__":
    main()