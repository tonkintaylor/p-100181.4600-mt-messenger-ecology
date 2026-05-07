# Figure Generation Pipeline — Design Spec

**Date:** 2025-05-06
**Branch:** `feature/r-script-reimplementation`
**Status:** Approved

## Goal

Reimplement the six legacy R plotting scripts in Python to enable headless, reproducible figure generation suitable for CI/automation. The existing `mgen` pipeline already produces `Data.xlsx`; this work adds a `mgen plot` command that reads that file and generates all monitoring figures and statistical outputs.

## Requirements

| Requirement | Decision |
|---|---|
| Primary goal | Headless reproducible figure generation (CI-friendly) |
| Scope | Full — sediment, macro, NMDS stats + plots + Excel tables |
| Visual fidelity | Functionally equivalent to R output (same data story, professional) |
| Output formats | PNG (300 DPI) + multi-page PDF |
| Output location | Configurable `figures_dir` in `cycle.toml` |
| CLI integration | `mgen plot` as separate command (independent of `mgen run`) |
| Testing | Three tiers: data, structural, golden image snapshots |
| NMDS dependencies | Hybrid: scipy + scikit-learn MDS + custom indicator species |

## Architecture

### Module Structure

```
src/mgen/
├── stats/                        # Pure computation (no matplotlib)
│   ├── __init__.py
│   ├── triggers.py               # Baseline trigger level calculation
│   ├── confidence.py             # t-distribution CI for replicated metrics
│   └── community.py              # Bray-Curtis, NMDS, ANOSIM, indicator species
│
├── plots/                        # Visual rendering (matplotlib only)
│   ├── __init__.py
│   ├── _style.py                 # Shared theme: palettes, summer boxes, baseline vline
│   ├── sediment.py               # SAM time-series + grain-size stacked bars
│   ├── macro.py                  # QMCI/EPT metrics with CI error bars
│   └── community.py              # NMDS ordination scatter plots
│
├── exports/                      # Non-visual file outputs
│   ├── __init__.py
│   └── community_tables.py       # Dissimilarity, indicator spp, drivers → xlsx
│
├── cli.py                        # EXTEND: add `mgen plot` command
└── config.py                     # EXTEND: add figures_dir
```

### Data Flow

```
Data.xlsx → pd.read_excel()
    ↓
stats/ (pure computation)
    ├── triggers.py      → dict[site, trigger_level]
    ├── confidence.py    → dict[site, dict[metric, MetricSummary]]
    └── community.py     → NMDSResult, ANOSIMResult, list[IndicatorSpecies]
    ↓
plots/ (rendering)       → PNG + PDF files
exports/ (tables)        → XLSX files
```

Each stats module returns plain Python/pandas/numpy objects (DataFrames, arrays, dataclasses). Plots modules receive pre-computed results and render them. No statistical computation in the plots layer.

## Stats Layer

### `stats/triggers.py`

```python
def compute_trigger(
    df: pd.DataFrame,
    metric_col: str,
    site: str,
    baseline_end: date = date(2022, 2, 28),
    direction: Literal["decline", "increase"] = "decline",
    threshold_pct: float = 0.15,
    cap: float | None = None,
) -> float:
    """Compute trigger level from baseline mean.

    direction="decline": baseline_mean * (1 - threshold_pct)  → macro metrics
    direction="increase": baseline_mean * (1 + threshold_pct) → sediment (capped at 100)
    """
```

### `stats/confidence.py`

```python
@dataclass
class MetricSummary:
    mean: float
    ci_lower: float
    ci_upper: float
    n: int

def summarize_with_ci(
    values: pd.Series,
    confidence: float = 0.95,
    clamp_lower: float = 0.0,
    clamp_upper: float = 100.0,
) -> MetricSummary:
    """t-distribution confidence interval, clamped to [0, 100].

    Matches the R implementation's summary_with_CI() helper.
    Uses scipy.stats.t.ppf for the t-critical value.
    """
```

### `stats/community.py`

