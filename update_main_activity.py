import sys
path = r'd:\Health_UT\Health_UT_INFO\client\android\app\src\main\kotlin\com\samsung\health\client\MainActivity.kt'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('val ssid = call.argument<String>("ssid") ?: "healthport"', 'val ssid = "DIRECT-healthport"')
content = content.replace('val pwd = call.argument<String>("pwd") ?: "12345678"', 'val pwd = "00000000"')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Updated MainActivity.kt successfully')
