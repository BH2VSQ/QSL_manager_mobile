from pathlib import Path

root = Path(__file__).resolve().parents[1]
files = list((root / 'lib').rglob('*.dart'))
errors = []
for p in files:
    text = p.read_text(encoding='utf-8')
    if "package:qsl_manager_mobile" in text:
        errors.append(f"{p}: avoid package self-import for portability")
    for left, right in [('(', ')'), ('{', '}'), ('[', ']')]:
        if text.count(left) != text.count(right):
            errors.append(f"{p}: unbalanced {left}{right}: {text.count(left)} vs {text.count(right)}")
if errors:
    raise SystemExit('\n'.join(errors))

qsl_api_text = (root / 'lib/services/qsl_api.dart').read_text(encoding='utf-8')
assert "The mobile client never derives one from the other." in qsl_api_text
assert "if (country.isNotEmpty)" in qsl_api_text
assert "address['country'] = country;" in qsl_api_text
assert "normalizedCountry = '';" not in qsl_api_text
assert "addressKey.endsWith(countryKey)" not in qsl_api_text

address_text = (root / 'lib/screens/address_book_screen.dart').read_text(encoding='utf-8')
assert "国家 / 地区（可选）" in address_text

print(f"Checked {len(files)} Dart files: delimiter balance OK")
print("Address-label field separation check: PASS")
