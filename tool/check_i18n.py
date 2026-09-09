from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
lib = root / "lib"
source = (lib / "core" / "app_strings.dart").read_text(encoding="utf-8")
keys = set(re.findall(r"^\s*'([^']+)'\s*:\s*\[", source, flags=re.M))
used = set()
for path in lib.rglob("*.dart"):
    text = path.read_text(encoding="utf-8")
    used.update(re.findall(r"(?:strings|AppStrings(?:\.of\([^)]*\)|\([^)]*\)))\.get\('([^']+)'\)", text))
missing = sorted(used - keys)
if missing:
    print("[I18N] FALHOU — chaves ausentes:")
    for key in missing:
        print(f"- {key}")
    sys.exit(1)
print(f"[I18N] OK — {len(keys)} chaves cadastradas; todas as chaves estáticas usadas estão definidas.")
