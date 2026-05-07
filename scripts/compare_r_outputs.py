"""Build a side-by-side HTML comparison: R reference images vs new R pipeline outputs.

Usage:
    python scripts/compare_r_outputs.py

Opens comparison_r_output/comparison_report.html showing ref/ images (left)
next to src/r/outputs/ images (right) so you can visually verify the new
consolidated R pipeline produces equivalent figures.
"""

from __future__ import annotations

import base64
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
REF_DIR = REPO_ROOT / "ref"
R_OUTPUT_DIR = REPO_ROOT / "src" / "r" / "outputs"
OUTPUT_DIR = REPO_ROOT / "comparison_r_output"
REPORT_PATH = OUTPUT_DIR / "comparison_report.html"

SITES = ["EM1", "EM2", "EM3", "EM4", "EM5", "EM7", "EM8"]


def _find_ref(patterns: list[str | Path]) -> Path | None:
    """Return first existing path from a list of candidates."""
    for p in patterns:
        path = Path(p) if not isinstance(p, Path) else p
        if not path.is_absolute():
            path = REF_DIR / path
        if path.exists():
            return path
    return None


def _find_new(patterns: list[str]) -> Path | None:
    """Return first existing path from R output candidates."""
    for p in patterns:
        path = R_OUTPUT_DIR / p
        if path.exists():
            return path
    return None


def _sediment_entries() -> list[dict]:
    """Sediment size + SAM time-series comparison entries."""
    entries: list[dict] = []

    for site in SITES:
        ref = _find_ref(
            [
                f"SedimentSize_{site}_A3.png",
                f"MacroOutput/Sediment Size/SedimentSizeStack_{site}.jpg",
            ]
        )
        new = _find_new([f"SedimentSize_{site}_A3.png"])
        if ref or new:
            entries.append(
                {
                    "category": "Sediment Size Distribution",
                    "label": site,
                    "ref_path": ref,
                    "new_path": new,
                }
            )

    for site in SITES:
        for metric in ["SAM1", "SAM3"]:
            ref = _find_ref(
                [
                    f"MacroOutput/SAM1 SAM3 Sediment/{site}.{metric}plot.jpg",
                ]
            )
            new = _find_new([f"{site}_{metric}_plot.jpeg"])
            if ref or new:
                entries.append(
                    {
                        "category": f"Sediment Time-series ({metric})",
                        "label": site,
                        "ref_path": ref,
                        "new_path": new,
                    }
                )

    return entries


def _macro_entries() -> list[dict]:
    """Macro metric comparison entries."""
    entries: list[dict] = []

    for site in SITES:
        if site == "EM5":
            continue
        ref = _find_ref(
            [
                f"{site}DRAFT.jpg",
                f"MacroOutput/UpdatedMacroPlots_250814/{site}DRAFT.jpg",
            ]
        )
        new = _find_new([f"{site}DRAFT.jpg"])
        if ref or new:
            entries.append(
                {
                    "category": "Macro Metrics (3-panel)",
                    "label": site,
                    "ref_path": ref,
                    "new_path": new,
                }
            )

    metric_map = {"qmci": "QMCI", "rich": "EPTrich", "abun": "EPTabun"}
    for site in SITES:
        if site == "EM5":
            continue
        for short, full in metric_map.items():
            ref = _find_ref(
                [
                    f"{site}_{short}.jpg",
                    f"metric_plots_jpeg/{site}_{full}_DRAFT.jpg",
                ]
            )
            new = _find_new(
                [
                    f"{site}_{short}.jpg",
                    f"metric_plots_jpeg/{site}_{full}_DRAFT.jpg",
                ]
            )
            if ref or new:
                entries.append(
                    {
                        "category": "Macro Individual Metrics",
                        "label": f"{site} {full}",
                        "ref_path": ref,
                        "new_path": new,
                    }
                )

    return entries


