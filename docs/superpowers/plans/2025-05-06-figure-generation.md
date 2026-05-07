# Figure Generation Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `mgen plot` command that reads `Data.xlsx` and generates all monitoring figures (sediment, macro, NMDS) and statistical exports as PNG + PDF + XLSX.

**Architecture:** Stats/plots split — pure computation in `src/mgen/stats/` (no matplotlib), thin rendering in `src/mgen/plots/` (matplotlib only), Excel exports in `src/mgen/exports/`. A thin orchestrator in `src/mgen/figures.py` coordinates the full flow. CLI adds `mgen plot` command.

**Tech Stack:** matplotlib (rendering), scipy (distances, t-distribution), scikit-learn (non-metric MDS), pandas/numpy (data), openpyxl (Excel export), pytest (testing)

---

## File Map

### New files to create

| File | Responsibility |
|---|---|
| `src/mgen/stats/__init__.py` | Package init |
| `src/mgen/stats/triggers.py` | Baseline trigger level calculation |
| `src/mgen/stats/confidence.py` | t-distribution CI for replicated metrics |
| `src/mgen/stats/community.py` | Bray-Curtis, NMDS, ANOSIM, IndVal, envfit |
| `src/mgen/plots/__init__.py` | Package init |
| `src/mgen/plots/_style.py` | Shared theme: palettes, summer boxes, baseline vline |
| `src/mgen/plots/sediment.py` | SAM time-series + grain-size stacked bars |
| `src/mgen/plots/macro.py` | QMCI/EPT metrics with CI error bars |
| `src/mgen/plots/community.py` | NMDS ordination scatter plots |
| `src/mgen/exports/__init__.py` | Package init |
| `src/mgen/exports/community_tables.py` | Dissimilarity, indicator spp, drivers → xlsx |
| `src/mgen/figures.py` | Orchestrator: stats → plots → exports |
| `tests/test_stats/__init__.py` | Test package |
| `tests/test_stats/test_triggers.py` | Trigger calculation tests |
| `tests/test_stats/test_confidence.py` | CI calculation tests |
| `tests/test_stats/test_community.py` | Community stats tests |
| `tests/test_plots/__init__.py` | Test package |
| `tests/test_plots/conftest.py` | Plot test fixtures |
| `tests/test_plots/test_style.py` | Style helpers tests |
| `tests/test_plots/test_sediment.py` | Sediment plot structural tests |
| `tests/test_plots/test_macro.py` | Macro plot structural tests |
| `tests/test_plots/test_community.py` | Community plot structural tests |
| `tests/test_exports/__init__.py` | Test package |
| `tests/test_exports/test_community_tables.py` | Export tests |
| `tests/test_figures.py` | Orchestrator integration tests |
| `tests/assets/golden_figures/` | Reference PNG images |

### Files to modify

| File | Change |
|---|---|
| `src/mgen/cli.py` | Add `mgen plot` command |
| `src/mgen/config.py` | Add `figures_dir` to `PipelineConfig` |
| `pyproject.toml` | Move matplotlib to production deps, add scipy + scikit-learn |
| `cycle.example.toml` | Add `figures_dir` example |

---

## Phase 1: Foundation

### Task 1: Add production dependencies

**Files:**
- Modify: `pyproject.toml:21-26`

- [ ] **Step 1: Update pyproject.toml dependencies**

```toml
dependencies = [
    "numpy>=1.26",
    "pandas>=2.2",
    "openpyxl>=3.1",
    "click>=8.1",
    "matplotlib>=3.10",
    "scipy>=1.14",
    "scikit-learn>=1.5",
]
```

Remove `"matplotlib>=3.10.3"` from the `[dependency-groups] dev` list.

- [ ] **Step 2: Install updated dependencies**

Run: `uv sync`
Expected: Installs matplotlib, scipy, scikit-learn as production deps

- [ ] **Step 3: Verify import works**

Run: `python -c "import matplotlib; import scipy; import sklearn; print('OK')"`
Expected: "OK"

- [ ] **Step 4: Commit**

```bash
git add pyproject.toml uv.lock
git commit -m "build: add matplotlib, scipy, scikit-learn as production deps"
```

---

### Task 2: Create stats package with trigger calculation

**Files:**
- Create: `src/mgen/stats/__init__.py`
- Create: `src/mgen/stats/triggers.py`
- Create: `tests/test_stats/__init__.py`
- Create: `tests/test_stats/test_triggers.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_stats/__init__.py` (empty) and `tests/test_stats/test_triggers.py`:

```python
"""Tests for baseline trigger level calculation."""

from __future__ import annotations

from datetime import date

import pandas as pd
import pytest

from mgen.stats.triggers import compute_trigger


class TestComputeTriggerSediment:
    """Sediment trigger: baseline_mean * 1.15, capped at 100."""

    @pytest.fixture
    def sediment_df(self) -> pd.DataFrame:
        return pd.DataFrame({
            "Site": ["EM1"] * 4 + ["EM2"] * 4,
            "Date": pd.to_datetime([
                "2021-03-15", "2021-06-15", "2021-09-15", "2021-12-15",
                "2021-03-15", "2021-06-15", "2021-09-15", "2021-12-15",
            ]),
            "Period": ["Baseline"] * 8,
            "SAM1": [60.0, 70.0, 80.0, 90.0, 85.0, 90.0, 88.0, 92.0],
            "SAM3": [50.0, 55.0, 60.0, 65.0, 70.0, 72.0, 74.0, 76.0],
        })

    def test_basic_trigger_level(self, sediment_df: pd.DataFrame) -> None:
        # EM1 SAM1 baseline mean = (60+70+80+90)/4 = 75.0
        # Trigger = 75.0 * 1.15 = 86.25
        result = compute_trigger(
            sediment_df, metric_col="SAM1", site="EM1",
            direction="increase", threshold_pct=0.15,
        )
        assert result == pytest.approx(86.25)

    def test_trigger_capped_at_100(self, sediment_df: pd.DataFrame) -> None:
        # EM2 SAM1 baseline mean = (85+90+88+92)/4 = 88.75
        # Trigger = 88.75 * 1.15 = 102.0625 → capped at 100
        result = compute_trigger(
            sediment_df, metric_col="SAM1", site="EM2",
            direction="increase", threshold_pct=0.15, cap=100.0,
        )
        assert result == 100.0

    def test_uses_only_baseline_data(self, sediment_df: pd.DataFrame) -> None:
        # Add construction data that should be ignored
        extra = pd.DataFrame({
            "Site": ["EM1"],
            "Date": pd.to_datetime(["2023-03-15"]),
            "Period": ["Routine Construction"],
            "SAM1": [200.0],
            "SAM3": [200.0],
        })
        df = pd.concat([sediment_df, extra], ignore_index=True)
        result = compute_trigger(
            df, metric_col="SAM1", site="EM1",
            direction="increase", threshold_pct=0.15,
        )
        # Should still be 86.25, not affected by the 200.0 value
        assert result == pytest.approx(86.25)


class TestComputeTriggerMacro:
    """Macro trigger: baseline_mean * 0.85 (15% decline)."""

    @pytest.fixture
    def macro_df(self) -> pd.DataFrame:
        return pd.DataFrame({
            "Site": ["EM1"] * 4,
            "Date": pd.to_datetime([
                "2021-03-15", "2021-06-15", "2021-09-15", "2021-12-15",
            ]),
            "Period": ["Baseline"] * 4,
            "QMCI": [5.0, 6.0, 5.5, 5.5],
        })

    def test_decline_trigger(self, macro_df: pd.DataFrame) -> None:
        # Mean = (5.0+6.0+5.5+5.5)/4 = 5.5
        # Trigger = 5.5 * 0.85 = 4.675
        result = compute_trigger(
            macro_df, metric_col="QMCI", site="EM1",
            direction="decline", threshold_pct=0.15,
        )
        assert result == pytest.approx(4.675)

    def test_no_cap_by_default(self, macro_df: pd.DataFrame) -> None:
        result = compute_trigger(
            macro_df, metric_col="QMCI", site="EM1",
            direction="decline", threshold_pct=0.15,
        )
        # No cap applied
        assert result == pytest.approx(4.675)


class TestComputeTriggerEdgeCases:
    """Edge cases for trigger calculation."""

    def test_empty_baseline_raises(self) -> None:
        df = pd.DataFrame({
            "Site": ["EM1"],
            "Date": pd.to_datetime(["2023-03-15"]),
            "Period": ["Routine Construction"],
            "SAM1": [50.0],
        })
        with pytest.raises(ValueError, match="No baseline data"):
            compute_trigger(df, metric_col="SAM1", site="EM1", direction="increase")

    def test_site_not_found_raises(self) -> None:
        df = pd.DataFrame({
            "Site": ["EM1"],
            "Date": pd.to_datetime(["2021-03-15"]),
            "Period": ["Baseline"],
            "SAM1": [50.0],
        })
        with pytest.raises(ValueError, match="No baseline data"):
            compute_trigger(df, metric_col="SAM1", site="EM99", direction="increase")

    def test_custom_baseline_end_date(self) -> None:
        df = pd.DataFrame({
            "Site": ["EM1"] * 2,
            "Date": pd.to_datetime(["2020-01-15", "2021-06-15"]),
            "Period": ["Baseline", "Baseline"],
            "SAM1": [40.0, 60.0],
        })
        # With default baseline_end (2022-02-28), both are included → mean=50
        result = compute_trigger(
            df, metric_col="SAM1", site="EM1",
            direction="increase", threshold_pct=0.15,
            baseline_end=date(2021, 1, 1),
        )
        # Only first value (40.0) is before 2021-01-01 → mean=40, trigger=46
        assert result == pytest.approx(46.0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_stats/test_triggers.py -v`
Expected: ImportError — `mgen.stats.triggers` does not exist

- [ ] **Step 3: Implement triggers module**

Create `src/mgen/stats/__init__.py`:

```python
"""Statistical computation modules for figure generation."""
```

Create `src/mgen/stats/triggers.py`:

```python
"""Baseline trigger level calculation for ecological monitoring.

Trigger levels are computed as a percentage deviation from the baseline mean:
- Sediment: baseline_mean * (1 + threshold_pct), capped at 100%
- Macro: baseline_mean * (1 - threshold_pct)
"""

from __future__ import annotations

from datetime import date
from typing import Literal

import pandas as pd

__all__ = ["compute_trigger"]

_DEFAULT_BASELINE_END = date(2022, 2, 28)


def compute_trigger(
    df: pd.DataFrame,
    metric_col: str,
    site: str,
    direction: Literal["decline", "increase"] = "decline",
    threshold_pct: float = 0.15,
    cap: float | None = None,
    baseline_end: date = _DEFAULT_BASELINE_END,
) -> float:
    """Compute trigger level from baseline mean for a given site and metric.

    Args:
        df: DataFrame with columns Site, Date, Period, and metric_col.
        metric_col: Name of the numeric column to compute trigger for.
        site: Site identifier (e.g. "EM1").
        direction: "increase" multiplies by (1 + threshold_pct),
            "decline" multiplies by (1 - threshold_pct).
        threshold_pct: Fractional deviation from mean (default 0.15 = 15%).
        cap: Upper bound for the trigger value (e.g. 100.0 for percentages).
        baseline_end: Only data with Date <= this date is considered baseline.

    Returns:
        Trigger level as a float.

    Raises:
        ValueError: If no baseline data exists for the given site.
    """
    baseline = df[
        (df["Site"] == site)
        & (df["Period"] == "Baseline")
        & (df["Date"].dt.date <= baseline_end)
    ]

    if baseline.empty:
        msg = f"No baseline data for site={site!r}, metric={metric_col!r}"
        raise ValueError(msg)

    mean = baseline[metric_col].mean()

    if direction == "increase":
        trigger = mean * (1 + threshold_pct)
    else:
        trigger = mean * (1 - threshold_pct)

    if cap is not None:
        trigger = min(trigger, cap)

    return trigger
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_stats/test_triggers.py -v`
Expected: All 7 tests pass

