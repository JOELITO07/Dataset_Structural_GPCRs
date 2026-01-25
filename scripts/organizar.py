import os
import shutil

# ----------------------------
# RUTAS
# ----------------------------
FASTA_DIR = r"D:\Nube\TM-MSA\Datasets\GPCRdb\sequences\fasta"

PDB_DIR = r"D:\Nube\TM-MSA\AlphaFolds2\script\AlphaFold_PDB"
JSON_DIR = r"D:\Nube\TM-MSA\AlphaFolds2\script\AlphaFold_JSON"
DIST_DIR = r"D:\Nube\TM-MSA\AlphaFolds2\script\distance"
WEIGHT_DIR = r"D:\Nube\TM-MSA\AlphaFolds2\script\weights"

OUTPUT_DIR = r"D:\Nube\TM-MSA\Datasets\GPCRdb"

# ----------------------------
# LEER IDS DESDE FASTA
# ----------------------------
def read_fasta_ids(fasta_file):
    ids = []
    with open(fasta_file, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith(">"):
                ids.append(line[1:].strip())
    return ids

# ----------------------------
# PROCESAMIENTO PRINCIPAL
# ----------------------------
for fasta_file in os.listdir(FASTA_DIR):
    if not fasta_file.endswith(".fasta"):
        continue

    class_name = os.path.splitext(fasta_file)[0]
    fasta_path = os.path.join(FASTA_DIR, fasta_file)

    print(f"\n📂 Procesando clase: {class_name}")

    protein_ids = read_fasta_ids(fasta_path)

    # Carpeta destino por clase
    class_output = os.path.join(OUTPUT_DIR, class_name)
    os.makedirs(class_output, exist_ok=True)

    for pid in protein_ids:
        pdb_file = f"{pid}.pdb"
        json_file = f"{pid}.json"
        dist_file = f"{pid}_D.csv"
        weight_file = f"{pid}_W.csv"

        # -------- PDB --------
        src = os.path.join(PDB_DIR, pdb_file)
        if os.path.exists(src):
            shutil.move(src, os.path.join(class_output,"pdb"))
            print(f"  ✔ PDB: {pdb_file}")

        # -------- JSON --------
        src = os.path.join(JSON_DIR, json_file)
        if os.path.exists(src):
            shutil.move(src, os.path.join(class_output,"json"))
            print(f"  ✔ JSON: {json_file}")

        # -------- DISTANCE --------
        src = os.path.join(DIST_DIR, dist_file)
        if os.path.exists(src):
            shutil.move(src, os.path.join(class_output,"distance"))
            print(f"  ✔ DIST: {dist_file}")

        # -------- WEIGHT --------
        src = os.path.join(WEIGHT_DIR, weight_file)
        if os.path.exists(src):
            shutil.move(src, os.path.join(class_output,"weights"))
            print(f"  ✔ WEIGHT: {weight_file}")

print("\n✅ Proceso completado")
