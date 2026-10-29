import importlib.util,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def load(name):
 spec=importlib.util.spec_from_file_location(name,ROOT/f"{name}.py")
 mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod
audit=load("audit");compare=load("compare")
class MigrationTests(unittest.TestCase):
 def test_parse_comments(self):
  raw='<mapframe>{"type":"FeatureCollection","features":[{"geometry":{"type":"Point","coordinates":[-40.3512,-3.68274] // note\n}}]}</mapframe>'
  self.assertEqual(audit.extract(raw)["features"][0]["geometry"]["coordinates"],[-40.3512,-3.68274])
 def test_legacy_comparison(self):
  inv=ROOT/"reports/inventory.csv";geo=ROOT/"reports/legacy.geojson"
  if inv.exists() and geo.exists(): self.assertEqual(compare.compare(inv,geo)["issue_count"],0)
 def test_title(self):
  self.assertEqual(audit.title_of("[[Casa_Camatuê]]"),"Casa Camatuê")
if __name__=="__main__":unittest.main()