- [ ] **Step 5: Run ruff**

Run: `ruff check src/mgen/stats/ tests/test_stats/`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add src/mgen/stats/ tests/test_stats/
git commit -m "feat: add trigger level calculation (stats/triggers.py)"
```

---

### Task 3: Confidence interval calculation

**Files:**
- Create: `src/mgen/stats/confidence.py`
- Create: `tests/test_stats/test_confidence.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_stats/test_confidence.py`:

```python
"""Tests for t-distribution confidence interval calculation."""

from __future__ import annotations

import pandas as pd
import pytest

from mgen.stats.confidence import MetricSummary, summarize_with_ci


class TestSummarizeWithCI:
    """Test the summarize_with_ci function."""

    def test_known_values(self) -> None:
        # 4 values: mean=5.5, std=1.2909944, se=0.6454972
        # t_crit(0.975, df=3) = 3.182446
        # margin = 3.182446 * 0.6454972 = 2.054
        values = pd.Series([4.0, 5.0, 6.0, 7.0])
        result = summarize_with_ci(values)
        assert result.mean == pytest.approx(5.5)
        assert result.n == 4
        assert result.ci_lower == pytest.approx(5.5 - 2.054, abs=0.01)
        assert result.ci_upper == pytest.approx(5.5 + 2.054, abs=0.01)

    def test_ci_clamped_to_zero(self) -> None:
        # Values close to zero → CI lower bound clamped at 0
        values = pd.Series([0.5, 0.3, 0.1, 0.2])
        result = summarize_with_ci(values, clamp_lower=0.0)
        assert result.ci_lower >= 0.0

    def test_ci_clamped_to_100(self) -> None:
        # Values close to 100 → CI upper bound clamped at 100
        values = pd.Series([98.0, 99.0, 100.0, 99.5])
        result = summarize_with_ci(values, clamp_upper=100.0)
        assert result.ci_upper <= 100.0

    def test_single_value_returns_nan_ci(self) -> None:
        # Can't compute CI with n=1
        values = pd.Series([5.0])
        result = summarize_with_ci(values)
        assert result.mean == pytest.approx(5.0)
        assert result.n == 1
        # CI should be NaN for single value (no variance)
        assert pd.isna(result.ci_lower)
        assert pd.isna(result.ci_upper)

    def test_custom_confidence_level(self) -> None:
        values = pd.Series([4.0, 5.0, 6.0, 7.0])
        result_95 = summarize_with_ci(values, confidence=0.95)
        result_99 = summarize_with_ci(values, confidence=0.99)
        # 99% CI should be wider than 95% CI
        width_95 = result_95.ci_upper - result_95.ci_lower
        width_99 = result_99.ci_upper - result_99.ci_lower
        assert width_99 > width_95

    def test_returns_metric_summary_dataclass(self) -> None:
        values = pd.Series([4.0, 5.0, 6.0, 7.0])
        result = summarize_with_ci(values)
        assert isinstance(result, MetricSummary)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_stats/test_confidence.py -v`
Expected: ImportError — `mgen.stats.confidence` does not exist

- [ ] **Step 3: Implement confidence module**

Create `src/mgen/stats/confidence.py`:

```python
"""Confidence interval calculation using the t-distribution.

Matches the R implementation's summary_with_CI() helper function
which uses t-based confidence intervals clamped to valid ranges.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import pandas as pd
from scipy import stats

__all__ = ["MetricSummary", "summarize_with_ci"]


@dataclass(frozen=True)
class MetricSummary:
    """Summary statistics for a metric with confidence interval.

    Attributes:
        mean: Sample mean.
        ci_lower: Lower bound of confidence interval.
        ci_upper: Upper bound of confidence interval.
        n: Sample size.
    """

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
    """Compute mean and t-distribution confidence interval.

    Args:
        values: Series of numeric values (e.g. replicate measurements).
        confidence: Confidence level (default 0.95 for 95% CI).
        clamp_lower: Lower bound to clamp CI (default 0.0).
        clamp_upper: Upper bound to clamp CI (default 100.0).

    Returns:
        MetricSummary with mean, CI bounds, and sample size.
        CI bounds are NaN if n < 2 (insufficient data for variance).
    """
    n = len(values)
    mean = values.mean()

    if n < 2:
        return MetricSummary(mean=float(mean), ci_lower=float("nan"), ci_upper=float("nan"), n=n)

    se = values.std(ddof=1) / math.sqrt(n)
    t_crit = stats.t.ppf((1 + confidence) / 2, df=n - 1)
    margin = t_crit * se

    ci_lower = max(mean - margin, clamp_lower)
    ci_upper = min(mean + margin, clamp_upper)

    return MetricSummary(mean=float(mean), ci_lower=float(ci_lower), ci_upper=float(ci_upper), n=n)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_stats/test_confidence.py -v`
Expected: All 6 tests pass

- [ ] **Step 5: Run ruff**

Run: `ruff check src/mgen/stats/confidence.py tests/test_stats/test_confidence.py`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add src/mgen/stats/confidence.py tests/test_stats/test_confidence.py
git commit -m "feat: add t-distribution confidence interval (stats/confidence.py)"
```

---

### Task 4: Shared plot styling

**Files:**
- Create: `src/mgen/plots/__init__.py`
- Create: `src/mgen/plots/_style.py`
- Create: `tests/test_plots/__init__.py`
- Create: `tests/test_plots/test_style.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_plots/__init__.py` (empty) and `tests/test_plots/test_style.py`:

```python
"""Tests for shared plot styling helpers."""

from __future__ import annotations

from datetime import date

import matplotlib.pyplot as plt
import pytest

from mgen.plots._style import (
    BASELINE_END,
    PERIOD_COLORS,
    SITES,
    add_baseline_vline,
    add_summer_shading,
    apply_ecology_theme,
    save_figure,
)


class TestConstants:
    def test_period_colors_has_three_entries(self) -> None:
        assert len(PERIOD_COLORS) == 3
        assert "Baseline" in PERIOD_COLORS
        assert "Routine Construction" in PERIOD_COLORS
        assert "Incident" in PERIOD_COLORS

    def test_sites_order(self) -> None:
        assert SITES == ["EM1", "EM2", "EM3", "EM5", "EM4", "EM7", "EM8"]

    def test_baseline_end_date(self) -> None:
        assert BASELINE_END == date(2022, 2, 28)


class TestApplyEcologyTheme:
    def test_sets_grid(self) -> None:
        fig, ax = plt.subplots()
        apply_ecology_theme(ax)
        # Grid should be enabled
        assert ax.get_xgridlines()[0].get_visible()
        plt.close(fig)


class TestAddSummerShading:
    def test_adds_patches_for_each_year(self) -> None:
        fig, ax = plt.subplots()
        ax.set_xlim(date(2020, 1, 1).toordinal(), date(2023, 12, 31).toordinal())
        add_summer_shading(ax, year_range=(2020, 2023))
        # Should have 4 patches (2020, 2021, 2022, 2023)
        patches = [p for p in ax.patches]
        assert len(patches) == 4
        plt.close(fig)


class TestAddBaselineVline:
    def test_adds_vertical_line(self) -> None:
        fig, ax = plt.subplots()
        add_baseline_vline(ax)
        # Should have at least one vertical line
        assert len(ax.get_lines()) >= 1
        plt.close(fig)


class TestSaveFigure:
    def test_saves_png_and_pdf(self, tmp_path) -> None:
        fig, ax = plt.subplots()
        ax.plot([1, 2, 3], [1, 2, 3])
        paths = save_figure(fig, tmp_path / "test_plot")
        plt.close(fig)
        assert (tmp_path / "test_plot.png").exists()
        assert (tmp_path / "test_plot.pdf").exists()
        assert len(paths) == 2

    def test_saves_only_requested_formats(self, tmp_path) -> None:
        fig, ax = plt.subplots()
        ax.plot([1, 2, 3], [1, 2, 3])
        paths = save_figure(fig, tmp_path / "test_plot", formats=["png"])
        plt.close(fig)
        assert (tmp_path / "test_plot.png").exists()
        assert not (tmp_path / "test_plot.pdf").exists()
        assert len(paths) == 1
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_plots/test_style.py -v`
Expected: ImportError — `mgen.plots._style` does not exist

- [ ] **Step 3: Implement style module**

Create `src/mgen/plots/__init__.py`:

```python
"""Plot rendering modules for figure generation."""
```

Create `src/mgen/plots/_style.py`:

```python
"""Shared plot styling for ecological monitoring figures.

Provides consistent visual language across all plot types:
period colors, summer shading, baseline end marker, and figure saving.
"""

from __future__ import annotations

from datetime import date
from pathlib import Path
from typing import TYPE_CHECKING

import matplotlib.dates as mdates
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt

if TYPE_CHECKING:
    from matplotlib.axes import Axes
    from matplotlib.figure import Figure

__all__ = [
    "BASELINE_END",
    "PERIOD_COLORS",
    "SITES",
    "add_baseline_vline",
    "add_summer_shading",
    "apply_ecology_theme",
    "save_figure",
]

PERIOD_COLORS: dict[str, str] = {
    "Baseline": "#ff9f1c",
    "Routine Construction": "#2ec4b6",
    "Incident": "#e71d36",
}

SITES: list[str] = ["EM1", "EM2", "EM3", "EM5", "EM4", "EM7", "EM8"]

BASELINE_END = date(2022, 2, 28)

_DPI = 300


def apply_ecology_theme(ax: Axes) -> None:
    """Apply standard axis formatting for ecology monitoring plots.

    Sets grid, date formatting with 3-month intervals, and clean spines.
    """
    ax.grid(visible=True, alpha=0.3, linestyle="--")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    ax.xaxis.set_major_locator(mdates.MonthLocator(interval=3))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %y"))
    plt.setp(ax.xaxis.get_majorticklabels(), rotation=90, ha="center")


def add_summer_shading(ax: Axes, year_range: tuple[int, int]) -> None:
    """Add gray shading rectangles for Jan-Mar of each year in range.

    Args:
        ax: Matplotlib axes to add shading to.
        year_range: (start_year, end_year) inclusive.
    """
    for year in range(year_range[0], year_range[1] + 1):
        start = date(year, 1, 1)
        end = date(year, 3, 31)
        rect = mpatches.Rectangle(
            (mdates.date2num(start), ax.get_ylim()[0]),
            width=mdates.date2num(end) - mdates.date2num(start),
            height=ax.get_ylim()[1] - ax.get_ylim()[0],
            facecolor="gray",
            alpha=0.15,
            edgecolor="none",
            zorder=0,
        )
        ax.add_patch(rect)


def add_baseline_vline(ax: Axes) -> None:
    """Add dashed vertical line at baseline monitoring end date."""
    ax.axvline(
        x=mdates.date2num(BASELINE_END),
        color="black",
        linestyle="--",
        linewidth=0.8,
        alpha=0.7,
        zorder=1,
    )


def save_figure(
    fig: Figure,
    path: Path,
    formats: list[str] | None = None,
) -> list[Path]:
    """Save figure at 300 DPI in requested formats.

    Args:
        fig: Matplotlib figure to save.
        path: Base path without extension (e.g. Path("output/plot_name")).
        formats: List of format extensions (default: ["png", "pdf"]).

    Returns:
        List of paths to saved files.
    """
    if formats is None:
        formats = ["png", "pdf"]

    paths: list[Path] = []
    for fmt in formats:
        out = path.with_suffix(f".{fmt}")
        out.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(out, dpi=_DPI, bbox_inches="tight", format=fmt)
        paths.append(out)

    plt.close(fig)
    return paths
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_plots/test_style.py -v`
Expected: All 8 tests pass

- [ ] **Step 5: Run ruff**

Run: `ruff check src/mgen/plots/ tests/test_plots/`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add src/mgen/plots/ tests/test_plots/
git commit -m "feat: add shared plot styling (_style.py)"
```

---

### Task 5: Config extension — add figures_dir

**Files:**
- Modify: `src/mgen/config.py`
- Modify: `cycle.example.toml`
- Modify: `tests/test_config.py`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_config.py`:

```python
class TestFiguresDir:
    """Tests for figures_dir configuration."""

    def test_figures_dir_from_config(self, tmp_path: Path) -> None:
        config_content = f"""
