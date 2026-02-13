import os
import numpy as np
from Bio.PDB import PDBParser

# ============================================================
# CONFIGURACIÓN (ajusta si cambias rutas)
# ============================================================
PDB_ROOT = r"D:\Nube\TM-MSA\Datasets\GPCRdb\alphafold_pdb"   # contiene subcarpetas classA_001, classA_002, ...
OUT_ROOT = r"D:\Nube\TM-MSA\Datasets\GPCRdb\distances"      # se crearán subcarpetas equivalentes

CONTACT_ATOM = "CA"
MAX_DIST = 50.0

# ============================================================
# Extraer Cα por RESIDUO (robusto) + idx (resseq del PDB)
# idx[k] = número de residuo (1-based) correspondiente a fila/columna k en D
# ============================================================
def get_ca_coords_and_idx(pdb_path, chain_id="A"):
    parser = PDBParser(QUIET=True)
    structure = parser.get_structure("model", pdb_path)

    model = next(structure.get_models())

    # En AlphaFold normalmente hay una cadena; si no existe 'A', toma la primera disponible.
    if chain_id in model:
        chain = model[chain_id]
    else:
        chain = next(model.get_chains())

    coords = []
    idx = []

    for res in chain.get_residues():
        # res.id = (hetflag, resseq, icode)
        if res.id[0] != " ":  # ignora hetero/water
            continue
        if CONTACT_ATOM not in res:
            continue

        coords.append(res[CONTACT_ATOM].get_coord())
        idx.append(res.id[1])  # resseq (típicamente 1..L)

    return np.array(coords, dtype=np.float32), np.array(idx, dtype=np.int32)

# ============================================================
# Matriz de distancias (cortada a MAX_DIST)
# ============================================================
def compute_distance_matrix(coords):
    n = len(coords)
    D = np.zeros((n, n), dtype=np.float32)
    for i in range(n):
        diff = coords[i] - coords
        D[i] = np.sqrt(np.sum(diff * diff, axis=1))
    return np.clip(D, 0, MAX_DIST)

# ============================================================
# Recorre subcarpetas (clases) y genera *_D.csv y *_idx.csv
# ============================================================
def process_all_classes():
    if not os.path.isdir(PDB_ROOT):
        raise RuntimeError(f"No existe PDB_ROOT: {PDB_ROOT}")

    os.makedirs(OUT_ROOT, exist_ok=True)

    class_dirs = [d for d in os.listdir(PDB_ROOT) if os.path.isdir(os.path.join(PDB_ROOT, d))]
    class_dirs.sort()

    total_ok = 0
    total_fail = 0

    for class_name in class_dirs:
        in_dir = os.path.join(PDB_ROOT, class_name)
        out_dir = os.path.join(OUT_ROOT, class_name)
        os.makedirs(out_dir, exist_ok=True)

        pdb_files = [f for f in os.listdir(in_dir) if f.lower().endswith(".pdb")]
        pdb_files.sort()

        if not pdb_files:
            print(f"⚠️  Sin PDBs en {in_dir}")
            continue

        print(f"\n📁 Clase: {class_name}  ({len(pdb_files)} PDBs)")

        for pdb_file in pdb_files:
            base_name = os.path.splitext(pdb_file)[0]
            pdb_path = os.path.join(in_dir, pdb_file)

            out_D = os.path.join(out_dir, f"{base_name}_D.csv")
            out_idx = os.path.join(out_dir, f"{base_name}_idx.csv")

            try:
                coords, idx = get_ca_coords_and_idx(pdb_path, chain_id="A")
                if coords.size == 0 or idx.size == 0:
                    raise ValueError("No se encontraron residuos con CA en el PDB")
                if coords.shape[0] != idx.shape[0]:
                    raise ValueError(f"coords ({coords.shape[0]}) != idx ({idx.shape[0]})")

                D = compute_distance_matrix(coords)

                # Guardar D e idx
                np.savetxt(out_D, D, delimiter=",", fmt="%.4f")
                np.savetxt(out_idx, idx, delimiter=",", fmt="%d")

                total_ok += 1
                print(f"✅ {base_name}: D={D.shape[0]}x{D.shape[1]} idx={idx.shape[0]}")

            except Exception as e:
                total_fail += 1
                print(f"❌ Error en {class_name}/{pdb_file}: {e}")

    print("\n🧩 Finalizado.")
    print(f"✅ OK   : {total_ok}")
    print(f"❌ FAIL : {total_fail}")

if __name__ == "__main__":
    process_all_classes()
