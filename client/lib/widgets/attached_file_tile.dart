import 'package:flutter/material.dart';
import '../models/attached_file.dart';

/// 첨부 파일 목록 한 줄 — 아이콘·이름·크기 + 삭제 버튼
class AttachedFileTile extends StatelessWidget {
  final AttachedFile file;
  final VoidCallback onDelete;

  const AttachedFileTile({
    super.key,
    required this.file,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 4),
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -4),
        minVerticalPadding: 0,
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        title: Text(
          file.name,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          file.sizeLabel,
          style: TextStyle(fontSize: 11, color: cs.outline),
        ),
        trailing: InkWell(
          onTap: onDelete,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(Icons.close, size: 16, color: cs.error),
          ),
        ),
      ),
    );
  }

  Widget _typeAvatar(ColorScheme cs) {
    final (icon, color) = switch (file.type) {
      AttachType.fit => (Icons.fitness_center, cs.primary),
      AttachType.cola => (Icons.folder_zip_outlined, cs.tertiary),
      AttachType.log => (Icons.folder_zip_outlined, Colors.blueGrey),
      AttachType.capture => (Icons.image_outlined, cs.secondary),
    };
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, size: 16, color: color),
    );
  }
}
