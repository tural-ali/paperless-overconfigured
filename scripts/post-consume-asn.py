#!/usr/bin/env python3
"""
Post-consume ASN fallback scanner for Paperless-ngx.
When the built-in ZXING barcode scanner misses tiny QR codes on Avery labels,
this script tries a corner-crop + 4x upscale strategy as a fallback.

Also falls back to OCR text extraction if the QR code still can't be read.

Set PAPERLESS_POST_CONSUME_SCRIPT to this file's path in docker-compose.yml.
"""
import os
import sys
import re
import logging

logging.basicConfig(level=logging.INFO, format="[ASN-fallback] %(message)s")
log = logging.getLogger(__name__)

DOCUMENT_ID = os.environ.get("DOCUMENT_ID", "")
DOCUMENT_SOURCE_PATH = os.environ.get("DOCUMENT_SOURCE_PATH", "")

if not DOCUMENT_ID or not DOCUMENT_SOURCE_PATH:
    sys.exit(0)

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "paperless.settings")
sys.path.insert(0, "/usr/src/paperless/src")

import django
django.setup()

from documents.models import Document

try:
    doc = Document.objects.get(id=int(DOCUMENT_ID))
except Document.DoesNotExist:
    sys.exit(0)

# Skip if ASN already assigned
if doc.archive_serial_number is not None:
    sys.exit(0)

log.info("Doc #%s has no ASN, trying fallback detection...", DOCUMENT_ID)

asn_value = None

# Strategy 1: Corner-crop + upscale QR code detection
try:
    import zxingcpp
    from pdf2image import convert_from_path
    from PIL import Image

    source = DOCUMENT_SOURCE_PATH
    if not os.path.exists(source):
        source = str(doc.source_path)

    if os.path.exists(source):
        images = convert_from_path(source, first_page=1, last_page=1, dpi=300)
        img = images[0]
        w, h = img.size

        regions = [
            img.crop((int(w * 0.65), 0, w, int(h * 0.25))),         # top-right
            img.crop((0, 0, int(w * 0.35), int(h * 0.25))),          # top-left
            img.crop((0, 0, w, int(h * 0.15))),                       # top-strip
            img.crop((int(w * 0.65), int(h * 0.75), w, h)),           # bot-right
            img.crop((0, int(h * 0.75), int(w * 0.35), h)),           # bot-left
        ]

        for region in regions:
            big = region.resize((region.width * 4, region.height * 4), Image.LANCZOS)
            results = zxingcpp.read_barcodes(big)
            for r in results:
                if "ASN" in r.text.upper():
                    m = re.search(r"(\d+)", r.text)
                    if m:
                        asn_value = int(m.group(1))
                        log.info("Found ASN %d via QR code in corner crop", asn_value)
                        break
            if asn_value:
                break
        del images, img
except Exception as e:
    log.warning("QR scan failed: %s", e)

# Strategy 2: OCR text fallback
if asn_value is None:
    content = doc.content or ""
    m = re.search(r"[AaPp][Ss][Nn]\s*0*(\d+)", content, re.IGNORECASE)
    if m:
        val = int(m.group(1))
        if 0 < val < 100000:
            asn_value = val
            log.info("Found ASN %d via OCR text", asn_value)

if asn_value is None:
    log.info("No ASN found for doc #%s", DOCUMENT_ID)
    sys.exit(0)

# Check for conflicts
existing = Document.objects.filter(archive_serial_number=asn_value).exclude(id=doc.id)
if existing.exists():
    log.warning(
        "ASN %d already assigned to doc #%d, skipping",
        asn_value,
        existing.first().id,
    )
    sys.exit(0)

# Assign the ASN
doc.archive_serial_number = asn_value
doc.save(update_fields=["archive_serial_number"])
log.info("Assigned ASN %d to document #%s", asn_value, DOCUMENT_ID)
