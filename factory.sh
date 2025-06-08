#!/bin/bash

# Audio extraction and conversion script
# Usage: ./extract.sh <steps> <input_folder> <output_folder>
# Steps: extract,convert (comma-delimited)

set -e  # Exit on any error

# Check if required arguments are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <steps> <input_folder> <output_folder>"
    echo "Steps: extract,convert (comma-delimited)"
    echo "Example: $0 'extract,convert' '~/Music/Ableton/Factory Packs' '/Volumes/ALL/Factory Packs'"
    exit 1
fi

STEPS="$1"
INPUT_DIR="$2"
OUTPUT_DIR="$3"

# Create output directories
EXTRACTED_DIR="${OUTPUT_DIR}/_extracted"
DECODED_DIR="${OUTPUT_DIR}/_converted"

mkdir -p "$EXTRACTED_DIR" "$DECODED_DIR"
FAILED_DIR="${OUTPUT_DIR}/_failed"
mkdir -p "$FAILED_DIR"

IFS=',' read -r -a steps <<< "$STEPS"

for step in "${steps[@]}"; do
    case "$step" in
        extract)
            echo "Starting extraction step..."
            ;;
        convert)
            echo "Starting conversion step..."
            ;;
        *)
            echo "Unknown step: $step"
            exit 1
            ;;
    esac
done


# Function to get relative path
get_relative_path() {
    local full_path="$1"
    local base_path="$2"
    #    echo "${full_path#$base_path/}"

    rel_path="${full_path#$base_path}"
    rel_path="${rel_path#/}"  # normalize
    echo "$rel_path"
}


# Function to copy file preserving directory structure
copy_with_structure() {
    local src_file="$1"
    local src_base="$2"
    local dest_base="$3"

    local rel_path=$(get_relative_path "$src_file" "$src_base")
    local dest_file="$dest_base/$rel_path"
    local dest_dir=$(dirname "$dest_file")

    mkdir -p "$dest_dir"
    cp "$src_file" "$dest_file"
    echo "$dest_file"
}

# Function to copy failed files to _failed directory
copy_failed() {
    local src_file="$1"
    local src_base="$2"
    local error_msg="$3"

    echo "ERROR: $error_msg - $src_file"
    copy_with_structure "$src_file" "$src_base" "$FAILED_DIR"
}

# Function to check if file is audio format
is_audio_format() {
    local file="$1"
    local ext=$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        wav|aif|aiff|mp3|ogg|flac|aac|m4a|wma)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check if file is audio format
is_lossless_audio_format() {
    local file="$1"
    local ext=$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        wav|aif|aiff|flac)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check if AIFF file has supported compression type for abledecoder
has_supported_compression() {
    local file="$1"

    # Use file command to check if it's AIFF-C compressed
    local file_info=$(file "$file" 2>/dev/null)

    # If it's AIFF-C compressed (not standard AIFF), it likely has unsupported compression
    if echo "$file_info" | grep -q "AIFF-C compressed"; then
        # Further check with hexdump to see compression type
        # Look for compression type in COMM chunk (around offset 0x2C-0x30)
        local compression_check=$(hexdump -C "$file" | head -5 | grep -E "fl32|NONE|able")

        if echo "$compression_check" | grep -q "fl32"; then
            echo "Unsupported compression type (fl32 - 32-bit floating point)"
            return 1
        elif echo "$compression_check" | grep -q "NONE"; then
            return 0  # Standard uncompressed AIFF
        elif echo "$compression_check" | grep -q "able"; then
            return 0  # Ableton encrypted format
        else
            echo "Unknown or unsupported compression type"
            return 1
        fi
    else
        # Standard AIFF file, should be supported
        return 0
    fi
}

# Step functions
step_extract() {
    echo "=== EXTRACT STEP ==="
    echo "Extracting audio files from input directory..."

    # Find all audio files in the input directory (including inside .app packages)
    find "$INPUT_DIR" -type f \( \
        -iname "*.wav" -o \
        -iname "*.aif" -o \
        -iname "*.aiff" -o \
        -iname "*.mp3" -o \
        -iname "*.ogg" -o \
        -iname "*.flac" -o \
        -iname "*.aac" -o \
        -iname "*.m4a" -o \
        -iname "*.wma" \
    \) | while read -r audio_file; do
        echo "Extracting: $audio_file"
        copy_with_structure "$audio_file" "$INPUT_DIR" "$EXTRACTED_DIR" || {
            copy_failed "$audio_file" "$INPUT_DIR" "Failed to extract"
        }
    done

    echo "Extract step completed."
}

# Function to check if file is .aif format (for abledecoder)
is_aif_format() {
    local file="$1"
    local ext=$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        aif|aiff)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

step_convert() {
    echo "=== CONVERT STEP ==="
    echo "Converting .aif files using abledecoder..."

    # Check if abledecoder is available
    if ! command -v ./abledecoder >/dev/null 2>&1; then
        echo "ERROR: abledecoder not found in PATH. Please install or add to PATH."
        return 1
    fi

    # Process only .aif files from _extracted directory
    find "$EXTRACTED_DIR" -type f | while read -r audio_file; do
        if is_aif_format "$audio_file"; then
            echo "Processing .aif file: $audio_file"

            # Check if the file has supported compression type
            if has_supported_compression "$audio_file"; then
                echo "Converting .aif file: $audio_file"

                rel_path=$(get_relative_path "$audio_file" "$EXTRACTED_DIR")
                converted_file="$DECODED_DIR/$rel_path"
                converted_dir=$(dirname "$converted_file")

                mkdir -p "$converted_dir"

                # Use abledecoder for conversion
                ./abledecoder "$audio_file" "$converted_file" || {
                    copy_failed "$audio_file" "$EXTRACTED_DIR" "abledecoder conversion failed"
                }
            else
                echo "Copying .aif file with compression: $audio_file"
                copy_with_structure "$src_file" "$src_base" "$DECODED_DIR"
            fi
        else
            # Copy non-.aif files directly to avoid conversion attempts
            if is_audio_format "$audio_file"; then
                echo "Skipping non-.aif audio file (copying as-is): $audio_file"
                copy_with_structure "$audio_file" "$EXTRACTED_DIR" "$DECODED_DIR"
            fi
        fi
    done

    echo "Convert step completed."
}

# Execute requested steps
echo "Starting audio processing pipeline..."
echo "Input: $INPUT_DIR"
echo "Output: $OUTPUT_DIR"
echo "Steps to execute: $STEPS"
echo ""

for step in "${steps[@]}"; do
    step_name=$(echo "$step" | tr -d ' ')
    case "$step_name" in
        extract)
            step_extract
            ;;
        convert)
            step_convert
            ;;
        *)
            echo "ERROR: Unknown step: $step_name"
            echo "Valid steps: extract, convert"
            exit 1
            ;;
    esac
    echo ""
done

echo "Process completed successfully!"
