#!/usr/bin/env python3
"""Análisis automático de todos los datasets de TM-M2StructAlign en Windows.

Expected layout (created by TM_MSAStructAlignerGPCRdb):

    ROOT/ejecuciones/DATASET/RUN_ID/FUN.tsv
    ROOT/ejecuciones/DATASET/RUN_ID/MSASol0.fasta
    ROOT/ejecuciones/DATASET/RUN_ID/runtime.txt

FUN.tsv row i maps to MSASol{i}.fasta. Both values written by the current
runner are benefit scores (larger is better): objective 1 is the structural
sum-of-pairs/topology score and objective 2 is LDDT.

The script creates a combined empirical Pareto front, per-run HV and IGD+,
balanced and preference-based compromise solutions, selected FASTA copies,
CSV summaries, and publication-ready PDF/SVG/PNG figures.
"""

from __future__ import annotations

import argparse
import csv
import math
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import matplotlib.pyplot as plt
    import numpy as np
except ModuleNotFoundError as exc:
    try:
        import tkinter.messagebox as messagebox
        messagebox.showerror(
            "Dependencia faltante",
            "Falta instalar NumPy o Matplotlib.\n\nAbra CMD y ejecute:\n"
            "py -m pip install numpy matplotlib",
        )
    except Exception:
        pass
    raise SystemExit(
        "Falta una dependencia. Ejecute: py -m pip install numpy matplotlib"
    ) from exc



@dataclass
class Solution:
    dataset: str
    run: str
    row: int
    fasta: Path
    f1: float
    f2: float
    n1: float = math.nan
    n2: float = math.nan
    combined_nd: bool = False


# ============================================================================
# CONFIGURACIÓN FIJA PARA WINDOWS
# ============================================================================
ROOT = Path(r"C:\GDrive2026\TM-MSA\Pruebas2")
EXECUTIONS_ROOT = ROOT / "ejecuciones"
OUTPUT_ROOT = EXECUTIONS_ROOT / "resultados"
BASELINES_ROOT = Path(r"C:\GDrive2026\TM-MSA\Datasets\GPCRdb\precomputed")

FUN_NAME = "FUN.tsv"
F1_NAME = "Topology-aware structural SoP"
F2_NAME = "LDDT"
NORMALIZATION = "minmax"

# FUN.tsv ya contiene los valores reales restaurados: ambos se maximizan.
F1_DIRECTION = "max"
F2_DIRECTION = "max"

WEIGHT_F1 = 0.5
WEIGHT_F2 = 0.5
SENSITIVITY_WEIGHT_F1 = 0.7
SENSITIVITY_WEIGHT_F2 = 0.3
EPSILON = 0.05

# Métodos que se excluyen ÚNICAMENTE de la figura. Se mantienen en la
# normalización, baseline_comparison.csv y todos los cálculos estadísticos.
PLOT_BASELINE_EXCLUSIONS = {
    "classA_001": {"tcoffee", "usalign_clean"},
    "classA_001_19": {"tcoffee", "usalign_clean"},
    "classA_002_19": {"tcoffee", "usalign_clean"},
    "classA_003_19": {"tcoffee", "usalign_clean"},
    "classB1": {"tcoffee", "usalign_clean"},
    "classB2": {"tcoffee", "usalign_clean"},
    "classB2_19": {"tcoffee", "usalign_clean"},
    "classC": {"tcoffee", "usalign_clean"},
    "classC_19":{"tcoffee", "usalign_clean"},
    "classF": {"tcoffee", "usalign_clean"},
    "classT2": {"tcoffee", "usalign_clean"},
    "classT2_19": {"tcoffee", "usalign_clean"},
}


def normalized_method_name(method: object) -> str:
    """Normaliza nombres como US-align, usalign_clean o mTM-align."""
    return re.sub(r"[^a-z0-9]+", "_", str(method).lower()).strip("_")


def show_baseline_in_plot(dataset: str, method: object) -> bool:
    """Decide solo la visibilidad gráfica; no altera datos ni indicadores."""
    excluded = PLOT_BASELINE_EXCLUSIONS.get(dataset, set())
    normalized = normalized_method_name(method)
    return not any(
        normalized == name or normalized.startswith(name + "_")
        for name in excluded
    )