[input]
macroinvertebrate_db = "{(tmp_path / 'macro.xlsx').as_posix()}"
aquatic_monitoring_db = "{(tmp_path / 'aquatic.xlsx').as_posix()}"

[output]
data_xlsx = "{(tmp_path / 'Data.xlsx').as_posix()}"
figures_dir = "{(tmp_path / 'Figures').as_posix()}"
"""
        # Create dummy input files
        (tmp_path / "macro.xlsx").touch()
        (tmp_path / "aquatic.xlsx").touch()
        config_path = tmp_path / "cycle.toml"
        config_path.write_text(config_content)

        config = load_config(config_path)
        assert config.figures_dir == tmp_path / "Figures"

    def test_figures_dir_defaults_to_figures_subdir(self, tmp_path: Path) -> None:
        config_content = f"""
[input]
macroinvertebrate_db = "{(tmp_path / 'macro.xlsx').as_posix()}"
aquatic_monitoring_db = "{(tmp_path / 'aquatic.xlsx').as_posix()}"

[output]
data_xlsx = "{(tmp_path / 'Data.xlsx').as_posix()}"
"""
        (tmp_path / "macro.xlsx").touch()
        (tmp_path / "aquatic.xlsx").touch()
        config_path = tmp_path / "cycle.toml"
        config_path.write_text(config_content)

        config = load_config(config_path)
        assert config.figures_dir == tmp_path / "Figures"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_config.py::TestFiguresDir -v`
Expected: AttributeError — PipelineConfig has no `figures_dir`

- [ ] **Step 3: Add figures_dir to PipelineConfig and load_config**

In `src/mgen/config.py`, add `figures_dir: Path` to the dataclass and update `load_config()` to parse it with a default:

```python
@dataclass(frozen=True)
class PipelineConfig:
    """Validated pipeline configuration from cycle.toml."""

    macroinvertebrate_db: Path
    aquatic_monitoring_db: Path
    data_xlsx: Path
    figures_dir: Path
```

In `load_config()`, after parsing `data_xlsx`, add:

```python
    figures_dir_raw = output_section.get("figures_dir")
    if figures_dir_raw:
        figures_dir = Path(figures_dir_raw)
    else:
        figures_dir = data_xlsx.parent / "Figures"
```

And pass `figures_dir=figures_dir` to `PipelineConfig(...)`.

- [ ] **Step 4: Update cycle.example.toml**

Add the `figures_dir` line:

```toml
[output]
data_xlsx = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/2025-2026 Report/Stats/Data.xlsx"
figures_dir = "T:/Wellington/TT Projects/1001181/1001181.4500/WorkingMaterial/Aquatic Monitoring/2025-2026 Report/Figures"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `pytest tests/test_config.py -v`
Expected: All config tests pass (including new ones)

- [ ] **Step 6: Run full test suite**

Run: `pytest --tb=short -q`
Expected: All tests pass (no regressions from config change)

- [ ] **Step 7: Commit**

```bash
git add src/mgen/config.py cycle.example.toml tests/test_config.py
git commit -m "feat: add figures_dir to pipeline config"
```

---

### Task 6: Sediment grain-size stacked bar plots

**Files:**
- Create: `src/mgen/plots/sediment.py`
- Create: `tests/test_plots/conftest.py`
- Create: `tests/test_plots/test_sediment.py`

- [ ] **Step 1: Write the test fixtures**

Create `tests/test_plots/conftest.py`:

```python
"""Shared fixtures for plot tests."""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import pytest


@pytest.fixture
def sediment_size_df() -> pd.DataFrame:
    """Minimal SedimentSize data for 2 sites, 3 dates each."""
    sites = ["EM1"] * 3 + ["EM2"] * 3
    dates = pd.to_datetime(["2021-03-15", "2021-09-15", "2022-03-15"] * 2)
    periods = ["Baseline", "Baseline", "Routine Construction"] * 2
    seasons = ["Summer", "Winter", "Summer"] * 2
    return pd.DataFrame({
        "Site": sites,
        "Date": dates,
        "Period": periods,
        "Season": seasons,
        "Clay/silt (<0.06 mm)": [10.0, 8.0, 12.0, 15.0, 10.0, 14.0],
        "Sand (>0.06-2 mm)": [15.0, 12.0, 18.0, 10.0, 14.0, 11.0],
        "Small gravel (>2-8 mm)": [20.0, 22.0, 18.0, 20.0, 18.0, 22.0],
        "Small-med gravel (>8-16 mm)": [12.0, 14.0, 10.0, 15.0, 12.0, 13.0],
        "Med-large gravel (>16-32 mm)": [10.0, 12.0, 8.0, 10.0, 14.0, 9.0],
        "Large gravel (>32-64 mm)": [8.0, 10.0, 12.0, 8.0, 10.0, 8.0],
        "Small cobble (>64-128 mm)": [10.0, 8.0, 9.0, 8.0, 9.0, 10.0],
        "Large cobble (>128-256 mm)": [7.0, 6.0, 5.0, 6.0, 5.0, 5.0],
        "Boulders (>256 mm)": [5.0, 5.0, 5.0, 5.0, 5.0, 5.0],
        "Bedrock": [3.0, 3.0, 3.0, 3.0, 3.0, 3.0],
    })


@pytest.fixture
def sediment_df() -> pd.DataFrame:
    """Minimal Sediment data for 2 sites across baseline + construction."""
    return pd.DataFrame({
        "Site": ["EM1"] * 4 + ["EM2"] * 4,
        "Date": pd.to_datetime([
            "2021-03-15", "2021-06-15", "2021-09-15", "2022-06-15",
            "2021-03-15", "2021-06-15", "2021-09-15", "2022-06-15",
        ]),
        "Period": [
            "Baseline", "Baseline", "Baseline", "Routine Construction",
            "Baseline", "Baseline", "Baseline", "Routine Construction",
        ],
        "SAM1": [60.0, 70.0, 80.0, 85.0, 50.0, 55.0, 60.0, 70.0],
        "SAM3": [50.0, 55.0, 60.0, 65.0, 40.0, 45.0, 50.0, 55.0],
        "Season": ["Summer", "Winter", "Spring", "Winter"] * 2,
    })
```

- [ ] **Step 2: Write the failing tests**

Create `tests/test_plots/test_sediment.py`:

```python
"""Tests for sediment plot rendering."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pytest

from mgen.plots.sediment import plot_sediment_size_distribution


class TestPlotSedimentSizeDistribution:
    """Structural tests for grain-size stacked bar chart."""

    def test_returns_file_paths(self, tmp_path: Path, sediment_size_df) -> None:
        paths = plot_sediment_size_distribution(sediment_size_df, tmp_path)
        assert len(paths) > 0
        for p in paths:
            assert p.exists()
            assert p.stat().st_size > 0

    def test_creates_one_png_per_site(self, tmp_path: Path, sediment_size_df) -> None:
        paths = plot_sediment_size_distribution(sediment_size_df, tmp_path)
        png_paths = [p for p in paths if p.suffix == ".png"]
        # 2 sites in fixture data
        assert len(png_paths) == 2

    def test_creates_pdf_per_site(self, tmp_path: Path, sediment_size_df) -> None:
        paths = plot_sediment_size_distribution(sediment_size_df, tmp_path)
        pdf_paths = [p for p in paths if p.suffix == ".pdf"]
        assert len(pdf_paths) == 2

    def test_file_names_contain_site(self, tmp_path: Path, sediment_size_df) -> None:
        paths = plot_sediment_size_distribution(sediment_size_df, tmp_path)
        png_names = [p.stem for p in paths if p.suffix == ".png"]
        assert any("EM1" in name for name in png_names)
        assert any("EM2" in name for name in png_names)

    def test_empty_dataframe_returns_empty_list(self, tmp_path: Path, sediment_size_df) -> None:
        import pandas as pd
        empty_df = sediment_size_df.iloc[0:0]
        paths = plot_sediment_size_distribution(empty_df, tmp_path)
        assert paths == []
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `pytest tests/test_plots/test_sediment.py -v`
Expected: ImportError — `mgen.plots.sediment` does not exist

- [ ] **Step 4: Implement sediment size plot**

Create `src/mgen/plots/sediment.py`:

