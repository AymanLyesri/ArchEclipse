"""Offline regression tests; live capture is verified separately."""
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zlib

spec = importlib.util.spec_from_file_location("capture_readme", Path(__file__).with_name("capture-readme.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))


def png(w=16, h=12, split=False):
    packed = zlib.compress((b"\0" + b"\x80\x90\xa0\xff" * w) * h)
    parts = [packed[:len(packed)//2], packed[len(packed)//2:]] if split else [packed]
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + b"".join(chunk(b"IDAT", p) for p in parts) + chunk(b"IEND", b""))


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def test_multiple_idat_chunks(self):
        path = self.root / "image.png"
        path.write_bytes(png(split=True))
        self.assertEqual(m.validate_png(path), (16, 12))

    def test_truncated_or_corrupt_png_rejected(self):
        path = self.root / "image.png"
        for data in (png()[:-12], png()[:-3], png()[:25] + b"BAD" + png()[28:], b"not png"):
            path.write_bytes(data)
            with self.assertRaises(RuntimeError):
                m.validate_png(path)

    def test_default_only_supported(self):
        self.assertTrue(m.select_shots(""))
        self.assertTrue(all(s["supported"] for s in m.select_shots("")))

    def test_explicit_unsupported_refused(self):
        with self.assertRaises(RuntimeError):
            m.assert_all_supported(m.select_shots("lock-screen"))

    def test_unknown_and_empty_selection(self):
        for names in ("not-real", ",,,"):
            with self.assertRaises(ValueError):
                m.select_shots(names)

    def test_required_shots_and_two_right_panels(self):
        items = {s["id"]: s for s in m.MANIFEST}
        for name in ("app-launcher", "left-panel-settings", "left-panel-keybinds", "left-panel-chatbot",
                     "left-panel-booru-1", "wallpaper-switcher", "workspace-overview", "right-panel-layout-1", "right-panel-layout-2"):
            self.assertTrue(items[name]["supported"], name)
        self.assertEqual([s["id"] for s in m.MANIFEST if s["state"] == "right"],
                         ["right-panel-layout-1", "right-panel-layout-2"])
        self.assertEqual(items["workspace-overview"]["asset"], ".github/assets/workspace-overview.png")

    def test_capture_layouts_are_nonpersistent(self):
        qml = (m.CONFIG / "services/CaptureIpc.qml").read_text()
        island = (m.CONFIG / "widgets/bar/islands/RightIsland.qml").read_text()
        self.assertIn('["Waifu", "Media", "Calendar", "NotificationHistory"]', qml)
        self.assertIn('["Calendar", "Media", "Waifu", "SystemResources"]', qml)
        self.assertIn("capture.rightWidgets", island)
        self.assertNotIn("Settings.rightPanelWidgets =", qml)

    def test_wallpaper_waits_for_hidden_loading_tiles(self):
        import subprocess
        qml = (m.CONFIG / "services/CaptureIpc.qml").read_text()
        fn = qml[qml.index("    function inspectImages("):qml.index("    IpcHandler {")]
        js = "const root = {}; " + fn + "; root.inspectImages = inspectImages;"
        js += """
        const result = {loading: 0, errors: 0, wallpaperFound: false};
        inspectImages({visible:true, opacity:1, captureReady:false, children:[
          {visible:true, opacity:0, thumbSettled:false, children:[]}
        ]}, result);
        if (result.loading < 2 || !result.wallpaperFound) process.exit(1);
        """
        self.assertEqual(subprocess.run(["node", "-e", js], capture_output=True).returncode, 0)

    def test_pill_crop_uses_surface_origin_and_logical_coords(self):
        layer = {"x": -1280, "y": 20, "w": 1280, "h": 800}
        status = {"rect": {"x": 400.2, "y": 0, "w": 450.6, "h": 700}, "visible": True}
        self.assertEqual(m.pill_rect(layer, status), {"x": -880, "y": 20, "w": 451, "h": 700})

    def test_invalid_or_outside_pill_rejected(self):
        for rect in ({"x": 100, "y": 0, "w": 200, "h": 20}, {"x": 0, "y": 0, "w": 0, "h": 20}):
            with self.assertRaises(RuntimeError):
                m.pill_rect({"x": 0, "y": 0, "w": 200, "h": 100}, {"rect": rect, "visible": True})

    def test_ambiguous_layers_rejected(self):
        item = {"namespace": "quickshell", "x": 0, "y": 0, "w": 500, "h": 600}
        for entries in ([], [item, item]):
            with self.assertRaises(RuntimeError):
                m.parse_quickshell_layer(json.dumps({"DP-9": {"levels": {"2": entries}}}), "DP-9")
        self.assertEqual(m.parse_quickshell_layer(json.dumps({"DP-9": {"levels": {"2": [item]}}}), "DP-9")["w"], 500)

    def test_transparent_surface_rejected(self):
        layers = json.dumps({"DP-9": {"levels": {"2": [
            {"namespace": "quickshell", "x": 0, "y": 0, "w": 460, "h": 1080, "alpha": 0}]}}})
        with self.assertRaises(RuntimeError):
            m.parse_quickshell_layer(layers, "DP-9")

    def test_monitor_discovery(self):
        self.assertEqual(m.parse_focused_monitor(json.dumps([{"name": "DP-9", "focused": True}]))["name"], "DP-9")

    def fixture(self):
        assets = self.root / ".github/assets"
        assets.mkdir(parents=True)
        readme = self.root / "README.md"
        readme.write_text("Keep edits\n![Overview](.github/assets/workspace-overview.gif)\n")
        shots = []
        for n in ("a", "b"):
            (assets / (n + ".png")).write_bytes(png(10, 10))
            src = self.root / (n + "-new.png")
            src.write_bytes(png(20, 20, split=True))
            shots.append({"id": n, "asset": ".github/assets/" + n + ".png", "src": str(src)})
        return readme, shots

    def test_install_backup(self):
        readme, shots = self.fixture()
        backup = Path(m.install_validated(shots, self.root, readme, self.root / "backups"))
        self.assertEqual(m.validate_png(self.root / shots[0]["asset"]), (20, 20))
        self.assertEqual((backup / "README.md").read_bytes(), readme.read_bytes())
        self.assertEqual(m.validate_png(backup / shots[0]["asset"]), (10, 10))

    def test_mid_install_failure_rolls_back(self):
        readme, shots = self.fixture()
        original = {p: p.read_bytes() for p in [readme] + [self.root / s["asset"] for s in shots]}
        real_replace = m.os.replace
        fail_dest = self.root / shots[1]["asset"]
        failed = False
        def fail_once(src, dest):
            nonlocal failed
            if Path(dest) == fail_dest and not failed:
                failed = True
                raise OSError("injected second replacement failure")
            return real_replace(src, dest)
        with patch.object(m.os, "replace", side_effect=fail_once):
            with self.assertRaises(OSError):
                m.install_validated(shots, self.root, readme, self.root / "backups")
        self.assertTrue(failed)
        for p, data in original.items():
            self.assertEqual(p.read_bytes(), data)

    def test_invalid_source_preserves_assets(self):
        readme, shots = self.fixture()
        Path(shots[1]["src"]).write_bytes(b"bad")
        with self.assertRaises(RuntimeError):
            m.install_validated(shots, self.root, readme, self.root / "backups")
        self.assertEqual(m.validate_png(self.root / shots[0]["asset"]), (10, 10))

    def test_targeted_gif_reference_update(self):
        readme, shots = self.fixture()
        shots = [{**shots[0], "id": "workspace-overview", "asset": ".github/assets/workspace-overview.png"}]
        m.install_validated(shots, self.root, readme, self.root / "backups", allow_gif_to_png=True)
        self.assertEqual(readme.read_text(), "Keep edits\n![Overview](.github/assets/workspace-overview.png)\n")

    def test_restore_on_capture_failure_and_no_install(self):
        args = m.parse_cli(["--only", "left-panel-settings", "--replace"])
        calls = []
        def ipc(action, *unused):
            calls.append(action)
            return {"ok": True}
        with patch.object(m, "capture_ipc", side_effect=ipc), patch.object(m, "capture_supported_shot", side_effect=RuntimeError("capture failed")), patch.object(m, "install_validated") as install:
            with self.assertRaises(RuntimeError):
                m.capture_run(args, "DP-9", self.root)
        self.assertEqual(calls, ["begin", "end"])
        install.assert_not_called()

    def test_restore_failure_prevents_install(self):
        args = m.parse_cli(["--only", "left-panel-settings", "--replace"])
        def ipc(action, *unused):
            if action == "end":
                raise RuntimeError("restore failed")
            return {"ok": True}
        with patch.object(m, "capture_ipc", side_effect=ipc), patch.object(m, "capture_supported_shot", return_value={"w": 500, "h": 900}), patch.object(m, "install_validated") as install:
            with self.assertRaises(RuntimeError):
                m.capture_run(args, "DP-9", self.root)
        install.assert_not_called()

    def test_interrupt_restores_and_prevents_install(self):
        args = m.parse_cli(["--only", "left-panel-settings", "--replace"])
        calls = []
        with patch.object(m, "capture_ipc", side_effect=lambda action, *args: calls.append(action) or {"ok": True}), patch.object(m, "capture_supported_shot", side_effect=KeyboardInterrupt), patch.object(m, "install_validated") as install:
            with self.assertRaises(KeyboardInterrupt):
                m.capture_run(args, "DP-9", self.root)
        self.assertEqual(calls, ["begin", "end"])
        install.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
