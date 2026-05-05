# /// script
# requires-python = ">=3.12"
# dependencies = ["pytest==9.0.3"]
# ///
"""Unit tests for verification_harness.py."""

from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import verification_harness as harness


class TestComputeComposite:
    def test_all_100(self) -> None:
        scores = {
            "Efficiency": 100,
            "False leads": 100,
            "Correctness": 100,
            "Confidence calibration": 100,
            "Clarity of communication": 100,
        }
        assert harness.compute_composite(scores) == 100.0

    def test_all_0(self) -> None:
        scores = {
            "Efficiency": 0,
            "False leads": 0,
            "Correctness": 0,
            "Confidence calibration": 0,
            "Clarity of communication": 0,
        }
        assert harness.compute_composite(scores) == 0.0

    def test_mixed_scores(self) -> None:
        scores = {
            "Efficiency": 80,
            "False leads": 90,
            "Correctness": 100,
            "Confidence calibration": 70,
            "Clarity of communication": 85,
        }
        # 80*0.20 + 90*0.20 + 100*0.25 + 70*0.15 + 85*0.20
        # = 16 + 18 + 25 + 10.5 + 17 = 86.5
        assert harness.compute_composite(scores) == pytest.approx(86.5)

    def test_boundary_at_90(self) -> None:
        scores = {
            "Efficiency": 90,
            "False leads": 90,
            "Correctness": 90,
            "Confidence calibration": 90,
            "Clarity of communication": 90,
        }
        assert harness.compute_composite(scores) == 90.0

    def test_weights_sum_to_one(self) -> None:
        total_weight = sum(w for _, w in harness.CRITERIA)
        assert total_weight == pytest.approx(1.0)


class TestFormatScoreLine:
    def test_format(self) -> None:
        scores = {
            "Efficiency": 95,
            "False leads": 90,
            "Correctness": 100,
            "Confidence calibration": 85,
            "Clarity of communication": 92,
        }
        composite = harness.compute_composite(scores)
        line = harness.format_score_line(scores, composite)
        assert "Efficiency 95/100" in line
        assert "False leads 90/100" in line
        assert "Correctness 100/100" in line
        assert "Confidence calibration 85/100" in line
        assert "Clarity of communication 92/100" in line
        assert "Composite:" in line


class TestAskDoneOrBlocked:
    def test_done(self) -> None:
        with patch("builtins.input", return_value="done"):
            assert harness.ask_done_or_blocked() == "done"

    def test_blocked(self) -> None:
        with patch("builtins.input", return_value="blocked"):
            assert harness.ask_done_or_blocked() == "blocked"

    def test_case_insensitive(self) -> None:
        with patch("builtins.input", return_value="DONE"):
            assert harness.ask_done_or_blocked() == "done"

    def test_invalid_then_valid(self) -> None:
        with patch("builtins.input", side_effect=["invalid", "done"]):
            assert harness.ask_done_or_blocked() == "done"

    def test_eof_returns_blocked(self) -> None:
        with patch("builtins.input", side_effect=EOFError):
            assert harness.ask_done_or_blocked() == "blocked"