```python
"""Sediment monitoring plots.

Provides:
- Grain-size distribution stacked bar charts (per site)
- SAM1/SAM3 time-series with trigger levels (per site)
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from mgen.plots._style import save_figure
from mgen.shared.schemas import SEDIMENT_SIZE_COLUMNS

__all__ = ["plot_sediment_size_distribution", "plot_sediment_timeseries"]

_SIZE_COLS = SEDIMENT_SIZE_COLUMNS[4:]  # The 10 grain-size columns

_SIZE_COLORS = [
    "#a6cee3", "#1f78b4", "#b2df8a", "#33a02c", "#fb9a99",
    "#e31a1c", "#fdbf6f", "#ff7f00", "#cab2d6", "#6a3d9a",
]


def plot_sediment_size_distribution(
    df: pd.DataFrame,
    output_dir: Path,
) -> list[Path]:
    """Create per-site stacked bar charts of grain-size percentage.

    Args:
        df: SedimentSize DataFrame with columns from SEDIMENT_SIZE_COLUMNS.
        output_dir: Directory to save output files.

    Returns:
        List of paths to saved figure files (PNG + PDF per site).
    """
    if df.empty:
        return []

    sites = sorted(df["Site"].unique())
    all_paths: list[Path] = []

    for site in sites:
        site_df = df[df["Site"] == site].sort_values("Date").reset_index(drop=True)
        fig, ax = plt.subplots(figsize=(10, 6))

        dates = site_df["Date"].dt.strftime("%b %Y")
        x = np.arange(len(dates))
        bottom = np.zeros(len(dates))

        for i, col in enumerate(_SIZE_COLS):
            values = site_df[col].values
            ax.bar(x, values, bottom=bottom, label=col, color=_SIZE_COLORS[i], width=0.7)
            bottom += values

        ax.set_xlabel("Date")
        ax.set_ylabel("Percentage (%)")
        ax.set_title(f"Sediment Size Distribution — {site}")
        ax.set_xticks(x)
        ax.set_xticklabels(dates, rotation=90, ha="center")
        ax.legend(loc="upper right", fontsize=7, ncol=2)
        ax.set_ylim(0, 100)

        fig.tight_layout()
        paths = save_figure(fig, output_dir / f"sediment_size_{site}")
        all_paths.extend(paths)

    return all_paths


def plot_sediment_timeseries(
    df: pd.DataFrame,
    triggers: dict[str, float],
    output_dir: Path,
) -> list[Path]:
    """Create per-site SAM1/SAM3 time-series plots with trigger levels.

    Args:
        df: Sediment DataFrame with columns Site, Date, Period, SAM1, SAM3.
        triggers: Mapping of site → trigger level for SAM1.
        output_dir: Directory to save output files.

    Returns:
        List of paths to saved figure files (PNG + PDF per site).
    """
    if df.empty:
        return []

    from mgen.plots._style import (
        PERIOD_COLORS,
        add_baseline_vline,
        add_summer_shading,
        apply_ecology_theme,
    )

    sites = sorted(df["Site"].unique())
    all_paths: list[Path] = []

    for site in sites:
        site_df = df[df["Site"] == site].sort_values("Date")
        fig, axes = plt.subplots(2, 1, figsize=(10, 8), sharex=True)

        for ax_idx, metric in enumerate(["SAM1", "SAM3"]):
            ax = axes[ax_idx]
            for period, color in PERIOD_COLORS.items():
                mask = site_df["Period"] == period
                subset = site_df[mask]
                if not subset.empty:
                    ax.scatter(subset["Date"], subset[metric], c=color, label=period, s=30, zorder=3)

            if site in triggers:
                ax.axhline(y=triggers[site], color="red", linestyle="-", linewidth=1, alpha=0.7, label="Trigger")

            ax.set_ylabel(metric)
            ax.set_title(f"{site} — {metric}")

            year_min = site_df["Date"].dt.year.min()
            year_max = site_df["Date"].dt.year.max()
            add_summer_shading(ax, (year_min, year_max))
            add_baseline_vline(ax)
            apply_ecology_theme(ax)

            if ax_idx == 0:
                ax.legend(loc="upper left", fontsize=8)

        fig.tight_layout()
        paths = save_figure(fig, output_dir / f"sediment_timeseries_{site}")
        all_paths.extend(paths)

    return all_paths
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `pytest tests/test_plots/test_sediment.py -v`
Expected: All 5 tests pass

- [ ] **Step 6: Run ruff**

Run: `ruff check src/mgen/plots/sediment.py tests/test_plots/`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add src/mgen/plots/sediment.py tests/test_plots/
git commit -m "feat: add sediment grain-size stacked bar plots"
```

---

### Task 7: CLI `mgen plot` command

**Files:**
- Modify: `src/mgen/cli.py`
- Create: `src/mgen/figures.py`
- Create: `tests/test_figures.py`

- [ ] **Step 1: Write the failing test for CLI**

Add to `tests/test_cli.py`:

```python
from click.testing import CliRunner
from mgen.cli import main


class TestPlotCommand:
    def test_plot_command_exists(self) -> None:
        runner = CliRunner()
        result = runner.invoke(main, ["plot", "--help"])
        assert result.exit_code == 0
        assert "Generate" in result.output

    def test_plot_requires_data_xlsx(self, tmp_path: Path) -> None:
        config_content = f"""
[input]
macroinvertebrate_db = "{(tmp_path / 'macro.xlsx').as_posix()}"
aquatic_monitoring_db = "{(tmp_path / 'aquatic.xlsx').as_posix()}"

[output]
data_xlsx = "{(tmp_path / 'nonexistent_Data.xlsx').as_posix()}"
"""
        (tmp_path / "macro.xlsx").touch()
        (tmp_path / "aquatic.xlsx").touch()
        config_path = tmp_path / "cycle.toml"
        config_path.write_text(config_content)

        runner = CliRunner()
        result = runner.invoke(main, ["plot", str(config_path)])
        assert result.exit_code != 0
        assert "Data.xlsx not found" in result.output
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/test_cli.py::TestPlotCommand -v`
Expected: FAIL — no `plot` command registered

- [ ] **Step 3: Implement figures orchestrator**

Create `src/mgen/figures.py`:

```python
"""Figure generation orchestrator.

Coordinates stats computation, plot rendering, and export writing.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import pandas as pd

__all__ = ["FigureResult", "generate_figures"]


@dataclass
class FigureResult:
    """Result from figure generation."""

    files_written: list[Path] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def success(self) -> bool:
        return len(self.files_written) > 0


def generate_figures(
    data: dict[str, pd.DataFrame],
    output_dir: Path,
    only: str = "all",
) -> FigureResult:
    """Run stats → plots → exports for requested subset.

    Args:
        data: Mapping of sheet_name → DataFrame from Data.xlsx.
        output_dir: Directory to write figures to.
        only: Which subset to generate ("all", "sediment", "macro", "community").

    Returns:
        FigureResult with list of files written and any warnings.
    """
    result = FigureResult()
    output_dir.mkdir(parents=True, exist_ok=True)

    if only in ("all", "sediment"):
        result.files_written.extend(_generate_sediment(data, output_dir))

    if only in ("all", "macro"):
        result.files_written.extend(_generate_macro(data, output_dir))

    if only in ("all", "community"):
        result.files_written.extend(_generate_community(data, output_dir, result))

    return result


def _generate_sediment(data: dict[str, pd.DataFrame], output_dir: Path) -> list[Path]:
    """Generate sediment plots (grain-size + time-series)."""
    from mgen.plots.sediment import plot_sediment_size_distribution, plot_sediment_timeseries
    from mgen.stats.triggers import compute_trigger

    paths: list[Path] = []

    # Grain-size distribution
    if "SedimentSize" in data:
        paths.extend(plot_sediment_size_distribution(data["SedimentSize"], output_dir))

    # SAM time-series with triggers
    if "Sediment" in data:
        sediment_df = data["Sediment"]
        sites = sorted(sediment_df["Site"].unique())
        triggers: dict[str, float] = {}
        for site in sites:
            try:
                triggers[site] = compute_trigger(
                    sediment_df, metric_col="SAM1", site=site,
                    direction="increase", threshold_pct=0.15, cap=100.0,
                )
            except ValueError:
                pass  # No baseline data for this site — skip trigger
        paths.extend(plot_sediment_timeseries(sediment_df, triggers, output_dir))

    return paths


def _generate_macro(data: dict[str, pd.DataFrame], output_dir: Path) -> list[Path]:
    """Generate macro metric plots."""
    # Placeholder — implemented in Phase 2 (Task 9)
    return []


def _generate_community(
    data: dict[str, pd.DataFrame], output_dir: Path, result: FigureResult
) -> list[Path]:
    """Generate NMDS plots and exports."""
    # Placeholder — implemented in Phase 3 (Tasks 10-13)
    return []
```

- [ ] **Step 4: Add plot command to CLI**

Add to `src/mgen/cli.py`:

```python
@main.command()
@click.argument("config_path", default="cycle.toml", type=click.Path(exists=False))
@click.option("--only", type=click.Choice(["sediment", "macro", "community", "all"]), default="all")
@click.option("--data-xlsx", type=click.Path(), default=None, help="Override Data.xlsx path")
def plot(config_path: str, only: str, data_xlsx: str | None) -> None:
    """Generate monitoring figures from Data.xlsx."""
    try:
        config = load_config(Path(config_path))
    except ConfigError as e:
        click.echo(f"❌ Config error: {e}", err=True)
        sys.exit(2)

    xlsx_path = Path(data_xlsx) if data_xlsx else config.data_xlsx
    if not xlsx_path.exists():
        click.echo(f"❌ Data.xlsx not found: {xlsx_path}", err=True)
        sys.exit(1)

    # Read all sheets
    data: dict[str, pd.DataFrame] = {}
    with pd.ExcelFile(xlsx_path) as xls:
        for sheet in xls.sheet_names:
            data[sheet] = pd.read_excel(xls, sheet_name=sheet)

    from mgen.figures import generate_figures

    result = generate_figures(data, config.figures_dir, only=only)

    if result.warnings:
        for warning in result.warnings:
            click.echo(f"⚠️  {warning}", err=True)

    if result.success:
        click.echo(f"✅ Wrote {len(result.files_written)} files to {config.figures_dir}")
    else:
        click.echo("❌ No figures generated", err=True)
        sys.exit(1)
```

Add `import pandas as pd` to the imports at the top of `cli.py`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `pytest tests/test_cli.py::TestPlotCommand -v`
Expected: All 2 tests pass

- [ ] **Step 6: Run full test suite**

Run: `pytest --tb=short -q`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add src/mgen/cli.py src/mgen/figures.py tests/test_cli.py tests/test_figures.py
git commit -m "feat: add mgen plot CLI command with figures orchestrator"
```

---

## Phase 2: Time-Series Plots

### Task 8: Sediment SAM time-series plots

**Files:**
- Modify: `tests/test_plots/test_sediment.py`
- (Implementation already in `src/mgen/plots/sediment.py` from Task 6)

- [ ] **Step 1: Write the failing tests for time-series**

Add to `tests/test_plots/test_sediment.py`:

```python
from mgen.plots.sediment import plot_sediment_timeseries


class TestPlotSedimentTimeseries:
    """Structural tests for SAM time-series plots."""

    def test_returns_file_paths(self, tmp_path: Path, sediment_df) -> None:
        triggers = {"EM1": 86.25, "EM2": 63.25}
        paths = plot_sediment_timeseries(sediment_df, triggers, tmp_path)
        assert len(paths) > 0
        for p in paths:
            assert p.exists()

    def test_creates_png_and_pdf_per_site(self, tmp_path: Path, sediment_df) -> None:
        triggers = {"EM1": 86.25, "EM2": 63.25}
        paths = plot_sediment_timeseries(sediment_df, triggers, tmp_path)
        png_paths = [p for p in paths if p.suffix == ".png"]
        pdf_paths = [p for p in paths if p.suffix == ".pdf"]
        # 2 sites
        assert len(png_paths) == 2
        assert len(pdf_paths) == 2

    def test_empty_triggers_still_plots(self, tmp_path: Path, sediment_df) -> None:
        paths = plot_sediment_timeseries(sediment_df, {}, tmp_path)
        assert len(paths) > 0

    def test_empty_dataframe_returns_empty(self, tmp_path: Path, sediment_df) -> None:
        import pandas as pd
        empty = sediment_df.iloc[0:0]
        paths = plot_sediment_timeseries(empty, {}, tmp_path)
        assert paths == []
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `pytest tests/test_plots/test_sediment.py -v`
Expected: All tests pass (implementation was done in Task 6)

- [ ] **Step 3: Commit**

```bash
git add tests/test_plots/test_sediment.py
git commit -m "test: add structural tests for sediment time-series plots"
```

---

### Task 9: Macro metric plots with 95% CI error bars

**Files:**
- Create: `src/mgen/plots/macro.py`
- Create: `tests/test_plots/test_macro.py`
- Modify: `src/mgen/figures.py` (implement `_generate_macro`)

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_plots/conftest.py`:

```python
@pytest.fixture
def macro1_df() -> pd.DataFrame:
    """Macro1 sheet with replicate data for 2 sites, 3 dates."""
    rows = []
    for site in ["EM1", "EM2"]:
        for date_str, period in [
            ("2021-03-15", "Baseline"),
            ("2021-09-15", "Baseline"),
            ("2022-06-15", "Routine Construction"),
        ]:
            # 3 replicates per site-date
            for rep in range(3):
                rows.append({
                    "Site": site,
                    "Date": pd.Timestamp(date_str),
                    "Period": period,
                    "EPTrich": 40.0 + rep * 5 + (0 if site == "EM1" else 10),
                    "EPTabun": 50.0 + rep * 3 + (0 if site == "EM1" else 5),
                    "QMCI": 5.0 + rep * 0.5 + (0 if site == "EM1" else 1),
                    "Season": "Summer" if "03" in date_str else "Winter",
                })
    return pd.DataFrame(rows)
