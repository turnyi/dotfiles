#!/usr/bin/env bash
set -euo pipefail

SNIPPETS_FILE="${HOME}/.config/snippets/snippets.json"
ESPANSO_FILE="${HOME}/.config/espanso/match/snippets.yml"

if [[ ! -f "${SNIPPETS_FILE}" ]]; then
  echo "Error: ${SNIPPETS_FILE} not found"
  exit 1
fi

python3 -c "
import json, yaml, sys

with open('${SNIPPETS_FILE}') as f:
    snippets = json.load(f)

matches = []
for s in snippets:
    matches.append({'trigger': s['keyword'], 'replace': s['content']})

doc = {'matches': matches}

with open('${ESPANSO_FILE}', 'w') as f:
    f.write('# Auto-generated from snippets.json - do not edit manually\n')
    f.write('# Run sync-snippets.sh to regenerate\n')
    yaml.dump(doc, f, default_flow_style=False, allow_unicode=True)

print(f'Synced {len(matches)} snippets to ${ESPANSO_FILE}')
" 2>/dev/null || {
  # Fallback if PyYAML not installed
  python3 << 'PYEOF'
import json

snippets_file = "$HOME/.config/snippets/snippets.json"
espanso_file = "$HOME/.config/espanso/match/snippets.yml"

PYEOF

  python3 -c "
import json, os

home = os.environ['HOME']
snippets_file = os.path.join(home, '.config', 'snippets', 'snippets.json')
espanso_file = os.path.join(home, '.config', 'espanso', 'match', 'snippets.yml')

with open(snippets_file) as f:
    snippets = json.load(f)

lines = [
    '# Auto-generated from snippets.json - do not edit manually',
    '# Run sync-snippets.sh to regenerate',
    'matches:',
]

for s in snippets:
    keyword = s['keyword']
    content = s['content']
    if '\n' in content:
        lines.append(f'  - trigger: \"{keyword}\"')
        lines.append(f'    replace: |')
        for line in content.split('\n'):
            lines.append(f'      {line}')
    else:
        escaped = content.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
        lines.append(f'  - trigger: \"{keyword}\"')
        lines.append(f'    replace: \"{escaped}\"')
    lines.append('')

with open(espanso_file, 'w') as f:
    f.write('\n'.join(lines) + '\n')

print(f'Synced {len(snippets)} snippets to {espanso_file}')
"
}

if command -v espanso &>/dev/null; then
  espanso restart 2>/dev/null || true
fi