```python
@dataclass
class NMDSResult:
    points: pd.DataFrame          # columns: NMDS1, NMDS2, Site, Date, Period
    stress: float

@dataclass
class ANOSIMResult:
    R_statistic: float
    p_value: float
    permutations: int

@dataclass
class IndicatorSpecies:
    species: str
    group: str
    stat: float                   # IndVal index
    p_value: float

def bray_curtis_matrix(species_df: pd.DataFrame) -> np.ndarray:
    """Compute pairwise Bray-Curtis dissimilarity using scipy.spatial.distance.pdist."""

def run_nmds(
    distance_matrix: np.ndarray,
    n_dims: int = 2,
    seed: int = 42,
    max_iter: int = 300,
) -> NMDSResult:
    """Non-metric MDS via sklearn.manifold.MDS(metric=False, dissimilarity='precomputed')."""

def run_anosim(
    distance_matrix: np.ndarray,
    groups: pd.Series,
    permutations: int = 999,
    seed: int = 42,
) -> ANOSIMResult:
    """Analysis of Similarities (ANOSIM) with permutation test.

    Custom implementation: ranks distances, computes R statistic,
    permutes group labels to build null distribution.
    """

def indicator_species_analysis(
    species_df: pd.DataFrame,
    groups: pd.Series,
    permutations: int = 999,
    seed: int = 42,
    p_threshold: float = 0.05,
) -> list[IndicatorSpecies]:
    """Indicator Value (IndVal) analysis (Dufrêne & Legendre 1997).

    Custom implementation of the IndVal index with permutation-based
    significance testing. Equivalent to R's indicspecies::multipatt.
    """

def envfit_species_drivers(
    nmds_points: np.ndarray,
    species_df: pd.DataFrame,
    permutations: int = 999,
    seed: int = 42,
) -> pd.DataFrame:
    """Fit species vectors onto ordination space (envfit equivalent).

    For each species, computes correlation (R²) between species abundance
    and NMDS axis scores using linear regression. Permutation-based p-values.
    Returns DataFrame with columns: Species, NMDS1_corr, NMDS2_corr, R2, p_value.
    """
```

## Plots Layer

### `plots/_style.py` — Shared visual language

```python
PERIOD_COLORS = {
    "Baseline": "#ff9f1c",
    "Routine Construction": "#2ec4b6",
    "Incident": "#e71d36",
}

SITES = ["EM1", "EM2", "EM3", "EM5", "EM4", "EM7", "EM8"]

BASELINE_END = date(2022, 2, 28)

def apply_ecology_theme(ax: Axes) -> None:
    """Standard axis formatting: 3-month date breaks, Mon YY labels, 90° rotation, grid."""

def add_summer_shading(ax: Axes, year_range: tuple[int, int]) -> None:
    """Add gray alpha=0.4 rectangles for Jan-Mar of each year in range."""

def add_baseline_vline(ax: Axes) -> None:
    """Dashed vertical line at BASELINE_END."""

def save_figure(fig: Figure, path: Path, formats: list[str] | None = None) -> list[Path]:
    """Save at 300 DPI in requested formats (default: png + pdf). Returns paths written."""
```

### `plots/sediment.py`

```python
def plot_sediment_timeseries(
    df: pd.DataFrame,
    triggers: dict[str, float],
    output_dir: Path,
) -> list[Path]:
    """Per-site SAM1+SAM3 scatter plots with trigger level hline.

    One figure per site. Each figure has 2 subplots (SAM1, SAM3).
    Points colored by Period. Summer shading + baseline vline applied.
    Also produces a combined multi-page PDF.
    """

def plot_sediment_size_distribution(
    df: pd.DataFrame,
    output_dir: Path,
) -> list[Path]:
    """Per-site stacked bar charts of grain-size percentage.

    One bar per sampling date. Stacked by Wentworth size category.
    Uses a diverging color palette (Paired) for size categories.
    """
```

### `plots/macro.py`

```python
def plot_macro_metrics(
    raw_df: pd.DataFrame,
    summaries: dict[str, dict[str, list[MetricSummary]]],
    triggers: dict[str, dict[str, float]],
    output_dir: Path,
) -> list[Path]:
    """Per-site 3-panel figures (QMCI, %EPT Richness, %EPT Abundance).

    Each panel shows:
    - Mean point with 95% CI error bars (from summaries)
    - Trigger level horizontal line
    - Summer shading + baseline vline
    - Points colored by Period

    Produces per-site PNGs and a combined multi-page PDF.
    """
```

### `plots/community.py`

```python
def plot_nmds_ordination(
    nmds: NMDSResult,
    subset_name: str,
    output_dir: Path,
    show_hulls: bool = True,
    show_arrows: bool = False,
    arrow_data: pd.DataFrame | None = None,
) -> list[Path]:
    """NMDS scatter plot with optional convex hulls and trend arrows.

    Points colored by Site, shaped by Period.
    Convex hulls drawn per site when show_hulls=True.
    Trend arrows (baseline→construction centroid) when show_arrows=True.

    Called multiple times for different subsets:
    - all sites, baseline only, construction only
    - Mangapepeke catchment, Mimi catchment
    - soft-bottom sites, hard-bottom sites
    - per-site (with temporal trend arrows)
    """
```

## Exports Layer

### `exports/community_tables.py`

