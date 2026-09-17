#!/usr/bin/env python3
"""Live capture smoke test. Restarts this shell; requires Pillow, qs, grim, hyprctl.
Leaves the shell running and README/assets untouched. Run from any directory.
Pixel checks detect empty/flat images, not semantic correctness or privacy.
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from PIL import Image, ImageFilter, ImageStat

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("capture_readme", HERE / "capture-readme.py")
assert spec and spec.loader
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def main():
    capture.CACHE.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="smoke-", dir=capture.CACHE))
    assets = capture.REPO / ".github/assets"
    import hashlib
    def digest_assets():
        paths = [capture.REPO / "README.md"] + sorted(assets.glob("*"))
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()}
    before = digest_assets()
    subprocess.run(["qs", "-p", str(capture.CONFIG), "kill"], capture_output=True, timeout=15)
    with (output / "shell.log").open("w") as log:
        shell = subprocess.Popen(["qs", "-p", str(capture.CONFIG)], env={**os.environ, "MANGOHUD": "0"},
                                 stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if shell.poll() is not None:
            raise RuntimeError(f"Shell exited {shell.returncode}; inspect {output / 'shell.log'}")
        try:
            reply = capture.capture_ipc("end")
            if reply.get("ok"):
                break
        except RuntimeError:
            pass
        time.sleep(0.25)
    else:
        raise RuntimeError("Shell IPC not ready within 30s")
    subprocess.run(["python3", str(HERE / "capture-readme.py"), "--output-dir", str(output)],
                   check=True, timeout=420)
    report = []
    for shot in capture.select_shots(""):
        path = output / Path(shot["asset"]).name
        with Image.open(path) as im:
            im.load()
            rgba = im.convert("RGBA")
            gray = rgba.convert("L")
            alpha = rgba.getchannel("A").getextrema()
            stddev = ImageStat.Stat(gray).stddev[0]
            entropy = gray.entropy()
            edges = ImageStat.Stat(gray.filter(ImageFilter.FIND_EDGES)).mean[0]
            assert min(im.size) >= 100, (path, "implausible size", im.size)
            assert alpha[1] > 0, (path, "fully transparent")
            assert stddev > 2 and entropy > 1 and edges > 0.5, (path, "flat/empty image", stddev, entropy, edges)
            row = dict(widget=shot["id"], size=im.size, alpha=alpha, stddev=round(stddev, 2),
                       entropy=round(entropy, 2), edges=round(edges, 2))
            report.append(row)
            print("PASS " + json.dumps(row), flush=True)
    assert before == digest_assets(), "Preview test changed README or assets"
    state = capture.run(["qs", "-p", capture.CONFIG, "ipc", "call", "bar", "barDiag", "state"])
    layers = json.loads(capture.run(["hyprctl", "layers", "-j"]))
    result = dict(passed=len(report), images=report, restored_state=state,
                  readme_assets_unchanged=True, layers=layers)
    (output / "report.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"PASS: {len(report)} live captures; README/assets unchanged; shell state={state}\nReport: {output / 'report.json'}")


if __name__ == "__main__":
    main()