def _nmds_entries() -> list[dict]:
    """NMDS comparison entries."""
    entries: list[dict] = []

    # All Sites
    ref = _find_ref(["MacroOutput/NMDS/NMDS_All.jpeg"])
    new = _find_new(["NMDS_AllSites.jpeg"])
    if ref or new:
        entries.append(
            {
                "category": "NMDS Grouped",
                "label": "All Sites",
                "ref_path": ref,
                "new_path": new,
            }
        )

    # Construction / Baseline
    for ref_name, new_name, label in [
        ("ConstructionNMDS.jpeg", "ConstructionNMDS.jpeg", "Construction"),
        ("RoutineNMDS.jpeg", "BaselineNMDS.jpeg", "Baseline/Routine"),
    ]:
        ref = _find_ref([ref_name])
        new = _find_new([new_name])
        if ref or new:
            entries.append(
                {
                    "category": "NMDS Grouped",
                    "label": label,
                    "ref_path": ref,
                    "new_path": new,
                }
            )

    # Catchment Subsets
    catchment_map = {
        "Mangapepeke": [
            "NMDS_Manga.jpeg",
            "MacroOutput/NMDS/NMDS_Manga.jpeg",
        ],
        "Mimi": ["NMDS_Mimi.jpeg", "MacroOutput/NMDS/NMDS_Mimi.jpeg"],
        "Hard-bottom": [
            "NMDS_Hard.jpeg",
            "MacroOutput/NMDS/NMDS_Hard.jpeg",
        ],
        "Soft-bottom": [
            "NMDS_Soft.jpeg",
            "MacroOutput/NMDS/NMDS_Soft.jpeg",
        ],
    }
    for name, ref_patterns in catchment_map.items():
        ref = _find_ref(ref_patterns)
        new = _find_new([f"NMDS_{name}.jpeg"])
        if ref or new:
            entries.append(
                {
                    "category": "NMDS Catchment Subsets",
                    "label": name,
                    "ref_path": ref,
                    "new_path": new,
                }
            )

    # Per-site with Regression Arrow
    arrow_map = {
        "EM1": (
            "Mangap\u0113peke_EM1_Control.jpeg",
            "Mangapepeke_EM1_Control.jpeg",
        ),
        "EM2": ("Mangap\u0113peke_EM2.jpeg", "Mangapepeke_EM2.jpeg"),
        "EM3": ("Mangap\u0113peke_EM3.jpeg", "Mangapepeke_EM3.jpeg"),
        "EM4": ("Mimi_EM4_Control.jpeg", "Mimi_EM4_Control.jpeg"),
        "EM7": ("Mimi_EM7.jpeg", "Mimi_EM7.jpeg"),
        "EM8": ("Mimi_EM8.jpeg", "Mimi_EM8.jpeg"),
    }
    for site, (ref_name, new_name) in arrow_map.items():
        ref = _find_ref([ref_name])
        new = _find_new([new_name])
        if ref or new:
            entries.append(
                {
                    "category": "NMDS Per-Site (Regression Arrow)",
                    "label": site,
                    "ref_path": ref,
                    "new_path": new,
                }
            )

    # Per-site with Species Labels
    species_map = {
        "EM1": (
            "EM1_NMDS_with_species.jpeg",
            "EM1_Control_NMDS_with_species.jpeg",
        ),
        "EM2": (
            "EM2_NMDS_with_species.jpeg",
            "EM2_NMDS_with_species.jpeg",
        ),
        "EM3": (
            "EM3_NMDS_with_species.jpeg",
            "EM3_NMDS_with_species.jpeg",
        ),
        "EM4": (
            "EM4_NMDS_with_species.jpeg",
            "EM4_Control_NMDS_with_species.jpeg",
        ),
        "EM7": (
            "EM7_NMDS_with_species.jpeg",
            "EM7_NMDS_with_species.jpeg",
        ),
        "EM8": (
            "EM8_NMDS_with_species.jpeg",
            "EM8_NMDS_with_species.jpeg",
        ),
    }
    for site, (ref_name, new_name) in species_map.items():
        ref = _find_ref([ref_name])
        new = _find_new([new_name])
        if ref or new:
            entries.append(
                {
                    "category": "NMDS Per-Site (Species Labels)",
                    "label": site,
                    "ref_path": ref,
                    "new_path": new,
                }
            )

    return entries


def _indicator_entries() -> list[dict]:
    """Indicator species comparison entries."""
    entries: list[dict] = []

    indic_map = {
        "EM1": (
            "indicator_species_EM1.jpeg",
            "indicator_species_EM1_Control.jpeg",
        ),
        "EM2": (
            "indicator_species_EM2.jpeg",
            "indicator_species_EM2.jpeg",
        ),
        "EM3": (
            "indicator_species_EM3.jpeg",
            "indicator_species_EM3.jpeg",
        ),
        "EM4": (
            "indicator_species_EM4.jpeg",
            "indicator_species_EM4_Control.jpeg",
        ),
        "EM7": (
            "indicator_species_EM7.jpeg",
            "indicator_species_EM7.jpeg",
        ),
        "EM8": (
            "indicator_species_EM8.jpeg",
            "indicator_species_EM8.jpeg",
        ),
        "Mangapepeke": (
            "indicator_species_Mangap\u0113peke_Sites.jpeg",
            "indicator_species_Mangapepeke_Sites.jpeg",
        ),
        "Mimi": (
            "indicator_species_Mimi_Sites.jpeg",
            "indicator_species_Mimi_Sites.jpeg",
        ),
    }
    for label, (ref_name, new_name) in indic_map.items():
        ref = _find_ref([ref_name])
        new = _find_new([new_name])
        if ref or new:
            entries.append(
                {
                    "category": "Indicator Species",
                    "label": label,
                    "ref_path": ref,
                    "new_path": new,
                }
            )

    return entries


