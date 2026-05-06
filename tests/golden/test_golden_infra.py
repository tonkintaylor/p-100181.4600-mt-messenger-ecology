"""Tests for golden image comparison infrastructure."""

from __future__ import annotations

from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pytest
from PIL import Image

mpl.use("Agg")

from tests.golden.conftest import assert_images_similar


class TestAssertImagesSimilar:
    def test_identical_images_pass(self, tmp_path: Path) -> None:
        """Two identical images should pass comparison."""
        fig, ax = plt.subplots()
        ax.plot([1, 2, 3], [1, 4, 9])
        path1 = tmp_path / "img1.png"
        path2 = tmp_path / "img2.png"
        fig.savefig(path1, dpi=100)
        fig.savefig(path2, dpi=100)
        plt.close(fig)
        assert_images_similar(path1, path2, tolerance=0.0)

    def test_different_images_fail(self, tmp_path: Path) -> None:
        """Two very different images should fail comparison."""
        fig1, ax1 = plt.subplots()
        ax1.plot([1, 2, 3], [1, 4, 9])
        path1 = tmp_path / "img1.png"
        fig1.savefig(path1, dpi=100)
        plt.close(fig1)

        fig2, ax2 = plt.subplots()
        ax2.bar([1, 2, 3], [9, 4, 1])
        path2 = tmp_path / "img2.png"
        fig2.savefig(path2, dpi=100)
        plt.close(fig2)

        with pytest.raises(AssertionError):
            assert_images_similar(path1, path2, tolerance=1.0)

    def test_tolerance_allows_minor_differences(self, tmp_path: Path) -> None:
        """Small tolerance should allow minor rendering differences."""
        rng = np.random.default_rng(42)
        fig, ax = plt.subplots()
        ax.plot([1, 2, 3], [1, 4, 9])
        path1 = tmp_path / "img1.png"
        fig.savefig(path1, dpi=100)
        plt.close(fig)

        img = Image.open(path1)
        arr = np.array(img).astype(float)
        arr += rng.normal(0, 0.5, arr.shape)
        arr = np.clip(arr, 0, 255).astype(np.uint8)
        path2 = tmp_path / "img2.png"
        Image.fromarray(arr).save(path2)

        assert_images_similar(path1, path2, tolerance=5.0)


@pytest.mark.golden
class TestGoldenMarker:
    def test_marker_exists(self) -> None:
        """Verify the golden marker is registered."""
        assert True
