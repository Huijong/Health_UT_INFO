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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: _typeAvatar(cs),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          file.sizeLabel,
          style: TextStyle(fontSize: 11, color: cs.outline),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, size: 18, color: cs.error),
          tooltip: '삭제',
          onPressed: onDelete,
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
