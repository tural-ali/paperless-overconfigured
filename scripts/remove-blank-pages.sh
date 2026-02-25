#!/bin/bash
# Pre-consume script to remove blank pages from scanned PDFs

INPUT_FILE="$DOCUMENT_WORKING_PATH"

# Only process PDFs
case "${INPUT_FILE,,}" in
    *.pdf) ;;
    *) exit 0 ;;
esac

# Check required tools
command -v qpdf > /dev/null || exit 0
command -v pdftoppm > /dev/null || exit 0
command -v convert > /dev/null || exit 0

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Split PDF into individual pages
mkdir -p "$TEMP_DIR/pages"
qpdf --split-pages "$INPUT_FILE" "$TEMP_DIR/pages/page-%d.pdf" 2>/dev/null
RC=$?
# qpdf returns 0 for success, 3 for warnings but success
if [ $RC -ne 0 ] && [ $RC -ne 3 ]; then
    exit 0
fi

# Analyze each page
PAGES_TO_KEEP=""
for page in "$TEMP_DIR/pages"/page-*.pdf; do
    [ -f "$page" ] || continue
    
    # Convert to grayscale image
    pdftoppm -gray -r 72 -singlefile "$page" "$TEMP_DIR/img" 2>/dev/null
    IMG="$TEMP_DIR/img.pgm"
    
    if [ -f "$IMG" ]; then
        # Calculate percentage of non-white pixels after thresholding
        STATS=$(convert "$IMG" -threshold 95% -format "%[fx:mean]" info: 2>/dev/null)
        
        if [ -n "$STATS" ]; then
            # Mean < 0.995 means more than 0.5% of pixels are dark (has content)
            HAS_CONTENT=$(awk "BEGIN {print ($STATS < 0.995) ? 1 : 0}")
            if [ "$HAS_CONTENT" = "1" ]; then
                PAGES_TO_KEEP="$PAGES_TO_KEEP $page"
            fi
        else
            PAGES_TO_KEEP="$PAGES_TO_KEEP $page"
        fi
        rm -f "$IMG"
    else
        PAGES_TO_KEEP="$PAGES_TO_KEEP $page"
    fi
done

# Rebuild if we removed pages
ORIGINAL_COUNT=$(find "$TEMP_DIR/pages" -name "page-*.pdf" 2>/dev/null | wc -l)
# shellcheck disable=SC2086
KEEP_COUNT=$(echo $PAGES_TO_KEEP | wc -w)

if [ "$KEEP_COUNT" -lt "$ORIGINAL_COUNT" ] && [ "$KEEP_COUNT" -gt 0 ]; then
    # shellcheck disable=SC2086
    qpdf --empty --pages $PAGES_TO_KEEP -- "$INPUT_FILE" 2>/dev/null
fi

exit 0
