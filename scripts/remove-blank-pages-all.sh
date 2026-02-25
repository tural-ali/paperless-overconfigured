#\!/bin/bash
# Batch remove blank pages from all existing PDFs

LOG_FILE="/tmp/blank-page-removal.log"
SCRIPT_PATH="/usr/src/paperless/scripts/remove-blank-pages.sh"
ORIGINALS_DIR="/usr/src/paperless/media/documents/originals"

echo "Starting blank page removal on all documents..." | tee "$LOG_FILE"
echo "Started at: $(date)" | tee -a "$LOG_FILE"

TOTAL=0
MODIFIED=0

find "$ORIGINALS_DIR" -name "*.pdf" -type f | while read -r PDF; do
    TOTAL=$((TOTAL + 1))
    
    BEFORE=$(qpdf --show-npages "$PDF" 2>/dev/null)
    [ -z "$BEFORE" ] && continue
    [ "$BEFORE" -lt 2 ] && continue  # Skip single-page PDFs
    
    export DOCUMENT_WORKING_PATH="$PDF"
    "$SCRIPT_PATH"
    
    AFTER=$(qpdf --show-npages "$PDF" 2>/dev/null)
    
    if [ "$BEFORE" \!= "$AFTER" ]; then
        REMOVED=$((BEFORE - AFTER))
        echo "[$(date +%H:%M:%S)] $PDF: $BEFORE -> $AFTER pages (removed $REMOVED)" | tee -a "$LOG_FILE"
        MODIFIED=$((MODIFIED + 1))
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "Completed at: $(date)" | tee -a "$LOG_FILE"
echo "Documents processed with changes logged above" | tee -a "$LOG_FILE"
