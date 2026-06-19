import os, re, sys

sha = os.environ.get('CI_COMMIT_SHORT_SHA')
if not sha:
    print("CI_COMMIT_SHORT_SHA not set", file=sys.stderr)
    sys.exit(1)

path = 'deploy/values.yaml'
with open(path) as f:
    content = f.read()

content = re.sub(r'^  tag: .*', f'  tag: {sha}', content, flags=re.M)

with open(path, 'w') as f:
    f.write(content)

print(f"Updated tag to {sha}")
