#!/usr/bin/env python3
"""Vérifie le pointeur de bundle sandbox/BUNDLE.json (stdlib seule, aucun accès réseau).

  python3 scripts/sandbox/verify_bundle.py                    lockfiles du dépôt  vs  BUNDLE.json
  python3 scripts/sandbox/verify_bundle.py --livrable DIR     + tarball miroir : SHA-256 d'abord, ouverture ensuite

Chaque écart s'affiche « ÉCART : … » ; code de sortie 1 s'il y en a au moins un, 0 sinon.
Le tarball n'est JAMAIS extrait : seuls les lockfiles sont lus en mémoire (pas de traversée de chemin possible).
"""
import argparse
import hashlib
import json
import sys
import tarfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BUNDLE = ROOT / "sandbox" / "BUNDLE.json"
SKIP_DIRS = {"node_modules", "vendor", ".lib", ".git", "out", "dist", "dist-bundle", "__pycache__"}
EXTRA_LOCKFILES = ("requirements/core.txt", "requirements/audio.txt", "vendor/SHA256SUMS")
MAX_MEMBER = 64 * 1024 * 1024  # un lockfile ne dépasse jamais ça : borne contre une archive piégée
TAR_ERRORS = (tarfile.TarError, KeyError, OSError, EOFError, zlib.error)


def say(message=""):
    sys.stdout.write(message + "\n")


def warn(message):
    sys.stderr.write(message + "\n")


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def lockfile_paths(root=ROOT):
    """Jeu de lockfiles du bundle : package-lock.json de chaque projet + requirements pinés + vendor/SHA256SUMS."""
    found = []
    stack = [Path(root)]
    while stack:
        folder = stack.pop()
        for entry in folder.iterdir():
            if entry.is_dir():
                if entry.name not in SKIP_DIRS:
                    stack.append(entry)
            elif entry.name == "package-lock.json":
                found.append(entry.relative_to(root).as_posix())
    found += [p for p in EXTRA_LOCKFILES if (Path(root) / p).is_file()]
    return sorted(set(found))


def set_fingerprint(hashes):
    """Empreinte du jeu : SHA-256 des lignes « hex  chemin » triées."""
    lines = "".join(f"{hashes[p]}  {p}\n" for p in sorted(hashes))
    return sha256_bytes(lines.encode("utf-8"))


def compare_hashes(recorded, actual, where, gaps):
    for path in sorted(set(recorded) | set(actual)):
        if path not in actual:
            gaps.append(f"{path} : listé dans BUNDLE.json mais absent ({where})")
        elif path not in recorded:
            gaps.append(f"{path} : présent ({where}) mais absent de BUNDLE.json")
        elif recorded[path] != actual[path]:
            gaps.append(f"{path} : SHA-256 différent ({where}) attendu {recorded[path][:16]}… obtenu {actual[path][:16]}…")


def check_tarball(directory, bundle, recorded, gaps):
    info = bundle.get("bundle", {})
    name, want = info.get("tarball"), info.get("tarball_sha256")
    tar_path = Path(directory) / str(name)
    if not name or not want:
        gaps.append("BUNDLE.json : bundle.tarball / bundle.tarball_sha256 manquant")
        return
    try:
        got = sha256_file(tar_path)
    except OSError as error:
        gaps.append(f"{tar_path} : illisible ({error.strerror or error})")
        return
    if got != want:
        gaps.append(f"{name} : SHA-256 du tarball différent, archive NON ouverte (attendu {want[:16]}… obtenu {got[:16]}…)")
        return
    sums = Path(directory) / "SHA256SUMS"
    if sums.is_file():
        try:
            listed = {line.split()[1].lstrip("*"): line.split()[0] for line in sums.read_text(encoding="utf-8").splitlines() if len(line.split()) == 2}
        except (OSError, UnicodeDecodeError) as error:
            gaps.append(f"{sums} : illisible ({error})")
            listed = {}
        if listed.get(name) != want:
            gaps.append(f"{sums} : la ligne de {name} ne correspond pas à BUNDLE.json")
    prefix = info.get("archive_prefix", "")
    inside = {}
    try:
        with tarfile.open(tar_path, mode="r:gz") as archive:
            for path in recorded:
                try:
                    member = archive.getmember(prefix + path)
                except KeyError:
                    gaps.append(f"{path} : absent du tarball")
                    continue
                if not member.isfile() or member.size > MAX_MEMBER:
                    gaps.append(f"{path} : entrée du tarball invalide (type ou taille)")
                    continue
                handle = archive.extractfile(member)
                inside[path] = sha256_bytes(handle.read(MAX_MEMBER + 1)) if handle else ""
    except TAR_ERRORS as error:
        gaps.append(f"{name} : tarball altéré ou illisible ({type(error).__name__}: {error})")
        return
    compare_hashes({p: recorded[p] for p in inside}, inside, "tarball", gaps)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--bundle", default=str(DEFAULT_BUNDLE), help="chemin de BUNDLE.json")
    parser.add_argument("--livrable", metavar="DIR", help="dossier du livrable miroir (tarball + SHA256SUMS)")
    parser.add_argument("--root", default=str(ROOT), help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    root = Path(args.root)
    gaps = []

    try:
        bundle = json.loads(Path(args.bundle).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        warn(f"ÉCART : {args.bundle} illisible ou JSON invalide ({error})")
        return 1
    if bundle.get("schema") != 1:
        gaps.append(f"BUNDLE.json : schema {bundle.get('schema')!r} (1 attendu)")
    recorded = bundle.get("lockfiles_sha256")
    if not isinstance(recorded, dict) or not recorded:
        warn("ÉCART : BUNDLE.json : lockfiles_sha256 absent ou vide")
        return 1

    actual = {}
    for path in lockfile_paths(root):
        actual[path] = sha256_file(root / path)
    compare_hashes(recorded, actual, "dépôt", gaps)
    if bundle.get("lockfile_set_sha256") != set_fingerprint(recorded):
        gaps.append("BUNDLE.json : lockfile_set_sha256 incohérent avec lockfiles_sha256")

    wanted_tags = (bundle.get("python") or {}).get("wheel_tags")
    wheels = root / "vendor" / "wheels"
    if wheels.is_dir() and wanted_tags is not None:
        have = sorted(p.name for p in wheels.iterdir() if p.is_dir())
        if have != sorted(wanted_tags):
            gaps.append(f"python.wheel_tags : BUNDLE.json {sorted(wanted_tags)} ≠ vendor/wheels {have}")

    if args.livrable:
        check_tarball(args.livrable, bundle, recorded, gaps)

    for gap in gaps:
        warn(f"ÉCART : {gap}")
    if gaps:
        warn(f"✗ verify-bundle : {len(gaps)} écart(s). Après `make vendor` ou un changement de lockfile : "
             "régénérer le livrable (scripts/sandbox/make_livrable.sh) puis BUNDLE.json (scripts/sandbox/write_bundle.py).")
        return 1
    scope = "dépôt + tarball" if args.livrable else "dépôt"
    say(f"✓ verify-bundle : {len(recorded)} lockfiles concordent ({scope}) ; empreinte du jeu {bundle['lockfile_set_sha256'][:16]}…")
    return 0


if __name__ == "__main__":
    sys.exit(main())
