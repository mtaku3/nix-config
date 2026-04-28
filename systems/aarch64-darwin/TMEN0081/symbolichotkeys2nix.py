import os
import sys
import plistlib
import json
import subprocess

if __name__ == '__main__':
    home = os.environ['HOME']
    p1 = subprocess.run(['/usr/libexec/PlistBuddy', '-c', 'Print :AppleSymbolicHotKeys', '-x', f'{home}/Library/Preferences/com.apple.symbolichotkeys.plist'], capture_output=True, text=True)
    plist_text = p1.stdout
    plist = plistlib.loads(plist_text)
    json_text = json.dumps(plist, ensure_ascii=False)
    p2 = subprocess.run(['nix-instantiate', '--arg-from-stdin', 'stdin', '--eval', '-E', '{ stdin }: builtins.fromJSON stdin'], input=json_text, capture_output=True, text=True)
    nix_text = p2.stdout
    print(nix_text)