class TestAskYesNo:
    def test_yes(self) -> None:
        with patch("builtins.input", return_value="yes"):
            assert harness.ask_yes_no("question?") is True

    def test_y(self) -> None:
        with patch("builtins.input", return_value="y"):
            assert harness.ask_yes_no("question?") is True

    def test_no(self) -> None:
        with patch("builtins.input", return_value="no"):
            assert harness.ask_yes_no("question?") is False

    def test_n(self) -> None:
        with patch("builtins.input", return_value="n"):
            assert harness.ask_yes_no("question?") is False

    def test_case_insensitive(self) -> None:
        with patch("builtins.input", return_value="YES"):
            assert harness.ask_yes_no("question?") is True

    def test_invalid_then_valid(self) -> None:
        with patch("builtins.input", side_effect=["maybe", "no"]):
            assert harness.ask_yes_no("question?") is False

    def test_eof_exits_with_1(self) -> None:
        with (
            patch("builtins.input", side_effect=EOFError),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.ask_yes_no("question?")
        assert exc_info.value.code == 1


class TestAskScore:
    def test_valid_score(self) -> None:
        with patch("builtins.input", return_value="85"):
            assert harness.ask_score("Efficiency") == 85

    def test_boundary_0(self) -> None:
        with patch("builtins.input", return_value="0"):
            assert harness.ask_score("Efficiency") == 0

    def test_boundary_100(self) -> None:
        with patch("builtins.input", return_value="100"):
            assert harness.ask_score("Efficiency") == 100

    def test_invalid_then_valid(self) -> None:
        with patch("builtins.input", side_effect=["abc", "-1", "101", "75"]):
            assert harness.ask_score("Efficiency") == 75

    def test_eof_exits_with_1(self) -> None:
        with (
            patch("builtins.input", side_effect=EOFError),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.ask_score("Efficiency")
        assert exc_info.value.code == 1


class TestAskChoice:
    def test_valid_choice(self) -> None:
        with patch("builtins.input", return_value="finishing"):
            assert (
                harness.ask_choice("choice?", ["finishing", "continuing"])
                == "finishing"
            )

    def test_case_insensitive(self) -> None:
        with patch("builtins.input", return_value="CONTINUING"):
            assert (
                harness.ask_choice("choice?", ["finishing", "continuing"])
                == "continuing"
            )

    def test_invalid_then_valid(self) -> None:
        with patch("builtins.input", side_effect=["invalid", "finishing"]):
            assert (
                harness.ask_choice("choice?", ["finishing", "continuing"])
                == "finishing"
            )

    def test_eof_exits_with_1(self) -> None:
        with (
            patch("builtins.input", side_effect=EOFError),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.ask_choice("choice?", ["finishing", "continuing"])
        assert exc_info.value.code == 1


class TestHandleBlocked:
    def test_exits_with_1(self) -> None:
        with (
            patch("builtins.input", return_value="something broke"),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.handle_blocked()
        assert exc_info.value.code == 1

    def test_eof_description(self) -> None:
        with (
            patch("builtins.input", side_effect=EOFError),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.handle_blocked()
        assert exc_info.value.code == 1


class TestCheckResponse:
    def test_done_does_not_exit(self) -> None:
        harness.check_response("done")  # should not raise

    def test_blocked_exits(self) -> None:
        with (
            patch("builtins.input", return_value="stuck"),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.check_response("blocked")
        assert exc_info.value.code == 1


class TestConfirmLessonFiled:
    def test_yes_immediately(self) -> None:
        with patch("builtins.input", return_value="yes"):
            result = harness.confirm_lesson_filed()
        assert result == "Lessons filed"

    def test_no_then_done_then_yes(self) -> None:
        inputs = ["no", "done", "yes"]
        with patch("builtins.input", side_effect=inputs):
            result = harness.confirm_lesson_filed()
        assert result == "Lessons filed"

    def test_no_then_blocked_exits(self) -> None:
        inputs = ["no", "blocked", "stuck"]
        with (
            patch("builtins.input", side_effect=inputs),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.confirm_lesson_filed()
        assert exc_info.value.code == 1


class TestStageDispatchCheck:
    def test_no_test_work(self) -> None:
        with patch("builtins.input", return_value="no"):
            harness.stage_dispatch_check()  # should not raise

    def test_dispatched_and_red_failed(self) -> None:
        with patch("builtins.input", side_effect=["yes", "yes", "yes"]):
            harness.stage_dispatch_check()  # should not raise

    def test_not_dispatched_exits_2(self) -> None:
        with (
            patch("builtins.input", side_effect=["yes", "no"]),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.stage_dispatch_check()
        assert exc_info.value.code == 2

    def test_red_not_failed_exits_2(self) -> None:
        with (
            patch("builtins.input", side_effect=["yes", "yes", "no"]),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.stage_dispatch_check()
        assert exc_info.value.code == 2


class TestStageToolCheck:
    def test_no_unavailability_claims(self) -> None:
        with patch("builtins.input", return_value="no"):
            harness.stage_tool_check()  # should not raise

    def test_verified_unavailability(self) -> None:
        with patch("builtins.input", side_effect=["yes", "yes"]):
            harness.stage_tool_check()  # should not raise

    def test_unverified_unavailability_exits_2(self) -> None:
        with (
            patch("builtins.input", side_effect=["yes", "no"]),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.stage_tool_check()
        assert exc_info.value.code == 2


class TestStageVerify:
    def test_confirmed(self) -> None:
        with patch("builtins.input", return_value="yes"):
            harness.stage_verify()  # should not raise

    def test_not_confirmed_exits_2(self) -> None:
        with (
            patch("builtins.input", return_value="no"),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.stage_verify()
        assert exc_info.value.code == 2


class TestStageAssess:
    def test_no_new_tests_needed(self) -> None:
        with patch("builtins.input", side_effect=["done", "no"]):
            harness.stage_assess()  # should not raise

    def test_tests_needed_and_satisfied(self) -> None:
        with patch("builtins.input", side_effect=["done", "yes", "yes"]):
            harness.stage_assess()  # should not raise

    def test_tests_needed_not_satisfied_exits_2(self) -> None:
        with (
            patch("builtins.input", side_effect=["done", "yes", "no"]),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.stage_assess()
        assert exc_info.value.code == 2


class TestStageRestructuringCheck:
    def test_no_restructuring(self) -> None:
        with patch("builtins.input", return_value="no"):
            harness.stage_restructuring_check()  # should not raise

    def test_restructured_and_dispatched(self) -> None:
        with patch("builtins.input", side_effect=["yes", "yes"]):
            harness.stage_restructuring_check()  # should not raise

    def test_restructured_not_dispatched_exits_2(self) -> None:
        with (
            patch("builtins.input", side_effect=["yes", "no"]),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.stage_restructuring_check()
        assert exc_info.value.code == 2


class TestStageFork:
    def test_finishing(self) -> None:
        with patch("builtins.input", return_value="finishing"):
            assert harness.stage_fork() == "finishing"

    def test_continuing(self) -> None:
        with patch("builtins.input", return_value="continuing"):
            assert harness.stage_fork() == "continuing"


class TestStageDifficultyReview:
    def test_no_difficulties(self) -> None:
        with patch("builtins.input", return_value="no"):
            result = harness.stage_difficulty_review()
        assert result == "No qualifying difficulties or discoveries"

    def test_with_difficulties_confirmed(self) -> None:
        # "yes" difficulties, "yes" has lesson
        inputs = ["yes", "yes"]
        with patch("builtins.input", side_effect=inputs):
            result = harness.stage_difficulty_review()
        assert result == "Lessons filed"

    def test_with_difficulties_no_lesson_then_creates(self) -> None:
        # "yes" difficulties, "no" lesson yet, done creating, "yes" has lesson now
        inputs = ["yes", "no", "done", "yes"]
        with patch("builtins.input", side_effect=inputs):
            result = harness.stage_difficulty_review()
        assert result == "Lessons filed"

    def test_yes_difficulties_no_lesson_then_blocked(self) -> None:
        inputs = ["yes", "no", "blocked", "stuck"]
        with (
            patch("builtins.input", side_effect=inputs),
            pytest.raises(SystemExit) as exc_info,
        ):
            harness.stage_difficulty_review()
        assert exc_info.value.code == 1


class TestStageSkillGapScan:
    def test_no_gaps(self) -> None:
        inputs = ["done", "no"]
        with patch("builtins.input", side_effect=inputs):
            result = harness.stage_skill_gap_scan()
        assert result == "No gaps found"

    def test_with_gaps(self) -> None:
        inputs = ["done", "yes", "yes"]
        with patch("builtins.input", side_effect=inputs):
            result = harness.stage_skill_gap_scan()
        assert result == "Lessons filed"


class TestStageSelfRating:
    def test_above_threshold(self) -> None:
        inputs = ["95", "95", "95", "95", "95"]
        with patch("builtins.input", side_effect=inputs):
            _scores, composite, extra = harness.stage_self_rating()
        assert composite == pytest.approx(95.0)
        assert extra == ""

    def test_below_threshold_triggers_lesson(self) -> None:
        inputs = ["80", "80", "80", "80", "80", "done", "yes"]
        with patch("builtins.input", side_effect=inputs):
            _scores, composite, extra = harness.stage_self_rating()
        assert composite == pytest.approx(80.0)
        assert extra == "Lessons filed"

    def test_exactly_90_passes(self) -> None:
        inputs = ["90", "90", "90", "90", "90"]
        with patch("builtins.input", side_effect=inputs):
            _scores, composite, extra = harness.stage_self_rating()
        assert composite == pytest.approx(90.0)
        assert extra == ""


class TestStageCompletionTemplate:
    def test_no_issues(self, capsys) -> None:
        scores = {
            "Efficiency": 95,
            "False leads": 95,
            "Correctness": 95,
            "Confidence calibration": 95,
            "Clarity of communication": 95,
        }
        harness.stage_completion_template(
            "No qualifying difficulties or discoveries",
            "No gaps found",
            scores,
            95.0,
            "",
        )
        captured = capsys.readouterr()
        assert "COMPLETION TEMPLATE" in captured.out
        assert "No qualifying difficulties or discoveries" in captured.out
        assert "No gaps found" in captured.out

    def test_with_lessons(self, capsys) -> None:
        scores = {
            "Efficiency": 80,
            "False leads": 80,
            "Correctness": 80,
            "Confidence calibration": 80,
            "Clarity of communication": 80,
        }
        harness.stage_completion_template(
            "https://github.com/org/repo/issues/1",
            "https://github.com/org/repo/issues/2",
            scores,
            80.0,
            "https://github.com/org/repo/issues/3",
        )
        captured = capsys.readouterr()
        assert "issues/1" in captured.out
        assert "issues/2" in captured.out
        assert "issues/3" in captured.out