```

Create `tests/test_plots/test_macro.py`:

```python
"""Tests for macro metric plot rendering."""

from __future__ import annotations

from pathlib import Path

import pytest

from mgen.plots.macro import plot_macro_metrics
from mgen.stats.confidence import MetricSummary


class TestPlotMacroMetrics:
    """Structural tests for macro 3-panel plots."""

    @pytest.fixture
    def mock_summaries(self) -> dict[str, dict[str, list[MetricSummary]]]:
        """Pre-computed summaries for 2 sites, 3 dates, 3 metrics."""
        summaries: dict[str, dict[str, list[MetricSummary]]] = {}
        for site in ["EM1", "EM2"]:
            summaries[site] = {}
            for metric in ["QMCI", "EPTrich", "EPTabun"]:
                summaries[site][metric] = [
                    MetricSummary(mean=5.0, ci_lower=4.0, ci_upper=6.0, n=3),
                    MetricSummary(mean=5.5, ci_lower=4.5, ci_upper=6.5, n=3),
                    MetricSummary(mean=6.0, ci_lower=5.0, ci_upper=7.0, n=3),
                ]
        return summaries

    @pytest.fixture
    def mock_triggers(self) -> dict[str, dict[str, float]]:
        return {
            "EM1": {"QMCI": 4.675, "EPTrich": 34.0, "EPTabun": 42.5},
            "EM2": {"QMCI": 5.1, "EPTrich": 42.5, "EPTabun": 46.75},
        }

    def test_returns_file_paths(
        self, tmp_path: Path, macro1_df, mock_summaries, mock_triggers
    ) -> None:
        paths = plot_macro_metrics(macro1_df, mock_summaries, mock_triggers, tmp_path)
        assert len(paths) > 0
        for p in paths:
            assert p.exists()

    def test_creates_png_per_site(
        self, tmp_path: Path, macro1_df, mock_summaries, mock_triggers
    ) -> None:
        paths = plot_macro_metrics(macro1_df, mock_summaries, mock_triggers, tmp_path)
        png_paths = [p for p in paths if p.suffix == ".png"]
        assert len(png_paths) == 2  # 2 sites

    def test_empty_df_returns_empty(
        self, tmp_path: Path, macro1_df, mock_summaries, mock_triggers
    ) -> None:
        import pandas as pd
        empty = macro1_df.iloc[0:0]
        paths = plot_macro_metrics(empty, {}, {}, tmp_path)
        assert paths == []
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_plots/test_macro.py -v`
Expected: ImportError — `mgen.plots.macro` does not exist

- [ ] **Step 3: Implement macro plots**

Create `src/mgen/plots/macro.py`:

```python
"""Macroinvertebrate metric plots with 95% confidence interval error bars.

Produces per-site 3-panel figures showing QMCI, %EPT Richness, and
%EPT Abundance over time, with trigger level lines and CI whiskers.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from mgen.plots._style import (
    PERIOD_COLORS,
    add_baseline_vline,
    add_summer_shading,
    apply_ecology_theme,
    save_figure,
)
from mgen.stats.confidence import MetricSummary

__all__ = ["plot_macro_metrics"]

_METRICS = ["QMCI", "EPTrich", "EPTabun"]
_METRIC_LABELS = {
    "QMCI": "QMCI",
    "EPTrich": "%EPT Richness",
    "EPTabun": "%EPT Abundance",
}


def plot_macro_metrics(
    raw_df: pd.DataFrame,
    summaries: dict[str, dict[str, list[MetricSummary]]],
    triggers: dict[str, dict[str, float]],
    output_dir: Path,
) -> list[Path]:
    """Create per-site 3-panel figures with CI error bars.

    Args:
        raw_df: Macro1 DataFrame (all replicates).
        summaries: site → metric → list of MetricSummary (one per date).
        triggers: site → metric → trigger level.
        output_dir: Directory to save output files.

    Returns:
        List of paths to saved figure files.
    """
    if raw_df.empty:
        return []

    sites = sorted(raw_df["Site"].unique())
    all_paths: list[Path] = []

    for site in sites:
        if site not in summaries:
            continue

        site_df = raw_df[raw_df["Site"] == site].sort_values("Date")
        dates = sorted(site_df["Date"].unique())

        fig, axes = plt.subplots(3, 1, figsize=(10, 12), sharex=True)

        for ax_idx, metric in enumerate(_METRICS):
            ax = axes[ax_idx]
            metric_summaries = summaries.get(site, {}).get(metric, [])

            # Plot CI error bars
            for i, (dt, summary) in enumerate(zip(dates, metric_summaries)):
                period = site_df[site_df["Date"] == dt]["Period"].iloc[0]
                color = PERIOD_COLORS.get(period, "gray")
                yerr_lower = summary.mean - summary.ci_lower if not pd.isna(summary.ci_lower) else 0
                yerr_upper = summary.ci_upper - summary.mean if not pd.isna(summary.ci_upper) else 0
                ax.errorbar(
                    dt, summary.mean,
                    yerr=[[yerr_lower], [yerr_upper]],
                    fmt="o", color=color, capsize=3, markersize=5, zorder=3,
                )

            # Trigger line
            site_triggers = triggers.get(site, {})
            if metric in site_triggers:
                ax.axhline(
                    y=site_triggers[metric],
                    color="red", linestyle="-", linewidth=1, alpha=0.7,
                    label="Trigger",
                )

            ax.set_ylabel(_METRIC_LABELS[metric])
            ax.set_title(f"{site} — {_METRIC_LABELS[metric]}")

            year_min = site_df["Date"].dt.year.min()
            year_max = site_df["Date"].dt.year.max()
            add_summer_shading(ax, (year_min, year_max))
            add_baseline_vline(ax)
            apply_ecology_theme(ax)

        fig.tight_layout()
        paths = save_figure(fig, output_dir / f"macro_{site}")
        all_paths.extend(paths)

    return all_paths
```

- [ ] **Step 4: Update _generate_macro in figures.py**

Replace the placeholder `_generate_macro` in `src/mgen/figures.py`:

```python
def _generate_macro(data: dict[str, pd.DataFrame], output_dir: Path) -> list[Path]:
    """Generate macro metric plots with CI error bars."""
    from mgen.plots.macro import plot_macro_metrics
    from mgen.stats.confidence import summarize_with_ci
    from mgen.stats.triggers import compute_trigger

    if "Macro1" not in data:
        return []

    macro_df = data["Macro1"]
    sites = sorted(macro_df["Site"].unique())
    metrics = ["QMCI", "EPTrich", "EPTabun"]

    # Compute summaries (mean + CI per site per date per metric)
    summaries: dict[str, dict[str, list]] = {}
    triggers: dict[str, dict[str, float]] = {}

    for site in sites:
        site_df = macro_df[macro_df["Site"] == site]
        summaries[site] = {}
        triggers[site] = {}

        for metric in metrics:
            date_summaries = []
            for dt in sorted(site_df["Date"].unique()):
                values = site_df[site_df["Date"] == dt][metric]
                date_summaries.append(summarize_with_ci(values))
            summaries[site][metric] = date_summaries

            try:
                triggers[site][metric] = compute_trigger(
                    macro_df, metric_col=metric, site=site,
                    direction="decline", threshold_pct=0.15,
                )
            except ValueError:
                pass

    return plot_macro_metrics(macro_df, summaries, triggers, output_dir)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `pytest tests/test_plots/test_macro.py -v`
Expected: All 3 tests pass

- [ ] **Step 6: Run full test suite**

Run: `pytest --tb=short -q`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add src/mgen/plots/macro.py src/mgen/figures.py tests/test_plots/test_macro.py tests/test_plots/conftest.py
git commit -m "feat: add macro metric plots with 95% CI error bars"
```

---

## Phase 3: Community Analysis

### Task 10: Bray-Curtis distance matrix + NMDS

**Files:**
- Create: `src/mgen/stats/community.py`
- Create: `tests/test_stats/test_community.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_stats/test_community.py`:

```python
"""Tests for community statistics (Bray-Curtis, NMDS, ANOSIM)."""

from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from mgen.stats.community import (
    ANOSIMResult,
    NMDSResult,
    bray_curtis_matrix,
    run_anosim,
    run_nmds,
)


class TestBrayCurtisMatrix:
    @pytest.fixture
    def species_df(self) -> pd.DataFrame:
        """3 samples × 4 species."""
        return pd.DataFrame({
            "sp_A": [10, 0, 5],
            "sp_B": [0, 10, 5],
            "sp_C": [5, 5, 5],
            "sp_D": [1, 1, 1],
        })

    def test_returns_square_matrix(self, species_df: pd.DataFrame) -> None:
        result = bray_curtis_matrix(species_df)
        assert result.shape == (3, 3)

    def test_diagonal_is_zero(self, species_df: pd.DataFrame) -> None:
        result = bray_curtis_matrix(species_df)
        np.testing.assert_array_almost_equal(np.diag(result), 0.0)

    def test_symmetric(self, species_df: pd.DataFrame) -> None:
        result = bray_curtis_matrix(species_df)
        np.testing.assert_array_almost_equal(result, result.T)

    def test_values_between_0_and_1(self, species_df: pd.DataFrame) -> None:
        result = bray_curtis_matrix(species_df)
        assert np.all(result >= 0.0)
        assert np.all(result <= 1.0)

    def test_identical_samples_have_zero_distance(self) -> None:
        df = pd.DataFrame({"sp_A": [10, 10], "sp_B": [5, 5]})
        result = bray_curtis_matrix(df)
        assert result[0, 1] == pytest.approx(0.0)


class TestRunNMDS:
    @pytest.fixture
    def distance_matrix(self) -> np.ndarray:
        """Known 5×5 distance matrix with clear 2-cluster structure."""
        # Cluster 1: samples 0,1,2 (close to each other)
        # Cluster 2: samples 3,4 (close to each other, far from cluster 1)
        dm = np.array([
            [0.0, 0.1, 0.15, 0.8, 0.85],
            [0.1, 0.0, 0.12, 0.82, 0.83],
            [0.15, 0.12, 0.0, 0.79, 0.81],
            [0.8, 0.82, 0.79, 0.0, 0.1],
            [0.85, 0.83, 0.81, 0.1, 0.0],
        ])
        return dm

    def test_returns_nmds_result(self, distance_matrix: np.ndarray) -> None:
        result = run_nmds(distance_matrix, n_dims=2, seed=42)
        assert isinstance(result, NMDSResult)

    def test_correct_shape(self, distance_matrix: np.ndarray) -> None:
        result = run_nmds(distance_matrix, n_dims=2, seed=42)
        assert result.points.shape == (5, 2)

    def test_stress_is_low_for_clear_structure(self, distance_matrix: np.ndarray) -> None:
        result = run_nmds(distance_matrix, n_dims=2, seed=42)
        assert result.stress < 0.2

    def test_deterministic_with_seed(self, distance_matrix: np.ndarray) -> None:
        r1 = run_nmds(distance_matrix, n_dims=2, seed=42)
        r2 = run_nmds(distance_matrix, n_dims=2, seed=42)
        np.testing.assert_array_almost_equal(r1.points, r2.points)


class TestRunANOSIM:
    def test_significant_for_distinct_groups(self) -> None:
        # Two very distinct groups
        dm = np.array([
            [0.0, 0.1, 0.9, 0.9],
            [0.1, 0.0, 0.9, 0.9],
            [0.9, 0.9, 0.0, 0.1],
            [0.9, 0.9, 0.1, 0.0],
        ])
        groups = pd.Series(["A", "A", "B", "B"])
        result = run_anosim(dm, groups, permutations=999, seed=42)
        assert isinstance(result, ANOSIMResult)
        assert result.R_statistic > 0.5
        assert result.p_value < 0.05

    def test_not_significant_for_random_groups(self) -> None:
        rng = np.random.default_rng(42)
        dm = np.zeros((10, 10))
        for i in range(10):
            for j in range(i + 1, 10):
                dm[i, j] = dm[j, i] = rng.uniform(0.3, 0.7)
        groups = pd.Series(["A"] * 5 + ["B"] * 5)
        result = run_anosim(dm, groups, permutations=999, seed=42)
        assert result.p_value > 0.05 or result.R_statistic < 0.25
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_stats/test_community.py -v`
Expected: ImportError — `mgen.stats.community` does not exist

- [ ] **Step 3: Implement community stats module**

Create `src/mgen/stats/community.py`:

```python
"""Community ecology statistics: Bray-Curtis, NMDS, ANOSIM, indicator species.

