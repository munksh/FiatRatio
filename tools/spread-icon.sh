#!/usr/bin/env bash
# Puts fiat ratio's icon into the family folder of every other Fiat app, so the
# "The fiat family" list on their About pages can show it. Safe to run again.
# Apps are looked for as ~/Projects/Fiat*; set PROJECTS=/path to look elsewhere.
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PROJECTS="${PROJECTS:-$HOME/Projects}"
ICON="$HERE/icons/172x172/harbour-fiatratio.png"
[ -f "$ICON" ] || { echo "missing $ICON"; exit 1; }
for app in "$PROJECTS"/Fiat*/; do
    app="${app%/}"
    [ "$app" = "$HERE" ] && continue
    [ -d "$app/qml" ] || continue
    mkdir -p "$app/qml/pages/images/family"
    cp "$ICON" "$app/qml/pages/images/family/harbour-fiatratio.png"
    if grep -rqs "harbour-fiatratio.png" "$app/qml" --include=*.qml; then
        echo "$(basename "$app"): icon copied, About page already lists fiat ratio"
    else
        echo "$(basename "$app"): icon copied, ADD the fiat ratio line to its About page:"
        grep -rln "images/family/harbour-fiat" "$app/qml" --include=*.qml | sed 's/^/    in /'
    fi
done
echo
echo 'The line to add (same shape as the others):'
echo '{ name: "fiat ratio", what: qsTr("let there be reckoning — money, kept"), icon: "images/family/harbour-fiatratio.png", url: "" }'
