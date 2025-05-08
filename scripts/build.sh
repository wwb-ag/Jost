#!/bin/bash
# Modern build script for Jost font - compatible with current tool versions

# Exit on error, but allow specific commands to fail with the || operator
set -e

# Ensure we're running from the correct directory
cd "$(dirname "$0")/.."
ROOT_DIR="$(pwd)"

echo "=== Jost Font Build Script ==="
echo "Building in: $ROOT_DIR"

# Ensure output directories exist
mkdir -p "$ROOT_DIR/fonts/ttf" "$ROOT_DIR/fonts/otf"

echo "1. Generating Variable Font"
fontmake -o variable -m "$ROOT_DIR/sources/designspace/jost.designspace" --output-path "$ROOT_DIR/fonts/Jost-VF.ttf"

echo "2. Cleaning up variable font"
# Note: skipping deprecated gftools fix-dsig commands
# Apply fix-nonhinting if it exists in this version
if command -v gftools fix-nonhinting &>/dev/null; then
  echo "  - Applying fix-nonhinting to variable font"
  gftools fix-nonhinting "$ROOT_DIR/fonts/Jost-VF.ttf" "$ROOT_DIR/fonts/Jost-VF.ttf.fix" || echo "Warning: fix-nonhinting failed, continuing"
  if [ -f "$ROOT_DIR/fonts/Jost-VF.ttf.fix" ]; then
    mv "$ROOT_DIR/fonts/Jost-VF.ttf.fix" "$ROOT_DIR/fonts/Jost-VF.ttf"
  fi
fi

# Clean up any backup files
find "$ROOT_DIR/fonts" -name "*backup*" -delete

echo "3. Generating source UFO files"
WEIGHTS=("100" "200" "300" "400" "500" "600" "700" "800" "900")
for weight in "${WEIGHTS[@]}"; do
  echo "  - Generating $weight"
  fontmake -o ufo -i "$weight" -m "$ROOT_DIR/sources/designspace/jost.designspace"
  fontmake -o ufo -i "${weight}i" -m "$ROOT_DIR/sources/designspace/jost.designspace"
done

echo "4. Generating TrueType Fonts"
# Create a temporary directory for intermediate TTF files
mkdir -p "$ROOT_DIR/fonts/ttf2"

# Build all instances
INSTANCES_ARGS=""
for ufo in "$ROOT_DIR"/sources/instances/*.ufo; do
  INSTANCES_ARGS="$INSTANCES_ARGS $ufo"
done

fontmake -o ttf --output-dir "$ROOT_DIR/fonts/ttf2/" -u $INSTANCES_ARGS

echo "5. Skipping deprecated fix-dsig step"

# Apply ttfautohint to each font
echo "6. Applying hinting"
WEIGHT_NAMES=(
  "100:Hairline" "200:Thin" "300:Light" "400:Book" 
  "500:Medium" "600:Semi" "700:Bold" "800:Heavy" "900:Black"
)

for pair in "${WEIGHT_NAMES[@]}"; do
  weight="${pair%%:*}"
  name="${pair##*:}"
  
  echo "  - Hinting $name"
  ttfautohint -n "$ROOT_DIR/fonts/ttf2/$weight.ttf" "$ROOT_DIR/fonts/ttf/Jost-$weight-$name.ttf"
  ttfautohint -n "$ROOT_DIR/fonts/ttf2/${weight}i.ttf" "$ROOT_DIR/fonts/ttf/Jost-$weight-${name}Italic.ttf"
  
  # Apply fix-hinting if available in this version
  if command -v gftools fix-hinting &>/dev/null; then
    gftools fix-hinting "$ROOT_DIR/fonts/ttf/Jost-$weight-$name.ttf" || echo "Warning: fix-hinting failed, continuing"
    gftools fix-hinting "$ROOT_DIR/fonts/ttf/Jost-$weight-${name}Italic.ttf" || echo "Warning: fix-hinting failed, continuing"
  fi
done

echo "7. Finalizing TTF fonts"
# Create a safety mechanism to avoid removing files if fix didn't work
if ls "$ROOT_DIR/fonts/ttf/"*.ttf.fix 1> /dev/null 2>&1; then
  # Remove original ttf files before moving the fixed ones
  rm "$ROOT_DIR/fonts/ttf/"*.ttf
  
  # Move fixed files to their final location
  for pair in "${WEIGHT_NAMES[@]}"; do
    weight="${pair%%:*}"
    name="${pair##*:}"
    
    mv "$ROOT_DIR/fonts/ttf/Jost-$weight-$name.ttf.fix" "$ROOT_DIR/fonts/ttf/Jost-$weight-$name.ttf"
    mv "$ROOT_DIR/fonts/ttf/Jost-$weight-${name}Italic.ttf.fix" "$ROOT_DIR/fonts/ttf/Jost-$weight-${name}Italic.ttf"
  done
else
  echo "  - No .fix files found - either fix-hinting command is not available or files are already processed"
fi

# Clean up temporary directory
rm -f "$ROOT_DIR/fonts/ttf2/"*.ttf
rmdir "$ROOT_DIR/fonts/ttf2"

echo "8. Generating OpenType Fonts"
fontmake -o otf --output-dir "$ROOT_DIR/fonts/otf/" -u $INSTANCES_ARGS

echo "9. Renaming OTF files"
# Rename OTF files to follow naming convention
for pair in "${WEIGHT_NAMES[@]}"; do
  weight="${pair%%:*}"
  name="${pair##*:}"
  
  mv "$ROOT_DIR/fonts/otf/$weight.otf" "$ROOT_DIR/fonts/otf/Jost-$weight-$name.otf"
  mv "$ROOT_DIR/fonts/otf/${weight}i.otf" "$ROOT_DIR/fonts/otf/Jost-$weight-${name}Italic.otf"
done

# Special case fix for Heavy/Hevy inconsistency in the original script
if [ -f "$ROOT_DIR/fonts/otf/Jost-800-Heavy.otf" ]; then
  mv "$ROOT_DIR/fonts/otf/Jost-800-Heavy.otf" "$ROOT_DIR/fonts/otf/Jost-800-Hevy.otf"
  mv "$ROOT_DIR/fonts/otf/Jost-800-HeavyItalic.otf" "$ROOT_DIR/fonts/otf/Jost-800-HevyItalic.otf"
fi

echo "10. Cleaning up"
rm -rf "$ROOT_DIR/sources/instances"

echo "=== Build completed successfully ==="
