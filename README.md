# GPCRdb Structural Alignment Benchmark Dataset

This repository provides a comprehensive benchmark dataset for the evaluation of **multiple sequence alignment (MSA) methods**, with a particular emphasis on **structure-aware and transmembrane-aware alignment of G protein-coupled receptors (GPCRs)**.

The dataset integrates **sequence data, AlphaFold2-predicted structures, distance matrices, transmembrane region annotations, reference alignments**, and **processed alignment results** obtained from multiple software tools.

It is designed to support **reproducible research** in structural bioinformatics, topology-aware alignment, and multi-objective optimization of MSAs.

**Dataset Overview:**
- **Total human GPCR sequences:** 284 (or 133 in the reduced 19-protein version)
- **GPCR classes covered:** 9 main classes/subclasses
- **Sequence sources:** UniProt, NCBI, and GPCRdb
- **Structure data:** AlphaFold2 predictions (JSON and PDB formats)
- **Alignment tools evaluated:** sequence-based baselines plus major structure-based tools
- **New additions:** dedicated experiment outputs and workflow scripts for Mustang, Caretta, mTM-align, FoldMason, and US-align

---

## Dataset Versions

The dataset is provided in **two complementary versions** to support different experimental scenarios.

### 1. Full Dataset (Complete Version)

The complete dataset includes **all available human GPCR sequences** grouped by biologically meaningful subclasses. This version is intended for:

- Large-scale MSA benchmarking
- Statistical and evolutionary analysis
- Scalability evaluation of alignment algorithms

**Composition of the full dataset:**

| Class (group)                    | Number of sequences |
| -------------------------------- | ------------------- |
| Class Aα (Rhodopsin – Aminergic) | 36                  |
| Class Aβ (Rhodopsin – Peptide)   | 76                  |
| Class Aγ (Rhodopsin – Protein)   | 30                  |
| Class Aδ (Rhodopsin – Lipid)     | 36                  |
| Class B1 (Secretin)              | 15                  |
| Class B2 (Adhesion)              | 33                  |
| Class C (Glutamate)              | 22                  |
| Class F (Frizzled)               | 11                  |
| Class T2 (Taste 2)               | 25                  |
| **Total**                        | **284**             |

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
│   ├── 📁 alphafold_pdb/           # AlphaFold2 structures (PDB format)
│   ├── 📁 alphafold_json/          # AlphaFold2 structures (JSON format)
│   ├── 📁 distances/               # Distance matrices from structures
│   ├── 📁 weights/                 # Alignment weights and scoring matrices
│   ├── 📁 reference_alignments/    # Gold-standard reference alignments
│   ├── 📁 precomputed/             # Precomputed structural-alignment experiment outputs
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
│   │   ├── classT2_19/
│   │   └── resultados_precomputed.txt
│   └── 📁 resultados_software/     # Alignment results from sequence-based baseline tools
│       ├── clustalw/
│       ├── kalign/
│       ├── mafft/
│       ├── tcoffee/
│       └── tm-aligner/
├── 📁 Tests/                      # Outputs from structural-alignment experiments
│   ├── 📁 mustang/
│   ├── 📁 caretta/
│   │   ├── caretta_execution_summary.tsv
│   │   ├── caretta_global.log
│   │   └── logs/
│   ├── 📁 mtmalign/
│   ├── 📁 foldmason/
│   └── 📁 usalign/
└── 📁 scripts/                     # Utility scripts for data processing and workflow execution
    ├── 📄 download.py
    ├── 📄 downloadsequences.py
    ├── 📄 downloadmsareferences_19.py
    ├── 📄 generar.py
    ├── 📄 generar_19version.py
    ├── 📄 organizar.py
    ├── 📄 groupfiles.py
    ├── 📄 groupsfiles2.py
    ├── 📄 mustang_run.sh
    ├── 📄 run_caretta.sh
    ├── 📄 ejecutar_mtmalign_parallel.sh
    ├── 📄 run_foldmason.sh
    ├── 📄 run_usalign.sh
    ├── 📄 gpcr_list.csv
    └── 📄 adhesion_gpcr_human_33.csv
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

The repository now contains both baseline sequence-based alignments and a dedicated set of structural-alignment experiments. The main resources are organized as follows:

| Tool | Category | Repository location | Notes |
|---|---|---|---|
| **ClustalW / Kalign / MAFFT / T-Coffee** | Sequence-based baselines | GPCRdb/resultados_software/ | Standard MSA outputs organized by GPCR class |
| **mTM-align** | Structure-based | Tests/mtmalign/ | Per-dataset execution folders and parallel log files |
| **Mustang** | Structure-based | Tests/mustang/ | Class-based result folders for structural alignment experiments |
| **Caretta** | Structure-based | Tests/caretta/ | Includes execution summary, global logs, and per-dataset outputs |
| **FoldMason** | Structure-based | Tests/foldmason/ | Dataset-level result directories generated by the workflow script |
| **US-align** | Structure-based | Tests/usalign/ | Batch outputs produced from the US-align workflow |

**Results organization:**
- Each tool has its own result directory under Tests/
- The outputs are organized by GPCR class, including both full and reduced (_19) datasets where applicable
- A consolidated summary of precomputed results is available in GPCRdb/precomputed/resultados_precomputed.txt

### Structural-alignment workflow scripts
- scripts/mustang_run.sh
- scripts/run_caretta.sh
- scripts/ejecutar_mtmalign_parallel.sh
- scripts/run_foldmason.sh
- scripts/run_usalign.sh

These scripts automate the execution of the structure-based workflows and prepare the result folders used for downstream analysis.

---

## Key Features

✅ **Comprehensive Dataset:** 284 human GPCR sequences across 9 major classes  
✅ **Dual Versions:** Full dataset and reduced 19-protein version for flexibility  
✅ **Multi-format Structure Data:** PDB and JSON formats for diverse use cases  
✅ **Reference Alignments:** Gold-standard alignments for validation  
✅ **Reproducible Results:** Outputs from both sequence-based and structural-alignment tools  
✅ **Structural Alignment Benchmarks:** Dedicated experiment folders for Mustang, Caretta, mTM-align, FoldMason, and US-align  
✅ **Precomputed Results:** Consolidated outputs stored under GPCRdb/precomputed/ for rapid reuse  
✅ **Transmembrane-aware:** Emphasis on TM region alignment accuracy  
✅ **Utility Scripts:** Python and shell scripts for dataset generation, organization, and workflow execution  

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

### v1.1 (Structural-alignment expansion)
- Added experiment outputs and result folders for Mustang, Caretta, mTM-align, FoldMason, and US-align
- Added new workflow scripts in the scripts/ directory to run the structural-alignment experiments
- Added precomputed result storage under GPCRdb/precomputed/ for reuse in downstream analyses
- Documented the organization of structural-alignment outputs under Tests/

### v1.0 (Initial Release)
- 284 human GPCR sequences across 9 classes
- AlphaFold2 structures (PDB and JSON formats)
- Distance matrices and alignment weights
- Reference alignments from 4+ sources
- Results from 5 alignment tools (ClustalW, Kalign, MAFFT, T-Coffee, mTM-align)
- Reduced 19-protein dataset for structure-based tools
- Python utility scripts for data processing
