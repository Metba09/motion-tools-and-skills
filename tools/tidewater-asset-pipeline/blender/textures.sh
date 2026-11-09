#!/bin/zsh
# textures.sh <Textures dir> <out dir> <prefix> [size]
# colour / normal -> JPEG, specular -> ORM (R 1, G roughness = 0.92 - 0.6 * spec, B metal 0), opacity cards -> PNG with alpha
# --- Bundle hors-ligne : ce script télécharge ou installe depuis Internet. Refusé tant que MOTION_OFFLINE != 0.
[ "${MOTION_OFFLINE:-1}" = 0 ] || { echo "✗ $(basename "$0") : accès réseau requis ; le sandbox est hors-ligne (MOTION_OFFLINE=1). Voir CLAUDE.md « Session Chat »." >&2; exit 3; }
src=$1; out=$2; p=$3; S=${4:-1024}
mkdir -p $out
for k in body head; do
  magick $src/${p}_${k}_color.tga -resize ${S}x${S} -quality 90 $out/${p}_${k}_color.jpg
  magick $src/${p}_${k}_normal.tga -resize ${S}x${S} -quality 92 $out/${p}_${k}_normal.jpg
  magick $src/${p}_${k}_specular.tga -resize ${S}x${S} -colorspace gray -fx '0.92-0.6*u' \
    \( +clone -fill white -colorize 100 \) \( +clone -fill black -colorize 100 \) \
    -swap 0,1 -combine -quality 92 $out/${p}_${k}_orm.jpg
done
[ -f $src/${p}_opacity_color.tga ] && magick $src/${p}_opacity_color.tga -resize ${S}x${S} $out/${p}_opacity.png
ls $out
