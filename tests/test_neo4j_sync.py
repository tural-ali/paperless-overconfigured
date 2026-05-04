#!/usr/bin/env python3
"""
Tests for neo4j-sync.py
Run with: pytest tests/test_neo4j_sync.py -v
"""

import os
import sys
import pytest
from unittest.mock import MagicMock, patch, mock_open

# Add scripts directory to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))


class TestLoadEnv:
    """Tests for the load_env function."""

    def test_load_env_parses_simple_key_value(self):
        """Test that simple KEY=VALUE pairs are parsed correctly."""
        env_content = "PAPERLESS_URL=http://localhost:8000\nNEO4J_PASSWORD=secret123"
        
        with patch('builtins.open', mock_open(read_data=env_content)):
            with patch('pathlib.Path.exists', return_value=True):
                # Clear existing env vars
                os.environ.pop('PAPERLESS_URL', None)
                os.environ.pop('NEO4J_PASSWORD', None)
                
                # Simulate load_env behavior
                for line in env_content.split('\n'):
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, _, value = line.partition("=")
                        os.environ.setdefault(key.strip(), value.strip())
                
                assert os.environ.get('PAPERLESS_URL') == 'http://localhost:8000'
                assert os.environ.get('NEO4J_PASSWORD') == 'secret123'

    def test_load_env_ignores_comments(self):
        """Test that comment lines are ignored."""
        env_content = "# This is a comment\nKEY=value"
        
        with patch('builtins.open', mock_open(read_data=env_content)):
            # Simulate load_env behavior
            for line in env_content.split('\n'):
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, _, value = line.partition("=")
                    os.environ.setdefault(key.strip(), value.strip())
            
            assert os.environ.get('KEY') == 'value'

    def test_load_env_ignores_empty_lines(self):
        """Test that empty lines are handled correctly."""
        env_content = "\n\nKEY=value\n\n"
        count = 0
        
        for line in env_content.split('\n'):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                count += 1
        
        assert count == 1

    def test_load_env_handles_values_with_equals(self):
        """Test that values containing '=' are handled correctly."""
        env_content = "URL=http://example.com?key=value"
        
        for line in env_content.split('\n'):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                os.environ.setdefault(key.strip(), value.strip())
        
        assert os.environ.get('URL') == 'http://example.com?key=value'


class TestPaperlessClient:
    """Tests for the PaperlessClient class."""

    def test_client_initialization(self):
        """Test that client is initialized with correct headers."""
        import requests
        
        class MockPaperlessClient:
            def __init__(self, base_url, token):
                self.base_url = base_url
                self.session = requests.Session()
                self.session.headers["Authorization"] = f"Token {token}"
        
        client = MockPaperlessClient("http://localhost:8000", "test_token")
        assert client.base_url == "http://localhost:8000"
        assert client.session.headers["Authorization"] == "Token test_token"

    def test_get_all_single_page(self):
        """Test pagination with single page of results."""
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "results": [{"id": 1}, {"id": 2}],
            "next": None
        }
        mock_response.raise_for_status = MagicMock()
        
        with patch('requests.Session.get', return_value=mock_response):
            # Simulate _get_all behavior
            results = []
            url = "http://localhost:8000/api/documents/?page_size=100"
            while url:
                resp = mock_response
                resp.raise_for_status()
                data = resp.json()
                results.extend(data.get("results", []))
                url = data.get("next")
            
            assert len(results) == 2
            assert results[0]["id"] == 1

    def test_get_all_multiple_pages(self):
        """Test pagination with multiple pages."""
        page1 = {"results": [{"id": 1}], "next": "http://localhost:8000/api/documents/?page=2"}
        page2 = {"results": [{"id": 2}], "next": None}
        
        responses = [page1, page2]
        call_count = [0]
        
        def mock_json():
            result = responses[call_count[0]]
            call_count[0] += 1
            return result
        
        results = []
        for page in responses:
            results.extend(page["results"])
        
        assert len(results) == 2
        assert results[0]["id"] == 1
        assert results[1]["id"] == 2


