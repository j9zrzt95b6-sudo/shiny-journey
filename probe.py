import random
import string
import re
import subprocess
import time
import urllib.request

# 1) Generate probe
random_suffix = ''.join(random.choices(string.digits, k=4))
fingerprint = f"DEPLOY_PROBE_20260724_{random_suffix}"
print(f"Generated fingerprint: {fingerprint}")

# 2) Edit files
def insert_meta_to_head(filename, fp):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # insert after <head>
    meta_tag = f'\n  <meta name="deploy-probe" content="{fp}">'
    updated_content = re.sub(r'(<head>)', rf'\1{meta_tag}', content, flags=re.IGNORECASE)
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    print(f"Injected meta tag to {filename}")

insert_meta_to_head('index.html', fingerprint)
insert_meta_to_head('official.html', fingerprint)

# Check changes
subprocess.run(['git', 'diff', 'index.html', 'official.html'], check=True)