def fixed_args(dataset: str) -> argparse.Namespace:
    """Construye la configuración fija correspondiente a un dataset."""
    return argparse.Namespace(
        root=ROOT,
        dataset=dataset,
        output=OUTPUT_ROOT / dataset,
        fun_name=FUN_NAME,
        f1_name=F1_NAME,
        f2_name=F2_NAME,
        normalization=NORMALIZATION,
        f1_direction=F1_DIRECTION,
        f2_direction=F2_DIRECTION,
        weight_f1=WEIGHT_F1,
        weight_f2=WEIGHT_F2,
        sensitivity_weight_f1=SENSITIVITY_WEIGHT_F1,
        sensitivity_weight_f2=SENSITIVITY_WEIGHT_F2,
        epsilon=EPSILON,
        baselines=BASELINES_ROOT / dataset / "baselines.csv",
        title=None,
    )


def locate_dataset(root: Path, dataset: str) -> Path:
    candidates = (root / "ejecuciones" / dataset, root / dataset)
    for candidate in candidates:
        if candidate.is_dir():
            return candidate.resolve()
    raise FileNotFoundError(
        f"Dataset directory not found. Tried: {', '.join(str(p) for p in candidates)}"
    )


def read_fun(path: Path) -> np.ndarray:
    rows: list[list[float]] = []
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = re.split(r"[\t,; ]+", line)
        try:
            values = [float(value) for value in fields if value]
        except ValueError as exc:
            raise ValueError(f"Non-numeric value in {path}:{number}: {line}") from exc
        if len(values) != 2 or not all(math.isfinite(value) for value in values):
            raise ValueError(f"Expected exactly two finite objectives in {path}:{number}")
        rows.append(values)
    if not rows:
        raise ValueError(f"No objective rows found in {path}")
    return np.asarray(rows, dtype=float)


def find_fasta(run_dir: Path, row: int) -> Path:
    """Resolve the FASTA using one unambiguous numbering convention per run.

    The current Java runner is zero-based: FUN row 0 maps to MSASol0.fasta.
    A one-based fallback is retained only for archived runs that do not contain
    MSASol0.fasta. We never mix both conventions within the same run.
    """
    zero_based_marker = run_dir / "MSASol0.fasta"
    zero_based_padded_marker = run_dir / "MSASol000.fasta"

    if zero_based_marker.is_file():
        target = run_dir / f"MSASol{row}.fasta"
        if target.is_file():
            return target.resolve()
        raise FileNotFoundError(
            f"Missing zero-based FASTA for FUN row {row}: {target}"
        )

    if zero_based_padded_marker.is_file():
        target = run_dir / f"MSASol{row:03d}.fasta"
        if target.is_file():
            return target.resolve()
        raise FileNotFoundError(
            f"Missing padded zero-based FASTA for FUN row {row}: {target}"
        )

    # Legacy one-based archives: FUN row 0 maps to MSASol1 or MSASol001.
    one_based = run_dir / f"MSASol{row + 1}.fasta"
    one_based_padded = run_dir / f"MSASol{row + 1:03d}.fasta"
    if one_based.is_file():
        return one_based.resolve()
    if one_based_padded.is_file():
        return one_based_padded.resolve()

    raise FileNotFoundError(
        f"No FASTA found for FUN row {row} in {run_dir}"
    )


def load_solutions(dataset_dir: Path, fun_name: str) -> tuple[list[Solution], list[str]]:
    solutions: list[Solution] = []
    warnings: list[str] = []
    run_dirs = sorted(path.parent for path in dataset_dir.glob(f"*/{fun_name}"))
    if not run_dirs:
        raise FileNotFoundError(f"No */{fun_name} files found below {dataset_dir}")
    for run_dir in run_dirs:
        values = read_fun(run_dir / fun_name)
        for row, (f1, f2) in enumerate(values):
            try:
                fasta = find_fasta(run_dir, row)
            except FileNotFoundError as exc:
                warnings.append(str(exc))
                continue
            solutions.append(
                Solution(dataset_dir.name, run_dir.name, row, fasta, float(f1), float(f2))
            )
    if not solutions:
        raise RuntimeError("No FUN rows could be paired with FASTA solutions")
    return solutions, warnings


def to_benefit(values: np.ndarray, direction: str) -> np.ndarray:
    return values if direction == "max" else -values


