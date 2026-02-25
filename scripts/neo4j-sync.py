#!/usr/bin/env python3
"""
Paperless Overconfigured — Neo4j Graph Sync

Syncs documents, correspondents, tags, and document types from Paperless-NGX
into a Neo4j graph database with relationship edges.

Usage:
    python3 neo4j-sync.py                # One-shot full sync
    python3 neo4j-sync.py --watch        # Continuous sync every 5 minutes
    python3 neo4j-sync.py --watch 900    # Continuous sync every 15 minutes

Environment variables (reads from .env automatically):
    PAPERLESS_URL           Paperless base URL (default: http://localhost:8000)
    PAPERLESS_API_TOKEN     Paperless API token (required)
    NEO4J_URI               Neo4j bolt URI (default: bolt://localhost:7687)
    NEO4J_PASSWORD          Neo4j password (required)
"""

import os
import sys
import time
import logging
from datetime import datetime, timedelta
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("neo4j-sync")

try:
    import requests
except ImportError:
    sys.exit("Missing dependency: pip install requests")

try:
    from neo4j import GraphDatabase
except ImportError:
    sys.exit("Missing dependency: pip install neo4j")


def load_env():
    """Load .env file from script directory or parent."""
    for path in [
        Path(__file__).resolve().parent.parent / ".env",
        Path(__file__).resolve().parent / ".env",
    ]:
        if path.exists():
            with open(path) as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, _, value = line.partition("=")
                        os.environ.setdefault(key.strip(), value.strip())
            break


load_env()

