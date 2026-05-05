"""Tests for Macroinvertebrate RawData ingestion (anti-corruption layer).

Verifies that ingest_raw_data() correctly parses the multi-row header,
splits taxa from metrics, and extracts MCI scores from the RawData sheet.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import pytest

from mgen.domain.macro_ingest import IngestError, RawDataBundle, ingest_raw_data
from mgen.shared.domain_types import VALID_SEASONS, VALID_SITES


class TestIngestRawDataStructure:
    """Test that ingest_raw_data returns a well-formed RawDataBundle."""

    def test_returns_raw_data_bundle(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert isinstance(result, RawDataBundle)

    def test_bundle_has_sample_metadata(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert isinstance(result.sample_metadata, pd.DataFrame)
        assert len(result.sample_metadata) > 0

    def test_bundle_has_taxa_counts(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert isinstance(result.taxa_counts, pd.DataFrame)
        assert len(result.taxa_counts) > 0

    def test_bundle_has_metric_rows(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert isinstance(result.metric_rows, pd.DataFrame)
        assert len(result.metric_rows) > 0

    def test_bundle_has_mci_scores(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert isinstance(result.mci_scores, pd.DataFrame)
        assert len(result.mci_scores) > 0


class TestSampleMetadata:
    """Test sample metadata extraction from the 5-row header."""

    def test_has_expected_columns(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        expected_cols = {"sample_id", "Season", "Date", "Site", "Replicate"}
        assert set(result.sample_metadata.columns) >= expected_cols

    def test_sites_are_valid(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        sites_found = set(result.sample_metadata["Site"].unique())
        assert sites_found <= VALID_SITES, (
            f"Unexpected sites: {sites_found - VALID_SITES}"
        )

    def test_contains_all_expected_sites(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        sites_found = set(result.sample_metadata["Site"].unique())
        assert sites_found == VALID_SITES

    def test_seasons_are_valid(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        seasons_found = set(result.sample_metadata["Season"].unique())
        assert seasons_found <= VALID_SEASONS

    def test_dates_are_datetime(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert pd.api.types.is_datetime64_any_dtype(result.sample_metadata["Date"])

    def test_replicate_is_nullable_integer(self, example_macro_db: Path) -> None:
        """Replicate column uses nullable Int64 (NaN for blanks, int otherwise)."""
        result = ingest_raw_data(example_macro_db)

        assert result.sample_metadata["Replicate"].dtype == pd.Int64Dtype()

    def test_replicated_sites_have_multiple_reps_per_date(
        self, example_macro_db: Path
    ) -> None:
        """Replicated sites (EM3, EM5, EM7) have reps 1-5 for each date."""
        result = ingest_raw_data(example_macro_db)
        meta = result.sample_metadata

        em3 = meta[meta["Site"] == "EM3"]
        # EM3 should have 5 replicates per sampling date
        first_date = em3["Date"].iloc[0]
        reps_for_date = em3[em3["Date"] == first_date]["Replicate"].dropna().tolist()
        assert sorted(reps_for_date) == [1, 2, 3, 4, 5]

    def test_sample_count_matches_expected(self, example_macro_db: Path) -> None:
        """RawData has 214 sample columns (cols E-218)."""
        result = ingest_raw_data(example_macro_db)

        assert len(result.sample_metadata) == 214

    def test_handles_site_with_space(self, example_macro_db: Path) -> None:
        """MMA 6 and MMA 6b have spaces in their names."""
        result = ingest_raw_data(example_macro_db)

        sites = set(result.sample_metadata["Site"].unique())
        assert "MMA 6" in sites
        assert "MMA 6b" in sites


class TestTaxaCounts:
    """Test taxa count extraction and metrics boundary."""

    def test_has_taxon_group_and_taxon_columns(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert "TaxonGroup" in result.taxa_counts.columns
        assert "Taxon" in result.taxa_counts.columns

    def test_excludes_metric_rows(self, example_macro_db: Path) -> None:
        """Taxa counts should NOT include 'Number of Taxa' or other metrics."""
        result = ingest_raw_data(example_macro_db)

        taxa_names = result.taxa_counts["Taxon"].astype(str).to_numpy()
        assert "Number of Taxa" not in taxa_names
        assert "MCI Value" not in taxa_names

    def test_taxa_count_expected_row_count(self, example_macro_db: Path) -> None:
        """RawData has 141 taxa rows (rows 6-146)."""
        result = ingest_raw_data(example_macro_db)

        assert len(result.taxa_counts) == 141

    def test_taxa_counts_has_sample_columns(self, example_macro_db: Path) -> None:
        """Taxa counts should have one column per sample (214 total) plus metadata."""
        result = ingest_raw_data(example_macro_db)

        # TaxonGroup + Taxon + 214 sample columns
        assert len(result.taxa_counts.columns) == 2 + 214

    def test_first_taxon_is_acanthophlebia(self, example_macro_db: Path) -> None:
        """First taxon in RawData row 6 is Acanthophlebia."""
        result = ingest_raw_data(example_macro_db)

        assert result.taxa_counts.iloc[0]["Taxon"] == "Acanthophlebia"

    def test_first_taxon_group_is_mayflies(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert result.taxa_counts.iloc[0]["TaxonGroup"] == "Mayflies"


class TestMetricRows:
    """Test metric row extraction below the 'Number of Taxa' marker."""

    def test_first_metric_is_number_of_taxa(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert result.metric_rows.iloc[0]["Metric"] == "Number of Taxa"

    def test_contains_mci_value(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        metrics = result.metric_rows["Metric"].astype(str).to_numpy()
        assert "MCI Value" in metrics

    def test_metric_rows_have_sample_columns(self, example_macro_db: Path) -> None:
        """Metric rows should have one column per sample plus Metric name."""
        result = ingest_raw_data(example_macro_db)

        # Metric + 214 sample columns
        assert len(result.metric_rows.columns) == 1 + 214


class TestMciScores:
    """Test MCI/MCI-sb tolerance score extraction from cols C-D."""

    def test_has_expected_columns(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert set(result.mci_scores.columns) == {"Taxon", "MCI", "MCI_sb"}

    def test_row_count_matches_taxa(self, example_macro_db: Path) -> None:
        """One MCI score row per taxon."""
        result = ingest_raw_data(example_macro_db)

        assert len(result.mci_scores) == len(result.taxa_counts)

    def test_mci_scores_are_numeric(self, example_macro_db: Path) -> None:
        result = ingest_raw_data(example_macro_db)

        assert pd.api.types.is_numeric_dtype(result.mci_scores["MCI"])
        assert pd.api.types.is_numeric_dtype(result.mci_scores["MCI_sb"])

    def test_acanthophlebia_mci_score(self, example_macro_db: Path) -> None:
        """Acanthophlebia has MCI=7, MCI-sb=9.6 per the spreadsheet."""
        result = ingest_raw_data(example_macro_db)

        row = result.mci_scores[result.mci_scores["Taxon"] == "Acanthophlebia"]
        assert len(row) == 1
        assert row.iloc[0]["MCI"] == pytest.approx(7.0)
        assert row.iloc[0]["MCI_sb"] == pytest.approx(9.6)


class TestIngestErrorHandling:
    """Test that ingest_raw_data raises IngestError for invalid inputs."""

    def test_raises_on_missing_file(self, tmp_path: Path) -> None:
        with pytest.raises(IngestError, match="File not found"):
            ingest_raw_data(tmp_path / "nonexistent.xlsx")

    def test_raises_on_missing_rawdata_sheet(self, tmp_path: Path) -> None:
        """An xlsx without a 'RawData' sheet raises IngestError."""
        fake_xlsx = tmp_path / "no_rawdata.xlsx"
        pd.DataFrame({"A": [1]}).to_excel(fake_xlsx, sheet_name="Other")

        with pytest.raises(IngestError, match="Cannot read 'RawData' sheet"):
            ingest_raw_data(fake_xlsx)

    def test_raises_on_missing_metrics_marker(self, tmp_path: Path) -> None:
        """Sheet without 'Number of Taxa' marker raises IngestError."""
        # Build a minimal sheet with header rows but no marker
        data = pd.DataFrame(
            [
                ["", "", "", "", ""],  # Row 1: QA
                ["", "", "", "", "Baseline"],  # Row 2: Season
                ["", "", "", "", "2024-01-01"],  # Row 3: Date
                ["", "", "", "", "EM1"],  # Row 4: Site
                ["", "", "", "", "1"],  # Row 5: Replicate
                ["Mayflies", "Taxon1", "5", "3", "10"],  # Row 6: data (no marker)
            ]
        )
        fake_xlsx = tmp_path / "no_marker.xlsx"
        with pd.ExcelWriter(fake_xlsx) as writer:
            data.to_excel(writer, sheet_name="RawData", header=False, index=False)

        with pytest.raises(IngestError, match=r"Number of Taxa.*marker not found"):
            ingest_raw_data(fake_xlsx)
