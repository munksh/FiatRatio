#!/usr/bin/env bash
# Copies the family's shared parts from Fiat Lux into fiat ratio, with the
# theme name swapped, then checks the whole tree. Run once from anywhere;
# run again whenever Lux's components change.
set -e

HERE="$(cd "$(dirname "$0")/.." && pwd)"
LUX="${LUX:-$HOME/Projects/FiatLux}"
IMAGO="${IMAGO:-$HOME/Projects/FiatImago}"
PARTS="PageHead SectionLabel MunkstolenMark WordChoice LinkText FiatButton"

if [ ! -d "$LUX/qml/components" ]; then
    echo "Fiat Lux not found at $LUX (run with LUX=/path/to/FiatLux)"
    exit 1
fi

mkdir -p "$HERE/qml/components" "$HERE/qml/pages/images/family"

for part in $PARTS; do
    sed 's/FiatLuxTheme/FiatRatioTheme/g' "$LUX/qml/components/$part.qml" \
        > "$HERE/qml/components/$part.qml"
    echo "copied $part.qml"
done

if ls "$LUX"/qml/pages/images/family/*.png > /dev/null 2>&1; then
    cp "$LUX"/qml/pages/images/family/*.png "$HERE/qml/pages/images/family/"
    echo "copied the family icons"
else
    echo "WARNING: no family icons in $LUX/qml/pages/images/family/"
fi
if [ -f "$IMAGO/icons/172x172/harbour-fiatimago.png" ]; then
    cp "$IMAGO/icons/172x172/harbour-fiatimago.png" "$HERE/qml/pages/images/family/"
    echo "copied fiat imago's icon"
fi
cp "$HERE/icons/172x172/harbour-fiatratio.png" "$HERE/qml/pages/images/family/"
cp "$LUX/LICENSE" "$HERE/LICENSE"
echo "copied LICENSE"

cd "$HERE"
echo
echo "--- other theme names left (must be empty):"
grep -rhoE "Fiat[A-Za-z]*Theme" qml/ | grep -v "^FiatRatioTheme$" | sort -u || true

echo "--- theme names used but not defined (must be empty):"
for n in $(grep -rhoE --include=*.qml "FiatRatioTheme\.[A-Za-z_]+" qml/ | sed 's/.*\.//' | sort -u); do
    grep -qE "(property [a-z]+ $n\b|function $n\b)" qml/FiatRatioTheme.qml || echo "$n"
done

echo "--- relative imports in the copied parts (each must exist under qml/components):"
for f in $PARTS; do
    grep -hoE 'import "[^"]+"' "qml/components/$f.qml" | while read -r _ path; do
        path="${path//\"/}"
        [ "$path" = ".." ] && continue
        [ -e "qml/components/$path" ] || echo "$f.qml imports $path, which is missing"
    done
done

echo "--- family icons in place:"
ls qml/pages/images/family/
