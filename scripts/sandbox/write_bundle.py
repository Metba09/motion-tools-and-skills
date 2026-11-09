#!/usr/bin/env python3
"""Régénère sandbox/BUNDLE.json (idempotent). TOUS les hachages sont calculés ici sur les fichiers réels.

  python3 scripts/sandbox/write_bundle.py --tarball DIR/motion-tools-bundle-source.tar.gz --source-commit <sha> \
      [--upstream-base <sha>] [--branch offline-bundle]

À lancer APRÈS scripts/sandbox/make_livrable.sh ; committer ensuite le pointeur (jamais avant : hash circulaire).
"""
import argparse
import json
import platform
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verify_bundle as vb  # noqa: E402

ROOT = vb.ROOT


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True, text=True).stdout.strip()


def npm_package_counts(paths):
    counts = {}
    for path in paths:
        if path.endswith("package-lock.json"):
            lock = json.loads((ROOT / path).read_text(encoding="utf-8"))
            counts[path.rsplit("/package-lock.json", 1)[0]] = len([k for k in lock.get("packages", {}) if k])
    return counts


def wheel_counts():
    result = {}
    for tier, folder in (("core", "wheels"), ("audio", "wheels-audio")):
        base = ROOT / "vendor" / folder
        if base.is_dir():
            result[tier] = {tag.name: len(list(tag.glob("*.whl"))) for tag in sorted(base.iterdir()) if tag.is_dir()}
    return result


def node_tiers():
    text = (ROOT / "scripts" / "projects.sh").read_text(encoding="utf-8")
    tiers = {}
    for name, body in re.findall(r"^NODE_(CORE|EXTRAS|BROWSER)=\(\n(.*?)^\)", text, re.S | re.M):
        tiers[name.lower()] = [line.split("#")[0].strip() for line in body.splitlines() if line.split("#")[0].strip()]
    return tiers


def not_vendored():
    text = (ROOT / "requirements" / "NOT-VENDORED.txt").read_text(encoding="utf-8")
    return re.findall(r"^#\s+(\w+)\s+:", text, re.M)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tarball", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--upstream-base", default=None, help="SHA amont (défaut : tête locale de main)")
    parser.add_argument("--branch", default="offline-bundle")
    parser.add_argument("--nom", default="motion-tools-bundle")
    args = parser.parse_args()

    tarball = Path(args.tarball)
    hashes = {path: vb.sha256_file(ROOT / path) for path in vb.lockfile_paths(ROOT)}
    manifest = json.loads((ROOT / "vendor" / "MANIFEST.json").read_text(encoding="utf-8"))
    sizes = manifest.get("dirs_bytes", {})
    tags = sorted(p.name for p in (ROOT / "vendor" / "wheels").iterdir() if p.is_dir())

    bundle = {
        "schema": 1,
        "note": ("Le dépôt (cette branche) est la source de vérité ; le livrable claude-memory n'est qu'un miroir de la source. "
                 "Ce fichier est committé APRÈS le tarball (un fichier ne peut pas contenir le hash d'une archive qui le contient) : "
                 "le tarball est `git archive` de source_commit, antérieur à ce pointeur."),
        "upstream_base": args.upstream_base or git("rev-parse", "main"),
        "branch": args.branch,
        "repo": "Metba09/motion-tools-and-skills",
        "python": {"wheel_tags": tags, "tested_with": platform.python_version(), "version_file": None},
        "wheelhouse": {
            "source": "PyPI (wheels) et registre npm (cache _cacache)",
            "verified_by": "sha256 : vendor/SHA256SUMS (scripts/doctor.sh --verify) ; intégrité npm : champs integrity des package-lock.json",
            "stored_in_git": True,
            "stored_in_git_note": ("Écart volontaire au modèle « wheels hors de Git » : demandé par le propriétaire (tout le package vendorisé "
                                   "dans le dépôt). Octets exacts garantis par .gitattributes (vendor/** -text). "
                                   "Licences à connaître : pedalboard (GPL), soxr (LGPL-2.1+) ; extras Remotion : licence Company requise "
                                   "pour un usage organisationnel (voir skills/video-shotcraft). Aucune wheel NVIDIA ni propriétaire repérée "
                                   "dans les METADATA des wheels."),
            "approx_size_bytes": sum(sizes.values()),
            "dirs_bytes": sizes,
            "install_command": "make setup (hors-ligne, depuis vendor/)",
            "refresh_command": "make vendor (réseau npm/PyPI, mainteneur) : rend ce pointeur périmé, make lint échoue jusqu'à mise à jour",
        },
        "counts": {
            "python_wheels_vendored": wheel_counts(),
            "npm_projects_by_tier": node_tiers(),
            "npm_packages_per_lockfile": npm_package_counts(hashes),
            "optional_not_vendored": not_vendored(),
            "optional_not_vendored_note": "niveaux Python voice, vision, analysis : NON vendorisés (voir requirements/NOT-VENDORED.txt)",
        },
        "lockfiles_sha256": hashes,
        "lockfile_set_sha256": vb.set_fingerprint(hashes),
        "bundle": {
            "repo": "Metba09/claude-memory (privé)",
            "path": f"livrables/{args.nom}/",
            "tarball": tarball.name,
            "tarball_sha256": vb.sha256_file(tarball),
            "archive_prefix": "motion-tools-and-skills/",
            "source_commit": git("rev-parse", "--verify", args.source_commit + "^{commit}"),
        },
    }
    target = ROOT / "sandbox" / "BUNDLE.json"
    target.parent.mkdir(exist_ok=True)
    target.write_text(json.dumps(bundle, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    vb.say(f"écrit {target.relative_to(ROOT)} : {len(hashes)} lockfiles, tarball {bundle['bundle']['tarball_sha256'][:16]}…, source {bundle['bundle']['source_commit'][:12]}")


if __name__ == "__main__":
    main()
