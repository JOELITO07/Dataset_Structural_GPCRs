import os
import csv
import json
import requests

# === CONFIGURACIÓN ===
INPUT_FILE = "adhesion_gpcr_human_33.csv"   # o "gpcr_list.json"
OUTPUT_PDB = "AlphaFold_PDB"
OUTPUT_JSON = "AlphaFold_JSON"
DOWNLOAD_JSON = True  # Cambia a False si no quieres bajar los archivos .json

os.makedirs(OUTPUT_PDB, exist_ok=True)
os.makedirs(OUTPUT_JSON, exist_ok=True)

def download_file(url, output_path):
    """Descarga un archivo desde una URL y lo guarda localmente."""
    try:
        r = requests.get(url, timeout=15)
        if r.status_code == 200:
            with open(output_path, "wb") as f:
                f.write(r.content)
            print(f"✅ Guardado: {output_path}")
        elif r.status_code == 404:
            print(f"⚠️ No encontrado: {url}")
        else:
            print(f"❌ Error {r.status_code} en {url}")
    except Exception as e:
        print(f"⚠️ Error al descargar {url}: {e}")

def process_entry(name, uniprot_id):
    """Descarga los archivos PDB (y JSON si aplica) para un UniProt ID."""
    pdb_url = f"https://alphafold.ebi.ac.uk/files/AF-{uniprot_id}-F1-model_v6.pdb"
    json_url = f"https://alphafold.ebi.ac.uk/files/AF-{uniprot_id}-F1-predicted_aligned_error_v6.json"
    download_file(pdb_url, os.path.join(OUTPUT_PDB, f"{name.lower()}.pdb"))
    if DOWNLOAD_JSON:
        download_file(json_url, os.path.join(OUTPUT_JSON, f"{name.lower()}.json"))

# === LECTURA DEL ARCHIVO ===
if INPUT_FILE.endswith(".csv"):
    with open(INPUT_FILE, newline='', encoding="utf-8") as csvfile:
        reader = csv.DictReader(csvfile, delimiter=';')
        for row in reader:
            # Extrae el UniProt ID de la columna correspondiente
            for key in row.keys():
                if "uniprot" in key.lower():
                    uniprot_id = row[key]
                    break
            else:
                continue  # si no hay columna UniProt, pasa a la siguiente fila

            raw_entry = row.get("Name", "").strip()

            # Maneja tanto formatos 'sp|ID|NAME' como nombres simples
            if "|" in raw_entry:
                parts = raw_entry.split("|")
                uniprot_id = parts[1] if len(parts) > 1 else uniprot_id
                protein_name = parts[2].lower() if len(parts) > 2 else parts[-1].lower()
            else:
                protein_name = raw_entry.lower() if raw_entry else uniprot_id.lower()

            if uniprot_id:
                print(f"Descargando {protein_name} ({uniprot_id})")
                process_entry(protein_name, uniprot_id)
else:
    print("❌ El archivo no es CSV. Usa un archivo con extensión .csv o .json.")

