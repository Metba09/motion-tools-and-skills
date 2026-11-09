#!/usr/bin/env python3
"""Génère LICENSES/, BUNDLE.md et VERSION dans un dossier de bundle en préparation (outil de maintenance).

  python3 release/metadata.py <dossier_stage> --version 1.0.0 --commit <sha> --branch <nom> --tiers core,browser
Tout est calculé à partir des fichiers réels du stage (METADATA des wheels, champs license des lockfiles npm).
"""
import argparse
import csv
import datetime
import email.parser
import json
import re
import shutil
import sys
import zipfile
from collections import Counter, defaultdict
from pathlib import Path

LICENSE_FILE = re.compile(r"(licen[sc]e|copying|notice|authors)", re.I)
RESTRICTED = re.compile(r"(?i)\b(A?GPL|LGPL|MPL|EPL|CDDL|SSPL|CC-BY-NC|commercial|proprietary|company)")
MAX_TEXT = 1_000_000


def python_rows(stage, out):
    rows, seen = [], set()
    for wheel in sorted((stage / "vendor").glob("wheels*/*/*.whl")):
        try:
            with zipfile.ZipFile(wheel) as z:
                metas = [n for n in z.namelist() if n.endswith(".dist-info/METADATA")]
                if not metas:
                    continue
                msg = email.parser.Parser().parsestr(z.read(metas[0]).decode("utf-8", "replace"), headersonly=True)
                name, version = msg.get("Name", wheel.name), msg.get("Version", "?")
                if (name.lower(), version) in seen:
                    continue
                seen.add((name.lower(), version))
                lic = (msg.get("License-Expression") or msg.get("License") or "").strip().splitlines()[:1]
                lic = lic[0][:90] if lic and lic[0].upper() != "UNKNOWN" else ""
                if not lic:
                    lic = "; ".join(c.split("::")[-1].strip() for c in msg.get_all("Classifier", []) if c.startswith("License ::")) or "inconnue"
                rows.append(("python", name, version, lic))
                target = out / "python" / f"{name}-{version}"
                for member in z.infolist():
                    base = Path(member.filename).name
                    if ".dist-info/" in member.filename and not member.is_dir() and LICENSE_FILE.search(base) and member.file_size <= MAX_TEXT:
                        target.mkdir(parents=True, exist_ok=True)
                        (target / base).write_bytes(z.read(member))
        except (zipfile.BadZipFile, OSError) as error:
            sys.stderr.write(f"avertissement : {wheel.name} illisible ({error})\n")
    return rows


def npm_rows(stage, lockfiles):
    rows, seen = [], set()
    for lock in lockfiles:
        data = json.loads(lock.read_text(encoding="utf-8"))
        for key, val in data.get("packages", {}).items():
            if not key or val.get("link"):
                continue
            name = val.get("name") or key.split("node_modules/")[-1]
            version = val.get("version", "?")
            if (name, version) in seen:
                continue
            seen.add((name, version))
            lic = val.get("license")
            if isinstance(lic, dict):
                lic = lic.get("type")
            if isinstance(lic, list):
                lic = " OR ".join(str(x.get("type", x)) if isinstance(x, dict) else str(x) for x in lic)
            rows.append(("npm", name, version, str(lic) if lic else "inconnue"))
    return rows


def node_projects(stage, tiers):
    text = (stage / "scripts" / "projects.sh").read_text(encoding="utf-8")
    projects = {}
    for tier, body in re.findall(r"^NODE_(CORE|EXTRAS|BROWSER)=\(\n(.*?)^\)", text, re.S | re.M):
        if tier.lower() in tiers:
            projects[tier.lower()] = [l.split("#")[0].strip() for l in body.splitlines() if l.split("#")[0].strip()]
    return projects


def direct_deps(stage, project):
    pkg = json.loads((stage / project / "package.json").read_text(encoding="utf-8"))
    lock = json.loads((stage / project / "package-lock.json").read_text(encoding="utf-8")).get("packages", {})
    names = sorted({**pkg.get("dependencies", {}), **pkg.get("devDependencies", {}), **pkg.get("optionalDependencies", {})})
    return [f"{n}@{lock.get('node_modules/' + n, {}).get('version', '?')}" for n in names]


