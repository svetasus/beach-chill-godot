import re
import subprocess

# Godot uses UIDs from the original file, we must get them right.
# Let's forcefully read from the git checkout of player.tscn and inject them manually into the two new .tscn files.
out = subprocess.check_output(['git', 'show', 'HEAD:scenes/features/player.tscn']).decode('utf-8')
orig_exts = {}
for line in out.split('\n'):
    if line.startswith('[ext_resource'):
        match = re.search(r'id="([^"]+)"', line)
        if match:
            orig_exts[match.group(1)] = line

def force_inject(filepath):
    with open(filepath, "r") as f:
        content = f.read()

    used_ids = set()
    for match in re.finditer(r'ExtResource\("([^"]+)"\)', content):
        used_ids.add(match.group(1))

    existing_exts = {}
    for line in content.split('\n'):
        if line.startswith('[ext_resource'):
            match = re.search(r'id="([^"]+)"', line)
            if match:
                existing_exts[match.group(1)] = line

    new_exts = []
    for rid in used_ids:
        if rid not in existing_exts and rid in orig_exts:
            new_exts.append(orig_exts[rid])

    if not new_exts:
        print(f"No new exts needed for {filepath}")
        return

    # Add the new exts
    lines = content.split('\n')

    # fix load_steps
    match = re.search(r'\[gd_scene.*?load_steps=(\d+)', content)
    if match:
        old_steps = int(match.group(1))
        new_steps = old_steps + len(new_exts)
        content = content.replace(f"load_steps={old_steps}", f"load_steps={new_steps}")
        lines = content.split('\n')

    last_ext_idx = -1
    for i, line in enumerate(lines):
        if line.startswith('[ext_resource'):
            last_ext_idx = i

    if last_ext_idx == -1:
        for i, line in enumerate(lines):
            if line.startswith('[gd_scene'):
                last_ext_idx = i
                break

    lines = lines[:last_ext_idx+1] + new_exts + lines[last_ext_idx+1:]

    with open(filepath, "w") as f:
        f.write('\n'.join(lines))
    print(f"Added {len(new_exts)} exts to {filepath}")

force_inject("scenes/features/components/player_ui.tscn")
force_inject("scenes/features/components/player_visuals.tscn")