Pure computation — no plotting. Results are consumed by plots/community.py
and exports/community_tables.py.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
from scipy.spatial.distance import pdist, squareform
from sklearn.manifold import MDS

__all__ = [
    "ANOSIMResult",
    "IndicatorSpecies",
    "NMDSResult",
    "bray_curtis_matrix",
    "envfit_species_drivers",
    "indicator_species_analysis",
    "run_anosim",
    "run_nmds",
]


@dataclass(frozen=True)
class NMDSResult:
    """Result from non-metric multidimensional scaling.

    Attributes:
        points: Array of shape (n_samples, n_dims) with ordination coordinates.
        stress: Stress value (lower is better; <0.2 is acceptable).
    """

    points: np.ndarray
    stress: float


@dataclass(frozen=True)
class ANOSIMResult:
    """Result from Analysis of Similarities.

    Attributes:
        R_statistic: ANOSIM R (range -1 to 1; >0 = between-group > within-group).
        p_value: Permutation-based p-value.
        permutations: Number of permutations used.
    """

    R_statistic: float
    p_value: float
    permutations: int


@dataclass(frozen=True)
class IndicatorSpecies:
    """A species identified as an indicator for a group.

    Attributes:
        species: Species name.
        group: Group the species indicates.
        stat: IndVal statistic (0-1).
        p_value: Permutation-based p-value.
    """

    species: str
    group: str
    stat: float
    p_value: float


def bray_curtis_matrix(species_df: pd.DataFrame) -> np.ndarray:
    """Compute pairwise Bray-Curtis dissimilarity matrix.

    Args:
        species_df: DataFrame where rows are samples and columns are species counts.

    Returns:
        Square symmetric matrix of shape (n_samples, n_samples).
    """
    condensed = pdist(species_df.values, metric="braycurtis")
    return squareform(condensed)


def run_nmds(
    distance_matrix: np.ndarray,
    n_dims: int = 2,
    seed: int = 42,
    max_iter: int = 300,
) -> NMDSResult:
    """Non-metric multidimensional scaling.

    Uses scikit-learn's MDS with metric=False (non-metric) and
    dissimilarity='precomputed'.

    Args:
        distance_matrix: Square symmetric distance matrix.
        n_dims: Number of dimensions for the ordination (default 2).
        seed: Random seed for reproducibility.
        max_iter: Maximum iterations for the optimization.

    Returns:
        NMDSResult with ordination points and stress value.
    """
    mds = MDS(
        n_components=n_dims,
        metric=False,
        dissimilarity="precomputed",
        random_state=seed,
        max_iter=max_iter,
        normalized_stress=True,
    )
    points = mds.fit_transform(distance_matrix)
    return NMDSResult(points=points, stress=mds.stress_)


def run_anosim(
    distance_matrix: np.ndarray,
    groups: pd.Series,
    permutations: int = 999,
    seed: int = 42,
) -> ANOSIMResult:
    """Analysis of Similarities (ANOSIM) with permutation test.

    Tests whether between-group dissimilarity is greater than within-group.

    Args:
        distance_matrix: Square symmetric distance matrix.
        groups: Group label for each sample (same length as matrix dimension).
        permutations: Number of permutations for the null distribution.
        seed: Random seed for reproducibility.

    Returns:
        ANOSIMResult with R statistic and p-value.
    """
    rng = np.random.default_rng(seed)
    n = len(groups)

    def _compute_r(dm: np.ndarray, grp: np.ndarray) -> float:
        """Compute ANOSIM R statistic from ranked distances."""
        ranks = np.zeros_like(dm)
        condensed = dm[np.triu_indices(n, k=1)]
        rank_vals = condensed.argsort().argsort() + 1
        idx = 0
        for i in range(n):
            for j in range(i + 1, n):
                ranks[i, j] = ranks[j, i] = rank_vals[idx]
                idx += 1

        within_ranks = []
        between_ranks = []
        for i in range(n):
            for j in range(i + 1, n):
                if grp[i] == grp[j]:
                    within_ranks.append(ranks[i, j])
                else:
                    between_ranks.append(ranks[i, j])

        if not within_ranks or not between_ranks:
            return 0.0

        r_b = np.mean(between_ranks)
        r_w = np.mean(within_ranks)
        n_pairs = n * (n - 1) / 2
        return (r_b - r_w) / (n_pairs / 2)

    groups_arr = groups.values
    observed_r = _compute_r(distance_matrix, groups_arr)

    count_ge = 0
    for _ in range(permutations):
        perm_groups = rng.permutation(groups_arr)
        perm_r = _compute_r(distance_matrix, perm_groups)
        if perm_r >= observed_r:
            count_ge += 1

    p_value = (count_ge + 1) / (permutations + 1)

    return ANOSIMResult(R_statistic=observed_r, p_value=p_value, permutations=permutations)


def indicator_species_analysis(
    species_df: pd.DataFrame,
    groups: pd.Series,
    permutations: int = 999,
    seed: int = 42,
    p_threshold: float = 0.05,
) -> list[IndicatorSpecies]:
    """Indicator Value (IndVal) analysis.

    Implements the Dufrêne & Legendre (1997) IndVal index with
    permutation-based significance testing.

    Args:
        species_df: DataFrame where rows are samples, columns are species.
        groups: Group label for each sample.
        permutations: Number of permutations for significance testing.
        seed: Random seed for reproducibility.
        p_threshold: Only return species with p <= this value.

    Returns:
        List of significant indicator species, sorted by stat descending.
    """
    rng = np.random.default_rng(seed)
    unique_groups = groups.unique()
    results: list[IndicatorSpecies] = []

    for species in species_df.columns:
        abundances = species_df[species].values
        best_indval = 0.0
        best_group = unique_groups[0]

        for group in unique_groups:
            mask = groups == group
            # Specificity: mean abundance in group / mean abundance across all groups
            mean_in = abundances[mask].mean()
            mean_all = abundances.mean()
            specificity = mean_in / mean_all if mean_all > 0 else 0.0
            # Fidelity: proportion of group samples where species is present
            fidelity = (abundances[mask] > 0).sum() / mask.sum()
            indval = specificity * fidelity

            if indval > best_indval:
                best_indval = indval
                best_group = group

        # Permutation test
        count_ge = 0
        for _ in range(permutations):
            perm_groups = rng.permutation(groups.values)
            for group in unique_groups:
                mask = perm_groups == group
                mean_in = abundances[mask].mean()
                mean_all = abundances.mean()
                spec = mean_in / mean_all if mean_all > 0 else 0.0
                fid = (abundances[mask] > 0).sum() / mask.sum()
                if spec * fid >= best_indval:
                    count_ge += 1
                    break

        p_value = (count_ge + 1) / (permutations + 1)
        if p_value <= p_threshold:
            results.append(IndicatorSpecies(
                species=species, group=best_group, stat=best_indval, p_value=p_value,
            ))

    return sorted(results, key=lambda x: x.stat, reverse=True)


def envfit_species_drivers(
    nmds_points: np.ndarray,
    species_df: pd.DataFrame,
    permutations: int = 999,
    seed: int = 42,
) -> pd.DataFrame:
    """Fit species vectors onto ordination space.

    For each species, computes correlation (R²) between species abundance
    and NMDS axis scores using linear regression. Permutation-based p-values.

    Args:
        nmds_points: Array of shape (n_samples, 2) — NMDS1/NMDS2 coordinates.
        species_df: DataFrame with species abundance per sample.
        permutations: Number of permutations for significance testing.
        seed: Random seed.

    Returns:
        DataFrame with columns: Species, NMDS1_corr, NMDS2_corr, R2, p_value.
    """
    rng = np.random.default_rng(seed)
    results = []

    for species in species_df.columns:
        abundances = species_df[species].values.astype(float)
        if abundances.std() == 0:
            continue

        # Center abundances
        centered = abundances - abundances.mean()
        # Project onto each axis
        corr1 = np.corrcoef(centered, nmds_points[:, 0])[0, 1]
        corr2 = np.corrcoef(centered, nmds_points[:, 1])[0, 1]
        r2 = corr1**2 + corr2**2

        # Permutation test for R²
        count_ge = 0
        for _ in range(permutations):
            perm = rng.permutation(centered)
            pc1 = np.corrcoef(perm, nmds_points[:, 0])[0, 1]
            pc2 = np.corrcoef(perm, nmds_points[:, 1])[0, 1]
            if pc1**2 + pc2**2 >= r2:
                count_ge += 1

        p_value = (count_ge + 1) / (permutations + 1)
        results.append({
            "Species": species,
            "NMDS1_corr": corr1,
            "NMDS2_corr": corr2,
            "R2": r2,
            "p_value": p_value,
        })

    return pd.DataFrame(results)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_stats/test_community.py -v`
Expected: All 9 tests pass

- [ ] **Step 5: Run ruff**

Run: `ruff check src/mgen/stats/community.py tests/test_stats/test_community.py`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add src/mgen/stats/community.py tests/test_stats/test_community.py
git commit -m "feat: add community stats (Bray-Curtis, NMDS, ANOSIM, IndVal)"
```

---

### Task 11: NMDS ordination plots

**Files:**
- Create: `src/mgen/plots/community.py`
- Create: `tests/test_plots/test_community.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_plots/test_community.py`:

