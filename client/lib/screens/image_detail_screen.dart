import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:client/utils/toast_util.dart';
import 'dart:io';

class ImageDetailScreen extends StatefulWidget {
  final String imageUrl;

  const ImageDetailScreen({Key? key, required this.imageUrl}) : super(key: key);

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  bool _isDownloading = false;

  Future<void> _downloadImage() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // 권한 확인 (Gal에서 자체적으로 처리하기도 하지만 명시적으로 확인)
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          if (mounted) ToastUtil.showToast(context, "갤러리 접근 권한이 필요합니다.");
          setState(() {
            _isDownloading = false;
          });
          return;
        }
      }

      // 임시 폴더에 다운로드
      final tempDir = await getTemporaryDirectory();
      final fileName = 'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savePath = '${tempDir.path}/$fileName';

      await Dio().download(widget.imageUrl, savePath);

      // 갤러리에 저장
      await Gal.putImage(savePath);

      if (mounted) ToastUtil.showToast(context, "이미지를 갤러리에 저장했습니다.");
    } catch (e) {
      if (mounted) ToastUtil.showToast(context, "이미지 저장에 실패했습니다.");
      debugPrint("Download Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download, color: Colors.white),
            onPressed: _isDownloading ? null : _downloadImage,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white54,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  SizedBox(height: 8),
                  Text('이미지를 불러올 수 없습니다.', style: TextStyle(color: Colors.white54)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
