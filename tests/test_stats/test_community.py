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
        """3 samples x 4 species."""
        return pd.DataFrame(
            {
                "sp_A": [10, 0, 5],
                "sp_B": [0, 10, 5],
                "sp_C": [5, 5, 5],
                "sp_D": [1, 1, 1],
            }
        )

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
        """Known 5x5 distance matrix with clear 2-cluster structure."""
        dm = np.array(
            [
                [0.0, 0.1, 0.15, 0.8, 0.85],
                [0.1, 0.0, 0.12, 0.82, 0.83],
                [0.15, 0.12, 0.0, 0.79, 0.81],
                [0.8, 0.82, 0.79, 0.0, 0.1],
                [0.85, 0.83, 0.81, 0.1, 0.0],
            ]
        )
        return dm

    def test_returns_nmds_result(self, distance_matrix: np.ndarray) -> None:
        result = run_nmds(distance_matrix, n_dims=2, seed=42)
        assert isinstance(result, NMDSResult)

    def test_correct_shape(self, distance_matrix: np.ndarray) -> None:
        result = run_nmds(distance_matrix, n_dims=2, seed=42)
        assert result.points.shape == (5, 2)

    def test_stress_is_low_for_clear_structure(
        self, distance_matrix: np.ndarray
    ) -> None:
        result = run_nmds(distance_matrix, n_dims=2, seed=42)
        assert result.stress < 0.2

    def test_deterministic_with_seed(self, distance_matrix: np.ndarray) -> None:
        r1 = run_nmds(distance_matrix, n_dims=2, seed=42)
        r2 = run_nmds(distance_matrix, n_dims=2, seed=42)
        np.testing.assert_array_almost_equal(r1.points, r2.points)


class TestRunANOSIM:
    def test_significant_for_distinct_groups(self) -> None:
        # Need n>=10 for permutation test to achieve p<0.05
        # Two clusters with clear within < between distances
        n_per_group = 5
        n = n_per_group * 2
        dm = np.zeros((n, n))
        for i in range(n):
            for j in range(i + 1, n):
                same_group = (i < n_per_group) == (j < n_per_group)
                if same_group:
                    dm[i, j] = dm[j, i] = 0.1
                else:
                    dm[i, j] = dm[j, i] = 0.9
        groups = pd.Series(["A"] * n_per_group + ["B"] * n_per_group)
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
