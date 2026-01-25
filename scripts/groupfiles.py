import os
import shutil

# =============================
# RUTAS FUENTE (PLANAS)
# =============================
PDB_SRC = r"D:\Nube\TM-MSA\AlphaFolds2\script\AlphaFold_PDB"
JSON_SRC = r"D:\Nube\TM-MSA\AlphaFolds2\script\AlphaFold_JSON"
DIST_SRC = r"D:\Nube\TM-MSA\AlphaFolds2\script\distances"
WEIGHT_SRC = r"D:\Nube\TM-MSA\AlphaFolds2\script\weights"

# =============================
# RUTAS DESTINO (AGRUPADAS)
# =============================
GPCR_BASE = r"D:\Nube\TM-MSA\Datasets\GPCRdb"

PDB_DST = os.path.join(GPCR_BASE, "alphafold_pdb")
JSON_DST = os.path.join(GPCR_BASE, "alphafold_json")
DIST_DST = os.path.join(GPCR_BASE, "distances")
WEIGHT_DST = os.path.join(GPCR_BASE, "weights")

# =============================
# FASTA POR CLASE
# =============================
FASTA_CLASSES_DIR = r"D:\Nube\TM-MSA\Datasets\GPCRdb\sequences\fasta"

# =============================
# LEER IDS DESDE FASTA
# =============================
def read_fasta_ids(fasta_file):
    ids = []
    with open(fasta_file, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith(">"):
                ids.append(line[1:].strip())
    return ids

# =============================
# PROCESAMIENTO PRINCIPAL
# =============================
for fasta_file in os.listdir(FASTA_CLASSES_DIR):

    if not fasta_file.lower().endswith(".fasta"):
        continue

    class_name = os.path.splitext(fasta_file)[0]  # classA_001
    fasta_path = os.path.join(FASTA_CLASSES_DIR, fasta_file)

    print(f"\n▶ Procesando clase: {class_name}")

    protein_ids = read_fasta_ids(fasta_path)

    # Crear subcarpetas por clase
    pdb_out = os.path.join(PDB_DST, class_name)
    json_out = os.path.join(JSON_DST, class_name)
    dist_out = os.path.join(DIST_DST, class_name)
    weight_out = os.path.join(WEIGHT_DST, class_name)

    for d in [pdb_out, json_out, dist_out, weight_out]:
        os.makedirs(d, exist_ok=True)

    # Copiar archivos
    for pid in protein_ids:

        files = [
            (PDB_SRC, f"{pid}.pdb", pdb_out),
            (JSON_SRC, f"{pid}.json", json_out),
            (DIST_SRC, f"{pid}_D.csv", dist_out),
            (WEIGHT_SRC, f"{pid}_W.csv", weight_out),
        ]

        for src_dir, filename, dst_dir in files:
            src = os.path.join(src_dir, filename)
            if os.path.exists(src):
                shutil.copy2(src, dst_dir)
                #print(f" Copiar : {src}  -->  {dst_dir}")
            else:
                print(f"  ⚠ No encontrado: {filename}")

    print(f"✔ Clase {class_name} completada")

print("\n✅ Organización GPCR finalizada correctamente")