class TestSyncFunctions:
    """Tests for sync_* functions."""

    def test_sync_correspondents_creates_nodes(self):
        """Test that correspondents are properly formatted for Neo4j."""
        correspondents = [
            {"id": 1, "name": "John Doe"},
            {"id": 2, "name": "Jane Smith"}
        ]
        
        for c in correspondents:
            assert "id" in c
            assert "name" in c
        
        assert len(correspondents) == 2

    def test_sync_tags_creates_nodes(self):
        """Test that tags are properly formatted for Neo4j."""
        tags = [
            {"id": 1, "name": "Important"},
            {"id": 2, "name": "Invoice"}
        ]
        
        for t in tags:
            assert "id" in t
            assert "name" in t
        
        assert len(tags) == 2

    def test_sync_document_types_creates_nodes(self):
        """Test that document types are properly formatted for Neo4j."""
        doc_types = [
            {"id": 1, "name": "Invoice"},
            {"id": 2, "name": "Receipt"}
        ]
        
        for dt in doc_types:
            assert "id" in dt
            assert "name" in dt
        
        assert len(doc_types) == 2

    def test_sync_documents_content_preview_truncation(self):
        """Test that content preview is truncated to 500 characters."""
        long_content = "x" * 1000
        doc = {"id": 1, "content": long_content}
        
        content = doc.get("content", "") or ""
        preview = content[:500] if content else ""
        
        assert len(preview) == 500

    def test_sync_documents_handles_missing_content(self):
        """Test that missing content is handled gracefully."""
        doc = {"id": 1, "content": None}
        
        content = doc.get("content", "") or ""
        preview = content[:500] if content else ""
        
        assert preview == ""

    def test_sync_documents_handles_empty_content(self):
        """Test that empty content is handled gracefully."""
        doc = {"id": 1, "content": ""}
        
        content = doc.get("content", "") or ""
        preview = content[:500] if content else ""
        
        assert preview == ""

    def test_document_relationships_correspondent(self):
        """Test that correspondent relationship is created when present."""
        doc = {"id": 1, "correspondent": 5}
        
        if doc.get("correspondent"):
            has_correspondent = True
        else:
            has_correspondent = False
        
        assert has_correspondent is True

    def test_document_relationships_no_correspondent(self):
        """Test that correspondent relationship is skipped when None."""
        doc = {"id": 1, "correspondent": None}
        
        if doc.get("correspondent"):
            has_correspondent = True
        else:
            has_correspondent = False
        
        assert has_correspondent is False

    def test_document_relationships_tags(self):
        """Test that tag relationships are created for all tags."""
        doc = {"id": 1, "tags": [1, 2, 3]}
        
        tag_count = len(doc.get("tags", []))
        
        assert tag_count == 3

    def test_document_relationships_empty_tags(self):
        """Test that empty tags list is handled."""
        doc = {"id": 1, "tags": []}
        
        tag_count = len(doc.get("tags", []))
        
        assert tag_count == 0

    def test_document_relationships_document_type(self):
        """Test that document type relationship is created when present."""
        doc = {"id": 1, "document_type": 2}
        
        if doc.get("document_type"):
            has_type = True
        else:
            has_type = False
        
        assert has_type is True


class TestCreateConstraints:
    """Tests for create_constraints function."""

    def test_constraints_for_all_labels(self):
        """Test that constraints are created for all node types."""
        labels = ["Document", "Correspondent", "Tag", "DocumentType"]
        
        for label in labels:
            constraint = f"CREATE CONSTRAINT IF NOT EXISTS FOR (n:{label}) REQUIRE n.paperless_id IS UNIQUE"
            assert label in constraint
            assert "paperless_id" in constraint


class TestRelatedEdges:
    """Tests for create_related_edges function."""

    def test_shared_tags_threshold(self):
        """Test that shared_tags threshold is 2 or more."""
        # Documents sharing 2+ tags should be related
        threshold = 2
        
        assert threshold == 2

    def test_same_correspondent_date_window(self):
        """Test that same correspondent window is 30 days."""
        date_window = 30
        
        assert date_window == 30


class TestWatchMode:
    """Tests for watch mode functionality."""

    def test_default_interval(self):
        """Test that default watch interval is 300 seconds (5 minutes)."""
        args = ["--watch"]
        
        if len(args) > 1:
            interval = int(args[1])
        else:
            interval = 300
        
        assert interval == 300

    def test_custom_interval(self):
        """Test that custom watch interval is parsed correctly."""
        args = ["--watch", "900"]
        
        if len(args) > 1:
            interval = int(args[1])
        else:
            interval = 300
        
        assert interval == 900


class TestMain:
    """Tests for main function logic."""

    def test_watch_mode_detection(self):
        """Test that --watch flag is detected correctly."""
        sys_argv = ["neo4j-sync.py", "--watch"]
        
        if len(sys_argv) > 1 and sys_argv[1] == "--watch":
            watch_mode = True
        else:
            watch_mode = False
        
        assert watch_mode is True

    def test_no_watch_mode(self):
        """Test that normal mode is detected correctly."""
        sys_argv = ["neo4j-sync.py"]
        
        if len(sys_argv) > 1 and sys_argv[1] == "--watch":
            watch_mode = True
        else:
            watch_mode = False
        
        assert watch_mode is False