def _build_entries() -> list[dict]:
    """Build all comparison entries."""
    entries: list[dict] = []
    entries.extend(_sediment_entries())
    entries.extend(_macro_entries())
    entries.extend(_nmds_entries())
    entries.extend(_indicator_entries())
    return entries


def _img_to_base64(path: Path) -> str:
    """Encode image to base64 data URI."""
    suffix = path.suffix.lower().lstrip(".")
    mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg"}.get(
        suffix, "image/png"
    )
    data = path.read_bytes()
    encoded = base64.b64encode(data).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def _build_html(entries: list[dict]) -> str:
    """Build HTML comparison report."""
    rows_html = []
    current_category = ""
    match_count = 0
    missing_ref = 0
    missing_new = 0

    for entry in entries:
        cat = entry["category"]
        if cat != current_category:
            rows_html.append(
                f'<tr class="category-header"><td colspan="3"><h2>{cat}</h2></td></tr>'
            )
            current_category = cat

        ref_path = entry["ref_path"]
        new_path = entry["new_path"]
        label = entry["label"]

        ref_img = _img_to_base64(ref_path) if ref_path and ref_path.exists() else ""
        new_img = _img_to_base64(new_path) if new_path and new_path.exists() else ""

        if ref_img and new_img:
            match_count += 1
        elif not ref_img:
            missing_ref += 1
        elif not new_img:
            missing_new += 1

        ref_cell = (
            f'<img src="{ref_img}" />'
            if ref_img
            else '<span class="missing">No reference</span>'
        )
        new_cell = (
            f'<img src="{new_img}" />'
            if new_img
            else '<span class="missing">Not generated</span>'
        )

        rows_html.append(
            f"<tr>"
            f'<td class="label">{label}</td>'
            f'<td class="img-cell">{ref_cell}</td>'
            f'<td class="img-cell">{new_cell}</td>'
            f"</tr>"
        )

    summary = (
        f"{match_count} matched | "
        f"{missing_new} missing from new pipeline | "
        f"{missing_ref} missing from ref"
    )

    return f"""\
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<title>R Pipeline Comparison: Reference vs New</title>
<style>
body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    margin: 20px;
    background: #f5f5f5;
}}
h1 {{ text-align: center; color: #1a1a2e; }}
h2 {{
    margin: 0;
    padding: 10px 0;
    color: #333;
    border-bottom: 2px solid #e94560;
}}
.summary {{
    text-align: center;
    font-size: 1.1em;
    padding: 12px;
    margin: 10px auto;
    max-width: 600px;
    background: white;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}}
table {{
    width: 100%;
    border-collapse: collapse;
    background: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    margin-top: 20px;
}}
th {{
    background: #0f3460;
    color: white;
    padding: 12px;
    text-align: center;
    position: sticky;
    top: 0;
    z-index: 10;
}}
td {{
    padding: 8px;
    vertical-align: top;
    border-bottom: 1px solid #eee;
}}
td.label {{
    width: 100px;
    font-weight: bold;
    text-align: center;
    vertical-align: middle;
    font-size: 0.9em;
}}
td.img-cell {{
    width: 46%;
    text-align: center;
}}
td.img-cell img {{
    max-width: 100%;
    height: auto;
    border: 1px solid #ddd;
    border-radius: 4px;
}}
.category-header td {{
    background: #f0f0f0;
    padding: 0 8px;
}}
.missing {{
    color: #e94560;
    font-style: italic;
    padding: 20px;
    display: block;
}}
tr:hover {{
    background: #f8f8ff;
}}
</style>
</head>
<body>
<h1>R Pipeline Comparison &mdash; Reference vs New</h1>
<div class="summary">
    <strong>{summary}</strong><br/>
    <small>Left = previous R output (ref/) | Right = new pipeline</small>
</div>
<table>
<thead><tr>\
<th>Label</th><th>Reference (ref/)</th>\
<th>New R Pipeline</th>\
</tr></thead>
<tbody>
{"".join(rows_html)}
</tbody>
</table>
</body>
</html>
"""


def main() -> None:
    """Generate comparison report."""
    if not R_OUTPUT_DIR.exists():
        print(f"ERROR: R outputs not found at {R_OUTPUT_DIR}")
        print("Run the pipeline first: Rscript src/r/run_all.R")
        raise SystemExit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print("Building comparison entries...")
    entries = _build_entries()
    print(f"  {len(entries)} comparison pairs found")

    print("Generating HTML report...")
    html = _build_html(entries)
    REPORT_PATH.write_text(html, encoding="utf-8")
    print(f"  Report saved: {REPORT_PATH}")
    print(f"  Open in browser: file:///{REPORT_PATH.as_posix()}")


if __name__ == "__main__":
    main()
