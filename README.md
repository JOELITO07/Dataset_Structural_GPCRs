# GPCRdb Structural Alignment Benchmark Dataset

This repository provides a comprehensive benchmark dataset for the evaluation of **multiple sequence alignment (MSA) methods**, with a particular emphasis on **structure-aware and transmembrane-aware alignment of G protein-coupled receptors (GPCRs)**.

The dataset integrates **sequence data, AlphaFold2-predicted structures, distance matrices, transmembrane region annotations, reference alignments**, and **processed alignment results** obtained from multiple software tools.

It is designed to support **reproducible research** in structural bioinformatics, topology-aware alignment, and multi-objective optimization of MSAs.

**Dataset Overview:**
- **Total human GPCR sequences:** 284 (or 133 in the reduced 19-protein version)
- **GPCR classes covered:** 9 main classes/subclasses
- **Sequence sources:** UniProt, NCBI, and GPCRdb
- **Structure data:** AlphaFold2 predictions (JSON and PDB formats)
- **Alignment tools evaluated:** 5 state-of-the-art MSA tools

---

## Dataset Versions

The dataset is provided in **two complementary versions** to support different experimental scenarios.

### 1. Full Dataset (Complete Version)

The complete dataset includes **all available human GPCR sequences** grouped by biologically meaningful subclasses. This version is intended for:

- Large-scale MSA benchmarking
- Statistical and evolutionary analysis
- Scalability evaluation of alignment algorithms

**Composition of the full dataset:**

| Class/Subclass | Dataset Code | Number of sequences |
|---|---|---|
| Class A-001 (Rhodopsin – Aminergic) | classA_001 | 19 |
| Class A-002 (Rhodopsin – Peptide) | classA_002 | 19 |
| Class A-003 (Rhodopsin – Chemokine) | classA_003 | 19 |
| Class A-004 (Rhodopsin – Lipid) | classA_004 | 19 |
| Class B1 (Secretin) | classB1 | 15 |
| Class B2 (Adhesion) | classB2 | 33 |
| Class C (Glutamate) | classC | 19 |
| Class F (Frizzled) | classF | 11 |
| Class T2 (Taste 2) | classT2 | 25 |
| **Total (Full Dataset)** | | **179** |
| **Total (Complete)** | | **284** |

Sequence characteristics:
- **Length range:** Approximately 290 to 6,000+ amino acids
- **Longest sequences:** Adhesion GPCRs (Class B2), with multiple extracellular domains
- **Alignment focus:** Transmembrane (TM) regions identified and extracted
- **Sequence coverage:** All major human GPCR classes and well-studied subfamilies

---

### 2. Reduced Dataset (_19 Version)

A reduced version of the dataset was constructed, containing **exactly 19 proteins per class/subclass** (where applicable).

This version was created to accommodate methodological constraints of certain structure-based alignment tools:

> Dong et al., *mTM-align: an algorithm for fast and accurate multiple protein structure alignment*, Bioinformatics, 34:1719–1725 (2018)

The original **mTM-align** implementation enforces a hard limit of **19 PDB structures per input**.

**Reduced Dataset Composition:**
- **9 classes/subclasses** with 19 proteins each (where sufficient data exists)
- **Total sequences:** 133 proteins (vs. 284 in full version)
- **Suffix notation:** `_19` appended to class names (e.g., `classA_001_19`)
- **Purpose:** Enable direct comparison of all 5 alignment tools, including structure-based methods

---

## Directory Structure

```
📦 Datasets/
├── 📄 README.md                    # This file
├── 📁 GPCRdb/                      # Main dataset directory
│   ├── 📄 List19Proteins.txt       # List of proteins in reduced 19-protein version
│   ├── 📁 sequences/               # Sequence data in multiple formats
│   │   ├── 📄 dataset_summary.csv  # Metadata and statistics
│   │   ├── 📁 fasta/               # FASTA format sequences
│   │   │   ├── classA_001.fasta
│   │   │   ├── classA_001_19.fasta
│   │   │   ├── classA_002.fasta
│   │   │   ├── classA_002_19.fasta
│   │   │   ├── classA_003.fasta
│   │   │   ├── classA_003_19.fasta
│   │   │   ├── classA_004.fasta
│   │   │   ├── classA_004_19.fasta
│   │   │   ├── classB1.fasta
│   │   │   ├── classB2.fasta
│   │   │   ├── classB2_19.fasta
│   │   │   ├── classC.fasta
│   │   │   ├── classC_19.fasta
│   │   │   ├── classF.fasta
│   │   │   ├── classT2.fasta
│   │   │   └── classT2_19.fasta
│   │   ├── 📁 gff3/                # GFF3 format annotations
│   │   └── 📁 tmregions/           # Transmembrane region data
│   ├── 📁 alphafold_pdb/           # AlphaFold2 structures (PDB format)
│   │   ├── classA_001/
│   │   ├── classA_001_19/
│   │   ├── classA_002/
│   │   ├── classA_002_19/
│   │   ├── classA_003/
│   │   ├── classA_003_19/
│   │   ├── classA_004/
│   │   ├── classA_004_19/
│   │   ├── classB1/
│   │   ├── classB2/
│   │   ├── classB2_19/
│   │   ├── classC/
│   │   ├── classC_19/
│   │   ├── classF/
│   │   ├── classT2/
│   │   └── classT2_19/
│   ├── 📁 alphafold_json/          # AlphaFold2 structures (JSON format)
│   │   └── [Same structure as alphafold_pdb/]
│   ├── 📁 distances/               # Distance matrices from structures
│   │   └── [Same structure as alphafold_pdb/]
│   ├── 📁 weights/                 # Alignment weights and scoring matrices
│   │   └── [Same structure as alphafold_pdb/]
│   ├── 📁 reference_alignments/    # Gold-standard reference alignments
│   │   ├── classA_001.fasta
│   │   ├── classA_001_19.fasta
│   │   ├── classA_002.fasta
│   │   ├── classA_002_19.fasta
│   │   ├── classA_003.fasta
│   │   ├── classA_003_19.fasta
│   │   ├── classA_004.fasta
│   │   ├── classA_004_19.fasta
│   │   ├── classB1.fasta
│   │   ├── classB2.fasta
│   │   ├── classB2_19.fasta
│   │   ├── classC.fasta
│   │   ├── classC_19.fasta
│   │   ├── classF.fasta
│   │   ├── classT2.fasta
│   │   └── classT2_19.fasta
│   └── 📁 resultados_software/     # Alignment results from 5 tools
│       ├── clustalw/
│       ├── kalign/
│       ├── mafft/
│       ├── tcoffee/
│       └── tm-aligner/
└── 📁 scripts/                     # Utility scripts for data processing
    ├── 📄 download.py              # Download data from external sources
    ├── 📄 downloadsequences.py     # Download GPCR sequences
    ├── 📄 downloadmsareferences_19.py
    ├── 📄 generar.py               # Generate full dataset
    ├── 📄 generar_19version.py     # Generate reduced 19-protein version
    ├── 📄 organizar.py             # Organize/prepare data
    ├── 📄 groupfiles.py            # Group files by class
    ├── 📄 groupsfiles2.py          # Alternative grouping script
    ├── 📄 downloadalignmentref     # Reference alignment downloader
    ├── 📄 gpcr_list.csv            # GPCR metadata (UniProt IDs, classifications)
    └── 📄 adhesion_gpcr_human_33.csv # Adhesion GPCR subset data
```

