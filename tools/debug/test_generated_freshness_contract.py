from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def need(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"{label}: unexpected {needle!r}")


def test_generated_freshness_normalizes_text_line_endings() -> None:
    """Freshness sentinels must survive Windows CRLF checkouts while still
    treating binary source assets as exact bytes."""
    checker = read("tools/probes/check_generated_freshness.py")
    need(checker, "TEXT_HASH_SUFFIXES", "text suffix allowlist")
    need(checker, "normalize_text_line_endings", "line-ending normalizer")
    need(checker, "path.suffix.lower()", "suffix-based text detection")
    need(checker, "b\"\\r\\n\"", "CRLF normalization")
    need(checker, "b\"\\r\"", "CR normalization")
    reject(checker, "\".bin\"", "binary files must keep raw hashing")


if __name__ == "__main__":
    test_generated_freshness_normalizes_text_line_endings()
    print("PASS: Generated freshness contract")
