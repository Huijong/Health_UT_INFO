import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

class CustomFilePicker {
  static Future<dynamic> showPicker({
    required BuildContext context,
    required String title,
    required String directoryPath,
    String? extensionFilter,
    List<String>? prefixFilters,
    String? priorityPrefix,
    bool allowMultiple = false,
    required Future<dynamic> Function() onFreeSelect,
  }) async {
    // 권한 요청
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }

    return await showGeneralDialog<dynamic>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: _CustomFilePickerPopup(
                title: title,
                directoryPath: directoryPath,
                extensionFilter: extensionFilter,
                prefixFilters: prefixFilters,
                priorityPrefix: priorityPrefix,
                allowMultiple: allowMultiple,
                onFreeSelect: onFreeSelect,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }
}

class _CustomFilePickerPopup extends StatefulWidget {
  final String title;
  final String directoryPath;
  final String? extensionFilter;
  final List<String>? prefixFilters;
  final String? priorityPrefix;
  final bool allowMultiple;
  final Future<dynamic> Function() onFreeSelect;

  const _CustomFilePickerPopup({
    required this.title,
    required this.directoryPath,
    this.extensionFilter,
    this.prefixFilters,
    this.priorityPrefix,
    this.allowMultiple = false,
    required this.onFreeSelect,
  });

  @override
  State<_CustomFilePickerPopup> createState() => _CustomFilePickerPopupState();
}

class _CustomFilePickerPopupState extends State<_CustomFilePickerPopup> {
  List<File> _files = [];
  Set<File> _selectedFiles = {};
  bool _isLoading = true;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final dir = Directory(widget.directoryPath);
      if (!await dir.exists()) {
        setState(() {
          _errorMsg = '폴더가 존재하지 않습니다.\n()';
          _isLoading = false;
        });
        return;
      }

      final entities = await dir.list().toList();
      List<File> matchedFiles = [];

      for (var entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          bool isMatch = true;

          if (widget.extensionFilter != null && !fileName.endsWith(widget.extensionFilter!)) {
            isMatch = false;
          }

          if (isMatch && widget.prefixFilters != null && widget.prefixFilters!.isNotEmpty) {
            bool hasPrefix = widget.prefixFilters!.any((prefix) => fileName.startsWith(prefix));
            if (!hasPrefix) isMatch = false;
          }

          if (isMatch) {
            matchedFiles.add(entity);
          }
        }
      }

      // Sort
      matchedFiles.sort((a, b) {
        final aName = p.basename(a.path);
        final bName = p.basename(b.path);
        
        // Priority check
        if (widget.priorityPrefix != null) {
          final aHasPriority = aName.startsWith(widget.priorityPrefix!);
          final bHasPriority = bName.startsWith(widget.priorityPrefix!);
          if (aHasPriority && !bHasPriority) return -1;
          if (!aHasPriority && bHasPriority) return 1;
        }

        // Date check (Newest first)
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      setState(() {
        _files = matchedFiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = '파일을 불러오는 중 오류가 발생했습니다.\n';
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return ' B';
    if (bytes < 1024 * 1024) return ' KB';
    return ' MB';
  }

  @override
  Widget build(BuildContext context) {
    final scrHeight = MediaQuery.of(context).size.height;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      height: scrHeight * 0.75,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.0),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // SAF Fallback Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      if (widget.allowMultiple)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3366FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          onPressed: _selectedFiles.isEmpty ? null : () {
                            Navigator.pop(context, _selectedFiles.toList());
                          },
                          child: Text('선택 완료 (${_selectedFiles.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () async {
                          final result = await widget.onFreeSelect();
                          if (result != null && mounted) {
                            Navigator.pop(context, result);
                          }
                        },
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('다른 폴더에서 찾기 (자유 선택)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                
                // File List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : _errorMsg.isNotEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.white38, size: 48),
                                    const SizedBox(height: 16),
                                    Text(_errorMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
                                  ],
                                ),
                              ),
                            )
                          : _files.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.folder_off_outlined, color: Colors.white38, size: 48),
                                      const SizedBox(height: 16),
                                      Text(
                                        '이 폴더에는 조건에 맞는 파일이 없습니다.\n상단의 자유 선택 버튼을 이용해 주세요.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  itemCount: _files.length,
                                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
                                  itemBuilder: (context, index) {
                                    final file = _files[index];
                                    final stat = file.statSync();
                                    final fileName = p.basename(file.path);
                                    
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.insert_drive_file, color: Colors.white),
                                      ),
                                      title: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                                      trailing: widget.allowMultiple 
                                          ? Icon(
                                              _selectedFiles.contains(file) ? Icons.check_circle : Icons.circle_outlined,
                                              color: _selectedFiles.contains(file) ? const Color(0xFF3366FF) : Colors.white38,
                                            )
                                          : null,
                                      onTap: () {
                                        if (widget.allowMultiple) {
                                          setState(() {
                                            if (_selectedFiles.contains(file)) {
                                              _selectedFiles.remove(file);
                                            } else {
                                              _selectedFiles.add(file);
                                            }
                                          });
                                        } else {
                                          Navigator.pop(context, file);
                                        }
                                      },
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
