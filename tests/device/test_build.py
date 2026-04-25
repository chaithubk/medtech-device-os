"""Tests for Yocto build process."""

import os
import pytest


def test_yocto_structure():
    """Verify Yocto directory structure."""
    yocto_dir = os.path.join(os.path.dirname(__file__), '../../yocto')
    assert os.path.exists(os.path.join(yocto_dir, 'meta-medtech'))
    assert os.path.exists(os.path.join(yocto_dir, 'conf'))


def test_meta_medtech_layer():
    """Verify meta-medtech layer structure."""
    layer_dir = os.path.join(os.path.dirname(__file__), '../../yocto/meta-medtech')
    assert os.path.exists(os.path.join(layer_dir, 'conf/layer.conf'))
    assert os.path.exists(os.path.join(layer_dir, 'recipes-medtech'))


def test_scripts_executable():
    """Verify build scripts exist and are executable."""
    scripts_dir = os.path.join(os.path.dirname(__file__), '../../scripts')
    scripts = ['build.sh', 'run-qemu.sh', 'generate-sbom.sh']
    
    for script in scripts:
        script_path = os.path.join(scripts_dir, script)
        assert os.path.exists(script_path), f"{script} not found"
        assert os.access(script_path, os.X_OK), f"{script} is not executable"