def normalize(solutions: list[Solution], baselines: list[dict[str, object]],
              mode: str, directions: tuple[str, str]) -> None:
    raw = np.asarray([[s.f1, s.f2] for s in solutions], dtype=float)
    benefit = np.column_stack(
        [to_benefit(raw[:, j], directions[j]) for j in range(2)]
    )
    baseline_benefit = np.empty((0, 2), dtype=float)
    if baselines:
        baseline_raw = np.asarray([[row["f1"], row["f2"]] for row in baselines], dtype=float)
        baseline_benefit = np.column_stack(
            [to_benefit(baseline_raw[:, j], directions[j]) for j in range(2)]
        )
    pooled = np.vstack([benefit, baseline_benefit])
    if mode == "none":
        if np.any(pooled < 0.0) or np.any(pooled > 1.0):
            raise ValueError("--normalization none requires benefit values within [0,1]")
        norm = benefit
        baseline_norm = baseline_benefit
    else:
        low = pooled.min(axis=0)
        span = pooled.max(axis=0) - low
        if np.any(span == 0.0):
            raise ValueError("Cannot min-max normalize an objective with zero pooled range")
        norm = (benefit - low) / span
        baseline_norm = (baseline_benefit - low) / span
    for solution, (n1, n2) in zip(solutions, norm):
        solution.n1, solution.n2 = float(n1), float(n2)
    for row, (n1, n2) in zip(baselines, baseline_norm):
        row["n1"], row["n2"] = float(n1), float(n2)


def nondominated_mask(points: np.ndarray) -> np.ndarray:
    """Return non-dominated mask for a maximization problem; retain duplicates."""
    mask = np.ones(len(points), dtype=bool)
    for i, point in enumerate(points):
        dominated = np.all(points >= point, axis=1) & np.any(points > point, axis=1)
        if np.any(dominated):
            mask[i] = False
    return mask


def unique_front(points: np.ndarray) -> np.ndarray:
    front = points[nondominated_mask(points)]
    return np.unique(front, axis=0)


def weighted_distance(point: np.ndarray, weights: tuple[float, float]) -> float:
    return float(np.sqrt(np.sum(np.asarray(weights) * np.square(1.0 - point))))


def validate_weights(weights: tuple[float, float], label: str) -> None:
    if any(weight < 0 for weight in weights) or not math.isclose(sum(weights), 1.0, abs_tol=1e-9):
        raise ValueError(f"{label} weights must be non-negative and sum to 1")


def select_solution(front: list[Solution], weights: tuple[float, float]) -> Solution:
    return min(front, key=lambda s: (weighted_distance(np.array([s.n1, s.n2]), weights), -s.n1, -s.n2))


def hypervolume_2d(points: np.ndarray, reference: tuple[float, float] = (0.0, 0.0)) -> float:
    """Exact dominated HV for normalized two-objective maximization."""
    ref = np.asarray(reference, dtype=float)
    usable = points[np.all(points > ref, axis=1)]
    if len(usable) == 0:
        return 0.0
    front = unique_front(usable)
    front = front[np.argsort(front[:, 0])]
    hv = 0.0
    previous_x = ref[0]
    for x, y in front:
        hv += max(0.0, x - previous_x) * max(0.0, y - ref[1])
        previous_x = max(previous_x, x)
    return float(hv)


def igd_plus(approximation: np.ndarray, reference_front: np.ndarray) -> float:
    """IGD+ for maximization: mean modified distance from reference to approximation."""
    distances = []
    for reference in reference_front:
        # Only an approximation's shortfall relative to a reference point is penalized.
        modified = np.maximum(reference - approximation, 0.0)
        distances.append(float(np.min(np.linalg.norm(modified, axis=1))))
    return float(np.mean(distances))


def read_runtime(run_dir: Path) -> float:
    path = run_dir / "runtime.txt"
    if not path.is_file():
        return math.nan
    for raw in path.read_text(encoding="utf-8").splitlines():
        fields = raw.split("\t", 1)
        if len(fields) == 2 and fields[0].strip() == "runtime_seconds":
            try:
                return float(fields[1])
            except ValueError:
                return math.nan
    return math.nan


