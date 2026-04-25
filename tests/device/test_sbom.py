"""Tests for SBOM generation."""

import json
import os
import pytest


def test_sbom_generation():
    """Test SBOM can be generated."""
    sbom_dir = os.path.join(os.path.dirname(__file__), '../../sbom')
    sbom_file = os.path.join(sbom_dir, 'sbom.json')
    
    # Skip if not generated yet
    if not os.path.exists(sbom_file):
        pytest.skip("SBOM not generated yet")
    
    with open(sbom_file) as f:
        sbom = json.load(f)
    
    # Validate SBOM structure
    assert "bomFormat" in sbom
    assert sbom["bomFormat"] == "CycloneDX"
    assert "components" in sbom
    assert len(sbom["components"]) > 0
