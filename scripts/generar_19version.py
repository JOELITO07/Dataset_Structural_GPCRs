import os
import shutil

# =============================
# CONFIGURACIÓN
# =============================
FASTA_INPUT = r"D:\Nube\TM-MSA\Datasets\GPCRdb\sequences\fasta\classT2.fasta"
N_PROTEINS = 19

# Fuentes (planas)
PDB_SRC = r"D:\Nube\TM-MSA\AlphaFolds2\script\AlphaFold_PDB"
JSON_SRC = r"D:\Nube\TM-MSA\AlphaFolds2\script\AlphaFold_JSON"
DIST_SRC = r"D:\Nube\TM-MSA\AlphaFolds2\script\distances"
WEIGHT_SRC = r"D:\Nube\TM-MSA\AlphaFolds2\script\weights"

# Destino base
GPCR_BASE = r"D:\Nube\TM-MSA\Datasets\GPCRdb"

FASTA_OUT_DIR = os.path.join(GPCR_BASE, "sequences", "fasta")
PDB_DST = os.path.join(GPCR_BASE, "alphafold_pdb")
JSON_DST = os.path.join(GPCR_BASE, "alphafold_json")
DIST_DST = os.path.join(GPCR_BASE, "distances")
WEIGHT_DST = os.path.join(GPCR_BASE, "weights")

# =============================
# LEER FASTA (IDS + SEQ)
# =============================
def read_fasta(fasta_file):
    entries = []
    header = None
    seq = []

    with open(fasta_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                if header:
                    entries.append((header, "".join(seq)))
                header = line[1:]
                seq = []
            else:
                seq.append(line)

        if header:
            entries.append((header, "".join(seq)))

    return entries

# =============================
# PROCESAMIENTO
# =============================
class_name = os.path.splitext(os.path.basename(FASTA_INPUT))[0]
class_19 = f"{class_name}_19"

print(f"▶ Procesando {class_name}")

entries = read_fasta(FASTA_INPUT)

selected = []
for pid, seq in entries:
    pdb_path = os.path.join(PDB_SRC, f"{pid}.pdb")
    if os.path.exists(pdb_path):
        selected.append((pid, seq))
    if len(selected) == N_PROTEINS:
        break

if len(selected) < N_PROTEINS:
    raise RuntimeError(f"No se encontraron {N_PROTEINS} proteínas con PDB disponible")

# =============================
# CREAR FASTA _19
# =============================
os.makedirs(FASTA_OUT_DIR, exist_ok=True)
fasta_out = os.path.join(FASTA_OUT_DIR, f"{class_19}.fasta")

with open(fasta_out, "w", encoding="utf-8") as f:
    for pid, seq in selected:
        f.write(f">{pid}\n")
        for i in range(0, len(seq), 80):
            f.write(seq[i:i+80] + "\n")

print(f"✔ FASTA creado: {fasta_out}")

# =============================
# CREAR CARPETAS DESTINO
# =============================
dirs = {
    "pdb": os.path.join(PDB_DST, class_19),
    "json": os.path.join(JSON_DST, class_19),
    "dist": os.path.join(DIST_DST, class_19),
    "weight": os.path.join(WEIGHT_DST, class_19),
}

for d in dirs.values():
    os.makedirs(d, exist_ok=True)

# =============================
# COPIAR ARCHIVOS
# =============================
for pid, _ in selected:

    files = [
        (PDB_SRC, f"{pid}.pdb", dirs["pdb"]),
        (JSON_SRC, f"{pid}.json", dirs["json"]),
        (DIST_SRC, f"{pid}_D.csv", dirs["dist"]),
        (WEIGHT_SRC, f"{pid}_W.csv", dirs["weight"]),
    ]

    for src_dir, fname, dst_dir in files:
        src = os.path.join(src_dir, fname)
        if os.path.exists(src):
            shutil.copy2(src, dst_dir)
        else:
            print(f"⚠ Archivo faltante: {fname}")

# =============================
# LISTA FINAL DE PROTEÍNAS
# =============================
protein_list = ",".join([pid for pid, _ in selected])


print("\n📌 Proteínas seleccionadas:")
print(protein_list)
print("✅ Subconjunto de 19 proteínas creado correctamente")