#!/usr/bin/env python3
"""
Simple validation script for NeRF setup
Tests the basic structure and configuration without requiring heavy dependencies
"""

import sys
import os
import json
from pathlib import Path

def validate_directory_structure():
    """Validate that all required directories exist."""
    project_root = Path(__file__).parent.parent
    
    required_dirs = [
        'ai/nerf',
        'ai/inference',
        'ai/models',
        'ai/data',
        'backend/src/services',
        'config',
        'scripts',
        'logs',
    ]
    
    missing_dirs = []
    for dir_path in required_dirs:
        full_path = project_root / dir_path
        if not full_path.exists():
            missing_dirs.append(dir_path)
    
    if missing_dirs:
        print(f"✗ Missing directories: {missing_dirs}")
        return False
    else:
        print("✓ All required directories exist")
        return True

def validate_nerf_files():
    """Validate that all required NeRF files exist."""
    project_root = Path(__file__).parent.parent
    ai_dir = project_root / 'ai'
    
    required_files = [
        'nerf/__init__.py',
        'nerf/nerf_config.py',
        'nerf/nerf_model.py',
        'nerf/nerf_trainer.py',
        'nerf/nerf_service.py',
        'nerf/camera_nerf_analyzer.py',
        'inference/advanced_analyzer.py',
        'inference/scene_analyzer.py',
        'requirements.txt'
    ]
    
    missing_files = []
    for file_path in required_files:
        full_path = ai_dir / file_path
        if not full_path.exists():
            missing_files.append(file_path)
    
    if missing_files:
        print(f"✗ Missing AI files: {missing_files}")
        return False
    else:
        print("✓ All required AI files exist")
        return True

def validate_backend_integration():
    """Validate backend integration files."""
    project_root = Path(__file__).parent.parent
    backend_dir = project_root / 'backend' / 'src' / 'services'
    
    required_files = [
        'auto_adjustment_service.js',
        'nerf_integration_service.js'
    ]
    
    missing_files = []
    for file_path in required_files:
        full_path = backend_dir / file_path
        if not full_path.exists():
            missing_files.append(file_path)
    
    if missing_files:
        print(f"✗ Missing backend files: {missing_files}")
        return False
    else:
        print("✓ All required backend integration files exist")
        return True

def validate_configuration():
    """Validate configuration files."""
    project_root = Path(__file__).parent.parent
    
    config_files = [
        'config/nerf_config.json'
    ]
    
    missing_configs = []
    invalid_configs = []
    
    for config_file in config_files:
        config_path = project_root / config_file
        if not config_path.exists():
            missing_configs.append(config_file)
        else:
            try:
                with open(config_path, 'r') as f:
                    config_data = json.load(f)
                
                # Validate essential sections
                if config_file == 'config/nerf_config.json':
                    required_sections = ['service', 'nerf', 'integration']
                    missing_sections = [s for s in required_sections if s not in config_data]
                    if missing_sections:
                        invalid_configs.append(f"{config_file}: missing sections {missing_sections}")
                        
            except json.JSONDecodeError as e:
                invalid_configs.append(f"{config_file}: invalid JSON - {e}")
            except Exception as e:
                invalid_configs.append(f"{config_file}: error - {e}")
    
    issues = missing_configs + invalid_configs
    if issues:
        print(f"✗ Configuration issues: {issues}")
        return False
    else:
        print("✓ Configuration files are valid")
        return True

def validate_scripts():
    """Validate script files."""
    project_root = Path(__file__).parent.parent
    scripts_dir = project_root / 'scripts'
    
    required_scripts = [
        'start_nerf_service.sh',
        'test_nerf_pipeline.py'
    ]
    
    missing_scripts = []
    for script in required_scripts:
        script_path = scripts_dir / script
        if not script_path.exists():
            missing_scripts.append(script)
        elif not os.access(script_path, os.X_OK):
            print(f"⚠ Script {script} exists but is not executable")
    
    if missing_scripts:
        print(f"✗ Missing scripts: {missing_scripts}")
        return False
    else:
        print("✓ All required scripts exist")
        return True

def validate_python_syntax():
    """Validate Python syntax in NeRF files."""
    project_root = Path(__file__).parent.parent
    ai_dir = project_root / 'ai'
    
    python_files = [
        'nerf/nerf_config.py',
        'nerf/nerf_model.py',
        'nerf/nerf_trainer.py',
        'nerf/nerf_service.py',
        'nerf/camera_nerf_analyzer.py'
    ]
    
    syntax_errors = []
    for py_file in python_files:
        file_path = ai_dir / py_file
        if file_path.exists():
            try:
                with open(file_path, 'r') as f:
                    code = f.read()
                compile(code, str(file_path), 'exec')
            except SyntaxError as e:
                syntax_errors.append(f"{py_file}: {e}")
            except Exception as e:
                syntax_errors.append(f"{py_file}: {e}")
    
    if syntax_errors:
        print(f"✗ Python syntax errors: {syntax_errors}")
        return False
    else:
        print("✓ All Python files have valid syntax")
        return True

def check_integration_completeness():
    """Check if integration is complete."""
    project_root = Path(__file__).parent.parent
    
    # Check if auto_adjustment_service.js has NeRF integration
    auto_adj_file = project_root / 'backend' / 'src' / 'services' / 'auto_adjustment_service.js'
    
    if auto_adj_file.exists():
        with open(auto_adj_file, 'r') as f:
            content = f.read()
        
        integration_indicators = [
            'NeRFIntegrationService',
            'nerf_enhanced',
            'applyNeRFEnhancements'
        ]
        
        found_indicators = [indicator for indicator in integration_indicators if indicator in content]
        
        if len(found_indicators) >= 2:
            print("✓ NeRF integration is present in auto-adjustment service")
            return True
        else:
            print(f"⚠ NeRF integration may be incomplete (found: {found_indicators})")
            return False
    else:
        print("✗ Auto-adjustment service file not found")
        return False

def main():
    """Run all validation tests."""
    print("NeRF Setup Validation")
    print("=" * 50)
    
    tests = [
        ("Directory Structure", validate_directory_structure),
        ("NeRF Files", validate_nerf_files),
        ("Backend Integration", validate_backend_integration),
        ("Configuration", validate_configuration),
        ("Scripts", validate_scripts),
        ("Python Syntax", validate_python_syntax),
        ("Integration Completeness", check_integration_completeness)
    ]
    
    results = {}
    for test_name, test_func in tests:
        print(f"\nTesting {test_name}...")
        try:
            results[test_name] = test_func()
        except Exception as e:
            print(f"✗ {test_name} test failed with error: {e}")
            results[test_name] = False
    
    # Summary
    print("\n" + "=" * 50)
    print("VALIDATION SUMMARY")
    print("=" * 50)
    
    passed = sum(1 for result in results.values() if result)
    total = len(results)
    
    print(f"Tests Passed: {passed}/{total}")
    print(f"Success Rate: {(passed/total)*100:.1f}%")
    
    print("\nDetailed Results:")
    for test_name, result in results.items():
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"  {status} {test_name}")
    
    if passed == total:
        print("\n🎉 All validation tests passed!")
        print("The NeRF integration setup appears to be complete.")
        print("\nNext steps:")
        print("1. Install Python dependencies: cd ai && pip install -r requirements.txt")
        print("2. Start NeRF service: ./scripts/start_nerf_service.sh start")
        print("3. Test the integration with your camera application")
        return 0
    else:
        print(f"\n⚠ {total - passed} validation test(s) failed.")
        print("Please address the issues above before proceeding.")
        return 1

if __name__ == '__main__':
    sys.exit(main())