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
    "compute_abundance_change",
    "envfit_species_drivers",
    "envfit_species_drivers_per_group",
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
    condensed = pdist(species_df.to_numpy(), metric="braycurtis")
    return squareform(condensed)


def run_nmds(
    distance_matrix: np.ndarray,
    n_dims: int = 2,
    seed: int = 42,
    max_iter: int = 1000,
) -> NMDSResult:
    """Non-metric multidimensional scaling.

    Uses scikit-learn's MDS with metric_mds=False (non-metric) and
    metric='precomputed'.

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
        metric_mds=False,
        metric="precomputed",
        random_state=seed,
        max_iter=max_iter,
        normalized_stress=True,
        n_init=4,
        init="random",
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
        condensed = dm[np.triu_indices(n, k=1)]
        rank_vals = condensed.argsort().argsort().astype(float) + 1

        ranks = np.zeros_like(dm)
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

    groups_arr = groups.to_numpy()
    observed_r = _compute_r(distance_matrix, groups_arr)

    count_ge = 0
    for _ in range(permutations):
        perm_groups = rng.permutation(groups_arr)
        perm_r = _compute_r(distance_matrix, perm_groups)
        if perm_r >= observed_r:
            count_ge += 1

    p_value = (count_ge + 1) / (permutations + 1)

    return ANOSIMResult(
        R_statistic=observed_r, p_value=p_value, permutations=permutations
    )


def indicator_species_analysis(
    species_df: pd.DataFrame,
    groups: pd.Series,
    permutations: int = 999,
    seed: int = 42,
    p_threshold: float = 0.05,
) -> list[IndicatorSpecies]:
    """Indicator Value (IndVal) analysis.

    Implements the Dufrene & Legendre (1997) IndVal index with
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
        abundances = species_df[species].to_numpy().astype(float)
        best_indval = 0.0
        best_group = unique_groups[0]

        for group in unique_groups:
            mask = (groups == group).to_numpy()
            mean_in = abundances[mask].mean()
            mean_all = abundances.mean()
            specificity = mean_in / mean_all if mean_all > 0 else 0.0
            fidelity = (abundances[mask] > 0).sum() / mask.sum()
            indval = specificity * fidelity

            if indval > best_indval:
                best_indval = indval
                best_group = group

        count_ge = 0
        for _ in range(permutations):
            perm_groups = rng.permutation(groups.to_numpy())
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
            results.append(
                IndicatorSpecies(
                    species=species,
                    group=best_group,
                    stat=best_indval,
                    p_value=p_value,
                )
            )

    return sorted(results, key=lambda x: x.stat, reverse=True)


def envfit_species_drivers(
    nmds_points: np.ndarray,
    species_df: pd.DataFrame,
    permutations: int = 999,
    seed: int = 42,
) -> pd.DataFrame:
    """Fit species vectors onto ordination space.

    For each species, computes correlation (R-squared) between species abundance
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
        abundances = species_df[species].to_numpy().astype(float)
        if abundances.std() == 0:
            continue

        centered = abundances - abundances.mean()
        corr1 = np.corrcoef(centered, nmds_points[:, 0])[0, 1]
        corr2 = np.corrcoef(centered, nmds_points[:, 1])[0, 1]
        r2 = corr1**2 + corr2**2

        count_ge = 0
        for _ in range(permutations):
            perm = rng.permutation(centered)
            pc1 = np.corrcoef(perm, nmds_points[:, 0])[0, 1]
            pc2 = np.corrcoef(perm, nmds_points[:, 1])[0, 1]
            if pc1**2 + pc2**2 >= r2:
                count_ge += 1

        p_value = (count_ge + 1) / (permutations + 1)
        results.append(
            {
                "Species": species,
                "NMDS1_corr": corr1,
                "NMDS2_corr": corr2,
                "R2": r2,
                "p_value": p_value,
            }
        )

    return pd.DataFrame(results)


def envfit_species_drivers_per_group(
    species_df: pd.DataFrame,
    groups: pd.Series,
    permutations: int = 999,
    seed: int = 42,
    p_threshold: float = 0.05,
    group_col_name: str = "Site",
    min_samples: int = 3,
) -> pd.DataFrame:
    """Run per-group NMDS + envfit, returning significant species drivers.

    For each unique value in ``groups``, subsets the community matrix,
    runs NMDS, then envfit. Matches the R per-site and per-catchment
    species driver analysis.

    Args:
        species_df: DataFrame where rows are samples and columns are species.
        groups: Group label (Site or Catchment) for each sample.
        permutations: Number of envfit permutations.
        seed: Random seed.
        p_threshold: Significance threshold for filtering.
        group_col_name: Name for the group column in output
            (e.g. "Site" or "Catchment").
        min_samples: Minimum samples required per group to run NMDS.

    Returns:
        DataFrame with Species, NMDS1_corr, NMDS2_corr, R2, p_value, and group column.
        Only significant species (p < p_threshold) are included.
    """
    all_results = []
    for group_val in sorted(groups.unique()):
        mask = (groups == group_val).to_numpy()
        if mask.sum() < min_samples:
            continue

        subset = species_df[mask].reset_index(drop=True)
        # Remove zero-sum rows
        row_sums = subset.sum(axis=1)
        subset = subset[row_sums > 0].reset_index(drop=True)
        if len(subset) < min_samples:
            continue

        dm = bray_curtis_matrix(subset)
        nmds = run_nmds(dm, n_dims=2, seed=seed)

        drivers = envfit_species_drivers(
            nmds.points, subset, permutations=permutations, seed=seed
        )
        if drivers.empty:
            continue

        sig = drivers[drivers["p_value"] < p_threshold].copy()
        sig[group_col_name] = group_val
        all_results.append(sig)

    if not all_results:
        return pd.DataFrame()
    return pd.concat(all_results, ignore_index=True)


def compute_abundance_change(
    macrospecies_df: pd.DataFrame,
    baseline_phase: str = "Baseline",
    construction_phase: str = "Routine Construction",
) -> pd.DataFrame:
    """Compute mean abundance change per species per site (Construction - Baseline).

    Matches R logic:
        macrospecies %>% group_by(Site, Phase, Species) %>% summarise(mean_Tally) %>%
        pivot_wider(Phase) %>% mutate(Change = Construction - Baseline)

    Args:
        macrospecies_df: Long-format MacroSpecies with
            Site, Phase, Species, Tally columns.
        baseline_phase: Label for the baseline phase.
        construction_phase: Label for the construction phase.

    Returns:
        DataFrame with columns: Site, Species, Baseline,
            Construction (or actual phase names), Change.
    """
    ms = macrospecies_df.copy()
    ms.columns = [c.strip() for c in ms.columns]

    grouped = (
        ms.groupby(["Site", "Phase", "Species"], observed=True)["Tally"]
        .mean()
        .reset_index()
    )
    pivoted = grouped.pivot_table(
        index=["Site", "Species"],
        columns="Phase",
        values="Tally",
        fill_value=0,
    ).reset_index()
    pivoted.columns.name = None

    if baseline_phase in pivoted.columns and construction_phase in pivoted.columns:
        pivoted["Change"] = pivoted[construction_phase] - pivoted[baseline_phase]
    elif construction_phase in pivoted.columns:
        pivoted["Change"] = pivoted[construction_phase]
    else:
        pivoted["Change"] = 0.0

    return pivoted.sort_values("Change", key=lambda s: s.abs(), ascending=False)