```python
"""Tests for community ordination plot rendering."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest

from mgen.plots.community import plot_nmds_ordination
from mgen.stats.community import NMDSResult


class TestPlotNMDSOrdination:
    @pytest.fixture
    def nmds_result(self) -> NMDSResult:
        """Simple 6-point NMDS result with 2 clusters."""
        points = np.array([
            [-1.0, -0.5],
            [-0.8, 0.5],
            [-1.2, 0.0],
            [1.0, -0.3],
            [0.8, 0.4],
            [1.1, 0.1],
        ])
        return NMDSResult(points=points, stress=0.05)

    @pytest.fixture
    def labels(self) -> dict:
        return {
            "sites": ["EM1", "EM1", "EM2", "EM2", "EM3", "EM3"],
            "periods": [
                "Baseline", "Construction",
                "Baseline", "Construction",
                "Baseline", "Construction",
            ],
        }

    def test_returns_file_paths(self, tmp_path: Path, nmds_result, labels) -> None:
        paths = plot_nmds_ordination(
            nmds_result, subset_name="all",
            sites=labels["sites"], periods=labels["periods"],
            output_dir=tmp_path,
        )
        assert len(paths) > 0
        for p in paths:
            assert p.exists()

    def test_creates_png_and_pdf(self, tmp_path: Path, nmds_result, labels) -> None:
        paths = plot_nmds_ordination(
            nmds_result, subset_name="all",
            sites=labels["sites"], periods=labels["periods"],
            output_dir=tmp_path,
        )
        extensions = {p.suffix for p in paths}
        assert ".png" in extensions
        assert ".pdf" in extensions

    def test_with_convex_hulls(self, tmp_path: Path, nmds_result, labels) -> None:
        paths = plot_nmds_ordination(
            nmds_result, subset_name="all",
            sites=labels["sites"], periods=labels["periods"],
            output_dir=tmp_path, show_hulls=True,
        )
        assert len(paths) > 0

    def test_file_name_contains_subset(self, tmp_path: Path, nmds_result, labels) -> None:
        paths = plot_nmds_ordination(
            nmds_result, subset_name="baseline",
            sites=labels["sites"], periods=labels["periods"],
            output_dir=tmp_path,
        )
        assert any("baseline" in p.stem for p in paths)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_plots/test_community.py -v`
Expected: ImportError — `mgen.plots.community` does not exist

- [ ] **Step 3: Implement community plots**

Create `src/mgen/plots/community.py`:

```python
"""NMDS ordination scatter plots with convex hulls and trend arrows.

Renders pre-computed NMDS coordinates as scatter plots, with optional
per-site convex hulls and temporal trend arrows.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from scipy.spatial import ConvexHull

from mgen.plots._style import PERIOD_COLORS, save_figure
from mgen.stats.community import NMDSResult

__all__ = ["plot_nmds_ordination"]

_SITE_COLORS = {
    "EM1": "#1b9e77", "EM2": "#d95f02", "EM3": "#7570b3",
    "EM4": "#e7298a", "EM5": "#66a61e", "EM7": "#e6ab02", "EM8": "#a6761d",
}

_PERIOD_MARKERS = {"Baseline": "o", "Routine Construction": "^", "Incident": "s"}


def plot_nmds_ordination(
    nmds: NMDSResult,
    subset_name: str,
    sites: list[str],
    periods: list[str],
    output_dir: Path,
    show_hulls: bool = True,
    show_arrows: bool = False,
) -> list[Path]:
    """Create NMDS ordination scatter plot.

    Args:
        nmds: NMDSResult with points array (n_samples, 2).
        subset_name: Label for this subset (used in filename).
        sites: Site label for each sample point.
        periods: Period label for each sample point.
        output_dir: Directory to save output files.
        show_hulls: Draw convex hulls per site.
        show_arrows: Draw trend arrows from baseline to construction centroid.

    Returns:
        List of paths to saved figure files.
    """
    fig, ax = plt.subplots(figsize=(10, 8))
    points = nmds.points

    unique_sites = sorted(set(sites))

    for site in unique_sites:
        site_mask = np.array([s == site for s in sites])
        color = _SITE_COLORS.get(site, "gray")

        for period, marker in _PERIOD_MARKERS.items():
            period_mask = np.array([p == period for p in periods])
            mask = site_mask & period_mask
            if mask.any():
                ax.scatter(
                    points[mask, 0], points[mask, 1],
                    c=color, marker=marker, s=50, label=f"{site} ({period})",
                    alpha=0.8, zorder=3,
                )

        # Convex hull per site
        if show_hulls and site_mask.sum() >= 3:
            site_points = points[site_mask]
            try:
                hull = ConvexHull(site_points)
                hull_pts = site_points[hull.vertices]
                hull_pts = np.vstack([hull_pts, hull_pts[0]])
                ax.plot(hull_pts[:, 0], hull_pts[:, 1], c=color, alpha=0.3, linewidth=1)
                ax.fill(hull_pts[:, 0], hull_pts[:, 1], c=color, alpha=0.05)
            except Exception:  # noqa: BLE001
                pass  # Not enough non-collinear points for hull

        # Trend arrows (baseline centroid → construction centroid)
        if show_arrows:
            baseline_mask = site_mask & np.array([p == "Baseline" for p in periods])
            construction_mask = site_mask & np.array([p == "Routine Construction" for p in periods])
            if baseline_mask.any() and construction_mask.any():
                bl_centroid = points[baseline_mask].mean(axis=0)
                cn_centroid = points[construction_mask].mean(axis=0)
                ax.annotate(
                    "", xy=cn_centroid, xytext=bl_centroid,
                    arrowprops={"arrowstyle": "->", "color": color, "lw": 1.5},
                )

    ax.set_xlabel("NMDS1")
    ax.set_ylabel("NMDS2")
    ax.set_title(f"NMDS Ordination — {subset_name} (stress={nmds.stress:.3f})")
    ax.axhline(0, color="gray", linewidth=0.5, alpha=0.5)
    ax.axvline(0, color="gray", linewidth=0.5, alpha=0.5)

    # Deduplicate legend
    handles, labels_list = ax.get_legend_handles_labels()
    by_label = dict(zip(labels_list, handles))
    ax.legend(by_label.values(), by_label.keys(), loc="best", fontsize=7, ncol=2)

    fig.tight_layout()
    return save_figure(fig, output_dir / f"nmds_{subset_name}")
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_plots/test_community.py -v`
Expected: All 4 tests pass

- [ ] **Step 5: Run ruff**

Run: `ruff check src/mgen/plots/community.py tests/test_plots/test_community.py`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add src/mgen/plots/community.py tests/test_plots/test_community.py
git commit -m "feat: add NMDS ordination plots with convex hulls"
```

---

### Task 12: Community Excel table exports

**Files:**
- Create: `src/mgen/exports/__init__.py`
- Create: `src/mgen/exports/community_tables.py`
- Create: `tests/test_exports/__init__.py`
- Create: `tests/test_exports/test_community_tables.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_exports/__init__.py` (empty) and `tests/test_exports/test_community_tables.py`:

```python
"""Tests for community analysis Excel exports."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from mgen.exports.community_tables import (
    export_dissimilarity_table,
    export_indicator_species,
    export_species_drivers,
)
from mgen.stats.community import IndicatorSpecies


class TestExportDissimilarityTable:
    def test_creates_xlsx(self, tmp_path: Path) -> None:
        dm = np.array([[0.0, 0.5, 0.8], [0.5, 0.0, 0.6], [0.8, 0.6, 0.0]])
        labels = ["EM1_2021", "EM1_2022", "EM2_2021"]
        path = export_dissimilarity_table(dm, labels, tmp_path / "dissimilarity.xlsx")
        assert path.exists()
        df = pd.read_excel(path, index_col=0)
        assert list(df.columns) == labels
        assert list(df.index) == labels


class TestExportIndicatorSpecies:
    def test_creates_xlsx(self, tmp_path: Path) -> None:
        indicators = [
            IndicatorSpecies(species="Deleatidium", group="EM1", stat=0.85, p_value=0.001),
            IndicatorSpecies(species="Potamopyrgus", group="EM2", stat=0.72, p_value=0.01),
        ]
        path = export_indicator_species(indicators, tmp_path / "indicators.xlsx")
        assert path.exists()
        df = pd.read_excel(path)
        assert len(df) == 2
        assert "species" in df.columns or "Species" in df.columns


class TestExportSpeciesDrivers:
    def test_creates_xlsx(self, tmp_path: Path) -> None:
        drivers = pd.DataFrame({
            "Species": ["sp_A", "sp_B"],
            "NMDS1_corr": [0.8, -0.3],
            "NMDS2_corr": [0.2, 0.7],
            "R2": [0.68, 0.58],
            "p_value": [0.001, 0.01],
        })
        path = export_species_drivers(drivers, tmp_path / "drivers.xlsx")
        assert path.exists()
        df = pd.read_excel(path)
        assert len(df) == 2
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_exports/ -v`
Expected: ImportError — `mgen.exports.community_tables` does not exist

- [ ] **Step 3: Implement exports module**

Create `src/mgen/exports/__init__.py`:

```python
"""Export modules for non-visual file outputs (Excel tables)."""
```

Create `src/mgen/exports/community_tables.py`:

```python
"""Export community analysis results to Excel tables.

Writes dissimilarity matrices, indicator species lists, and species
driver tables as formatted .xlsx files for inclusion in reports.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from mgen.stats.community import IndicatorSpecies

__all__ = [
    "export_dissimilarity_table",
    "export_indicator_species",
    "export_species_drivers",
]


def export_dissimilarity_table(
    distance_matrix: np.ndarray,
    labels: list[str],
    output_path: Path,
) -> Path:
    """Write Bray-Curtis dissimilarity matrix to xlsx.

    Args:
        distance_matrix: Square symmetric distance matrix.
        labels: Row/column labels (e.g. "EM1_2021-03").
        output_path: Path to write the .xlsx file.

    Returns:
        Path to the written file.
    """
    df = pd.DataFrame(distance_matrix, index=labels, columns=labels)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_excel(output_path)
    return output_path


def export_indicator_species(
    indicators: list[IndicatorSpecies],
    output_path: Path,
) -> Path:
    """Write significant indicator species to xlsx.

    Args:
        indicators: List of IndicatorSpecies results.
        output_path: Path to write the .xlsx file.

    Returns:
        Path to the written file.
    """
    rows = [
        {"Species": ind.species, "Group": ind.group, "IndVal": ind.stat, "p_value": ind.p_value}
        for ind in indicators
    ]
    df = pd.DataFrame(rows)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_excel(output_path, index=False)
    return output_path


