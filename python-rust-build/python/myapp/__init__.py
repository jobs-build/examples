"""JOBS python-rust-build example: a click+rich app with a PyO3 native module."""

from myapp._native import greeting

__all__ = ["greeting"]
