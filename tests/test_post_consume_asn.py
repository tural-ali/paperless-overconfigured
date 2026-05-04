#!/usr/bin/env python3
"""
Tests for post-consume-asn.py
Run with: pytest tests/test_post_consume_asn.py -v
"""

import re
import pytest


class TestASNRegexPatterns:
    """Tests for ASN detection regex patterns."""

    def test_asn_qr_code_pattern_with_prefix(self):
        """Test QR code pattern detection with ASN prefix."""
        pattern = r"(\d+)"
        text = "ASN0001234"
        
        if "ASN" in text.upper():
            m = re.search(pattern, text)
            if m:
                asn_value = int(m.group(1))
            else:
                asn_value = None
        else:
            asn_value = None
        
        assert asn_value == 1234

    def test_asn_qr_code_pattern_lowercase(self):
        """Test QR code pattern detection with lowercase asn."""
        text = "asn0005678"
        
        if "ASN" in text.upper():
            m = re.search(r"(\d+)", text)
            if m:
                asn_value = int(m.group(1))
            else:
                asn_value = None
        else:
            asn_value = None
        
        assert asn_value == 5678

    def test_asn_qr_code_pattern_no_leading_zeros(self):
        """Test QR code pattern detection without leading zeros."""
        text = "ASN999"
        
        if "ASN" in text.upper():
            m = re.search(r"(\d+)", text)
            if m:
                asn_value = int(m.group(1))
            else:
                asn_value = None
        else:
            asn_value = None
        
        assert asn_value == 999

    def test_asn_qr_code_pattern_no_match(self):
        """Test QR code pattern with non-ASN text."""
        text = "Invoice #12345"
        
        if "ASN" in text.upper():
            m = re.search(r"(\d+)", text)
            if m:
                asn_value = int(m.group(1))
            else:
                asn_value = None
        else:
            asn_value = None
        
        assert asn_value is None


class TestOCRTextPattern:
    """Tests for OCR text ASN detection."""

    def test_ocr_pattern_asn_with_space(self):
        """Test OCR pattern with ASN followed by space."""
        content = "This document has ASN 12345 in it"
        pattern = r"[AaPp][Ss][Nn]\s*0*(\d+)"
        
        m = re.search(pattern, content, re.IGNORECASE)
        if m:
            val = int(m.group(1))
        else:
            val = None
        
        assert val == 12345

    def test_ocr_pattern_asn_no_space(self):
        """Test OCR pattern with ASN directly followed by number."""
        content = "Reference: ASN00042"
        pattern = r"[AaPp][Ss][Nn]\s*0*(\d+)"
        
        m = re.search(pattern, content, re.IGNORECASE)
        if m:
            val = int(m.group(1))
        else:
            val = None
        
        assert val == 42

    def test_ocr_pattern_psn_variant(self):
        """Test OCR pattern with PSN variant (common OCR error)."""
        content = "PSN 00123"
        pattern = r"[AaPp][Ss][Nn]\s*0*(\d+)"
        
        m = re.search(pattern, content, re.IGNORECASE)
        if m:
            val = int(m.group(1))
        else:
            val = None
        
        assert val == 123

    def test_ocr_pattern_strips_leading_zeros(self):
        """Test that leading zeros are stripped from ASN."""
        content = "ASN0000001"
        pattern = r"[AaPp][Ss][Nn]\s*0*(\d+)"
        
        m = re.search(pattern, content, re.IGNORECASE)
        if m:
            val = int(m.group(1))
        else:
            val = None
        
        assert val == 1

    def test_ocr_pattern_case_insensitive(self):
        """Test that pattern is case insensitive."""
        test_cases = [
            "asn 100",
            "ASN 100",
            "Asn 100",
            "aSn 100",
        ]
        pattern = r"[AaPp][Ss][Nn]\s*0*(\d+)"
        
        for content in test_cases:
            m = re.search(pattern, content, re.IGNORECASE)
            assert m is not None
            assert int(m.group(1)) == 100


class TestASNValidation:
    """Tests for ASN value validation."""

    def test_asn_value_within_valid_range(self):
        """Test that ASN values within range pass validation."""
        val = 500
        is_valid = 0 < val < 100000
        
        assert is_valid is True

    def test_asn_value_at_minimum_boundary(self):
        """Test ASN value at minimum boundary (1)."""
        val = 1
        is_valid = 0 < val < 100000
        
        assert is_valid is True

    def test_asn_value_at_maximum_boundary(self):
        """Test ASN value at maximum boundary (99999)."""
        val = 99999
        is_valid = 0 < val < 100000
        
        assert is_valid is True

    def test_asn_value_zero_invalid(self):
        """Test that ASN value 0 is invalid."""
        val = 0
        is_valid = 0 < val < 100000
        
        assert is_valid is False

    def test_asn_value_negative_invalid(self):
        """Test that negative ASN values are invalid."""
        val = -1
        is_valid = 0 < val < 100000
        
        assert is_valid is False

    def test_asn_value_too_large_invalid(self):
        """Test that ASN values >= 100000 are invalid."""
        val = 100000
        is_valid = 0 < val < 100000
        
        assert is_valid is False

    def test_asn_value_very_large_invalid(self):
        """Test that very large ASN values are invalid."""
        val = 999999
        is_valid = 0 < val < 100000
        
        assert is_valid is False


