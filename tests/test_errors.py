"""Tests for error types and DomainResult."""

from __future__ import annotations

from mgen.shared.errors import DomainResult, ValidationError


class TestValidationError:
    def test_str_format(self) -> None:
        err = ValidationError(
            domain="macro",
            severity="error",
            file="data.xlsx",
            sheet="Macro1",
            location="column 'Site', rows [0]",
            message="Missing values",
        )

        result = str(err)

        assert "[ERROR]" in result
        assert "data.xlsx" in result
        assert "Macro1" in result
        assert "Missing values" in result

    def test_str_format_warning(self) -> None:
        err = ValidationError(
            domain="sediment",
            severity="warning",
            file="f.xlsx",
            sheet="S1",
            location="header",
            message="Extra column",
        )

        assert "[WARNING]" in str(err)


class TestDomainResult:
    def test_ok_when_no_errors(self) -> None:
        result = DomainResult()

        assert result.ok is True

    def test_ok_when_only_warnings(self) -> None:
        result = DomainResult(
            errors=[
                ValidationError(
                    domain="test",
                    severity="warning",
                    file="f",
                    sheet="s",
                    location="l",
                    message="m",
                )
            ]
        )

        assert result.ok is True

    def test_not_ok_when_error_present(self) -> None:
        result = DomainResult(
            errors=[
                ValidationError(
                    domain="test",
                    severity="error",
                    file="f",
                    sheet="s",
                    location="l",
                    message="m",
                )
            ]
        )

        assert result.ok is False
