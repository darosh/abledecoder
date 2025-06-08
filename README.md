# abledecoder

> Converts Ableton factory sounds

Note: works on Mac

## Prerequisites

- CMake 3.10 or higher
- OpenSSL 3.x (with legacy provider support)
- C++11 compatible compiler

### macOS Setup

Install dependencies via Homebrew:

```bash
brew install cmake openssl@3
```

## Build

### Method 1: Using CMake (Recommended)

```bash
# Clean any previous builds
rm -f CMakeCache.txt && rm -rf CMakeFiles/

# Configure with explicit OpenSSL path (macOS with Homebrew)
cmake -DCMAKE_BUILD_TYPE=Release -DOPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl@3 .

# Build
make

# Make scripts executable
chmod +x ./abledecoder
chmod +x ./factory.sh
```

### Method 2: Using Make directly (Legacy)

```bash
make
chmod +x ./abledecoder
chmod +x ./factory.sh
```

**Note:** If you encounter OpenSSL errors like "unsupported algorithm BF-CBC", use Method 1 with the explicit OpenSSL
configuration.

## Usage

### Basic conversion

```bash
./abledecoder <input.aif> <output.aif>
```

### Factory scripts

```bash
./factory.sh extract,convert ~/Music/Ableton/Factory\ Packs /Volumes/ALL/Factory\ Packs
```

## Troubleshooting

### OpenSSL 3.x Compatibility Issues

If you see errors like:

```
error:0308010C:digital envelope routines:inner_evp_generic_fetch:unsupported:crypto/evp/evp_fetch.c:375:Global default library context, Algorithm (BF-CBC : 14), Properties ()
```

This indicates that OpenSSL 3.x has deprecated the Blowfish-CBC algorithm. The code includes compatibility fixes, but
you need to:

1. Use the CMake build method with explicit OpenSSL configuration
2. Ensure you have OpenSSL 3.x installed (not older versions)
3. Make sure the legacy provider is available

### macOS Specific Issues

- If CMake can't find OpenSSL, make sure you have the Homebrew version installed: `brew install openssl@3`
- Use the full path in the cmake command: `-DOPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl@3`
- If you're on Apple Silicon (M1/M2), the Homebrew path should be `/opt/homebrew/opt/openssl@3`
- If you're on Intel Mac, the path might be `/usr/local/opt/openssl@3`
