import re, os

root = 'MManger/Views'
pattern = re.compile(r'''(Text|Button|Section|navigationTitle|navigationBarTitleDisplayMode|\.accessibilityLabel|Label)\s*\(\s*"([^"\\]+)"''')

for dirpath, _, files in os.walk(root):
    for f in files:
        if not f.endswith('.swift'):
            continue
        path = os.path.join(dirpath, f)
        with open(path, 'r', encoding='utf-8') as fp:
            content = fp.read()
        new_content = content
        matches = list(pattern.finditer(content))
        for m in reversed(matches):
            full = m.group(0)
            ctor = m.group(1)
            s = m.group(2)
            if not s.strip():
                continue
            if 'NSLocalizedString' in full or '\\(' in s:
                continue
            if s in ('·', '•', '→', '/', '-'):
                continue
            if '@' in s and '.' in s:
                continue
            replacement = f'{ctor}(NSLocalizedString("{s}", comment: "")'
            new_content = new_content[:m.start()] + replacement + new_content[m.end():]
        if new_content != content:
            with open(path, 'w', encoding='utf-8') as fp:
                fp.write(new_content)
            print('Updated', path)
