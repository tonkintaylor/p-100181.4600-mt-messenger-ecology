"""Golden image comparison utilities for visual regression testing."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


def assert_images_similar(
    actual: Path,
    expected: Path,
    tolerance: float = 2.0,
) -> None:
    """Assert two images are similar within tolerance.

    Computes the root-mean-square difference between pixel values.
    Tolerance is in terms of pixel intensity (0-255 scale).

    Args:
        actual: Path to the generated image.
        expected: Path to the golden reference image.
        tolerance: Maximum allowed RMS difference (0-255 scale).

    Raises:
        AssertionError: If images differ by more than tolerance.
        FileNotFoundError: If either image path doesn't exist.
    """
    if not actual.exists():
        msg = f"Actual image not found: {actual}"
        raise FileNotFoundError(msg)
    if not expected.exists():
        msg = f"Expected image not found: {expected}"
        raise FileNotFoundError(msg)

    img_actual = Image.open(actual).convert("RGB")
    img_expected = Image.open(expected).convert("RGB")

    # Resize if dimensions differ (shouldn't happen in practice)
    if img_actual.size != img_expected.size:
        msg = (
            f"Image dimensions differ: {img_actual.size} vs {img_expected.size}\n"
            f"  Actual: {actual}\n"
            f"  Expected: {expected}"
        )
        raise AssertionError(msg)

    arr_actual = np.array(img_actual, dtype=float)
    arr_expected = np.array(img_expected, dtype=float)

    rms_diff = np.sqrt(np.mean((arr_actual - arr_expected) ** 2))

    if rms_diff > tolerance:
        msg = (
            f"Images differ by RMS={rms_diff:.2f} "
            f"(tolerance={tolerance:.2f})\n"
            f"  Actual: {actual}\n"
            f"  Expected: {expected}"
        )
        raise AssertionError(msg)