def dir_size_mb(path):
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file()) / 1e6


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stage")
    ap.add_argument("--version", required=True)
    ap.add_argument("--commit", required=True)
    ap.add_argument("--branch", default="")
    ap.add_argument("--tiers", default="core,browser")
    args = ap.parse_args()
    stage, tiers = Path(args.stage), set(args.tiers.split(","))
    out = stage / "LICENSES"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir()

    projects = node_projects(stage, tiers)
    locks = [stage / p / "package-lock.json" for plist in projects.values() for p in plist]
    rows = python_rows(stage, out) + npm_rows(stage, locks)
    with open(out / "THIRD_PARTY.tsv", "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["ecosystem", "name", "version", "license"])
        writer.writerows(sorted(rows))

    by_eco = defaultdict(Counter)
    for eco, _, _, lic in rows:
        by_eco[eco][lic] += 1
    restricted = [r for r in rows if RESTRICTED.search(r[3])]
    unknown = [r for r in rows if r[3] == "inconnue"]
    lines = ["# Licences et redistribution (généré par release/metadata.py)", "",
             f"{len(rows)} composants tiers recensés ({sum(1 for r in rows if r[0] == 'python')} Python, {sum(1 for r in rows if r[0] == 'npm')} npm). Liste complète : `THIRD_PARTY.tsv`.", "",
             "## Composants à licence à obligations (copyleft faible/fort, ou mention commerciale)", ""]
    lines += [f"- {e} {n} {v} : {l}" for e, n, v, l in sorted(restricted)] or ["- aucun repéré dans les métadonnées"]
    lines += ["", f"## Licence non déclarée dans les métadonnées : {len(unknown)} composant(s)", "",
              "Voir `THIRD_PARTY.tsv` (valeur « inconnue ») ; consulter le `package.json` ou le dépôt amont du paquet avant toute redistribution.", "",
              "## Où sont les textes de licence", "",
              "- Python : copiés dans `LICENSES/python/<nom>-<version>/` depuis chaque wheel.",
              "- npm : non copiés ici ; ils sont dans chaque paquet (`vendor/npm-cache`, puis `node_modules/<paquet>/` après installation).",
              "- Dépôt lui-même : `LICENSE` à la racine ; le contenu des dossiers `skills/`, `starters/` et `tools/` garde ses propres notices amont (`THIRD_PARTY_NOTICES*`, `UPSTREAM-README*`).", "",
              "## Limites de cette analyse", "",
              "- Les licences sont celles DÉCLARÉES par les métadonnées ; rien n'a été analysé dans le code lui-même.",
              "- Le niveau `browser` embarque un binaire Chromium (@sparticuz/chromium) : ses composants tiers ont leurs propres licences, non analysées ici." if "browser" in tiers else "- Niveau `browser` non inclus.",
              "- Les niveaux non inclus (voir BUNDLE.md) ont leurs propres licences, non couvertes."]
    (out / "REDISTRIBUTION.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    summary = []
    for eco, counter in sorted(by_eco.items()):
        summary.append(f"[{eco}]")
        summary += [f"{n:5d}  {lic}" for lic, n in counter.most_common()]
    (out / "SUMMARY.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")

    py = defaultdict(list)
    for wheel in sorted((stage / "vendor").glob("wheels*/*/*.whl")):
        py[wheel.parent.name].append(wheel.name.split("-")[0] + "==" + wheel.name.split("-")[1])
    md = ["# motion-tools-bundle", "",
          "| | |", "|---|---|",
          f"| Nom | motion-tools-bundle |", f"| Version | {args.version} |",
          f"| Date (UTC) | {datetime.datetime.now(datetime.timezone.utc):%Y-%m-%d %H:%M} |",
          f"| Commit source | `{args.commit}` (branche `{args.branch}`) |",
          f"| Niveaux inclus | {', '.join(sorted(tiers))} |",
          f"| Taille du dossier | {dir_size_mb(stage):.0f} Mo (avant compression) |", "",
          "## Runtimes requis", "",
          "- Node >= 22.12 (testé : v22.23.4), npm >= 10.",
          "- Python 3.12 ou 3.13 (testé : 3.13.18), Linux x86_64 glibc.",
          "- Système, NON vendorisés : `ffmpeg` / `ffprobe` (encodage, transcription) ; un Chrome système est facultatif (Chromium embarqué si niveau `browser`).", "",
          "## Niveaux NON inclus", "",
          "- Facultatifs vendorisables mais absents de cette archive : " + (", ".join(t for t in ("extras", "audio") if t not in tiers) or "aucun") + ".",
          "- Jamais vendorisés : Python `voice`, `vision`, `analysis` (voir `requirements/NOT-VENDORED.txt`).", "",
          "## Dépendances vendorisées", "", f"Liste complète avec licences : `LICENSES/THIRD_PARTY.tsv` ({len(rows)} composants).", "",
          "### Python (wheels)", ""]
    for tag, items in sorted(py.items()):
        md.append(f"- `{tag}` ({len(items)}) : " + ", ".join(items))
    md += ["", "### npm : dépendances directes par projet (version verrouillée)", ""]
    for tier, plist in projects.items():
        for project in plist:
            deps = direct_deps(stage, project)
            md.append(f"- `{project}` [{tier}] : " + (", ".join(deps) if deps else "aucune"))
    (stage / "BUNDLE.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    (stage / "VERSION").write_text(args.version + "\n", encoding="utf-8")
    sys.stdout.write(f"LICENSES/ : {len(rows)} composants, {len(restricted)} à obligations, {len(unknown)} sans licence déclarée ; BUNDLE.md écrit\n")


if __name__ == "__main__":
    main()
