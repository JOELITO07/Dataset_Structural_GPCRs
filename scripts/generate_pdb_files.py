import os
from pathlib import Path

# Configuración de rutas
# AJUSTA ESTA RUTA SEGÚN TU SISTEMA
BASE_PATH = "/home/azureuser/Dataset_Structural_GPCRs/GPCRdb"
ALPHAFOLD_PDB_DIR = "c:\\GDrive2026\\TM-MSA\\Datasets\\GPCRdb\\alphafold_pdb"

def get_pdb_files(directory):
    """Obtiene lista de archivos .pdb en un directorio"""
    try:
        pdb_files = sorted([f for f in os.listdir(directory) if f.endswith('.pdb')])
        return pdb_files
    except Exception as e:
        print(f"Error leyendo directorio {directory}: {e}")
        return []

def create_description_file(folder_name, pdb_files, output_dir, base_path):
    """Crea un fichero de descripción para mTM-align"""
    
    # Ruta completa del directorio
    full_path = f"{base_path}/alphafold_pdb/{folder_name}"
    
    # Nombre del fichero de salida (sin extensión)
    output_file = os.path.join(output_dir, f"{folder_name}_mustang")
    
    try:
        with open(output_file, 'w') as f:
            # Escribir PATH
            f.write(f"> {full_path}\n")
            
            # Escribir cada archivo PDB
            for pdb_file in pdb_files:
                f.write(f"+ {pdb_file}\n")
        
        print(f"✓ Creado: {output_file} ({len(pdb_files)} archivos PDB)")
        return True
    
    except Exception as e:
        print(f"✗ Error creando {output_file}: {e}")
        return False

def main():
    """Función principal"""
    
    # Verificar que el directorio existe
    if not os.path.isdir(ALPHAFOLD_PDB_DIR):
        print(f"Error: El directorio no existe: {ALPHAFOLD_PDB_DIR}")
        return
    
    print(f"Procesando: {ALPHAFOLD_PDB_DIR}")
    print(f"Base path: {BASE_PATH}\n")
    
    # Obtener lista de carpetas
    try:
        folders = sorted([d for d in os.listdir(ALPHAFOLD_PDB_DIR) 
                         if os.path.isdir(os.path.join(ALPHAFOLD_PDB_DIR, d))])
    except Exception as e:
        print(f"Error listando directorios: {e}")
        return
    
    if not folders:
        print("No se encontraron carpetas en alphafold_pdb")
        return
    
    print(f"Encontradas {len(folders)} carpetas:\n")
    
    success_count = 0
    for folder in folders:
        folder_path = os.path.join(ALPHAFOLD_PDB_DIR, folder)
        pdb_files = get_pdb_files(folder_path)
        
        if pdb_files:
            if create_description_file(folder, pdb_files, ALPHAFOLD_PDB_DIR, BASE_PATH):
                success_count += 1
        else:
            print(f"⚠ {folder}: No contiene archivos .pdb")
    
    print(f"\n{'='*60}")
    print(f"Resumen: {success_count}/{len(folders)} ficheros creados exitosamente")

if __name__ == "__main__":
    main()
