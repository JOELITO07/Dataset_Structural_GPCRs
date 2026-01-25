import os
import shutil
import csv

# ----------------------------
# RUTAS BASE
# ----------------------------
PDB_DIR = r"D:\Nube\TM-MSA\AlphaFolds2\script\AlphaFold_PDB"
DIST_DIR = r"D:\Nube\TM-MSA\AlphaFolds2\script\distances"
WEIGHT_DIR = r"D:\Nube\TM-MSA\AlphaFolds2\script\weights"

FASTA_CLASSES_DIR = r"D:\Nube\TM-MSA\AlphaFolds2\script\gpcr_sequences"
OUTPUT_DIR = r"D:\Nube\TM-MSA\AlphaFolds2\grouped_files"

CSV_SUMMARY = os.path.join(OUTPUT_DIR, "proteins_by_class.csv")

# ----------------------------
# FUNCIÓN PARA LEER IDS FASTA
# ----------------------------
def read_fasta_ids(fasta_file, limit=20):
    ids = []
    with open(fasta_file, "r") as f:
        for line in f:
            if line.startswith(">"):
                ids.append(line[1:].strip())
                if len(ids) == limit:
                    break
    return ids

# ----------------------------
# CSV GLOBAL
# ----------------------------
os.makedirs(OUTPUT_DIR, exist_ok=True)
csv_rows = []

# ----------------------------
# PROCESAMIENTO PRINCIPAL
# ----------------------------
for fasta_file in os.listdir(FASTA_CLASSES_DIR):
    if not fasta_file.endswith(".fasta"):
        continue

    class_name = os.path.splitext(fasta_file)[0]
    fasta_path = os.path.join(FASTA_CLASSES_DIR, fasta_file)

    print(f"\nProcesando clase: {class_name}")

    protein_ids = read_fasta_ids(fasta_path, limit=20)

    # Crear carpetas de salida
    class_base = os.path.join(OUTPUT_DIR, class_name)
    pdb_out = os.path.join(class_base, "pdb")
    dist_out = os.path.join(class_base, "distance")
    weight_out = os.path.join(class_base, "weight")

    os.makedirs(pdb_out, exist_ok=True)
    os.makedirs(dist_out, exist_ok=True)
    os.makedirs(weight_out, exist_ok=True)

    # Archivo UniProt por clase (para API de alineamiento)
    uniprot_txt = os.path.join(class_base, "uniprot_list.txt")

    with open(uniprot_txt, "w") as f_up:
        f_up.write(",".join(protein_ids))

    # Copiar archivos y llenar CSV
    for pid in protein_ids:
        csv_rows.append([class_name, pid])

        pdb_file = f"{pid}.pdb"
        dist_file = f"{pid}_D.csv"
        weight_file = f"{pid}_W.csv"

        # PDB
        src = os.path.join(PDB_DIR, pdb_file)
        if os.path.exists(src):
            shutil.copy2(src, pdb_out)

        # DISTANCIA
        src = os.path.join(DIST_DIR, dist_file)
        if os.path.exists(src):
            shutil.copy2(src, dist_out)

        # PESOS
        src = os.path.join(WEIGHT_DIR, weight_file)
        if os.path.exists(src):
            shutil.copy2(src, weight_out)

    print(f"✔ Clase {class_name}: {len(protein_ids)} proteínas")

# ----------------------------
# ESCRIBIR CSV GLOBAL
# ----------------------------
with open(CSV_SUMMARY, "w", newline="", encoding="utf-8") as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(["clase", "proteina"])
    writer.writerows(csv_rows)

print("\n✅ Proceso completado")
print(f"📄 CSV generado: {CSV_SUMMARY}")
