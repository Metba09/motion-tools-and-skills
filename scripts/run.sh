#!/usr/bin/env bash
# Point d'entrée unique des usages courants du bundle (tout hors-ligne). Voir : scripts/run.sh help
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
cmd=${1:-help}; shift || true
usage() { cat <<'U'
usage : bash scripts/run.sh <commande> [arguments]

  setup [niveau]                  installe depuis vendor/ (défaut : noyau + navigateur embarqué s'il est présent)
                                  niveaux : core | browser | extras | audio | all   (ceux non inclus : refus clair)
  check [--full]                  intégrité + runtimes + fumée (rapide) ; --full : + lint, format, tests
  doctor                          diagnostic de l'environnement
  new <kinetic-reel|painted-animation> <dossier>
                                  crée un projet de rendu (installation hors-ligne)
  sheet <dossier> [options]       planche-contact du projet (WebGL logiciel activé)
  transcribe <video> <sortie.json> --script "texte"   transcription hors-ligne (mots répartis sur l'audio)
  smoke [étapes]                  bout en bout (python fal transcribe lemo gates build kinetic painted)
  env                             affiche les exports d'environnement :  eval "$(bash scripts/run.sh env)"
  help                            cet écran
U
}
case "$cmd" in
  setup)
    if [ $# -gt 0 ]; then bash "$ROOT/setup.sh" "$@"
    else bash "$ROOT/setup.sh" core; [ -d "$VENDOR/npm-cache-browser" ] && bash "$ROOT/setup.sh" browser; fi ;;
  check)   exec bash "$ROOT/scripts/check.sh" "$@" ;;
  doctor)  exec bash "$ROOT/scripts/doctor.sh" "$@" ;;
  smoke)   exec bash "$ROOT/scripts/smoke.sh" "$@" ;;
  env)     printf '. %q\n' "$ROOT/scripts/env.sh" ;;
  new)
    [ $# -eq 2 ] || { usage >&2; exit 2; }
    case "$1" in kinetic-reel|painted-animation) ;; *) die "projet inconnu : $1 (kinetic-reel | painted-animation)" ;; esac
    . "$ROOT/scripts/env.sh"; exec bash "$ROOT/skills/$1/scripts/new_project.sh" "$2" ;;
  sheet)
    [ $# -ge 1 ] || { usage >&2; exit 2; }
    d=$1; shift; [ -f "$d/package.json" ] || die "pas un projet de rendu : $d"
    . "$ROOT/scripts/env.sh"; cd "$d"; exec npm run --silent sheet -- --soft-gl "$@" ;;
  transcribe)
    [ $# -ge 2 ] || { usage >&2; exit 2; }
    . "$ROOT/scripts/env.sh"; exec node "$ROOT/skills/talking-head-b-roll/scripts/transcribe.mjs" "$@" ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
