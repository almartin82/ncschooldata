"""
Tests for pyncschooldata Python wrapper.

Minimal smoke tests - the actual data logic is tested by R testthat.
These just verify the Python wrapper imports and exposes expected functions.
"""

import pytest


def test_import_package():
    """Package imports successfully."""
    import pyncschooldata
    assert pyncschooldata is not None


def test_has_fetch_enr():
    """fetch_enr function is available."""
    import pyncschooldata
    assert hasattr(pyncschooldata, 'fetch_enr')
    assert callable(pyncschooldata.fetch_enr)


def test_has_get_available_years():
    """get_available_years function is available."""
    import pyncschooldata
    assert hasattr(pyncschooldata, 'get_available_years')
    assert callable(pyncschooldata.get_available_years)


def test_has_version():
    """Package has a version string."""
    import pyncschooldata
    assert hasattr(pyncschooldata, '__version__')
    assert isinstance(pyncschooldata.__version__, str)
