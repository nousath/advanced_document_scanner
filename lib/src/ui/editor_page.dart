import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AdsEditorPage extends StatefulWidget {
  const AdsEditorPage({
    super.key,
    required this.imagePaths,
    required this.enableHighlight,
    required this.enableCrop,
    required this.enableCut,
    required this.enableRotate,
  });

  final List<String> imagePaths;
  final bool enableHighlight;
  final bool enableCrop;
  final bool enableCut;
  final bool enableRotate;

  @override
  State<AdsEditorPage> createState() => _AdsEditorPageState();
}

class _AdsEditorPageState extends State<AdsEditorPage> {
  int _index = 0;
  bool _saving = false;

  // edit state per page
  final Map<int, _PageEdits> _edits = {};

  _PageEdits _e() => _edits.putIfAbsent(_index, () => _PageEdits());

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      final out = <String>[];
      for (var i = 0; i < widget.imagePaths.length; i++) {
        final edits = _edits[i] ?? _PageEdits();
        final saved = await _renderAndSave(
          inputPath: widget.imagePaths[i],
          rotateQuarterTurns: edits.rotateQuarterTurns,
          cropRect01: edits.cropRect01,
          strokes01: edits.strokes01,
        );
        out.add(saved);
      }
      if (!mounted) return;
      Navigator.of(context).pop<List<String>>(out);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_index < widget.imagePaths.length - 1) setState(() => _index++);
  }

  void _prev() {
    if (_index > 0) setState(() => _index--);
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.imagePaths[_index];
    final edits = _e();

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit (${_index + 1}/${widget.imagePaths.length})'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveAll,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _EditorCanvas(
              filePath: path,
              enableHighlight: widget.enableHighlight,
              enableCrop: widget.enableCrop,
              rotateQuarterTurns: edits.rotateQuarterTurns,
              cropRect01: edits.cropRect01,
              strokes01: edits.strokes01,
              onRotate: widget.enableRotate
                  ? () => setState(() => edits.rotateQuarterTurns = (edits.rotateQuarterTurns + 1) % 4)
                  : null,
              onCropRectChanged: (r) => setState(() => edits.cropRect01 = r),
              onStrokesChanged: (s) => setState(() => edits.strokes01 = s),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _index == 0 ? null : _prev,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous',
                  ),
                  Expanded(
                    child: Text(
                      p.basename(path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _index == widget.imagePaths.length - 1 ? null : _next,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next',
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _PageEdits {
  int rotateQuarterTurns = 0;

  /// Crop rect in 0..1 space relative to the displayed image area.
  Rect? cropRect01;

  /// Highlight strokes, each stroke is a list of points in 0..1 space.
  List<List<Offset>> strokes01 = const [];
}

class _EditorCanvas extends StatefulWidget {
  const _EditorCanvas({
    required this.filePath,
    required this.enableHighlight,
    required this.enableCrop,
    required this.rotateQuarterTurns,
    required this.cropRect01,
    required this.strokes01,
    required this.onRotate,
    required this.onCropRectChanged,
    required this.onStrokesChanged,
  });

  final String filePath;
  final bool enableHighlight;
  final bool enableCrop;
  final int rotateQuarterTurns;
  final Rect? cropRect01;
  final List<List<Offset>> strokes01;
  final VoidCallback? onRotate;
  final ValueChanged<Rect?> onCropRectChanged;
  final ValueChanged<List<List<Offset>>> onStrokesChanged;

  @override
  State<_EditorCanvas> createState() => _EditorCanvasState();
}

enum _Tool { highlight, crop }

class _EditorCanvasState extends State<_EditorCanvas> {
  _Tool _tool = _Tool.highlight;
  bool _drawing = false;
  Offset? _dragStart;

  Size _boxSize = Size.zero;

  Rect? get _crop => widget.cropRect01;

  @override
  void initState() {
    super.initState();
    if (!widget.enableHighlight && widget.enableCrop) {
      _tool = _Tool.crop;
    }
  }

  void _setTool(_Tool t) {
    setState(() {
      _tool = t;
      _drawing = false;
      _dragStart = null;
    });
  }

  Offset _to01(Offset local) {
    final w = _boxSize.width <= 0 ? 1 : _boxSize.width;
    final h = _boxSize.height <= 0 ? 1 : _boxSize.height;
    return Offset((local.dx / w).clamp(0, 1), (local.dy / h).clamp(0, 1));
  }

  Rect _rectFrom01(Rect r) {
    return Rect.fromLTRB(
      r.left * _boxSize.width,
      r.top * _boxSize.height,
      r.right * _boxSize.width,
      r.bottom * _boxSize.height,
    );
  }

  void _onPanStart(DragStartDetails d) {
    if (_boxSize == Size.zero) return;

    if (_tool == _Tool.highlight && widget.enableHighlight) {
      _drawing = true;
      final pts = List<List<Offset>>.from(widget.strokes01);
      pts.add([_to01(d.localPosition)]);
      widget.onStrokesChanged(pts);
    } else if (_tool == _Tool.crop && widget.enableCrop) {
      _dragStart = d.localPosition;
      widget.onCropRectChanged(null);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_boxSize == Size.zero) return;

    if (_tool == _Tool.highlight && widget.enableHighlight) {
      if (!_drawing) return;
      final pts = List<List<Offset>>.from(widget.strokes01);
      if (pts.isEmpty) return;
      final last = List<Offset>.from(pts.removeLast());
      last.add(_to01(d.localPosition));
      pts.add(last);
      widget.onStrokesChanged(pts);
    } else if (_tool == _Tool.crop && widget.enableCrop) {
      final s = _dragStart;
      if (s == null) return;
      final a = _to01(s);
      final b = _to01(d.localPosition);
      final left = math.min(a.dx, b.dx);
      final top = math.min(a.dy, b.dy);
      final right = math.max(a.dx, b.dx);
      final bottom = math.max(a.dy, b.dy);
      // avoid tiny crop
      final r = Rect.fromLTRB(left, top, right, bottom);
      widget.onCropRectChanged(r);
    }
  }

  void _onPanEnd(DragEndDetails d) {
    _drawing = false;
    _dragStart = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        _boxSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: theme.colorScheme.surface,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: widget.rotateQuarterTurns,
                    child: Image.file(
                      File(widget.filePath),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: _OverlayPainter(
                    strokes01: widget.strokes01,
                    cropRect01: widget.cropRect01,
                    showHighlight: widget.enableHighlight && _tool == _Tool.highlight,
                    showCrop: widget.enableCrop && _tool == _Tool.crop,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _Toolbar(
                enableHighlight: widget.enableHighlight,
                enableCrop: widget.enableCrop,
                activeTool: _tool,
                onTool: _setTool,
                onRotate: widget.onRotate,
                onClear: () {
                  if (_tool == _Tool.highlight) {
                    widget.onStrokesChanged(const []);
                  } else {
                    widget.onCropRectChanged(null);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.enableHighlight,
    required this.enableCrop,
    required this.activeTool,
    required this.onTool,
    required this.onRotate,
    required this.onClear,
  });

  final bool enableHighlight;
  final bool enableCrop;
  final _Tool activeTool;
  final ValueChanged<_Tool> onTool;
  final VoidCallback? onRotate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface.withOpacity(0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            if (enableHighlight)
              _ChipButton(
                icon: Icons.border_color_outlined,
                label: 'Highlight',
                active: activeTool == _Tool.highlight,
                onTap: () => onTool(_Tool.highlight),
              ),
            if (enableHighlight && enableCrop) const SizedBox(width: 8),
            if (enableCrop)
              _ChipButton(
                icon: Icons.crop_outlined,
                label: 'Crop',
                active: activeTool == _Tool.crop,
                onTap: () => onTool(_Tool.crop),
              ),
            const Spacer(),
            IconButton(
              tooltip: 'Rotate',
              onPressed: onRotate,
              icon: const Icon(Icons.rotate_right_outlined),
            ),
            IconButton(
              tooltip: 'Clear',
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active
              ? theme.colorScheme.primary.withOpacity(0.12)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? theme.colorScheme.primary : null),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? theme.colorScheme.primary : null)),
          ],
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.strokes01,
    required this.cropRect01,
    required this.showHighlight,
    required this.showCrop,
  });

  final List<List<Offset>> strokes01;
  final Rect? cropRect01;
  final bool showHighlight;
  final bool showCrop;

  @override
  void paint(Canvas canvas, Size size) {
    if (showHighlight) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(6, size.shortestSide * 0.012)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFFEB3B).withOpacity(0.55);

      for (final stroke in strokes01) {
        if (stroke.length < 2) continue;
        final path = Path();
        final first = stroke.first;
        path.moveTo(first.dx * size.width, first.dy * size.height);
        for (final p in stroke.skip(1)) {
          path.lineTo(p.dx * size.width, p.dy * size.height);
        }
        canvas.drawPath(path, paint);
      }
    }

    if (showCrop && cropRect01 != null) {
      final r = Rect.fromLTRB(
        cropRect01!.left * size.width,
        cropRect01!.top * size.height,
        cropRect01!.right * size.width,
        cropRect01!.bottom * size.height,
      );

      // dim outside
      final dim = Paint()..color = Colors.black.withOpacity(0.35);
      final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      final hole = Path()..addRect(r);
      final outside = Path.combine(PathOperation.difference, full, hole);
      canvas.drawPath(outside, dim);

      // crop rect
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white;
      canvas.drawRect(r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.strokes01 != strokes01 || oldDelegate.cropRect01 != cropRect01 || oldDelegate.showCrop != showCrop || oldDelegate.showHighlight != showHighlight;
  }
}

Future<String> _renderAndSave({
  required String inputPath,
  required int rotateQuarterTurns,
  required Rect? cropRect01,
  required List<List<Offset>> strokes01,
}) async {
  final bytes = await File(inputPath).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  ui.Image img = frame.image;

  // Apply rotation on canvas output
  final rotatedSize = _rotatedSize(img.width, img.height, rotateQuarterTurns);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Draw rotated image
  canvas.save();
  if (rotateQuarterTurns != 0) {
    // rotate around origin into positive coords
    switch (rotateQuarterTurns % 4) {
      case 1:
        canvas.translate(rotatedSize.width.toDouble(), 0);
        canvas.rotate(math.pi / 2);
        break;
      case 2:
        canvas.translate(rotatedSize.width.toDouble(), rotatedSize.height.toDouble());
        canvas.rotate(math.pi);
        break;
      case 3:
        canvas.translate(0, rotatedSize.height.toDouble());
        canvas.rotate(-math.pi / 2);
        break;
    }
  }
  canvas.drawImage(img, Offset.zero, Paint());
  canvas.restore();

  // Highlight strokes (normalized to preview; assume full image area)
  if (strokes01.isNotEmpty) {
    final hp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFFFEB3B).withOpacity(0.55)
      ..strokeWidth = math.max(8, math.min(rotatedSize.width, rotatedSize.height) * 0.01);

    for (final s in strokes01) {
      if (s.length < 2) continue;
      final path = Path();
      path.moveTo(s.first.dx * rotatedSize.width, s.first.dy * rotatedSize.height);
      for (final pt in s.skip(1)) {
        path.lineTo(pt.dx * rotatedSize.width, pt.dy * rotatedSize.height);
      }
      canvas.drawPath(path, hp);
    }
  }

  final picture = recorder.endRecording();
  ui.Image outImage = await picture.toImage(rotatedSize.width, rotatedSize.height);

  // Crop (after rotation) if requested
  if (cropRect01 != null) {
    final cropPx = Rect.fromLTRB(
      (cropRect01.left * rotatedSize.width).clamp(0, rotatedSize.width.toDouble()),
      (cropRect01.top * rotatedSize.height).clamp(0, rotatedSize.height.toDouble()),
      (cropRect01.right * rotatedSize.width).clamp(0, rotatedSize.width.toDouble()),
      (cropRect01.bottom * rotatedSize.height).clamp(0, rotatedSize.height.toDouble()),
    );
    final w = cropPx.width.round();
    final h = cropPx.height.round();
    if (w > 20 && h > 20) {
      final rec2 = ui.PictureRecorder();
      final c2 = Canvas(rec2);
      c2.drawImageRect(
        outImage,
        cropPx,
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint(),
      );
      final p2 = rec2.endRecording();
      outImage = await p2.toImage(w, h);
    }
  }

  final bd = await outImage.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = bd!.buffer.asUint8List();

  final dir = await getTemporaryDirectory();
  final outDir = Directory(p.join(dir.path, 'ads_edited'));
  if (!await outDir.exists()) await outDir.create(recursive: true);
  final ts = DateTime.now().millisecondsSinceEpoch;
  final outPath = p.join(outDir.path, 'edited_$ts.png');
  await File(outPath).writeAsBytes(pngBytes, flush: true);
  return outPath;
}

({int width, int height}) _rotatedSize(int w, int h, int turns) {
  final t = turns % 4;
  if (t == 1 || t == 3) return (width: h, height: w);
  return (width: w, height: h);
}