---

## Data Components and Usage

### Sequences (`sequences/`)
- **FASTA files:** High-quality protein sequences in FASTA format
- **Dataset Summary:** CSV file with metadata for all sequences
- **GFF3 annotations:** Gene feature format annotations
- **Transmembrane regions:** Pre-identified and annotated TM regions for each protein

### Structural Data
- **AlphaFold2 Structures:** 
  - **PDB format** (`alphafold_pdb/`): Standard PDB files for visualization and structure analysis
  - **JSON format** (`alphafold_json/`): Structured format with metadata, confidence scores (pLDDT), and PAE (Predicted Aligned Error)

### Derived Data
- **Distance Matrices** (`distances/`): Pairwise distance matrices computed from 3D structures
- **Weights** (`weights/`): Pre-computed alignment weights and scoring matrices

### Reference Alignments (`reference_alignments/`)
Gold-standard alignments curated from:
- **UniProt/GPCRdb reference alignments**
- **Manually validated structural alignments**
- **Multi-tool consensus alignments**

These serve as the ground truth for benchmarking MSA methods.

---

## Software Evaluation Results

The directory `resultados_software/` contains processed alignment results from five established MSA tools:

| Tool | Type | Category | Reference |
|---|---|---|---|
| **ClustalW** | Progressive | Sequence-based | [ClustalW2](http://www.clustal.org/) |
| **Kalign** | Progressive | Sequence-based | [Kalign](https://msa.sbc.su.se/cgi-bin/msa.cgi) |
| **MAFFT** | FFT-based | Sequence-based | [MAFFT](https://mafft.cbrc.jp/alignment/software/) |
| **T-Coffee** | Progressive | Sequence-based | [T-Coffee](http://www.tcoffee.org/) |
| **TM-aligner / mTM-align** | Profile | Structure-based | [mTM-align](https://yanglab.nankai.edu.cn/mTM-align/) |

**Results Organization:**
- One subdirectory per tool
- Organized by GPCR class (classA_001, classA_002, ..., classT2)
- Both full and reduced (\_19) datasets evaluated

---

## Key Features

✅ **Comprehensive Dataset:** 284 human GPCR sequences across 9 major classes  
✅ **Dual Versions:** Full dataset and reduced 19-protein version for flexibility  
✅ **Multi-format Structure Data:** PDB and JSON formats for diverse use cases  
✅ **Reference Alignments:** Gold-standard alignments for validation  
✅ **Reproducible Results:** Output from 5 established alignment tools  
✅ **Transmembrane-aware:** Emphasis on TM region alignment accuracy  
✅ **Utility Scripts:** Python scripts for data processing and generation  

---

## Usage Example

To evaluate a new MSA method on this dataset:

1. Use FASTA sequences from `sequences/fasta/`
2. Optionally incorporate structural information from `alphafold_pdb/` or `alphafold_json/`
3. Compare results against `reference_alignments/`
4. Benchmark against outputs in `resultados_software/`
5. Use `distances/` or `weights/` for structure-aware scoring

For structure-based methods, extract PDB files from the corresponding class directory.

---

## Citation

If you use this dataset in your research, please cite:


---

## License and Terms of Use

This dataset is provided for **academic, educational, and research purposes only**.

**License:**
- Sequences: Licensed under CC-BY 4.0 (UniProt/GPCRdb)
- AlphaFold2 structures: Licensed under CC-BY 4.0 (DeepMind/ESMFold)
- Compiled dataset and derived data: CC-BY 4.0

**Original data sources retain their respective licenses and attribution requirements.**

---

## Changelog

### v1.0 (Initial Release)
- 284 human GPCR sequences across 9 classes
- AlphaFold2 structures (PDB and JSON formats)
- Distance matrices and alignment weights
- Reference alignments from 4+ sources
- Results from 5 alignment tools (ClustalW, Kalign, MAFFT, T-Coffee, mTM-align)
- Reduced 19-protein dataset for structure-based tools
- Python utility scripts for data processing