def load_baselines(path: Path | None) -> list[dict[str, object]]:
    if path is None:
        return []
    rows: list[dict[str, object]] = []
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        required = {"method", "objective_1", "objective_2"}
        if not required.issubset(reader.fieldnames or []):
            raise ValueError(f"Baseline CSV requires columns: {sorted(required)}")
        for row in reader:
            rows.append({"method": row["method"], "f1": float(row["objective_1"]),
                         "f2": float(row["objective_2"])})
    return rows


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def plot_results(solutions: list[Solution], combined: list[Solution], selections: dict[str, Solution],
                 baselines: list[dict[str, object]], output: Path, args: argparse.Namespace) -> None:
    fig, ax = plt.subplots(figsize=(7.2, 5.8), constrained_layout=True)
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")

    all_points = np.asarray([[s.n1, s.n2] for s in solutions])
    ax.scatter(
        all_points[:, 0], all_points[:, 1],
        s=13, color="#9ca3af", alpha=0.14, linewidths=0,
        label="All solutions (10 runs)", zorder=1,
    )

    ordered = sorted(combined, key=lambda s: (s.n1, -s.n2))
    front_points = np.asarray([[s.n1, s.n2] for s in ordered])
    ax.plot(front_points[:, 0], front_points[:, 1], "o-", color="#1769aa", linewidth=1.8,
            markersize=4.2, label="Combined non-dominated front", zorder=3)

    # Conventional aligners: identical blue circles, named next to each point,
    # but deliberately excluded from the legend.
    visible_baselines = [
        row for row in baselines
        if show_baseline_in_plot(args.dataset, row["method"])
    ]
    for row in visible_baselines:
        ax.scatter(
            row["n1"], row["n2"], marker="o", s=42,
            color="#2563eb", edgecolor="white", linewidth=0.6,
            label="_nolegend_", zorder=4,
        )
        ax.annotate(
            str(row["method"]),
            xy=(row["n1"], row["n2"]),
            xytext=(-6, 0), textcoords="offset points",
            ha="right", va="center", fontsize=7.5, color="#1f2937",
            annotation_clip=True, zorder=5,
        )

    styles = {
        # Extreme solutions use the same circular marker as the Pareto points.
        # They are highlighted in red and omitted from the legend.
        "extreme_f1": ("o", "#dc2626" , "Best Solution (f1)", 66),
        "extreme_f2": ("o", "#dc2626" , "Best Solution (f2)", 66),
        "compromise_balanced": ("*", "#d62728", "Compromise (0.5, 0.5)"),
        "compromise_sensitivity": ("*", "#ff7f0e", "Preference sensitivity"),
    }
    plotted: set[tuple[float, float, str]] = set()
    for key, solution in selections.items():
        style = styles[key]
        marker, color, label = style[:3]
        size = style[3] if len(style) == 4 else 135
        signature = (solution.n1, solution.n2, label)
        if signature not in plotted:
            ax.scatter(solution.n1, solution.n2, marker=marker, s=size, color=color,
                       edgecolor="black", linewidth=0.65, label=label, zorder=6)
            plotted.add(signature)

    ax.set_xlabel(f"Normalized {args.f1_name}")
    ax.set_ylabel(f"Normalized {args.f2_name}")
    ax.set_title(args.title or f"Combined Pareto front — {args.dataset}")
    ax.grid(False)
    # Show only the range occupied by visible points, with a small margin.
    # Excluded baselines do not affect the visual limits.
    display_points = all_points
    if visible_baselines:
        baseline_points = np.asarray(
            [[row["n1"], row["n2"]] for row in visible_baselines],
            dtype=float,
        )
        display_points = np.vstack([display_points, baseline_points])

    x_min, x_max = float(display_points[:, 0].min()), float(display_points[:, 0].max())
    y_min, y_max = float(display_points[:, 1].min()), float(display_points[:, 1].max())
    x_margin = max((x_max - x_min) * 0.04, 0.015)
    y_margin = max((y_max - y_min) * 0.04, 0.015)
    ax.set_xlim(x_min - x_margin, x_max + x_margin)
    ax.set_ylim(y_min - y_margin, y_max + y_margin)

    ax.legend(
        fontsize=8,
        loc="lower right",
        frameon=True,
        fancybox=False,
        framealpha=1.0,
        facecolor="white",
        edgecolor="black",
    )
    for extension in ("pdf", "svg", "png"):
        fig.savefig(
            output / f"pareto_front_{args.dataset}.{extension}",
            dpi=350,
            bbox_inches="tight",
            facecolor="white",
        )
    plt.close(fig)


