"""Tests for shared domain value objects."""

from __future__ import annotations

import pytest

from mgen.shared.domain_types import (
    SITES_WITHOUT_REPLICATES,
    VALID_PERIODS,
    VALID_SEASONS,
    VALID_SITES,
    Site,
)


class TestSite:
    def test_valid_site_creates_successfully(self) -> None:
        site = Site(code="EM1")

        assert site.code == "EM1"

    def test_invalid_site_raises_value_error(self) -> None:
        with pytest.raises(ValueError, match="Unknown site"):
            Site(code="INVALID")

    def test_site_without_replicates(self) -> None:
        site = Site(code="EM1")

        assert not site.has_replicates
        assert site.uses_qmci_sb

    def test_site_with_replicates(self) -> None:
        site = Site(code="EM3")

        assert site.has_replicates
        assert not site.uses_qmci_sb

    def test_frozen_prevents_mutation(self) -> None:
        site = Site(code="EM1")

        with pytest.raises(AttributeError):
            site.code = "EM2"  # type: ignore[misc]


class TestConstants:
    def test_valid_sites_is_frozenset(self) -> None:
        assert isinstance(VALID_SITES, frozenset)
        assert len(VALID_SITES) == 9

    def test_sites_without_replicates_subset_of_valid(self) -> None:
        assert SITES_WITHOUT_REPLICATES <= VALID_SITES

    def test_valid_seasons(self) -> None:
        assert isinstance(VALID_SEASONS, frozenset)
        assert "Baseline" in VALID_SEASONS

    def test_valid_periods(self) -> None:
        assert isinstance(VALID_PERIODS, frozenset)
        assert "Construction" in VALID_PERIODS
