#!/usr/bin/env bash
set -euo pipefail
mkdir -p assets/fonts
cd assets/fonts

# Download selected font files (Montserrat, Inter, JetBrainsMono) from Google Fonts GitHub or another CDN.
# Note: These URLs are examples; if upstream changes, replace with stable sources.

declare -A fonts=(
  # Montserrat provides a variable font (wght) covering many weights
  [Montserrat-wght]=https://raw.githubusercontent.com/google/fonts/main/ofl/montserrat/Montserrat%5Bwght%5D.ttf
  # Inter variable font (opsz,wght) from Google Fonts (URL-encoded)
  [Inter-opsz-wght]=https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf
  # JetBrains Mono regular
  [JetBrainsMono-Regular]=https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf/JetBrainsMono-Regular.ttf
)

for name in "${!fonts[@]}"; do
  url="${fonts[$name]}"
  file="${name}.ttf"
  if [ ! -f "$file" ]; then
    echo "Downloading $file from $url"
    curl -fsSL -o "$file" "$url"
  else
    echo "$file already exists, skipping"
  fi
done

echo "Downloading Montserrat per-weight and Inter medium fonts (exact filenames)..."

# Montserrat weights (from Google Fonts repository)
curl -L -o Montserrat-Regular.ttf https://github.com/google/fonts/raw/main/ofl/montserrat/Montserrat-Regular.ttf || true
curl -L -o Montserrat-Light.ttf https://github.com/google/fonts/raw/main/ofl/montserrat/Montserrat-Light.ttf || true
curl -L -o Montserrat-Medium.ttf https://github.com/google/fonts/raw/main/ofl/montserrat/Montserrat-Medium.ttf || true
curl -L -o Montserrat-SemiBold.ttf https://github.com/google/fonts/raw/main/ofl/montserrat/Montserrat-SemiBold.ttf || true

# Inter medium weight
curl -L -o Inter-Medium.ttf https://github.com/google/fonts/raw/main/ofl/inter/Inter-Medium.ttf || true

# JetBrainsMono regular (fallback if missing)
curl -L -o JetBrainsMono-Regular.ttf https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono-Regular.ttf || true

echo "Downloaded fonts to $(pwd)"

echo "Creating additional filenames expected by google_fonts..."
cp -n Montserrat-Regular.ttf Montserrat-Regular.ttf || true
cp -n Montserrat-Light.ttf Montserrat-Light.ttf || true
cp -n Montserrat-Medium.ttf Montserrat-Medium.ttf || true
cp -n Montserrat-SemiBold.ttf Montserrat-SemiBold.ttf || true
cp -n Inter-Medium.ttf Inter-Medium.ttf || true

echo "Duplication complete"