PAPERLESS_URL = os.environ.get("PAPERLESS_URL", "http://localhost:8000").rstrip("/")
PAPERLESS_TOKEN = os.environ.get("PAPERLESS_API_TOKEN", "")
NEO4J_URI = os.environ.get("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = "neo4j"
NEO4J_PASSWORD = os.environ.get("NEO4J_PASSWORD", "")

if not PAPERLESS_TOKEN:
    sys.exit("PAPERLESS_API_TOKEN is required. Set it in .env or environment.")
if not NEO4J_PASSWORD:
    sys.exit("NEO4J_PASSWORD is required. Set it in .env or environment.")


class PaperlessClient:
    """Minimal Paperless-NGX API client."""

    def __init__(self, base_url, token):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Token {token}"

    def _get_all(self, endpoint):
        """Paginate through all results."""
        url = f"{self.base_url}/api/{endpoint}/?page_size=100"
        results = []
        while url:
            resp = self.session.get(url, timeout=30)
            resp.raise_for_status()
            data = resp.json()
            results.extend(data.get("results", []))
            url = data.get("next")
        return results

    def documents(self):
        return self._get_all("documents")

    def correspondents(self):
        return self._get_all("correspondents")

    def tags(self):
        return self._get_all("tags")

    def document_types(self):
        return self._get_all("document_types")


def create_constraints(session):
    """Create uniqueness constraints for node types."""
    for label, prop in [
        ("Document", "paperless_id"),
        ("Correspondent", "paperless_id"),
        ("Tag", "paperless_id"),
        ("DocumentType", "paperless_id"),
    ]:
        session.run(
            f"CREATE CONSTRAINT IF NOT EXISTS "
            f"FOR (n:{label}) REQUIRE n.{prop} IS UNIQUE"
        )


def sync_correspondents(session, correspondents):
    """Merge correspondent nodes."""
    for c in correspondents:
        session.run(
            "MERGE (c:Correspondent {paperless_id: $id}) "
            "SET c.name = $name",
            id=c["id"],
            name=c["name"],
        )
    log.info("Synced %d correspondents", len(correspondents))


def sync_tags(session, tags):
    """Merge tag nodes."""
    for t in tags:
        session.run(
            "MERGE (t:Tag {paperless_id: $id}) "
            "SET t.name = $name",
            id=t["id"],
            name=t["name"],
        )
    log.info("Synced %d tags", len(tags))


def sync_document_types(session, doc_types):
    """Merge document type nodes."""
    for dt in doc_types:
        session.run(
            "MERGE (dt:DocumentType {paperless_id: $id}) "
            "SET dt.name = $name",
            id=dt["id"],
            name=dt["name"],
        )
    log.info("Synced %d document types", len(doc_types))


def sync_documents(session, documents):
    """Merge document nodes and create relationships."""
    for doc in documents:
        content = doc.get("content", "") or ""
        preview = content[:500] if content else ""

        session.run(
            "MERGE (d:Document {paperless_id: $id}) "
            "SET d.title = $title, "
            "    d.created = $created, "
            "    d.added = $added, "
            "    d.asn = $asn, "
            "    d.content_preview = $preview",
            id=doc["id"],
            title=doc.get("title", ""),
            created=doc.get("created", ""),
            added=doc.get("added", ""),
            asn=doc.get("archive_serial_number"),
            preview=preview,
        )

        # Correspondent relationship
        if doc.get("correspondent"):
            session.run(
                "MATCH (d:Document {paperless_id: $doc_id}) "
                "MATCH (c:Correspondent {paperless_id: $corr_id}) "
                "MERGE (d)-[:SENT_BY]->(c)",
                doc_id=doc["id"],
                corr_id=doc["correspondent"],
            )

        # Tag relationships
        for tag_id in doc.get("tags", []):
            session.run(
                "MATCH (d:Document {paperless_id: $doc_id}) "
                "MATCH (t:Tag {paperless_id: $tag_id}) "
                "MERGE (d)-[:TAGGED_WITH]->(t)",
                doc_id=doc["id"],
                tag_id=tag_id,
            )

        # Document type relationship
        if doc.get("document_type"):
            session.run(
                "MATCH (d:Document {paperless_id: $doc_id}) "
                "MATCH (dt:DocumentType {paperless_id: $dt_id}) "
                "MERGE (d)-[:HAS_TYPE]->(dt)",
                doc_id=doc["id"],
                dt_id=doc["document_type"],
            )

    log.info("Synced %d documents with relationships", len(documents))


def create_related_edges(session):
    """Create RELATED_TO edges between documents sharing 2+ tags."""
    result = session.run(
        "MATCH (d1:Document)-[:TAGGED_WITH]->(t:Tag)<-[:TAGGED_WITH]-(d2:Document) "
        "WHERE d1.paperless_id < d2.paperless_id "
        "WITH d1, d2, COUNT(t) AS shared_tags "
        "WHERE shared_tags >= 2 "
        "MERGE (d1)-[r:RELATED_TO]-(d2) "
        "SET r.shared_tags = shared_tags "
        "RETURN COUNT(r) AS created"
    )
    count = result.single()["created"]
    if count:
        log.info("Created/updated %d RELATED_TO edges (shared tags)", count)

    # Also link documents from same correspondent within 30 days
    result = session.run(
        "MATCH (d1:Document)-[:SENT_BY]->(c:Correspondent)<-[:SENT_BY]-(d2:Document) "
        "WHERE d1.paperless_id < d2.paperless_id "
        "  AND d1.created IS NOT NULL AND d2.created IS NOT NULL "
        "  AND d1.created <> '' AND d2.created <> '' "
        "  AND abs(duration.between(date(d1.created), date(d2.created)).days) <= 30 "
        "MERGE (d1)-[r:RELATED_TO]-(d2) "
        "SET r.same_correspondent = true "
        "RETURN COUNT(r) AS created"
    )
    record = result.single()
    if record and record["created"]:
        log.info(
            "Created/updated %d RELATED_TO edges (same correspondent, near dates)",
            record["created"],
        )


def full_sync():
    """Run a complete sync from Paperless to Neo4j."""
    log.info("Starting sync: %s -> %s", PAPERLESS_URL, NEO4J_URI)

    paperless = PaperlessClient(PAPERLESS_URL, PAPERLESS_TOKEN)
    driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

    try:
        with driver.session() as session:
            create_constraints(session)

            correspondents = paperless.correspondents()
            tags = paperless.tags()
            doc_types = paperless.document_types()
            documents = paperless.documents()

            sync_correspondents(session, correspondents)
            sync_tags(session, tags)
            sync_document_types(session, doc_types)
            sync_documents(session, documents)
            create_related_edges(session)

        log.info("Sync complete")
    finally:
        driver.close()


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--watch":
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 300
        log.info("Watch mode: syncing every %d seconds", interval)
        while True:
            try:
                full_sync()
            except Exception as e:
                log.error("Sync failed: %s", e)
            time.sleep(interval)
    else:
        full_sync()


if __name__ == "__main__":
    main()
