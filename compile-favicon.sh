# Requirements
# - inkscape
# - imagemagick

FAVICON_SVG="favicon.svg"
SIZES="16 32 48"
SIZE_PNGS=""

for SIZE in $SIZES; do
    inkscape -w $SIZE -h $SIZE --export-filename="$SIZE.png" $FAVICON_SVG
    SIZE_PNGS="$SIZE_PNGS $SIZE.png"
done

convert $SIZE_PNGS favicon.ico
rm $SIZE_PNGS
mv favicon.ico assets/images/favicon.ico
cp $FAVICON_SVG assets/images/favicon.svg
