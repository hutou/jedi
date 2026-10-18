python3 - <<'PY'
from pathlib import Path
import re

count = "617"
paths = [Path("release/check.sh"), Path("release/build-info.py"), Path("release/package.py")]
texts = [path.read_text() for path in paths]
old_counts = []
for path, text in zip(paths, texts):
    found = re.findall(r"\b([0-9]+) examples, 0 failures, 0 errors, 0 pending", text)
    if len(found) != 1:
        raise SystemExit(f"Review the current spec check in {path} before continuing.")
    old_counts.extend(found)
if len(set(old_counts)) != 1:
    raise SystemExit("Release scripts disagree about the expected spec count.")
old = old_counts[0]
updates = {path: re.sub(r"\b" + old + r"\b", count, text)
           for path, text in zip(paths, texts)}
smoke = Path("release/smoke.py")
text = smoke.read_text()
text = text.replace('"--name=EXA-10", ', '')
text = text.replace('"--scale=EXA-10"', '"--scale=B_vr_01"')
text = text.replace('"--name=EXA01"', '"--name=T_exa_01"')
text = text.replace('"EXA01"', '"T_exa_01"')
if "EXA-10" in text:
    raise SystemExit("Review the scale creation and reference in release/smoke.py.")
updates[smoke] = text
for path, text in updates.items():
    if path.read_text() != text:
        path.write_text(text)
        print(f"Updated {path}")
print(f"Expected passing spec count: {count}")
PY
git diff -- release/check.sh release/build-info.py release/package.py release/smoke.py
