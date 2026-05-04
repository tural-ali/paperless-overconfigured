# Paperless Overconfigured - Test Suite

This directory contains comprehensive tests for all scripts in the repository.

## Test Structure

```
tests/
├── README.md                     # This file
├── test_install.bats            # Tests for install.sh helper functions
├── test_uninstall.bats          # Tests for uninstall.sh script
├── test_backup.bats             # Tests for backup.sh (generated script)
├── test_remove_blank_pages.bats # Tests for remove-blank-pages.sh
├── test_neo4j_sync.py           # Tests for neo4j-sync.py
└── test_post_consume_asn.py     # Tests for post-consume-asn.py
```

## Running Tests

### Prerequisites

Install the test frameworks:

```bash
# For BATS (Bash Automated Testing System)
# Ubuntu/Debian:
sudo apt-get install bats

# macOS:
brew install bats-core

# Or install from source:
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local

# For Python tests (pytest)
pip install pytest pytest-cov
```

### Running All Tests

```bash
# Run all BATS tests
bats tests/*.bats

# Run all Python tests
pytest tests/ -v

# Run all tests with coverage
pytest tests/ -v --cov=scripts --cov-report=html
```

### Running Individual Test Files

```bash
# Run install.sh tests
bats tests/test_install.bats

# Run uninstall.sh tests
bats tests/test_uninstall.bats

# Run backup.sh tests
bats tests/test_backup.bats

# Run remove-blank-pages.sh tests
bats tests/test_remove_blank_pages.bats

# Run neo4j-sync.py tests
pytest tests/test_neo4j_sync.py -v

# Run post-consume-asn.py tests
pytest tests/test_post_consume_asn.py -v
```

### Running Specific Tests

```bash
# Run a specific BATS test by name
bats tests/test_install.bats --filter "detect_os"

# Run a specific Python test class
pytest tests/test_neo4j_sync.py::TestPaperlessClient -v

# Run a specific Python test method
pytest tests/test_post_consume_asn.py::TestASNRegexPatterns::test_asn_qr_code_pattern_with_prefix -v
```

## Test Coverage Summary

### install.sh (test_install.bats)
- OS detection (Ubuntu, Debian, Fedora, RHEL, NixOS, macOS)
- Architecture detection (amd64, arm64)
- Secret/password generation
- OCR language selection
- Access method URL building
- LLM provider configuration
- Backup provider selection
- Docker Compose profiles

### uninstall.sh (test_uninstall.bats)
- Installation directory detection
- Uninstall choice handling (stop only, volumes, full removal)
- Confirmation prompts
- Cron job detection
- Docker image removal option

### backup.sh (test_backup.bats)
- Backup type determination (daily/weekly/monthly)
- Filename generation
- Rclone upload conditions
- GitHub backup conditions
- Healthchecks.io integration
- Retention periods
- Path construction

### remove-blank-pages.sh (test_remove_blank_pages.bats)
- PDF file extension detection
- Blank page threshold calculation
- Page counting logic
- Rebuild conditions
- qpdf return code handling

### neo4j-sync.py (test_neo4j_sync.py)
- Environment variable loading
- PaperlessClient initialization
- Pagination handling
- Node sync functions
- Content preview truncation
- Relationship creation
- Watch mode functionality

### post-consume-asn.py (test_post_consume_asn.py)
- QR code pattern matching
- OCR text pattern matching
- ASN value validation
- Image crop region calculations
- Upscaling calculations
- Environment variable handling
- Conflict detection
- Strategy ordering

## Writing New Tests

### BATS Test Template

```bash
#!/usr/bin/env bats

@test "description of what is being tested" {
    # Setup
    VAR="value"
    
    # Execute
    result=$(some_command)
    
    # Assert
    [ "$result" = "expected" ]
}
```

### Python Test Template

```python
import pytest

class TestFeatureName:
    """Tests for the feature."""

    def test_specific_behavior(self):
        """Test description."""
        # Setup
        input_value = "test"
        
        # Execute
        result = function_under_test(input_value)
        
        # Assert
        assert result == "expected"
```

## CI/CD Integration

Add to `.github/workflows/test.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test-bash:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install BATS
        run: sudo apt-get install -y bats
      - name: Run BATS tests
        run: bats tests/*.bats

  test-python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: pip install pytest pytest-cov requests
      - name: Run pytest
        run: pytest tests/*.py -v --cov --cov-report=xml
      - name: Upload coverage
        uses: codecov/codecov-action@v4
```