```python
def export_dissimilarity_table(
    distance_matrix: np.ndarray,
    labels: list[str],
    output_path: Path,
) -> Path:
    """Write Bray-Curtis dissimilarity matrix to xlsx."""

def export_indicator_species(
    indicators: list[IndicatorSpecies],
    output_path: Path,
) -> Path:
    """Write significant indicator species per group to xlsx."""

def export_species_drivers(
    envfit_results: pd.DataFrame,
    output_path: Path,
) -> Path:
    """Write envfit species drivers (R² + p-value) to xlsx."""
```

## CLI & Config

### Config extension

```toml
# cycle.toml
[output]
data_xlsx = "T:/.../Data.xlsx"
figures_dir = "T:/.../Figures"    # Optional; defaults to data_xlsx parent / "Figures"
```

`PipelineConfig` gains:
```python
figures_dir: Path  # defaults to data_xlsx.parent / "Figures" if not specified
```

### CLI command

```python
@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
@click.option("--only", type=click.Choice(["sediment", "macro", "community", "all"]), default="all")
@click.option("--data-xlsx", type=click.Path(), default=None, help="Override Data.xlsx path")
def plot(config_path: str, only: str, data_xlsx: str | None) -> None:
    """Generate monitoring figures from Data.xlsx."""
```

### Orchestrator

```python
@dataclass
class FigureResult:
    files_written: list[Path]
    warnings: list[str]
    success: bool

def generate_all_figures(
    data: dict[str, pd.DataFrame],
    output_dir: Path,
    only: str = "all",
) -> FigureResult:
    """Run stats → plots → exports for requested subset. Returns summary."""
```

## Testing Strategy

### Tier 1: Data/computation tests (fast, CI-blocking)

| Module | What's tested |
|---|---|
| `triggers.py` | Parametrized: sediment ×1.15 capped at 100, macro ×0.85 |
| `confidence.py` | Known values validated against R's `qt()` output |
| `community.py` | Bray-Curtis vs scipy reference; NMDS stress decreases with iterations; ANOSIM significance for known group separation; IndVal for known dominant taxon |

### Tier 2: Structural assertions (fast, CI-blocking)

- Plot functions return expected number of file paths
- Rendered figures have correct number of axes/subplots
- Axis labels and titles match expectations
- Data point count matches input DataFrame length
- Colors match period palette for known data points

### Tier 3: Golden image snapshots (CI runs, warnings-only)

- Generate reference images from fixture data
- Compare renders against golden images using RMSE threshold
- Marked `@pytest.mark.golden` — CI produces artifacts for human review
- Update workflow: `pytest --update-golden` regenerates reference images
- Golden images stored in `tests/assets/golden_figures/`

## Dependencies

### New production dependencies

```toml
"matplotlib>=3.10",      # figure rendering (move from dev group)
"scipy>=1.14",           # distance matrices, t-distribution
"scikit-learn>=1.5",     # MDS (non-metric) for NMDS ordination
```

### Removed

- No scikit-bio (Windows issues, heavy)
- No plotnine (unnecessary ggplot2 clone — matplotlib gives full control)

## Implementation Phases

### Phase 1 — Foundation

- `stats/triggers.py` + `stats/confidence.py`
- `plots/_style.py` (shared theme)
- `plots/sediment.py` — grain-size stacked bars (simplest plot)
- CLI wiring (`mgen plot`) + config extension (`figures_dir`)
- Tier 1+2 tests for all of above

### Phase 2 — Time-series plots

- `plots/sediment.py` — SAM time-series with trigger lines
- `plots/macro.py` — CI error bars, 3-panel layout
- Golden image testing infrastructure

### Phase 3 — Community analysis

- `stats/community.py` (Bray-Curtis, NMDS, ANOSIM, IndVal)
- `plots/community.py` (ordination scatter with hulls/arrows)
- `exports/community_tables.py` (xlsx outputs)
- Statistical correctness tests (reference values from R)

### Phase 4 — Polish & CI

- Golden image snapshots for all plot types
- CI workflow artifact upload for visual review
- Documentation update

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| scikit-learn NMDS may differ from R's `vegan::metaMDS` | Accept "functionally equivalent" — same community structure, different rotation. Validate stress values are comparable. |
| NMDS is stochastic (random seed) | Fix seed=42 for reproducibility. Document that ordination may differ from R output. |
| Indicator species (IndVal) custom code correctness | Validate against published examples (Dufrêne & Legendre 1997 Table 1). Cross-check a few species against R's `multipatt` output. |
| matplotlib styling ≠ ggplot2 | Accepted. Functionally equivalent, not pixel-identical. |
| Large golden image files in repo | Keep fixture data minimal (3-4 dates × 3 sites). Compress PNGs. |

## Out of Scope

- Automated visual comparison with R output (manual review only)
- Interactive/dashboard plots (static figures only)
- Replacing the `mgen run` pipeline itself (already done)
- Real-time or streaming plot updates
