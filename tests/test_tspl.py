import importlib.machinery
import importlib.util
import unittest
from pathlib import Path


FILTER_PATH = Path(__file__).parents[1] / "filter" / "ble_tspl"
loader = importlib.machinery.SourceFileLoader("ble_tspl", str(FILTER_PATH))
spec = importlib.util.spec_from_loader(loader.name, loader)
ble_tspl = importlib.util.module_from_spec(spec)
loader.exec_module(ble_tspl)


class TsplTests(unittest.TestCase):
    def test_bitmap_landscape_header(self):
        result = ble_tspl.build_bitmap_tspl(1199, 799, b"\x00" * 119900,
                                            landscape=True)

        self.assertTrue(result.startswith(b"SIZE 150 mm,100 mm\r\n"))
        self.assertIn(b"BITMAP 0,0,150,100,0,", result)

    def test_pbm_inversion_preserves_padding_bits(self):
        result = ble_tspl._invert_pbm(9, 1, b"\x00\x00")

        self.assertEqual(result, b"\xff\x80")

    def test_bitmap_preserves_pbm_bits_and_uses_overwrite_mode(self):
        result = ble_tspl.build_bitmap_tspl(8, 1, b"\x80")

        self.assertIn(b"BITMAP 395,599,1,1,0,", result)
        self.assertTrue(result.endswith(b"\x80\r\nPRINT 1\r\n"))

    def test_text_input_is_tspl(self):
        result = ble_tspl.text_to_tspl("hello")

        self.assertTrue(result.startswith(b"SIZE 100,150\n"))
        self.assertIn(b'TEXT 10,10,"FONT 0",0,1,1,"hello"', result)
        self.assertTrue(result.endswith(b"PRINT 1\n"))
