#!/usr/bin/env bash
# End-to-end test on the Linux desktop build under a virtual display.
# Leaves test-artifacts/e2e/{result.json,inventory.csv,inventory.pdf,inventory.txt,images.txt,checksums.txt,run.log}.
set -euo pipefail
cd "$(dirname "$0")/.."
export TZ=America/New_York
ART="$PWD/test-artifacts/e2e"
rm -rf "$ART" && mkdir -p "$ART"
xvfb-run -a flutter test integration_test/app_e2e_test.dart -d linux \
  --dart-define=ARTIFACT_DIR="$ART" 2>&1 | tee "$ART/run.log"
pdftotext -layout "$ART/inventory.pdf" "$ART/inventory.txt"
grep -q '10,648.00' "$ART/inventory.txt" || { echo "PDF is missing the total value"; exit 1; }
grep -q '2024-02-29 (expired)' "$ART/inventory.txt" || { echo "PDF is missing the dishwasher warranty"; exit 1; }
pdfimages -list "$ART/inventory.pdf" > "$ART/images.txt"
IMAGES=$(awk 'NR>2 && $3=="image"' "$ART/images.txt" | wc -l)
[ "$IMAGES" -eq 4 ] || { echo "PDF has $IMAGES pictures, expected 4"; exit 1; }
(cd "$ART" && sha256sum inventory.csv > checksums.txt)
# The build as it ships today (Pro free until billing is live, privacy link).
mkdir -p "$ART/free_build"
xvfb-run -a flutter test integration_test/free_build_e2e_test.dart -d linux \
  --dart-define=ARTIFACT_DIR="$ART/free_build" 2>&1 | tee "$ART/free_build/run.log"
python3 -c "import json,sys;d=json.load(open('$ART/free_build/result.json'));print('free build checks passed:',sum(c['pass'] for c in d['checks']),'/',len(d['checks']));sys.exit(0 if d['passed'] else 1)"
python3 -c "import json,sys;d=json.load(open('$ART/result.json'));print('checks passed:',sum(c['pass'] for c in d['checks']),'/',len(d['checks']));sys.exit(0 if d['passed'] else 1)"
echo "PDF pictures: $IMAGES"
