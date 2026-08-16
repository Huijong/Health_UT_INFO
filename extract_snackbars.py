import os
import re

target_dir = r'd:\Health_UT\Health_UT_INFO\client\lib'
results = {}

# We'll look for pattern like: SnackBar(content: Text('...')) or Text("...") or Text(variable)
# Since Dart code can be multi-line, we'll read the whole file and find all showSnackBar calls.
for root, dirs, files in os.walk(target_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Find all occurrences of showSnackBar
            snackbars = re.findall(r'showSnackBar\s*\((.*?)\);', content, re.DOTALL)
            if snackbars:
                file_rel = os.path.relpath(filepath, target_dir)
                results[file_rel] = []
                for sb in snackbars:
                    # try to extract the Text content
                    text_match = re.search(r'Text\s*\(\s*(.*?)\s*\)', sb, re.DOTALL)
                    if text_match:
                        msg = text_match.group(1).strip()
                        # clean up newlines in the string
                        msg = re.sub(r'\s+', ' ', msg)
                        results[file_rel].append(msg)
                    else:
                        results[file_rel].append("[Dynamic or Custom Widget] " + sb[:50].replace('\n', ' '))

# Format the output
output = []
for file, msgs in results.items():
    output.append(f"### {file}")
    for msg in msgs:
        output.append(f"- {msg}")
    output.append("")

with open('snackbar_list.md', 'w', encoding='utf-8') as f:
    f.write('\n'.join(output))

print("List created in snackbar_list.md")
