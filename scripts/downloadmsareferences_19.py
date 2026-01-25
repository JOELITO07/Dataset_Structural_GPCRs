import os
import requests

# =============================
# CONFIGURACIÓN
# =============================
BASE_URL = "https://gpcrdb.org/services/alignment/protein"
OUTPUT_DIR = r"D:\Nube\TM-MSA\Datasets\GPCRdb\reference_alignments"

os.makedirs(OUTPUT_DIR, exist_ok=True)

# =============================
# LISTAS DE PROTEÍNAS (SIN ESPACIOS)
# =============================
CLASSES = {
    "classA_001": "5ht1a_human,5ht1b_human,5ht1d_human,5ht1e_human,5ht1f_human,5ht2a_human,5ht2b_human,5ht2c_human,5ht4r_human,5ht5a_human,5ht6r_human,5ht7r_human,acm1_human,acm2_human,drd2_human,acm3_human,acm4_human,acm5_human,ada1a_human",

    "classA_002": "agtr1_human,agtr2_human,apj_human,nmbr_human,grpr_human,brs3_human,bkrb1_human,bkrb2_human,cckar_human,gasr_human,c3ar_human,c5ar1_human,c5ar2_human,ednra_human,ednrb_human,fpr1_human,fpr2_human,fpr3_human,galr1_human",

    "classA_003": "cml1_human,ccr1_human,ccr2_human,ccr3_human,ccr4_human,ccr5_human,ccr6_human,ccr7_human,ccr8_human,ccr9_human,ccr10_human,cxcr1_human,cxcr2_human,cxcr3_human,cxcr4_human,cxcr5_human,cxcr6_human,cx3c1_human,xcr1_human",

    "classA_004": "ffar1_human,ffar2_human,ffar3_human,ffar4_human,gpr42_human,lt4r1_human,lt4r2_human,cltr1_human,cltr2_human,oxer1_human,lpar1_human,lpar2_human,lpar3_human,lpar4_human,lpar5_human,lpar6_human,s1pr1_human,s1pr2_human,s1pr3_human",

    "classB2": "agrl1_human,agrl2_human,agrl3_human,agrl4_human,agre1_human,agre2_human,agre3_human,agre4_human,agre5_human,agra1_human,agra2_human,agra3_human,agrd1_human,agrd2_human,agrf1_human,agrf2_human,agrf3_human,agrf4_human,agrf5_human",

    "classC": "casr_human,gabr1_human,gabr2_human,grm1_human,grm2_human,grm3_human,grm4_human,grm5_human,grm6_human,grm7_human,grm8_human,ts1r1_human,ts1r2_human,ts1r3_human,gp156_human,gp158_human,gp179_human,rai3_human,gpc5b_human",

    "classT2": "ta2r1_human,ta2r3_human,ta2r4_human,ta2r5_human,ta2r7_human,ta2r8_human,ta2r9_human,t2r10_human,t2r13_human,t2r14_human,t2r16_human,t2r19_human,t2r20_human,t2r30_human,t2r31_human,t2r38_human,t2r39_human,t2r40_human,t2r41_human"
}

# =============================
# FUNCIÓN DE DESCARGA
# =============================
def download_alignment(protein_list):
    url = f"{BASE_URL}/{protein_list}/"
    response = requests.get(url, timeout=60)
    response.raise_for_status()
    return response.json()

# =============================
# PROCESO PRINCIPAL
# =============================
for class_name, proteins in CLASSES.items():

    print(f"▶ Descargando MSA de referencia: {class_name}")

    alignment = download_alignment(proteins)

    out_fasta = os.path.join(
        OUTPUT_DIR,
        f"{class_name}_19.fasta"
    )

    with open(out_fasta, "w", encoding="utf-8") as f:
        for prot_id, aligned_seq in alignment.items():
            f.write(f">{prot_id}\n")
            f.write(f"{aligned_seq}\n")

    print(f"  ✔ Guardado en {out_fasta}")

print("\n✅ Descarga de alineamientos de referencia completada")