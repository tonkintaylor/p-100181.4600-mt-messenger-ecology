"""Generate Python plots and build a side-by-side HTML comparison report.

Usage:
    python scripts/compare_outputs.py

Reads Data.xlsx from ref/, generates Python figures to a temp directory,
then produces an HTML report comparing R reference images (left) against
Python outputs (right).
"""

from __future__ import annotations

import base64
import shutil
from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parent.parent
REF_DIR = REPO_ROOT / "ref"
DATA_XLSX = REF_DIR / "Data.xlsx"
OUTPUT_DIR = REPO_ROOT / "comparison_output"
PYTHON_DIR = OUTPUT_DIR / "python"
REPORT_PATH = OUTPUT_DIR / "comparison_report.html"


# ---------------------------------------------------------------------------
# Mapping: R reference images -> Python output filenames
# ---------------------------------------------------------------------------


def _build_mapping() -> list[dict[str, str | Path | None]]:
    """Build list of comparison entries linking R refs to Python outputs.

    Each entry: {category, label, r_path, python_glob}
    """
    entries: list[dict[str, str | Path | None]] = []

    # --- Sediment Size ---
    sed_size_dir = REF_DIR / "MacroOutput" / "Sediment Size"
    if sed_size_dir.exists():
        for f in sorted(sed_size_dir.glob("SedimentSizeStack_*.jpg")):
            site = f.stem.replace("SedimentSizeStack_", "")
            entries.append(
                {
                    "category": "Sediment Size Distribution",
                    "label": site,
                    "r_path": f,
                    "python_glob": f"sediment_size_{site}.png",
                }
            )

    # --- Sediment Time-series (SAM1) ---
    sed_ts_dir = REF_DIR / "MacroOutput" / "SAM1 SAM3 Sediment"
    if sed_ts_dir.exists():
        for f in sorted(sed_ts_dir.glob("*.SAM1plot.jpg")):
            site = f.stem.split(".")[0]
            entries.append(
                {
                    "category": "Sediment Time-series (SAM1)",
                    "label": site,
                    "r_path": f,
                    "python_glob": f"sediment_timeseries_{site}.png",
                }
            )

    # --- Macro Metric Plots ---
    macro_dir = REF_DIR / "metric_plots_jpeg"
    if macro_dir.exists():
        for f in sorted(macro_dir.glob("*_QMCI_DRAFT.jpg")):
            site = f.stem.split("_")[0]
            entries.append(
                {
                    "category": "Macro Metrics (3-panel)",
                    "label": site,
                    "r_path": f,
                    "python_glob": f"macro_{site}.png",
                }
            )

    # --- NMDS All Sites ---
    nmds_dir = REF_DIR / "MacroOutput" / "NMDS"
    if nmds_dir.exists():
        nmds_all = nmds_dir / "NMDS_All.jpeg"
        if nmds_all.exists():
            entries.append(
                {
                    "category": "NMDS Ordination",
                    "label": "All Sites",
                    "r_path": nmds_all,
                    "python_glob": "NMDS_AllSites.png",
                }
            )
        for f in sorted(nmds_dir.glob("NMDS_EM*.jpeg")):
            site = f.stem.replace("NMDS_", "")
            entries.append(
                {
                    "category": "NMDS Per-Site",
                    "label": site,
                    "r_path": f,
                    "python_glob": f"NMDS_PerSite_{site}.png",
                }
            )

    # --- NMDS Arrow plots ---
    arrow_dir = REF_DIR / "NMDS Arrow and label plots"
    if arrow_dir.exists():
        for f in sorted(arrow_dir.glob("*_NMDS.jpeg")):
            site = f.stem.replace("_NMDS", "").replace("_Control", "")
            entries.append(
                {
                    "category": "NMDS Arrow + Label Plots",
                    "label": site,
                    "r_path": f,
                    "python_glob": f"NMDS_PerSite_{site}.png",
                }
            )

    return entries


# ---------------------------------------------------------------------------
# Generate Python figures
# ---------------------------------------------------------------------------


def _load_data() -> dict[str, pd.DataFrame]:
    """Load Data.xlsx with column name normalization."""
    data: dict[str, pd.DataFrame] = {}
    with pd.ExcelFile(DATA_XLSX) as xls:
        for sheet in xls.sheet_names:
            df = pd.read_excel(xls, sheet_name=sheet)
            # Strip whitespace from column names (Data.xlsx has 'Site ' etc.)
            df.columns = [c.strip() for c in df.columns]
            data[sheet] = df

    # Build a Community matrix from MacroSpecies if no Community sheet exists
    if "Community" not in data and "MacroSpecies" in data:
        sp = data["MacroSpecies"].copy()
        if "Tally" not in sp.columns and "Tally " in data["MacroSpecies"].columns:
            sp = sp.rename(columns={"Tally ": "Tally"})
        # Pivot: rows = (Date, Site), columns = Species, values = Tally
        if {"Date", "Site", "Species", "Tally"}.issubset(sp.columns):
            pivot = sp.pivot_table(
                index=["Date", "Site"],
                columns="Species",
                values="Tally",
                aggfunc="sum",
                fill_value=0,
            ).reset_index()
            # Add Period from Phase if available
            if "Phase" in sp.columns:
                period_map = sp.drop_duplicates(subset=["Date", "Site"])[
                    ["Date", "Site", "Phase"]
                ].rename(columns={"Phase": "Period"})
                pivot = pivot.merge(period_map, on=["Date", "Site"], how="left")
            data["Community"] = pivot

    return data