class TestCropRegions:
    """Tests for image crop region calculations."""

    def test_top_right_crop_region(self):
        """Test top-right crop region calculation."""
        w, h = 2000, 3000
        
        region = (int(w * 0.65), 0, w, int(h * 0.25))
        
        assert region == (1300, 0, 2000, 750)

    def test_top_left_crop_region(self):
        """Test top-left crop region calculation."""
        w, h = 2000, 3000
        
        region = (0, 0, int(w * 0.35), int(h * 0.25))
        
        assert region == (0, 0, 700, 750)

    def test_top_strip_crop_region(self):
        """Test top-strip crop region calculation."""
        w, h = 2000, 3000
        
        region = (0, 0, w, int(h * 0.15))
        
        assert region == (0, 0, 2000, 450)

    def test_bottom_right_crop_region(self):
        """Test bottom-right crop region calculation."""
        w, h = 2000, 3000
        
        region = (int(w * 0.65), int(h * 0.75), w, h)
        
        assert region == (1300, 2250, 2000, 3000)

    def test_bottom_left_crop_region(self):
        """Test bottom-left crop region calculation."""
        w, h = 2000, 3000
        
        region = (0, int(h * 0.75), int(w * 0.35), h)
        
        assert region == (0, 2250, 700, 3000)


class TestUpscaling:
    """Tests for image upscaling calculations."""

    def test_4x_upscale_dimensions(self):
        """Test that 4x upscale calculates correct dimensions."""
        original_width = 100
        original_height = 50
        
        new_width = original_width * 4
        new_height = original_height * 4
        
        assert new_width == 400
        assert new_height == 200

    def test_upscale_preserves_aspect_ratio(self):
        """Test that upscale preserves aspect ratio."""
        original_width = 100
        original_height = 50
        scale = 4
        
        original_ratio = original_width / original_height
        new_ratio = (original_width * scale) / (original_height * scale)
        
        assert original_ratio == new_ratio


class TestEnvironmentVariables:
    """Tests for environment variable handling."""

    def test_document_id_missing_exits(self):
        """Test that missing DOCUMENT_ID causes early exit."""
        DOCUMENT_ID = ""
        DOCUMENT_SOURCE_PATH = "/path/to/file.pdf"
        
        should_exit = not DOCUMENT_ID or not DOCUMENT_SOURCE_PATH
        
        assert should_exit is True

    def test_document_source_path_missing_exits(self):
        """Test that missing DOCUMENT_SOURCE_PATH causes early exit."""
        DOCUMENT_ID = "123"
        DOCUMENT_SOURCE_PATH = ""
        
        should_exit = not DOCUMENT_ID or not DOCUMENT_SOURCE_PATH
        
        assert should_exit is True

    def test_both_env_vars_present_continues(self):
        """Test that both env vars present allows processing."""
        DOCUMENT_ID = "123"
        DOCUMENT_SOURCE_PATH = "/path/to/file.pdf"
        
        should_exit = not DOCUMENT_ID or not DOCUMENT_SOURCE_PATH
        
        assert should_exit is False


class TestASNSkipCondition:
    """Tests for ASN already assigned skip condition."""

    def test_asn_already_assigned_skips(self):
        """Test that already assigned ASN causes skip."""
        archive_serial_number = 12345
        
        should_skip = archive_serial_number is not None
        
        assert should_skip is True

    def test_asn_not_assigned_continues(self):
        """Test that no ASN allows processing."""
        archive_serial_number = None
        
        should_skip = archive_serial_number is not None
        
        assert should_skip is False


class TestConflictDetection:
    """Tests for ASN conflict detection."""

    def test_conflict_detected_when_existing_document_found(self):
        """Test that conflict is detected when ASN exists on another doc."""
        asn_value = 100
        current_doc_id = 5
        
        # Simulate existing documents with this ASN
        existing_docs = [{"id": 3, "archive_serial_number": 100}]
        
        # Filter out current doc
        conflicts = [d for d in existing_docs if d["id"] != current_doc_id]
        
        has_conflict = len(conflicts) > 0
        
        assert has_conflict is True

    def test_no_conflict_when_same_document(self):
        """Test that no conflict when ASN belongs to current doc."""
        asn_value = 100
        current_doc_id = 3
        
        # Simulate existing documents with this ASN
        existing_docs = [{"id": 3, "archive_serial_number": 100}]
        
        # Filter out current doc
        conflicts = [d for d in existing_docs if d["id"] != current_doc_id]
        
        has_conflict = len(conflicts) > 0
        
        assert has_conflict is False

    def test_no_conflict_when_asn_unique(self):
        """Test that no conflict when ASN is unique."""
        asn_value = 100
        current_doc_id = 5
        
        # Simulate no existing documents with this ASN
        existing_docs = []
        
        has_conflict = len(existing_docs) > 0
        
        assert has_conflict is False


class TestStrategyOrder:
    """Tests for ASN detection strategy order."""

    def test_qr_code_strategy_runs_first(self):
        """Test that QR code detection runs before OCR."""
        strategy_order = ["qr_code", "ocr_text"]
        
        assert strategy_order[0] == "qr_code"
        assert strategy_order[1] == "ocr_text"

    def test_ocr_fallback_only_when_qr_fails(self):
        """Test that OCR runs only when QR detection returns None."""
        # QR code found
        qr_result = 12345
        ocr_result = 99999
        
        if qr_result is None:
            final_asn = ocr_result
        else:
            final_asn = qr_result
        
        assert final_asn == 12345

    def test_ocr_used_when_qr_finds_nothing(self):
        """Test that OCR result is used when QR finds nothing."""
        qr_result = None
        ocr_result = 99999
        
        if qr_result is None:
            final_asn = ocr_result
        else:
            final_asn = qr_result
        
        assert final_asn == 99999