def export_species_drivers(
    envfit_results: pd.DataFrame,
    output_path: Path,
) -> Path:
    """Write envfit species drivers to xlsx.

    Args:
        envfit_results: DataFrame with Species, NMDS1_corr, NMDS2_corr, R2, p_value.
        output_path: Path to write the .xlsx file.

    Returns:
        Path to the written file.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)
    envfit_results.to_excel(output_path, index=False)
    return output_path
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_exports/ -v`
Expected: All 3 tests pass

- [ ] **Step 5: Commit**

```bash
git add src/mgen/exports/ tests/test_exports/
git commit -m "feat: add community analysis Excel table exports"
```

---

### Task 13: Wire community analysis into orchestrator

**Files:**
- Modify: `src/mgen/figures.py`
- Create: `tests/test_figures.py`

- [ ] **Step 1: Write the failing integration test**

Create `tests/test_figures.py`:

```python
"""Integration tests for the figure generation orchestrator."""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import pytest

from mgen.figures import FigureResult, generate_figures


@pytest.fixture
def data_xlsx_sheets(sediment_df, sediment_size_df, macro1_df) -> dict[str, pd.DataFrame]:
    """Minimal Data.xlsx content for all required sheets."""
    # Build a species matrix for community analysis
    species_df = pd.DataFrame({
        "Phase": ["Baseline"] * 6 + ["Routine Construction"] * 6,
        "Date": pd.to_datetime(["2021-03-15"] * 6 + ["2022-06-15"] * 6),
        "Site": ["EM1", "EM1", "EM2", "EM2", "EM3", "EM3"] * 2,
        "Taxa": ["Mayflies"] * 12,
        "Species": ["Deleatidium", "Potamopyrgus"] * 6,
        "Tally": [10, 2, 3, 15, 8, 5, 12, 1, 2, 18, 6, 7],
    })
    return {
        "Sediment": sediment_df,
        "SedimentSize": sediment_size_df,
        "Macro1": macro1_df,
        "Macro": macro1_df.groupby(["Site", "Date", "Period", "Season"], as_index=False).mean(numeric_only=True),
        "MacroSpecies": species_df,
    }


class TestGenerateFigures:
    def test_sediment_only(self, tmp_path: Path, data_xlsx_sheets) -> None:
        result = generate_figures(data_xlsx_sheets, tmp_path, only="sediment")
        assert result.success
        assert any("sediment" in p.stem for p in result.files_written)

    def test_returns_figure_result(self, tmp_path: Path, data_xlsx_sheets) -> None:
        result = generate_figures(data_xlsx_sheets, tmp_path, only="sediment")
        assert isinstance(result, FigureResult)

    def test_all_generates_multiple_types(self, tmp_path: Path, data_xlsx_sheets) -> None:
        result = generate_figures(data_xlsx_sheets, tmp_path, only="all")
        assert result.success
        stems = [p.stem for p in result.files_written]
        assert any("sediment" in s for s in stems)
```

- [ ] **Step 2: Run test to verify it fails (community not wired)**

Run: `pytest tests/test_figures.py -v`
Expected: Tests may pass partially — depends on fixture availability. Focus on ensuring the orchestrator test structure is correct.

- [ ] **Step 3: Implement _generate_community in figures.py**

Replace the placeholder in `src/mgen/figures.py`:

```python
def _generate_community(
    data: dict[str, pd.DataFrame], output_dir: Path, result: FigureResult
) -> list[Path]:
    """Generate NMDS plots and export Excel tables."""
    from mgen.exports.community_tables import (
        export_dissimilarity_table,
        export_indicator_species,
        export_species_drivers,
    )
    from mgen.plots.community import plot_nmds_ordination
    from mgen.stats.community import (
        bray_curtis_matrix,
        envfit_species_drivers,
        indicator_species_analysis,
        run_anosim,
        run_nmds,
    )

    if "MacroSpecies" not in data:
        return []

    macro_species = data["MacroSpecies"]
    paths: list[Path] = []

    # Pivot to site-date × species matrix
    pivot = macro_species.pivot_table(
        index=["Site", "Date"], columns="Species", values="Tally", fill_value=0,
    )

    if len(pivot) < 4:
        result.warnings.append("Too few samples for NMDS (need >= 4)")
        return []

    # Compute distance matrix
    dm = bray_curtis_matrix(pivot)

    # Export dissimilarity table
    labels = [f"{s}_{d.strftime('%Y-%m')}" for s, d in pivot.index]
    paths.append(export_dissimilarity_table(dm, labels, output_dir / "dissimilarity.xlsx"))

    # Run NMDS
    nmds = run_nmds(dm, n_dims=2, seed=42)

    # Site/period labels for plot
    sites = [s for s, _ in pivot.index]
    periods_raw = []
    for site, dt in pivot.index:
        mask = (macro_species["Site"] == site) & (macro_species["Date"] == dt)
        period = macro_species.loc[mask, "Phase"].iloc[0] if mask.any() else "Unknown"
        periods_raw.append(period)

    # All-sites NMDS plot
    paths.extend(plot_nmds_ordination(
        nmds, subset_name="all", sites=sites, periods=periods_raw,
        output_dir=output_dir, show_hulls=True,
    ))

    # ANOSIM
    site_groups = pd.Series(sites)
    anosim = run_anosim(dm, site_groups, permutations=999, seed=42)
    if anosim.p_value > 0.05:
        result.warnings.append(f"ANOSIM not significant (R={anosim.R_statistic:.3f}, p={anosim.p_value:.3f})")

    # Indicator species
    indicators = indicator_species_analysis(pivot, site_groups, permutations=999, seed=42)
    if indicators:
        paths.append(export_indicator_species(indicators, output_dir / "indicator_species.xlsx"))

    # Envfit species drivers
    drivers = envfit_species_drivers(nmds.points, pivot, permutations=999, seed=42)
    significant_drivers = drivers[drivers["p_value"] <= 0.05]
    if not significant_drivers.empty:
        paths.append(export_species_drivers(significant_drivers, output_dir / "species_drivers.xlsx"))

    return paths
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_figures.py -v`
Expected: All tests pass

- [ ] **Step 5: Run full test suite**

Run: `pytest --tb=short -q`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add src/mgen/figures.py tests/test_figures.py
git commit -m "feat: wire community analysis into figure orchestrator"
```

---

## Phase 4: Polish & Golden Images

### Task 14: Golden image testing infrastructure

**Files:**
- Create: `tests/assets/golden_figures/.gitkeep`
- Modify: `tests/test_plots/conftest.py`
- Modify: `pyproject.toml` (add golden marker)

- [ ] **Step 1: Add pytest marker and conftest infrastructure**

Add to `pyproject.toml` under `[tool.pytest.ini_options]`:

```toml
markers = [
    "golden: golden image comparison tests (may produce CI artifacts)",
]
```

Add to `tests/test_plots/conftest.py`:

```python
from pathlib import Path

import numpy as np
from PIL import Image

GOLDEN_DIR = Path(__file__).parent.parent / "assets" / "golden_figures"


@pytest.fixture
def golden_dir() -> Path:
    """Path to golden figure reference images."""
    return GOLDEN_DIR


def assert_image_similar(actual_path: Path, golden_path: Path, threshold: float = 0.95) -> None:
    """Assert two images are similar using normalized cross-correlation.

    Args:
        actual_path: Path to the generated image.
        golden_path: Path to the reference golden image.
        threshold: Minimum similarity score (0-1). Default 0.95.

    Raises:
        AssertionError: If images differ beyond threshold.
    """
    if not golden_path.exists():
        pytest.skip(f"Golden image not found: {golden_path}")

    actual = np.array(Image.open(actual_path).convert("L")).astype(float)
    golden = np.array(Image.open(golden_path).convert("L")).astype(float)

    if actual.shape != golden.shape:
        pytest.fail(f"Image dimensions differ: {actual.shape} vs {golden.shape}")

    # Normalized cross-correlation
    a_norm = (actual - actual.mean()) / (actual.std() + 1e-10)
    g_norm = (golden - golden.mean()) / (golden.std() + 1e-10)
    similarity = np.mean(a_norm * g_norm)

    assert similarity >= threshold, (
        f"Image similarity {similarity:.4f} below threshold {threshold}"
    )
```

- [ ] **Step 2: Add Pillow to test dependencies**

In `pyproject.toml` under `[dependency-groups] test`:

```toml
test = [
    "coverage[toml]>=7.9.1",
    "pytest>=8.4.0",
    "pytest-cov>=6.1.1",
    "pillow>=10.0",
]
```

- [ ] **Step 3: Create golden figures directory**

```bash
mkdir -p tests/assets/golden_figures
touch tests/assets/golden_figures/.gitkeep
```

- [ ] **Step 4: Add --update-golden conftest hook**

Add to `tests/test_plots/conftest.py`:

```python
import shutil

def pytest_addoption(parser):
    parser.addoption("--update-golden", action="store_true", help="Regenerate golden reference images")


@pytest.fixture
def update_golden(request) -> bool:
    return request.config.getoption("--update-golden")
```

- [ ] **Step 5: Install updated deps**

Run: `uv sync`
Expected: Installs Pillow

- [ ] **Step 6: Commit**

```bash
git add tests/assets/golden_figures/.gitkeep tests/test_plots/conftest.py pyproject.toml
git commit -m "feat: add golden image testing infrastructure"
```

---

### Task 15: Add golden image tests for sediment plots

**Files:**
- Modify: `tests/test_plots/test_sediment.py`

- [ ] **Step 1: Add golden tests**

Add to `tests/test_plots/test_sediment.py`:

```python
@pytest.mark.golden
class TestSedimentSizeGolden:
    def test_em1_matches_golden(
        self, tmp_path: Path, sediment_size_df, golden_dir, update_golden
    ) -> None:
        from tests.test_plots.conftest import assert_image_similar

        paths = plot_sediment_size_distribution(sediment_size_df, tmp_path)
        actual = next(p for p in paths if "EM1" in p.stem and p.suffix == ".png")

        golden_path = golden_dir / "sediment_size_EM1.png"
        if update_golden:
            import shutil
            golden_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(actual, golden_path)
            pytest.skip("Golden image updated")

        assert_image_similar(actual, golden_path)
```

- [ ] **Step 2: Generate initial golden images**

Run: `pytest tests/test_plots/test_sediment.py::TestSedimentSizeGolden --update-golden -v`
Expected: Tests skip with "Golden image updated"

- [ ] **Step 3: Run golden tests normally**

Run: `pytest tests/test_plots/test_sediment.py::TestSedimentSizeGolden -v`
Expected: Pass (images match themselves)

- [ ] **Step 4: Commit golden images**

```bash
git add tests/assets/golden_figures/ tests/test_plots/test_sediment.py
git commit -m "test: add golden image tests for sediment size plots"
```

---

### Task 16: Final integration test — end-to-end

**Files:**
- Modify: `tests/test_figures.py`

- [ ] **Step 1: Add end-to-end test using real fixture data**

Add to `tests/test_figures.py`:

```python
class TestEndToEndWithRealData:
    """Integration test using the real example databases."""

    @pytest.fixture
    def real_data(self, expected_data_xlsx: Path) -> dict[str, pd.DataFrame]:
        """Load the golden Data.xlsx as figure input."""
        data = {}
        with pd.ExcelFile(expected_data_xlsx) as xls:
            for sheet in xls.sheet_names:
                data[sheet] = pd.read_excel(xls, sheet_name=sheet)
        return data

    def test_generates_sediment_figures(self, tmp_path: Path, real_data) -> None:
        result = generate_figures(real_data, tmp_path, only="sediment")
        assert result.success
        png_files = [p for p in result.files_written if p.suffix == ".png"]
        assert len(png_files) >= 6  # At least 6 sites worth of plots

    def test_generates_macro_figures(self, tmp_path: Path, real_data) -> None:
        result = generate_figures(real_data, tmp_path, only="macro")
        assert result.success
        png_files = [p for p in result.files_written if p.suffix == ".png"]
        assert len(png_files) >= 1

    def test_generates_community_outputs(self, tmp_path: Path, real_data) -> None:
        result = generate_figures(real_data, tmp_path, only="community")
        # May produce warnings (e.g. not enough data) but should not crash
        assert isinstance(result, FigureResult)
```

- [ ] **Step 2: Run integration tests**

Run: `pytest tests/test_figures.py::TestEndToEndWithRealData -v`
Expected: All pass (or skip gracefully if fixture data lacks enough samples for NMDS)

- [ ] **Step 3: Run full test suite**

Run: `pytest --tb=short -q`
Expected: All tests pass

- [ ] **Step 4: Run ruff on entire project**

Run: `ruff check src/mgen/ tests/`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add tests/test_figures.py
git commit -m "test: add end-to-end integration tests for figure generation"
```

---

## Summary

| Phase | Tasks | Key deliverable |
|---|---|---|
| 1: Foundation | 1-7 | Stats modules + style + sediment bars + CLI command |
| 2: Time-series | 8-9 | Sediment SAM + Macro CI error bar plots |
| 3: Community | 10-13 | NMDS, ANOSIM, IndVal, ordination plots, Excel exports |
| 4: Polish | 14-16 | Golden image testing, end-to-end integration |

Total: 16 tasks, each independently committable and testable.