def _generate_python_figures() -> None:
    """Run the Python figure pipeline against Data.xlsx."""
    from mgen.figures import generate_figures

    data = _load_data()
    print(f"  Sheets loaded: {list(data.keys())}")

    result = generate_figures(data, PYTHON_DIR, only="all")
    print(f"  Generated {len(result.files_written)} files")
    if result.warnings:
        for w in result.warnings:
            print(f"  WARNING: {w}")


# ---------------------------------------------------------------------------
# HTML Report
# ---------------------------------------------------------------------------


def _img_to_base64(path: Path) -> str:
    """Encode image to base64 data URI."""
    suffix = path.suffix.lower().lstrip(".")
    mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg"}.get(
        suffix, "image/png"
    )
    data = path.read_bytes()
    encoded = base64.b64encode(data).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def _build_html(entries: list[dict[str, str | Path | None]]) -> str:
    """Build HTML comparison report."""
    rows_html = []
    current_category = ""

    for entry in entries:
        cat = entry["category"]
        if cat != current_category:
            rows_html.append(
                f'<tr class="category-header"><td colspan="3"><h2>{cat}</h2></td></tr>'
            )
            current_category = cat

        r_path = entry["r_path"]
        python_glob = entry["python_glob"]
        label = entry["label"]

        # Find Python output
        python_matches = list(PYTHON_DIR.glob(python_glob))
        python_path = python_matches[0] if python_matches else None

        r_img = _img_to_base64(Path(r_path)) if r_path and Path(r_path).exists() else ""
        p_img = (
            _img_to_base64(python_path) if python_path and python_path.exists() else ""
        )

        r_cell = (
            f'<img src="{r_img}" />'
            if r_img
            else '<span class="missing">No R reference</span>'
        )
        p_cell = (
            f'<img src="{p_img}" />'
            if p_img
            else '<span class="missing">Not yet generated</span>'
        )

        rows_html.append(
            f"<tr>"
            f'<td class="label">{label}</td>'
            f'<td class="img-cell">{r_cell}</td>'
            f'<td class="img-cell">{p_cell}</td>'
            f"</tr>"
        )

    return f"""\
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<title>R vs Python Plot Comparison</title>
<style>
body {{
    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    margin: 20px;
    background: #f5f5f5;
}}
h1 {{ text-align: center; }}
h2 {{
    margin: 0;
    padding: 10px 0;
    color: #333;
    border-bottom: 2px solid #2ec4b6;
}}
table {{
    width: 100%;
    border-collapse: collapse;
    background: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}}
th {{
    background: #2ec4b6;
    color: white;
    padding: 12px;
    text-align: center;
    position: sticky;
    top: 0;
}}
td {{
    padding: 8px;
    vertical-align: top;
    border-bottom: 1px solid #eee;
}}
td.label {{
    width: 80px;
    font-weight: bold;
    text-align: center;
    vertical-align: middle;
}}
td.img-cell {{
    width: 48%;
    text-align: center;
}}
td.img-cell img {{
    max-width: 100%;
    height: auto;
    border: 1px solid #ddd;
    border-radius: 4px;
}}
.category-header td {{
    background: #f9f9f9;
    padding: 0 8px;
}}
.missing {{
    color: #e71d36;
    font-style: italic;
}}
tr:hover {{
    background: #f0fffe;
}}
</style>
</head>
<body>
<h1>R vs Python &mdash; Plot Comparison Report</h1>
<p style="text-align:center; color:#666;">
Generated from <code>ref/Data.xlsx</code>.
Left = R reference, Right = Python output.
</p>
<table>
<thead><tr><th>Site</th><th>R Reference</th><th>Python Output</th></tr></thead>
<tbody>
{"".join(rows_html)}
</tbody>
</table>
</body>
</html>"""


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    """Run comparison: generate plots then build HTML report."""
    print(f"Data.xlsx: {DATA_XLSX}")
    if not DATA_XLSX.exists():
        print(f"ERROR: {DATA_XLSX} not found")
        return

    # Clean output dir
    if OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    PYTHON_DIR.mkdir(parents=True, exist_ok=True)

    # Generate Python plots
    print("Generating Python figures...")
    _generate_python_figures()

    # Build mapping and report
    print("Building comparison report...")
    entries = _build_mapping()
    html = _build_html(entries)

    REPORT_PATH.write_text(html, encoding="utf-8")
    print(f"\nReport written to: {REPORT_PATH}")
    print("   Open in browser to compare side-by-side.")
    print(f"   Python outputs in: {PYTHON_DIR}")


if __name__ == "__main__":
    main()
