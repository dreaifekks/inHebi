#!/usr/bin/env python3
"""Export XCUITest attachments and copy page-named images into artifacts/screenshots."""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
result = Path(sys.argv[1]).resolve()
export = root / 'artifacts' / (result.stem + '-attachments')
output = root / 'artifacts' / 'screenshots'
export.mkdir(parents=True, exist_ok=True)
output.mkdir(parents=True, exist_ok=True)
subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(result), '--output-path', str(export)], check=True)
manifest = json.loads((export / 'manifest.json').read_text())
index = []
for test in manifest:
    for attachment in test['attachments']:
        source = export / attachment['exportedFileName']
        if source.suffix.lower() not in ['.png', '.jpg', '.jpeg', '.heic']:
            continue
        match = re.search(r'\b(\d{2}-[a-z]+(?:-[a-z]+)*)', attachment['suggestedHumanReadableName'])
        name = match.group(1) if match else f'additional-{len(index) + 1:03d}'
        destination = output / (name + source.suffix.lower())
        shutil.copy2(source, destination)
        index.append({'test': test['testIdentifier'], 'name': name, 'path': str(destination), 'source': str(source)})
(output / 'index.json').write_text(json.dumps(index, indent=2) + '\n')
print('\n'.join(item['path'] for item in index))
