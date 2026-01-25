import os
import json
import numpy as np
from Bio.PDB import PDBParser

# === CONFIGURACIÓN ===
PDB_DIR = "AlphaFold_PDB"
JSON_DIR = "AlphaFold_JSON"
OUT_DIST = "distances"
OUT_WEIGHTS = "weights"

os.makedirs(OUT_DIST, exist_ok=True)
os.makedirs(OUT_WEIGHTS, exist_ok=True)

# === PARÁMETROS ===
CONTACT_ATOM = "CA"       # usamos Carbono Alfa
PAE_TAU = 10.0             # factor de suavizado para pesos: w = exp(-PAE/τ)
MAX_DIST = 50.0            # corte máximo de distancia (Å) para evitar errores

# === FUNCIÓN: extraer coordenadas de Cα ===
def get_ca_coordinates(pdb_path):
    parser = PDBParser(QUIET=True)
    structure = parser.get_structure("model", pdb_path)
    coords = []
    for atom in structure.get_atoms():
        if atom.get_id() == CONTACT_ATOM:
            coords.append(atom.get_coord())
    return np.array(coords)

# === FUNCIÓN: calcular matriz de distancias ===
def compute_distance_matrix(coords):
    n = len(coords)
    D = np.zeros((n, n), dtype=np.float32)
    for i in range(n):
        diff = coords[i] - coords
        D[i] = np.sqrt(np.sum(diff * diff, axis=1))
    D = np.clip(D, 0, MAX_DIST)
    return D

# === FUNCIÓN: leer archivo JSON y generar matriz de pesos W ===
def compute_weight_matrix(json_path, tau=PAE_TAU):
    with open(json_path, "r") as f:
        data = json.load(f)

    # Detecta formato de archivo (lista o diccionario)
    if isinstance(data, list) and len(data) > 0 and "predicted_aligned_error" in data[0]:
        PAE = np.array(data[0]["predicted_aligned_error"], dtype=np.float32)
    elif isinstance(data, dict) and "predicted_aligned_error" in data:
        PAE = np.array(data["predicted_aligned_error"], dtype=np.float32)
    elif "pae" in data:
        PAE = np.array(data["pae"], dtype=np.float32)
    else:
        raise ValueError(f"No se encontró matriz PAE en {json_path}")

    # Calcular pesos: w = exp(-PAE / tau)
    W = np.exp(-PAE / tau)
    return W


# === PROCESAR TODAS LAS PROTEÍNAS ===
pdb_files = [f for f in os.listdir(PDB_DIR) if f.endswith(".pdb")]

for pdb_file in pdb_files:
    base_name = os.path.splitext(pdb_file)[0]
    pdb_path = os.path.join(PDB_DIR, pdb_file)
    json_path = os.path.join(JSON_DIR, base_name + ".json")

    if not os.path.exists(json_path):
        print(f"⚠️  No se encontró JSON para {base_name}, se omite.")
        continue

    print(f"🧠 Procesando {base_name} ...")

    try:
        # 1. Coordenadas y distancias
        coords = get_ca_coordinates(pdb_path)
        D = compute_distance_matrix(coords)
        #np.save(os.path.join(OUT_DIST, base_name + "_D.npy"), D)
        np.savetxt(os.path.join(OUT_DIST, base_name + "_D.csv"), D, delimiter=",", fmt="%.4f")


        # 2. Pesos desde PAE
        W = compute_weight_matrix(json_path)
        #np.save(os.path.join(OUT_WEIGHTS, base_name + "_W.npy"), W)
        np.savetxt(os.path.join(OUT_WEIGHTS, base_name + "_W.csv"), W, delimiter=",", fmt="%.4f")

        print(f"✅ Matrices guardadas: {base_name}_D.csv  {base_name}_W.csv")

    except Exception as e:
        print(f"❌ Error procesando {base_name}: {e}")

print("\n🧩 Finalizado. Todas las matrices estructurales han sido generadas.")