def process_dataset(dataset: str) -> dict[str, object]:
    args = fixed_args(dataset)
    balanced = (args.weight_f1, args.weight_f2)
    sensitivity = (args.sensitivity_weight_f1, args.sensitivity_weight_f2)
    validate_weights(balanced, "Main")
    validate_weights(sensitivity, "Sensitivity")
    if args.epsilon < 0:
        raise ValueError("--epsilon must be non-negative")

    dataset_dir = locate_dataset(args.root.resolve(), args.dataset)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    selected_dir = output / "selected_alignments"
    selected_dir.mkdir(exist_ok=True)

    solutions, warnings = load_solutions(dataset_dir, args.fun_name)
    directions = (args.f1_direction, args.f2_direction)
    baselines = load_baselines(args.baselines)
    normalize(solutions, baselines, args.normalization, directions)
    points = np.asarray([[s.n1, s.n2] for s in solutions])
    combined_mask = nondominated_mask(points)
    for solution, keep in zip(solutions, combined_mask):
        solution.combined_nd = bool(keep)
    # Collapse identical objective vectors deterministically for reference metrics and plotting.
    representatives: dict[tuple[float, float], Solution] = {}
    for solution in solutions:
        if solution.combined_nd:
            representatives.setdefault((solution.n1, solution.n2), solution)
    combined = list(representatives.values())
    combined_points = np.asarray([[s.n1, s.n2] for s in combined])

    extreme_f1 = max(combined, key=lambda s: (s.n1, s.n2, -s.row))
    extreme_f2 = max(combined, key=lambda s: (s.n2, s.n1, -s.row))
    compromise = select_solution(combined, balanced)
    compromise_sensitivity = select_solution(combined, sensitivity)
    selections = {
        "extreme_f1": extreme_f1,
        "extreme_f2": extreme_f2,
        "compromise_balanced": compromise,
        "compromise_sensitivity": compromise_sensitivity,
    }
    for label, solution in selections.items():
        shutil.copy2(solution.fasta, selected_dir / f"{label}.fasta")

    solution_rows = [{
        "dataset": s.dataset, "run": s.run, "fun_row": s.row,
        "fasta": str(s.fasta), "objective_1": s.f1, "objective_2": s.f2,
        "normalized_f1": s.n1, "normalized_f2": s.n2,
        "combined_nondominated": int(s.combined_nd),
    } for s in solutions]
    solution_fields = list(solution_rows[0])
    write_csv(output / "combined_solutions.csv", solution_fields, solution_rows)
    write_csv(output / "combined_pareto_front.csv", solution_fields,
              [row for row in solution_rows if row["combined_nondominated"]])

    selection_rows = []
    for label, s in selections.items():
        weights = balanced if label != "compromise_sensitivity" else sensitivity
        selection_rows.append({
            "selection": label, "run": s.run, "fun_row": s.row, "source_fasta": str(s.fasta),
            "objective_1": s.f1, "objective_2": s.f2, "normalized_f1": s.n1,
            "normalized_f2": s.n2,
            "distance_to_ideal": weighted_distance(np.array([s.n1, s.n2]), weights),
        })
    write_csv(output / "selected_solutions.csv", list(selection_rows[0]), selection_rows)

    best_distance = weighted_distance(np.array([compromise.n1, compromise.n2]), balanced)
    indicator_rows = []
    for run in sorted({s.run for s in solutions}):
        run_solutions = [s for s in solutions if s.run == run]
        run_points = np.asarray([[s.n1, s.n2] for s in run_solutions])
        run_front = unique_front(run_points)
        reached = any(weighted_distance(point, balanced) <= best_distance + args.epsilon
                      for point in run_front)
        contribution = sum(s.combined_nd for s in run_solutions)
        indicator_rows.append({
            "dataset": args.dataset, "run": run, "hypervolume": hypervolume_2d(run_front),
            "igd_plus": igd_plus(run_front, combined_points),
            "nondominated_solutions": len(run_front),
            "combined_front_contribution": contribution,
            "reached_compromise_region": int(reached),
            "runtime_seconds": read_runtime(dataset_dir / run),
        })
    write_csv(output / "indicators_by_run.csv", list(indicator_rows[0]), indicator_rows)

    numeric = ("hypervolume", "igd_plus", "nondominated_solutions",
               "combined_front_contribution", "runtime_seconds")
    summary_rows = []
    for metric in numeric:
        values = np.asarray([float(row[metric]) for row in indicator_rows], dtype=float)
        values = values[np.isfinite(values)]
        summary_rows.append({
            "metric": metric, "n": len(values),
            "median": float(np.median(values)) if len(values) else math.nan,
            "q1": float(np.quantile(values, 0.25)) if len(values) else math.nan,
            "q3": float(np.quantile(values, 0.75)) if len(values) else math.nan,
            "iqr": float(np.quantile(values, 0.75) - np.quantile(values, 0.25)) if len(values) else math.nan,
        })
    reached_values = [int(row["reached_compromise_region"]) for row in indicator_rows]
    summary_rows.append({"metric": "compromise_reach_proportion", "n": len(reached_values),
                         "median": float(np.mean(reached_values)), "q1": "", "q3": "", "iqr": ""})
    write_csv(output / "indicator_summary.csv", ["metric", "n", "median", "q1", "q3", "iqr"], summary_rows)

    if baselines:
        baseline_rows = []
        for row in baselines:
            point = np.asarray([row["n1"], row["n2"]])
            dominated = bool(np.any(np.all(combined_points >= point, axis=1)
                                    & np.any(combined_points > point, axis=1)))
            baseline_rows.append({**row, "distance_to_ideal": weighted_distance(point, balanced),
                                  "dominated_by_combined_front": int(dominated)})
        write_csv(output / "baseline_comparison.csv", list(baseline_rows[0]), baseline_rows)
    plot_results(solutions, combined, selections, baselines, output, args)

    if warnings:
        (output / "warnings.log").write_text("\n".join(warnings) + "\n", encoding="utf-8")
    print(f"Analyzed {len(solutions)} solutions from {len(indicator_rows)} runs")
    print(f"Combined non-dominated objective vectors: {len(combined)}")
    print(f"Balanced compromise: {compromise.run}/MSASol{compromise.row}.fasta")
    print(f"Results: {output}")
    return {
        "dataset": dataset,
        "solutions": len(solutions),
        "runs": len(indicator_rows),
        "pareto_points": len(combined),
        "balanced_run": compromise.run,
        "balanced_fasta": compromise.fasta.name,
        "output": str(output),
        "status": "ok",
        "error": "",
    }


