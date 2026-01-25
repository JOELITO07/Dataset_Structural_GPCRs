import requests
import os
import csv

# =========================
# Configuración
# =========================
BASE_URL = "https://gpcrdb.org/services/proteinfamily/proteins"
SPECIES = "Homo sapiens"

OUTPUT_DIR = "gpcr_sequences"
FASTA_DIR = os.path.join(OUTPUT_DIR, "fasta")
SUMMARY_FILE = os.path.join(OUTPUT_DIR, "dataset_summary.csv")

os.makedirs(FASTA_DIR, exist_ok=True)

# =========================
# Subclases a descargar
# (ajusta si deseas excluir alguna)
# =========================
SUBCLASSES = {
    "001": [
        "001_001", "001_002", "001_003", "001_004"
    ],
    "002": ["002"],
    "003": ["003"],
    "004": ["004"],
    "006": ["006"],
    "009": ["009"]
}

# =========================
# Función de descarga
# =========================
def download_subclass(slug, species):
    url = f"{BASE_URL}/{slug}/{species.replace(' ', '%20')}/"
    response = requests.get(url)
    response.raise_for_status()
    return response.json()

# =========================
# Proceso principal
# =========================
summary_rows = []

for class_slug, subclasses in SUBCLASSES.items():
    for sub_slug in subclasses:
        print(f"Descargando subclase {sub_slug} ({SPECIES})")

        proteins = download_subclass(sub_slug, SPECIES)

        fasta_path = os.path.join(FASTA_DIR, f"{sub_slug}.fasta")
        lengths = []

        with open(fasta_path, "w") as fasta_file:
            for p in proteins:
                entry_name = p["entry_name"]
                sequence = p["sequence"]

                fasta_file.write(f">{entry_name}\n")
                fasta_file.write(f"{sequence}\n")

                lengths.append(len(sequence))

        if lengths:
            summary_rows.append({
                "class": class_slug,
                "subclass": sub_slug,
                "num_sequences": len(lengths),
                "min_length": min(lengths),
                "max_length": max(lengths)
            })
        else:
            summary_rows.append({
                "class": class_slug,
                "subclass": sub_slug,
                "num_sequences": 0,
                "min_length": 0,
                "max_length": 0
            })

# =========================
# Guardar tabla resumen
# =========================
with open(SUMMARY_FILE, "w", newline="") as csvfile:
    fieldnames = ["class", "subclass", "num_sequences", "min_length", "max_length"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    for row in summary_rows:
        writer.writerow(row)

print("✔ Descarga completa")
print(f"✔ FASTA en: {FASTA_DIR}")
print(f"✔ Resumen en: {SUMMARY_FILE}")
