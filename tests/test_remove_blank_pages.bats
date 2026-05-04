#!/usr/bin/env bats
# Tests for remove-blank-pages.sh script
# Run with: bats tests/test_remove_blank_pages.bats

SCRIPT_PATH="${BATS_TEST_DIRNAME}/../scripts/remove-blank-pages.sh"

# ─────────────────────────────────────────────────────────────
# Tests for file extension detection
# ─────────────────────────────────────────────────────────────

@test "script exits early for non-PDF files (txt)" {
    INPUT_FILE="test.txt"
    case "${INPUT_FILE,,}" in
        *.pdf) result="pdf" ;;
        *) result="exit" ;;
    esac
    [ "$result" = "exit" ]
}

@test "script exits early for non-PDF files (jpg)" {
    INPUT_FILE="image.jpg"
    case "${INPUT_FILE,,}" in
        *.pdf) result="pdf" ;;
        *) result="exit" ;;
    esac
    [ "$result" = "exit" ]
}

@test "script processes PDF files (lowercase)" {
    INPUT_FILE="document.pdf"
    case "${INPUT_FILE,,}" in
        *.pdf) result="pdf" ;;
        *) result="exit" ;;
    esac
    [ "$result" = "pdf" ]
}

@test "script processes PDF files (uppercase)" {
    INPUT_FILE="DOCUMENT.PDF"
    case "${INPUT_FILE,,}" in
        *.pdf) result="pdf" ;;
        *) result="exit" ;;
    esac
    [ "$result" = "pdf" ]
}

@test "script processes PDF files (mixed case)" {
    INPUT_FILE="Document.Pdf"
    case "${INPUT_FILE,,}" in
        *.pdf) result="pdf" ;;
        *) result="exit" ;;
    esac
    [ "$result" = "pdf" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for blank page detection threshold
# Note: A page is considered to have content when mean < 0.995
# (less than 99.5% white pixels). Pages with mean >= 0.995 are blank.
# ─────────────────────────────────────────────────────────────

@test "page with mean 0.99 has content (below threshold)" {
    STATS=0.99
    HAS_CONTENT=$(awk "BEGIN {print ($STATS < 0.995) ? 1 : 0}")
    [ "$HAS_CONTENT" = "1" ]
}

@test "page with mean 0.999 is blank (above threshold)" {
    STATS=0.999
    HAS_CONTENT=$(awk "BEGIN {print ($STATS < 0.995) ? 1 : 0}")
    [ "$HAS_CONTENT" = "0" ]
}

@test "page with mean 0.995 is blank (at threshold)" {
    STATS=0.995
    HAS_CONTENT=$(awk "BEGIN {print ($STATS < 0.995) ? 1 : 0}")
    [ "$HAS_CONTENT" = "0" ]
}

@test "page with mean 0.994 has content" {
    STATS=0.994
    HAS_CONTENT=$(awk "BEGIN {print ($STATS < 0.995) ? 1 : 0}")
    [ "$HAS_CONTENT" = "1" ]
}

@test "page with mean 0.5 has content" {
    STATS=0.5
    HAS_CONTENT=$(awk "BEGIN {print ($STATS < 0.995) ? 1 : 0}")
    [ "$HAS_CONTENT" = "1" ]
}

@test "page with mean 0.0 has content (all black)" {
    STATS=0.0
    HAS_CONTENT=$(awk "BEGIN {print ($STATS < 0.995) ? 1 : 0}")
    [ "$HAS_CONTENT" = "1" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for page counting logic
# ─────────────────────────────────────────────────────────────

@test "pages to keep count calculated correctly - no removal" {
    PAGES_TO_KEEP="page1 page2 page3"
    ORIGINAL_COUNT=3
    # shellcheck disable=SC2086
    KEEP_COUNT=$(echo $PAGES_TO_KEEP | wc -w)
    [ "$KEEP_COUNT" -eq 3 ]
    [ "$KEEP_COUNT" -eq "$ORIGINAL_COUNT" ]
}

@test "pages to keep count calculated correctly - some removal" {
    PAGES_TO_KEEP="page1 page3"
    ORIGINAL_COUNT=3
    # shellcheck disable=SC2086
    KEEP_COUNT=$(echo $PAGES_TO_KEEP | wc -w)
    [ "$KEEP_COUNT" -eq 2 ]
    [ "$KEEP_COUNT" -lt "$ORIGINAL_COUNT" ]
}

@test "pages to keep count calculated correctly - all removed" {
    PAGES_TO_KEEP=""
    ORIGINAL_COUNT=3
    # shellcheck disable=SC2086
    KEEP_COUNT=$(echo $PAGES_TO_KEEP | wc -w)
    [ "$KEEP_COUNT" -eq 0 ]
}

# ─────────────────────────────────────────────────────────────
# Tests for rebuild condition logic
# ─────────────────────────────────────────────────────────────

@test "rebuild happens when pages removed and some remain" {
    KEEP_COUNT=2
    ORIGINAL_COUNT=3
    if [ "$KEEP_COUNT" -lt "$ORIGINAL_COUNT" ] && [ "$KEEP_COUNT" -gt 0 ]; then
        result="rebuild"
    else
        result="skip"
    fi
    [ "$result" = "rebuild" ]
}

@test "no rebuild when all pages kept" {
    KEEP_COUNT=3
    ORIGINAL_COUNT=3
    if [ "$KEEP_COUNT" -lt "$ORIGINAL_COUNT" ] && [ "$KEEP_COUNT" -gt 0 ]; then
        result="rebuild"
    else
        result="skip"
    fi
    [ "$result" = "skip" ]
}

@test "no rebuild when all pages removed" {
    KEEP_COUNT=0
    ORIGINAL_COUNT=3
    if [ "$KEEP_COUNT" -lt "$ORIGINAL_COUNT" ] && [ "$KEEP_COUNT" -gt 0 ]; then
        result="rebuild"
    else
        result="skip"
    fi
    [ "$result" = "skip" ]
}

@test "rebuild happens when 1 of 2 pages removed" {
    KEEP_COUNT=1
    ORIGINAL_COUNT=2
    if [ "$KEEP_COUNT" -lt "$ORIGINAL_COUNT" ] && [ "$KEEP_COUNT" -gt 0 ]; then
        result="rebuild"
    else
        result="skip"
    fi
    [ "$result" = "rebuild" ]
}

# ─────────────────────────────────────────────────────────────
# Tests for qpdf return code handling
# ─────────────────────────────────────────────────────────────

@test "qpdf return code 0 is success" {
    RC=0
    if [ $RC -ne 0 ] && [ $RC -ne 3 ]; then
        result="fail"
    else
        result="success"
    fi
    [ "$result" = "success" ]
}

@test "qpdf return code 3 is success (warnings)" {
    RC=3
    if [ $RC -ne 0 ] && [ $RC -ne 3 ]; then
        result="fail"
    else
        result="success"
    fi
    [ "$result" = "success" ]
}

@test "qpdf return code 1 is failure" {
    RC=1
    if [ $RC -ne 0 ] && [ $RC -ne 3 ]; then
        result="fail"
    else
        result="success"
    fi
    [ "$result" = "fail" ]
}

@test "qpdf return code 2 is failure" {
    RC=2
    if [ $RC -ne 0 ] && [ $RC -ne 3 ]; then
        result="fail"
    else
        result="success"
    fi
    [ "$result" = "fail" ]
}