def discover_datasets() -> list[str]:
    if not EXECUTIONS_ROOT.is_dir():
        raise FileNotFoundError(f"No existe la carpeta: {EXECUTIONS_ROOT}")

    datasets = []
    for directory in EXECUTIONS_ROOT.iterdir():
        if not directory.is_dir() or directory.name.lower() == "resultados":
            continue
        if any(directory.glob(f"*/{FUN_NAME}")):
            datasets.append(directory.name)
        else:
            print(f"[OMITIDO] {directory.name}: no contiene */{FUN_NAME}")
    return sorted(datasets, key=str.lower)


def main() -> int:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    datasets = discover_datasets()
    if not datasets:
        raise RuntimeError(f"No se encontraron datasets en {EXECUTIONS_ROOT}")

    print(f"Root:       {ROOT}")
    print(f"Ejecuciones:{EXECUTIONS_ROOT}")
    print(f"Resultados: {OUTPUT_ROOT}")
    print(f"Baselines:  {BASELINES_ROOT}")
    print(f"Datasets:   {len(datasets)}")
    print()

    batch_rows: list[dict[str, object]] = []
    failures = 0

    for index, dataset in enumerate(datasets, 1):
        print("=" * 78)
        print(f"[{index}/{len(datasets)}] Procesando {dataset}")
        print(f"Baseline: {BASELINES_ROOT / dataset / 'baselines.csv'}")
        print("=" * 78)
        try:
            row = process_dataset(dataset)
            batch_rows.append(row)
            print(f"[OK] {dataset}\n")
        except Exception as error:
            failures += 1
            print(f"[ERROR] {dataset}: {error}\n", file=sys.stderr)
            batch_rows.append({
                "dataset": dataset,
                "solutions": "",
                "runs": "",
                "pareto_points": "",
                "balanced_run": "",
                "balanced_fasta": "",
                "output": str(OUTPUT_ROOT / dataset),
                "status": "failed",
                "error": str(error),
            })

    write_csv(
        OUTPUT_ROOT / "batch_summary.csv",
        ["dataset", "solutions", "runs", "pareto_points", "balanced_run",
         "balanced_fasta", "output", "status", "error"],
        batch_rows,
    )

    print("=" * 78)
    print(f"Finalizado: {len(datasets) - failures}/{len(datasets)} datasets correctos")
    print(f"Resumen: {OUTPUT_ROOT / 'batch_summary.csv'}")
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, RuntimeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(2)