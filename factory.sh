#!/bin/bash

# Audio extraction and conversion script
# Usage: ./extract.sh <steps> <input_folder> <output_folder>
# Steps: extract,convert,compress,merge (comma-delimited)

set -e  # Exit on any error

# Check if required arguments are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <steps> <input_folder> <output_folder>"
    echo "Steps: extract,convert,compress,merge (comma-delimited)"
    echo "Example: $0 'extract,convert,compress,merge' '~/Music/Ableton/Factory Packs' '/Volumes/ALL/Factory Packs'"
    exit 1
fi

STEPS="$1"
INPUT_DIR="$2"
OUTPUT_DIR="$3"

# Create output directories
EXTRACTED_DIR="${OUTPUT_DIR}/_extracted"
DECODED_DIR="${OUTPUT_DIR}/_converted"
COMPRESSED_DIR="${OUTPUT_DIR}/_compressed"

mkdir -p "$EXTRACTED_DIR" "$DECODED_DIR" "$COMPRESSED_DIR"
FAILED_DIR="${OUTPUT_DIR}/_failed"
MERGED_DIR="${OUTPUT_DIR}/_merged"
mkdir -p "$FAILED_DIR" "$MERGED_DIR"

IFS=',' read -r -a steps <<< "$STEPS"

for step in "${steps[@]}"; do
    case "$step" in
        extract)
            echo "Starting extraction step..."
            ;;
        convert)
            echo "Starting conversion step..."
            ;;
        compress)
            echo "Starting compression step..."
            ;;
        merge)
            echo "Starting merge step..."
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
    echo "${full_path#$base_path/}"
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
                echo "Skipping .aif file with unsupported compression: $audio_file"
                copy_failed "$audio_file" "$EXTRACTED_DIR" "Unsupported compression type"
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

step_compress() {
    echo "=== COMPRESS STEP ==="
    echo "Converting to compressed formats (FLAC)..."

    # Check if ffmpeg is available
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "ERROR: ffmpeg not found. Cannot perform compression."
        return 1
    fi

    # Process converted files
    find "$DECODED_DIR" -type f | while read -r audio_file; do
        if is_audio_format "$audio_file"; then
            echo "Compressing to FLAC: $audio_file"

            rel_path=$(get_relative_path "$audio_file" "$DECODED_DIR")
            flac_file="$COMPRESSED_DIR/${rel_path%.*}.flac"
            flac_dir=$(dirname "$flac_file")

            mkdir -p "$flac_dir"

            ffmpeg -i "$audio_file" -c:a flac "$flac_file" -y 2>/dev/null || {
                copy_failed "$audio_file" "$DECODED_DIR" "FLAC compression failed"
            }
        fi
    done

    echo "Compress step completed."
}

step_merge() {
    echo "=== MERGE STEP ==="
    echo "Merging all processed files and cleaning up..."

    # Copy files from all processing directories to merged directory
    for source_dir in "$EXTRACTED_DIR" "$DECODED_DIR" "$COMPRESSED_DIR"; do
        if [ -d "$source_dir" ]; then
            echo "Merging files from $(basename "$source_dir")..."
            find "$source_dir" -type f | while read -r file; do
                rel_path=$(get_relative_path "$file" "$source_dir")
                dest_file="$MERGED_DIR/$(basename "$source_dir")/$rel_path"
                dest_dir=$(dirname "$dest_file")

                mkdir -p "$dest_dir"
                cp "$file" "$dest_file" || {
                    echo "Warning: Failed to merge $file"
                }
            done
        fi
    done

    # Clean up empty directories in all processing folders
    echo "Cleaning up empty directories..."
    for cleanup_dir in "$EXTRACTED_DIR" "$DECODED_DIR" "$COMPRESSED_DIR"; do
        if [ -d "$cleanup_dir" ]; then
            find "$cleanup_dir" -type d -empty -delete 2>/dev/null || true
        fi
    done

    echo "Merge step completed."
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
        compress)
            step_compress
            ;;
        merge)
            step_merge
            ;;
        *)
            echo "ERROR: Unknown step: $step_name"
            echo "Valid steps: extract, convert, compress, merge"
            exit 1
            ;;
    esac
    echo ""
done

echo "Process completed successfully!"
