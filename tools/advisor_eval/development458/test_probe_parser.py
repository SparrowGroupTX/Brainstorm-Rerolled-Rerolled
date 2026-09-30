"""Manufactured parser checks; never launches Lua or original game source."""
from __future__ import annotations

from copy import deepcopy
import unittest

from tools.advisor_learning.lifecycle_reference_457 import source_rule_stock
from tools.advisor_learning.lifecycle_reference_458 import source_rule_open_callback
from tools.advisor_learning.test_lifecycle_457 import cases
from .run_source_probe import parse_output


def synthetic_expected(fixtures: list[dict]) -> dict:
    opening = source_rule_open_callback(fixtures[0]["used_packs"], slot=2,
                                        key="p_arcana_normal_1", cash=4, price=4)
    return {
        "cases": [{"id": fixture["id"], "reference": source_rule_stock(fixture),
                   "candidate": deepcopy(source_rule_stock(fixture))}
                  for fixture in fixtures],
        "opening": {"case_id": fixtures[0]["id"], "reference": opening,
                    "candidate": deepcopy(opening)},
    }


def synthetic_output(fixtures: list[dict]) -> str:
    lines = ["Lua runtime: manufactured", "Running manufactured.lua"]
    for fixture in fixtures:
        case_id = fixture["id"]
        used = list(fixture["used_packs"])
        draws = iter(fixture["draws"])
        draw_count = offer_count = 0
        for slot in (1, 2):
            key = used[slot - 1] if slot <= len(used) else None
            if key is None:
                key = next(draws)
                draw_count += 1
                lines.append(f"TRACE|{case_id}|DRAW|{slot}|{key}")
                if slot <= len(used):
                    used[slot - 1] = key
                else:
                    used.append(key)
            if key == "USED":
                continue
            lines.extend((f"TRACE|{case_id}|UI|<nil>|{key}",
                          f"TRACE|{case_id}|MATERIALIZE|{slot}|{key}",
                          f"TRACE|{case_id}|OFFER|{slot}|{key}"))
            offer_count += 1
        lines.append(f"STOCK|{case_id}|used1={used[0]}|used2={used[1]}|"
                     f"draws={draw_count}|offers={offer_count}")
        open_seen = "<nil>"
        open_count = 0
        if case_id == "used_first_stored_second":
            used[1] = "USED"
            open_seen = "USED"
            open_count = 1
            lines.append(f"TRACE|{case_id}|OPEN|2|USED")
        lines.append(f"CASE|{case_id}|used1={used[0]}|used2={used[1]}|"
                     f"draws={draw_count}|offers={offer_count}|open_seen={open_seen}|"
                     f"open_count={open_count}|cash={fixture['cash']}")
    lines.extend(("PASS manufactured.lua", "1/1 fixtures passed"))
    return "\n".join(lines) + "\n"


class ProbeParserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixtures = cases()
        cls.expected = synthetic_expected(cls.fixtures)
        cls.output = synthetic_output(cls.fixtures)

    def test_complete_manufactured_output_agrees(self):
        compared = parse_output(self.output, self.fixtures, self.expected)
        self.assertEqual(len(compared), 8)
        self.assertTrue(all(row["agreement"] for row in compared), compared)

    def test_wrong_physical_offer_position_is_mismatch(self):
        wrong = self.output.replace(
            "TRACE|used_first_stored_second|OFFER|2|p_arcana_normal_1",
            "TRACE|used_first_stored_second|OFFER|1|p_arcana_normal_1", 1)
        compared = parse_output(wrong, self.fixtures, self.expected)
        self.assertFalse(compared[0]["agreement"])
        self.assertIn("source_trace", compared[0]["differences"])

    def test_opening_callback_observing_old_key_is_mismatch(self):
        wrong = self.output.replace("open_seen=USED", "open_seen=p_arcana_normal_1", 1)
        compared = parse_output(wrong, self.fixtures, self.expected)
        self.assertIn("open_callback_order", compared[0]["differences"])

    def test_duplicate_missing_and_interleaved_records_rejected(self):
        case_line = next(line for line in self.output.splitlines() if line.startswith("CASE|"))
        malformed = (
            self.output.replace(case_line, case_line + "\n" + case_line, 1),
            self.output.replace(case_line + "\n", "", 1),
            self.output.replace("used2=USED|draws=0", "used2=USPASS manufactured.lua\nED|draws=0", 1),
            self.output.replace("PASS manufactured.lua",
                                "TRACE|used_first_stored_second|DRAW|1|p_arcana_normal_1\n"
                                "PASS manufactured.lua", 1),
        )
        for text in malformed:
            with self.subTest(text_length=len(text)):
                with self.assertRaises(ValueError):
                    parse_output(text, self.fixtures, self.expected)


if __name__ == "__main__":
    unittest.main()
