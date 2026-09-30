from pathlib import Path
H=Path(__file__).resolve().parent
s=(H.parent/'development447/audit.py').read_text()
s=s.replace("C=E/'development446/install/captures/001'", "C=H/'captures/001'")
s=s.replace("r['end']['details'].get('outcome')", "(r['end'] or {}).get('details',{}).get('outcome')")
s=s.replace("'loaded_version':'2.219.0-alpha','events':28200,\n 'starts':10,'endings':10", "'loaded_versions':read(C/'summary.json')['versions'],'events':read(C/'summary.json')['events'],\n 'starts':len(read(C/'summary.json')['starts']),'endings':len(read(C/'summary.json')['endings'])")
s=s.replace("'packets_omitted_by_original_128_cap':40", "'packet_coverage':'See review/report.json;128 cap unchanged'")
with(H/'audit.py').open('x')as f:f.write(s)
