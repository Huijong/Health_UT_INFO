import sys
path = r'd:\Health_UT\Health_UT_INFO\watch\app\src\main\kotlin\com\samsung\health\client\SyncService.kt'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('healthport hotspot', 'P2P/hotspot')
content = content.replace('"healthport"', '"DIRECT-healthport"')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated Watch logs successfully')
