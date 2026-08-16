import os
import re

toast_code = """
  void _showToast(String message) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.45,
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF23293F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF3366FF).withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF3366FF), size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) entry.remove();
    });
  }
"""

def inject_toast_method(content):
    if "void _showToast(String message)" not in content:
        # Find the first build method and inject before it
        build_match = re.search(r'  @override\s+Widget build\(BuildContext context\)', content)
        if build_match:
            idx = build_match.start()
            content = content[:idx] + toast_code + "\n" + content[idx:]
    return content

def replace_snackbars_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    content = inject_toast_method(content)

    # Regex to find standard ScaffoldMessenger calls.
    # Pattern looks like: ScaffoldMessenger.of(context).showSnackBar(... SnackBar(...content: Text( <text_content> )...)...);
    # This might span multiple lines
    
    # We will use a more resilient approach since parsing dart code with regex can be tricky due to nested brackets.
    # We can find `ScaffoldMessenger.of(context).showSnackBar` and extract everything until the closing `);`
    
    pattern = re.compile(r'ScaffoldMessenger\.of\(context\)\.showSnackBar\s*\(\s*(?:const\s*)?SnackBar\s*\(\s*content\s*:\s*Text\s*\(\s*(.*?)\s*(?:,\s*style[^)]*\))?\s*\)[^;]*\)\s*\);', re.DOTALL)
    
    def replacer(match):
        text_arg = match.group(1).strip()
        # text_arg could be a string literal like 'Hello' or a variable like message or a combined '$var'
        return f"_showToast({text_arg});"
        
    content = pattern.sub(replacer, content)

    # There might be some that don't match the exact pattern.
    # Let's do a fallback for simpler ones on single line
    pattern2 = re.compile(r'ScaffoldMessenger\.of\(context\)\.showSnackBar\((?:const\s*)?SnackBar\(content:\s*Text\((.*?)\)[^)]*\)\);')
    content = pattern2.sub(replacer, content)

    # Also handle some edge cases where it's multi-line like:
    # ScaffoldMessenger.of(context).showSnackBar(
    #   SnackBar(content: Text('...')),
    # );
    pattern3 = re.compile(r'ScaffoldMessenger\.of\(context\)\.showSnackBar\s*\(\s*(?:const\s*)?SnackBar\s*\(\s*content\s*:\s*Text\s*\((.*?)\)\s*(?:,[^)]*)?\s*\)\s*,?\s*\);', re.DOTALL)
    content = pattern3.sub(replacer, content)

    if content != original_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

files_to_check = [
    r'd:\Health_UT\Health_UT_INFO\client\lib\screens\home_screen.dart',
    r'd:\Health_UT\Health_UT_INFO\client\lib\screens\settings_screen.dart',
    r'd:\Health_UT\Health_UT_INFO\client\lib\screens\notice_history_screen.dart',
    r'd:\Health_UT\Health_UT_INFO\client\lib\screens\lab_watch_sync_screen.dart'
]

for f in files_to_check:
    replace_snackbars_in_file(f)

