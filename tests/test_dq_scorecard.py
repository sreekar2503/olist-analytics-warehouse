"""
Unit tests for the scorecard's joining logic.

These run without a database or a dbt build, against hand-built fixtures, so CI
can verify the mechanism even when the CC BY-NC-SA dataset is unavailable. The
scorecard is the artifact the README's quality claims rest on; testing it only
by running it would mean the only evidence it works is that it produced output.
"""

import importlib.util
import sys
from pathlib import Path

import pandas as pd
import pytest

ROOT = Path(__file__).resolve().parents[1]

spec = importlib.util.spec_from_file_location("dq", ROOT / "scripts" / "dq_scorecard.py")
dq = importlib.util.module_from_spec(spec)
sys.modules["dq"] = dq
spec.loader.exec_module(dq)


def manifest(*tests):
    """Build a minimal manifest containing the given (id, name, dimension) tests."""
    nodes = {}
    for uid, name, dimension in tests:
        config = {"meta": {"dq_dimension": dimension}} if dimension else {"meta": {}}
        nodes[uid] = {"resource_type": "test", "name": name, "config": config}
    nodes["model.olist.stg_orders"] = {"resource_type": "model", "name": "stg_orders"}
    return {"nodes": nodes}


def results(*rows):
    """Build minimal run_results from (id, status, failures) rows."""
    return {"results": [
        {"unique_id": uid, "status": status, "failures": failures}
        for uid, status, failures in rows
    ]}


def test_dimension_is_read_from_test_config():
    df = dq.collect(
        manifest(("test.a", "unique_order_id", "uniqueness")),
        results(("test.a", "pass", 0)),
    )
    assert df.loc[0, "dimension"] == "uniqueness"
    assert bool(df.loc[0, "passed"]) is True


def test_untagged_test_is_surfaced_not_dropped():
    """An untagged test must appear as 'untagged'. Silently ignoring it would
    overstate coverage, which is the exact failure this project argues against."""
    df = dq.collect(
        manifest(("test.a", "some_test", None)),
        results(("test.a", "pass", 0)),
    )
    assert df.loc[0, "dimension"] == "untagged"

    card = dq.scorecard(df)
    assert "untagged" in card.index
    assert card.loc["untagged", "tests"] == 1


def test_uncovered_dimension_keeps_its_row_with_zero_tests():
    """A dimension with no tests is a finding, not a row to reindex away."""
    df = dq.collect(
        manifest(("test.a", "t", "uniqueness")),
        results(("test.a", "pass", 0)),
    )
    card = dq.scorecard(df)

    for dimension in dq.DIMENSIONS:
        assert dimension in card.index, f"{dimension} vanished from the scorecard"

    assert card.loc["timeliness", "tests"] == 0
    # pandas stores the missing rate as NaN in a float column, which is what
    # writes an empty field to the CSV. Empty is the honest rendering: a
    # dimension with no tests has no pass rate, and 0.0 would read as failure
    # while 1.0 would read as perfect coverage.
    assert pd.isna(card.loc["timeliness", "pass_rate"])


def test_dimension_order_is_fixed():
    """The published order must not depend on dict iteration or row order."""
    df = dq.collect(
        manifest(("test.a", "t", "accuracy"), ("test.b", "u", "completeness")),
        results(("test.b", "pass", 0), ("test.a", "pass", 0)),
    )
    assert list(dq.scorecard(df).index)[:6] == dq.DIMENSIONS


def test_a_warn_does_not_count_as_a_pass():
    """dbt reports a threshold breach as 'warn'. Counting that as a pass would
    let a real defect show up as a 1.000 pass rate."""
    df = dq.collect(
        manifest(("test.a", "weight_positive", "accuracy")),
        results(("test.a", "warn", 4)),
    )
    card = dq.scorecard(df)
    assert card.loc["accuracy", "tests"] == 1
    assert card.loc["accuracy", "passed"] == 0
    assert card.loc["accuracy", "pass_rate"] == 0.0
    assert card.loc["accuracy", "failing_rows"] == 4


def test_failing_rows_are_summed_within_a_dimension():
    df = dq.collect(
        manifest(("test.a", "t", "accuracy"), ("test.b", "u", "accuracy")),
        results(("test.a", "fail", 61), ("test.b", "warn", 4)),
    )
    assert dq.scorecard(df).loc["accuracy", "failing_rows"] == 65


def test_models_are_ignored_only_tests_are_scored():
    df = dq.collect(
        manifest(("test.a", "t", "validity")),
        results(("test.a", "pass", 0), ("model.olist.stg_orders", "success", 0)),
    )
    assert len(df) == 1


def test_pass_rate_is_rounded_to_three_places():
    df = dq.collect(
        manifest(*[(f"test.{i}", f"t{i}", "validity") for i in range(3)]),
        results(("test.0", "pass", 0), ("test.1", "pass", 0), ("test.2", "fail", 1)),
    )
    assert dq.scorecard(df).loc["validity", "pass_rate"] == pytest.approx(0.667)
