import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AdsCapturePage extends StatefulWidget {
  const AdsCapturePage({
    super.key,
    required this.pageLimit,
    required this.multiPage,
  });

  final int pageLimit;
  final bool multiPage;

  @override
  State<AdsCapturePage> createState() => _AdsCapturePageState();
}

class _AdsCapturePageState extends State<AdsCapturePage> {
  CameraController? _controller;
  bool _starting = true;
  bool _capturing = false;
  String? _err;

  final List<String> _paths = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final c = CameraController(
        back,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await c.initialize();
      if (!mounted) return;
      setState(() {
        _controller = c;
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _starting = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    if (!widget.multiPage && _paths.isNotEmpty) {
      _finish();
      return;
    }

    if (_paths.length >= widget.pageLimit) return;

    setState(() => _capturing = true);
    try {
      final xfile = await c.takePicture();
      final saved = await _saveToAppDir(xfile.path);
      if (!mounted) return;
      setState(() {
        _paths.add(saved);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<String> _saveToAppDir(String tempPath) async {
    final dir = await getTemporaryDirectory();
    final outDir = Directory(p.join(dir.path, 'ads_scans'));
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final out = p.join(outDir.path, 'scan_$ts.jpg');
    await File(tempPath).copy(out);
    return out;
  }

  void _finish() {
    Navigator.of(context).pop<List<String>>(_paths);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Document (${_paths.length}/${widget.pageLimit})'),
        actions: [
          if (_paths.isNotEmpty)
            TextButton(
              onPressed: _finish,
              child: const Text('Next'),
            )
        ],
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Camera error: $_err'),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _controller == null
                          ? const SizedBox.shrink()
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(_controller!),
                                // Simple guide overlay
                                IgnorePointer(
                                  child: CustomPaint(
                                    painter: _GuidePainter(
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    _ThumbStrip(
                      paths: _paths,
                      onRemove: (i) => setState(() => _paths.removeAt(i)),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _capturing ? null : _capture,
                                icon: _capturing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.camera_alt_outlined),
                                label: Text(widget.multiPage ? 'Capture page' : 'Capture'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _paths.isEmpty ? null : _finish,
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.paths, required this.onRemove});

  final List<String> paths;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox(height: 10);

    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(paths[i]),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => onRemove(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;

    final w = size.width;
    final h = size.height;

    // A4-ish guide box
    final guideW = w * 0.84;
    final guideH = h * 0.72;
    final left = (w - guideW) / 2;
    final top = (h - guideH) / 2;
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, guideW, guideH), const Radius.circular(12));
    canvas.drawRRect(r, p);

    // corner ticks
    final tick = 20.0;
    final pp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;

    // top-left
    canvas.drawLine(Offset(left, top + tick), Offset(left, top), pp);
    canvas.drawLine(Offset(left, top), Offset(left + tick, top), pp);
    // top-right
    canvas.drawLine(Offset(left + guideW - tick, top), Offset(left + guideW, top), pp);
    canvas.drawLine(Offset(left + guideW, top), Offset(left + guideW, top + tick), pp);
    // bottom-left
    canvas.drawLine(Offset(left, top + guideH - tick), Offset(left, top + guideH), pp);
    canvas.drawLine(Offset(left, top + guideH), Offset(left + tick, top + guideH), pp);
    // bottom-right
    canvas.drawLine(Offset(left + guideW - tick, top + guideH), Offset(left + guideW, top + guideH), pp);
    canvas.drawLine(Offset(left + guideW, top + guideH - tick), Offset(left + guideW, top + guideH), pp);
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) => oldDelegate.color != color;
}
