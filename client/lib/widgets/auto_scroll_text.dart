import 'dart:async';
import 'package:flutter/material.dart';

class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  
  const AutoScrollText({Key? key, required this.text, required this.style}) : super(key: key);

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scroll();
    });
  }

  Future<void> _scroll() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    if (_scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        while (mounted) {
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted || !_scrollController.hasClients) break;
          await _scrollController.animateTo(
            maxExtent,
            duration: Duration(milliseconds: (maxExtent * 25).toInt()),
            curve: Curves.linear,
          );
          if (!mounted) break;
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted || !_scrollController.hasClients) break;
          _scrollController.jumpTo(0);
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style),
    );
  }
}
