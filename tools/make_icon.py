#!/usr/bin/env python3
"""Draw the fiat ratio launcher icon: the house silhouette in the accent
indigo, the ratio colon on top in cream. Writes icons/harbour-fiatratio.svg
and the four PNG sizes Sailfish wants.

    pip install cairosvg
    python3 tools/make_icon.py

The silhouette is the family's: a square whose top-left and bottom-right
corners are replaced by the inscribed circle, drawn as circle, top-right
quadrant and bottom-left quadrant together."""
import os

ACCENT = "#5046A4"
GLYPH = "#F2E9D8"
SILHOUETTE = ('<circle cx="128" cy="128" r="128"/>'
              '<rect x="128" y="0" width="128" height="128"/>'
              '<rect x="0" y="128" width="128" height="128"/>')

# The ratio colon: two cream dots, one over the other. A ratio is a relation
# between two things, and the colon is how it is written.
GLYPH_SVG = f'''
<circle cx="128" cy="92" r="24" fill="{GLYPH}"/>
<circle cx="128" cy="164" r="24" fill="{GLYPH}"/>'''


def svg():
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">'
            f'<g fill="{ACCENT}">{SILHOUETTE}</g>{GLYPH_SVG}</svg>\n')


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icons")
    with open(os.path.join(root, "harbour-fiatratio.svg"), "w") as f:
        f.write(svg())
    import cairosvg
    for size in (86, 108, 128, 172):
        d = os.path.join(root, f"{size}x{size}")
        os.makedirs(d, exist_ok=True)
        cairosvg.svg2png(bytestring=svg().encode(), write_to=os.path.join(d, "harbour-fiatratio.png"),
                         output_width=size, output_height=size)
    print("icons written")


if __name__ == "__main__":
    main()
