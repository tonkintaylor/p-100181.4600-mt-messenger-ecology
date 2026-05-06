"""Shared fixtures for plot tests."""

from __future__ import annotations

import matplotlib as mpl

mpl.use("Agg")

import pandas as pd
import pytest


@pytest.fixture
def sediment_size_df() -> pd.DataFrame:
    """Minimal SedimentSize data for 2 sites, 3 dates each."""
    sites = ["EM1"] * 3 + ["EM2"] * 3
    dates = pd.to_datetime(["2021-03-15", "2021-09-15", "2022-03-15"] * 2)
    periods = ["Baseline", "Baseline", "Routine Construction"] * 2
    seasons = ["Summer", "Winter", "Summer"] * 2
    return pd.DataFrame(
        {
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
        }
    )


@pytest.fixture
def sediment_df() -> pd.DataFrame:
    """Minimal Sediment data for 2 sites across baseline + construction."""
    return pd.DataFrame(
        {
            "Site": ["EM1"] * 4 + ["EM2"] * 4,
            "Date": pd.to_datetime(
                [
                    "2021-03-15",
                    "2021-06-15",
                    "2021-09-15",
                    "2022-06-15",
                    "2021-03-15",
                    "2021-06-15",
                    "2021-09-15",
                    "2022-06-15",
                ]
            ),
            "Period": [
                "Baseline",
                "Baseline",
                "Baseline",
                "Routine Construction",
                "Baseline",
                "Baseline",
                "Baseline",
                "Routine Construction",
            ],
            "SAM1": [60.0, 70.0, 80.0, 85.0, 50.0, 55.0, 60.0, 70.0],
            "SAM3": [50.0, 55.0, 60.0, 65.0, 40.0, 45.0, 50.0, 55.0],
            "Season": ["Summer", "Winter", "Spring", "Winter"] * 2,
        }
    )


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
            for rep in range(3):
                rows.append(
                    {
                        "Site": site,
                        "Date": pd.Timestamp(date_str),
                        "Period": period,
                        "EPTrich": 40.0 + rep * 5 + (0 if site == "EM1" else 10),
                        "EPTabun": 50.0 + rep * 3 + (0 if site == "EM1" else 5),
                        "QMCI": 5.0 + rep * 0.5 + (0 if site == "EM1" else 1),
                        "Season": "Summer" if "03" in date_str else "Winter",
                    }
                )
    return pd.DataFrame(rows)
