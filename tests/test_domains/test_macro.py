"""Tests for macroinvertebrate metric derivation and domain pipeline."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from mgen.domain.macro import derive_metrics, process_macro_domain
from mgen.domain.macro_ingest import ingest_raw_data
from mgen.shared.domain_types import SITES_WITHOUT_REPLICATES
from mgen.shared.errors import DomainResult
from mgen.shared.schemas import MACRO1_COLUMNS


class TestDeriveMetrics:
    """Unit tests for metric derivation domain service.

    These test the ecologist-signed formulas independently of file I/O.
    """

    @pytest.fixture
    def sample_taxa_counts(self) -> pd.DataFrame:
        """Minimal taxa count data for a single sample."""
        return pd.DataFrame(
            {
                "TaxonGroup": [
                    "Mayflies",
                    "Mayflies",
                    "Stoneflies",
                    "Caddisflies",
                    "Oligochaeta",
                ],
                "Taxon": [
                    "Deleatidium",
                    "Coloburiscus",
                    "Zelandobius",
                    "Oxyethira",
                    "Oligochaeta",
                ],
                4: pd.array([10, 5, 3, 2, 8], dtype="Int64"),
            }
        )

    @pytest.fixture
    def sample_mci_scores(self) -> pd.DataFrame:
        """MCI tolerance scores matching the taxa above."""
        return pd.DataFrame(
            {
                "Taxon": [
                    "Deleatidium",
                    "Coloburiscus",
                    "Zelandobius",
                    "Oxyethira",
                    "Oligochaeta",
                ],
                "MCI": [8.0, 9.0, 5.0, 4.0, 1.0],
                "MCI_sb": [7.0, 8.0, 4.0, 3.0, 1.0],
            }
        )

    def test_number_of_taxa(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        assert result["Number of Taxa"] == 5

    def test_number_of_individuals(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        # 10 + 5 + 3 + 2 + 8 = 28
        assert result["Number of Individuals"] == 28

    def test_mci_calculation(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        # MCI = (sum of scores for taxa present / number of taxa present) * 20
        # Scores: 8, 9, 5, 4, 1 → sum = 27, count = 5
        # MCI = (27 / 5) * 20 = 108.0
        assert result["MCI"] == pytest.approx(108.0)

    def test_mci_sb_calculation(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        # MCI-sb = (sum of MCI_sb scores / count) * 20
        # Scores: 7, 8, 4, 3, 1 → sum = 23, count = 5
        # MCI-sb = (23 / 5) * 20 = 92.0
        assert result["MCI-sb"] == pytest.approx(92.0)

    def test_qmci_calculation(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        # QMCI formula: weighted average = 156/28 = 5.571...
        # Weights: 10*8 + 5*9 + 3*5 + 2*4 + 8*1 = 156, total = 28
        assert result["QMCI"] == pytest.approx(156 / 28)

    def test_qmci_sb_calculation(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        # QMCI-sb formula: weighted average = 136/28
        # Weights: 10*7 + 5*8 + 3*4 + 2*3 + 8*1 = 136, total = 28
        assert result["QMCI-sb"] == pytest.approx(136 / 28)

    def test_ept_richness(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        # EPT = Mayflies + Stoneflies + Caddisflies (excl. Hydroptilidae genera)
        # E richness: 2 (Deleatidium, Coloburiscus)
        # P richness: 1 (Zelandobius)
        # T richness: 0 (Oxyethira is Hydroptilidae, excluded)
        # EPT total: 3
        assert result["EPT Richness"] == 3

    def test_ept_abundance(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        # EPT abundance: Mayflies (10+5) + Stoneflies (3) + Caddisflies excl Hydro (0)
        # = 15 + 3 + 0 = 18
        assert result["EPT Abundance"] == 18

    def test_pct_ept_abundance(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        # % EPT Abundance = EPT Abundance / Number of Individuals = 18 / 28
        assert result["% EPT Abundance"] == pytest.approx(18 / 28)

    def test_pct_ept_richness(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        # % EPT Richness = EPT Richness / Number of Taxa = 3 / 5
        assert result["% EPT Richness"] == pytest.approx(3 / 5)

    def test_aspm_mci(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        # ASPM-MCI = mean(MCI/200, EPT_Richness/29, EPT_Abundance/100)
        # = mean(108/200, 3/29, 18/100)
        # = mean(0.54, 0.10345, 0.18) = 0.27448...
        expected = np.mean([108 / 200, 3 / 29, 18 / 100])
        assert result["ASPM-MCI"] == pytest.approx(expected)

    def test_e_p_t_richness_breakdown(
        self,
        sample_taxa_counts: pd.DataFrame,
        sample_mci_scores: pd.DataFrame,
    ) -> None:
        result = derive_metrics(sample_taxa_counts, sample_mci_scores, sample_col=4)

        assert result["E Richness"] == 2
        assert result["P Richness"] == 1
        assert result["T Richness"] == 0

    def test_handles_zero_abundance_taxa(self) -> None:
        """Taxa with zero counts should not contribute to metrics."""
        taxa = pd.DataFrame(
            {
                "TaxonGroup": ["Mayflies", "Stoneflies"],
                "Taxon": ["Deleatidium", "Zelandobius"],
                4: pd.array([5, 0], dtype="Int64"),
            }
        )
        scores = pd.DataFrame(
            {
                "Taxon": ["Deleatidium", "Zelandobius"],
                "MCI": [8.0, 5.0],
                "MCI_sb": [7.0, 4.0],
            }
        )

        result = derive_metrics(taxa, scores, sample_col=4)

        assert result["Number of Taxa"] == 1
        assert result["Number of Individuals"] == 5
        # Only Deleatidium present: MCI = (8/1)*20 = 160
        assert result["MCI"] == pytest.approx(160.0)

    def test_handles_all_na_counts(self) -> None:
        """All-NA sample should return zero counts and NaN metrics."""
        taxa = pd.DataFrame(
            {
                "TaxonGroup": ["Mayflies"],
                "Taxon": ["Deleatidium"],
                4: pd.array([pd.NA], dtype="Int64"),
            }
        )
        scores = pd.DataFrame(
            {
                "Taxon": ["Deleatidium"],
                "MCI": [8.0],
                "MCI_sb": [7.0],
            }
        )

        result = derive_metrics(taxa, scores, sample_col=4)

        assert result["Number of Taxa"] == 0
        assert result["Number of Individuals"] == 0
        assert np.isnan(result["MCI"])


class TestDeriveMetricsIntegration:
    """Integration tests validating against real spreadsheet formula results."""

    def test_em1_mci_matches_spreadsheet(self, example_macro_db: Path) -> None:
        """EM1 (col 4) MCI should match spreadsheet value of ~118.14."""
        bundle = ingest_raw_data(example_macro_db)
        result = derive_metrics(bundle.taxa_counts, bundle.mci_scores, sample_col=4)

        # Spreadsheet row "MCI Value" col 4 = 118.139535
        assert result["MCI"] == pytest.approx(118.139535, rel=1e-4)

    def test_em1_qmci_matches_spreadsheet(self, example_macro_db: Path) -> None:
        """EM1 (col 4) QMCI should match spreadsheet value of ~5.117."""
        bundle = ingest_raw_data(example_macro_db)
        result = derive_metrics(bundle.taxa_counts, bundle.mci_scores, sample_col=4)

        # Spreadsheet row "QMCI" col 4 = 5.116822
        assert result["QMCI"] == pytest.approx(5.116822, rel=1e-4)

    def test_em1_ept_abundance_matches_spreadsheet(
        self, example_macro_db: Path
    ) -> None:
        """EM1 (col 4) EPT abundance should match spreadsheet value of 49."""
        bundle = ingest_raw_data(example_macro_db)
        result = derive_metrics(bundle.taxa_counts, bundle.mci_scores, sample_col=4)

        assert result["EPT Abundance"] == 49

    def test_em1_aspm_mci_matches_spreadsheet(self, example_macro_db: Path) -> None:
        """EM1 (col 4) ASPM-MCI should match spreadsheet value of ~0.544."""
        bundle = ingest_raw_data(example_macro_db)
        result = derive_metrics(bundle.taxa_counts, bundle.mci_scores, sample_col=4)

        # Spreadsheet row "ASPM-MCI" col 4 = 0.544141
        assert result["ASPM-MCI"] == pytest.approx(0.544141, rel=1e-3)

    def test_em2_mci_matches_spreadsheet(self, example_macro_db: Path) -> None:
        """EM2 (col 5) MCI should match spreadsheet value of ~103.08."""
        bundle = ingest_raw_data(example_macro_db)
        result = derive_metrics(bundle.taxa_counts, bundle.mci_scores, sample_col=5)

        # Spreadsheet row "MCI Value" col 5 = 103.076923
        assert result["MCI"] == pytest.approx(103.076923, rel=1e-4)


class TestProcessMacroDomain:
    """Integration tests for the full macro domain pipeline."""

    def test_returns_domain_result(self, example_macro_db: Path) -> None:
        result = process_macro_domain(example_macro_db)

        assert isinstance(result, DomainResult)

    def test_result_is_ok(self, example_macro_db: Path) -> None:
        result = process_macro_domain(example_macro_db)

        assert result.ok

    def test_result_contains_macro1_and_macro_sheets(
        self, example_macro_db: Path
    ) -> None:
        result = process_macro_domain(example_macro_db)

        assert "Macro1" in result.data
        assert "Macro" in result.data

    def test_macro1_has_correct_columns(self, example_macro_db: Path) -> None:
        result = process_macro_domain(example_macro_db)

        assert list(result.data["Macro1"].columns) == MACRO1_COLUMNS

    def test_macro_has_correct_columns(self, example_macro_db: Path) -> None:
        result = process_macro_domain(example_macro_db)

        assert list(result.data["Macro"].columns) == MACRO1_COLUMNS

    def test_macro1_has_rows(self, example_macro_db: Path) -> None:
        result = process_macro_domain(example_macro_db)

        assert len(result.data["Macro1"]) > 0

    def test_macro_excludes_non_replicate_sites(self, example_macro_db: Path) -> None:
        result = process_macro_domain(example_macro_db)
        macro_df = result.data["Macro"]

        sites_in_macro = set(macro_df["Site"].unique())
        assert not sites_in_macro & SITES_WITHOUT_REPLICATES

    def test_macro_has_fewer_rows_than_macro1(self, example_macro_db: Path) -> None:
        result = process_macro_domain(example_macro_db)

        # Macro1 has individual samples; Macro aggregates replicates
        assert len(result.data["Macro"]) < len(result.data["Macro1"])

    def test_qmci_sb_used_for_non_replicate_sites(self, example_macro_db: Path) -> None:
        result = process_macro_domain(example_macro_db)
        macro1_df = result.data["Macro1"]

        # Non-replicate sites should have QMCI values present
        non_rep = macro1_df[macro1_df["Site"].isin(SITES_WITHOUT_REPLICATES)]
        assert len(non_rep) > 0
        assert non_rep["QMCI"].notna().all()

    def test_invalid_path_returns_error(self, tmp_path: Path) -> None:
        result = process_macro_domain(tmp_path / "nonexistent.xlsx")

        assert not result.ok
        assert len(result.errors) > 0
