"""Pruebas sin teléfono de tools/hero: python3 -m unittest tools/test_hero.py"""
import importlib.machinery
import importlib.util
import pathlib
import tempfile
import tomllib
import unittest

_loader = importlib.machinery.SourceFileLoader("hero", str(pathlib.Path(__file__).with_name("hero")))
hero = importlib.util.module_from_spec(importlib.util.spec_from_loader("hero", _loader))
_loader.exec_module(hero)


class Power(unittest.TestCase):
    def test_line_with_and_without_names(self):
        text = ("1000 hero-run: power: -42 mA 3900 mV 80% ext=0; cpu 900 ms of 30000 (8 cores = 0%); top:"
                " backboardd[30] 500 ms [41] 200 ms\n"
                "basura\n")
        rows = hero.parse_power(text)
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0]["ma"], rows[0]["ext"], rows[0]["cpu"]), (-42, 0, 900))
        self.assertEqual(rows[0]["top"], [("backboardd", 30, 500), ("?", 41, 200)])


class Evidence(unittest.TestCase):
    def test_next_id_valid_toml_and_permanent_copy(self):
        with tempfile.TemporaryDirectory() as d:
            d = pathlib.Path(d)
            toml = d / "evidence.toml"
            toml.write_text('[[evidence]]\nid = "E-0007"\ntitle = "x"\n')
            src = d / "log.txt"
            src.write_text("hola")
            eid, dst = hero.add_evidence(toml, src, 'con "comillas" y \\ barra', d / "store")
            data = tomllib.loads(toml.read_text())["evidence"]
            self.assertEqual(eid, "E-0008")
            self.assertEqual(data[-1]["title"], 'con "comillas" y \\ barra')
            self.assertEqual(data[-1]["sha256"], hero.sha256(dst))
            self.assertEqual(dst.read_text(), "hola")


class Normalize(unittest.TestCase):
    def test_hides_addresses(self):
        self.assertEqual(hero.normalize("p 0x1f2c"), "p 0xA")


if __name__ == "__main__":
    unittest.main()
