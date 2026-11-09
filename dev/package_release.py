"""Package only explicitly selected release artifacts; preserve previous releases."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def archive(destination, entries):
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as package:
        for source, name in entries:
            package.write(source, name)
    with zipfile.ZipFile(destination) as package:
        if package.testzip() is not None:
            raise RuntimeError(f"Archive verification failed: {destination}")

exe = BUILD / "Hyperscale Datacenter Tycoon.exe"
test_report = json.loads((BUILD / "final12-tests.json").read_text(encoding="utf-8-sig"))
if len(test_report) != 19 or not all(row["passed"] for row in test_report):
    raise RuntimeError("Final executable must pass all 19 release suites before packaging")

portable = [(exe, exe.name), (ROOT / "README.md", "README.md")]
portable += [(p, "docs/" + p.name) for p in (ROOT / "docs").glob("*.md")]
portable += [(BUILD / name, name) for name in ("GODOT-LICENSE.txt", "GODOT-THIRD-PARTY-NOTICES.txt")]
portable += [(p, p.relative_to(ROOT).as_posix()) for p in (ROOT / "release/steam").glob("*.md")]
first_image = ROOT / "release/steam/screenshots/01-first-campus.png"
portable.append((first_image, first_image.relative_to(ROOT).as_posix()))
portable += [(BUILD / "verification-1.2.0.json", "verification-1.2.0.json")]
destination = BUILD / "Hyperscale-Datacenter-Tycoon-1.2.0-Windows.zip"
archive(destination, portable)
with zipfile.ZipFile(destination) as package:
    assert hashlib.sha256(package.read(exe.name)).hexdigest() == digest(exe)

media = [(p, p.relative_to(ROOT / "release/steam").as_posix())
         for p in (ROOT / "release/steam").rglob("*")
         if p.is_file() and p.suffix in (".md", ".png", ".mp4")]
archive(BUILD / "Hyperscale-Steam-Release-Materials.zip", media)

sources = [(ROOT / name, name) for name in ("project.godot", "main.tscn", "export_presets.cfg", "README.md", "Play.cmd", "Play Preview.cmd")]
for folder in ("scripts", "tests", "assets", "docs", "dev"):
    sources += [(p, p.relative_to(ROOT).as_posix()) for p in (ROOT / folder).rglob("*")
                if p.is_file() and p.suffix not in (".import", ".pyc") and "__pycache__" not in p.parts]
sources += [(p, p.relative_to(ROOT).as_posix()) for p in (ROOT / "release/steam").glob("*.md")]
archive(ROOT / ".tools/checkpoints/phase13-source.zip", sources)
print(json.dumps({"portable": str(destination), "bytes": destination.stat().st_size,
                  "zip_sha256": digest(destination), "exe_sha256": digest(exe),
                  "checks": sum(row["checks"] for row in test_report)}, indent=2))
