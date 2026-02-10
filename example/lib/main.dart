import 'dart:io';

import 'package:advanced_document_scanner/advanced_document_scanner.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Document Scanner',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scanner = const AdvancedDocumentScanner();

  bool _busy = false;
  List<String> _original = [];
  List<String> _edited = [];
  List<String> _exported = [];

  AdsImageFormat _format = AdsImageFormat.jpg;
  AdsQualityPreset _preset = AdsQualityPreset.high;

  bool _customSize = false;
  int _w = 1600;
  int _h = 2200;

  int _jpgQuality = 85;
  bool _overrideJpgQuality = false;

  List<String> get _source => _edited.isNotEmpty ? _edited : _original;

  Future<void> _scan() async {
    setState(() => _busy = true);
    try {
      final result = await _scanner.captureAndEdit(
        context: context,
        pageLimit: 10,
        multiPage: true,
      );
      setState(() {
        _original = result.originalImagePaths;
        _edited = result.editedImagePaths ?? [];
        _exported = [];
      });
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanNative() async {
    setState(() => _busy = true);
    try {
      final result = await _scanner.scanWithMlKit(
        context: context,
        pageLimit: 10,
        allowGallery: true,
        returnJpeg: true,
        returnPdf: true,
        openEditorAfterScan: true,
      );
      setState(() {
        _original = result.originalImagePaths;
        _edited = result.editedImagePaths ?? [];
        _exported = [];
      });
      if (result.pdfPath != null) {
        _snack('Native PDF saved: ${result.pdfPath}');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    if (_source.isEmpty) {
      _snack('Scan a document first');
      return;
    }
    setState(() => _busy = true);
    try {
      final edited = await _scanner.openEditor(
        context: context,
        imagePaths: _source,
        enableHighlight: true,
        enableCrop: true,
        enableCut: true,
        enableRotate: true,
      );
      setState(() {
        _edited = edited;
        _exported = [];
      });
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    if (_source.isEmpty) {
      _snack('Scan a document first');
      return;
    }
    setState(() => _busy = true);
    try {
      final outputDir = await _scanner.getDefaultExportDir(
        folderName: 'advanced_document_scanner_exports',
      );

      final options = AdsExportOptions(
        format: _format,
        preset: _preset,
        targetWidth: _customSize ? _w : null,
        targetHeight: _customSize ? _h : null,
        jpgQuality: (_format == AdsImageFormat.jpg && _overrideJpgQuality) ? _jpgQuality : null,
      );

      final exported = await _scanner.exportImages(
        imagePaths: _source,
        outputDir: outputDir,
        options: options,
      );

      setState(() {
        _exported = exported;
      });

      _snack('Exported ${exported.length} file(s)');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final previewList = _exported.isNotEmpty ? _exported : _source;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Document Scanner'),
      ),
      body: Column(
        children: [
          _Controls(
            busy: _busy,
            format: _format,
            preset: _preset,
            customSize: _customSize,
            width: _w,
            height: _h,
            onFormat: (v) => setState(() => _format = v),
            onPreset: (v) => setState(() => _preset = v),
            onCustomSize: (v) => setState(() => _customSize = v),
            onWidth: (v) => setState(() => _w = v),
            onHeight: (v) => setState(() => _h = v),
            overrideJpgQuality: _overrideJpgQuality,
            jpgQuality: _jpgQuality,
            onOverrideJpgQuality: (v) => setState(() => _overrideJpgQuality = v),
            onJpgQuality: (v) => setState(() => _jpgQuality = v),
            onScan: _scan,
            onScanNative: _scanNative,
            onEdit: _edit,
            onExport: _export,
          ),
          const Divider(height: 1),
          Expanded(
            child: previewList.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: previewList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final path = previewList[i];
                      return _ImageCard(index: i + 1, path: path);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.busy,
    required this.format,
    required this.preset,
    required this.customSize,
    required this.width,
    required this.height,
    required this.onFormat,
    required this.onPreset,
    required this.onCustomSize,
    required this.onWidth,
    required this.onHeight,
    required this.overrideJpgQuality,
    required this.jpgQuality,
    required this.onOverrideJpgQuality,
    required this.onJpgQuality,
    required this.onScan,
    required this.onScanNative,
    required this.onEdit,
    required this.onExport,
  });

  final bool busy;
  final AdsImageFormat format;
  final AdsQualityPreset preset;

  final bool customSize;
  final int width;
  final int height;

  final ValueChanged<AdsImageFormat> onFormat;
  final ValueChanged<AdsQualityPreset> onPreset;
  final ValueChanged<bool> onCustomSize;
  final ValueChanged<int> onWidth;
  final ValueChanged<int> onHeight;

  final bool overrideJpgQuality;
  final int jpgQuality;
  final ValueChanged<bool> onOverrideJpgQuality;
  final ValueChanged<int> onJpgQuality;

  final VoidCallback onScan;
  final VoidCallback onScanNative;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<AdsImageFormat>(
                  value: format,
                  decoration: const InputDecoration(
                    labelText: 'Export format',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: AdsImageFormat.jpg, child: Text('JPG')),
                    DropdownMenuItem(value: AdsImageFormat.png, child: Text('PNG')),
                    DropdownMenuItem(value: AdsImageFormat.gif, child: Text('GIF')),
                  ],
                  onChanged: busy ? null : (v) => onFormat(v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<AdsQualityPreset>(
                  value: preset,
                  decoration: const InputDecoration(
                    labelText: 'Quality preset',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: AdsQualityPreset.low, child: Text('Low')),
                    DropdownMenuItem(value: AdsQualityPreset.medium, child: Text('Medium')),
                    DropdownMenuItem(value: AdsQualityPreset.high, child: Text('High')),
                    DropdownMenuItem(value: AdsQualityPreset.max, child: Text('Max')),
                  ],
                  onChanged: busy ? null : (v) => onPreset(v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SwitchListTile.adaptive(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Custom size'),
                  value: customSize,
                  onChanged: busy ? null : onCustomSize,
                ),
              ),
            ],
          ),
          if (customSize) ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: width.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Target width',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) onWidth(n);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: height.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Target height',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) onHeight(n);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (format == AdsImageFormat.jpg) ...[
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Override JPG quality'),
              value: overrideJpgQuality,
              onChanged: busy ? null : onOverrideJpgQuality,
            ),
            if (overrideJpgQuality)
              Row(
                children: [
                  const Text('Quality'),
                  Expanded(
                    child: Slider(
                      value: jpgQuality.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 18,
                      label: jpgQuality.toString(),
                      onChanged: busy ? null : (v) => onJpgQuality(v.round()),
                    ),
                  ),
                  SizedBox(width: 44, child: Text(jpgQuality.toString())),
                ],
              ),
          ],
          const SizedBox(height: 8),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onScan,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_outlined),
                      label: const Text('Scan (Camera)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: busy ? null : onScanNative,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Scan (ML Kit)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onExport,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64),
            SizedBox(height: 12),
            Text('Scan a document to get started.', style: TextStyle(fontSize: 16)),
            SizedBox(height: 6),
            Text(
              'Then edit (highlight/crop/rotate) and export as JPG/PNG/GIF with presets and custom sizing.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.index, required this.path});

  final int index;
  final String path;

  @override
  Widget build(BuildContext context) {
    final f = File(path);
    final exists = f.existsSync();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              'Page $index • ${_shortPath(path)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!exists)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('File not found.'),
            )
          else
            Image.file(f, fit: BoxFit.contain),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  static String _shortPath(String p) {
    final parts = p.replaceAll('\\', '/').split('/');
    if (parts.length <= 2) return p;
    return '${parts[parts.length - 2]}/${parts.last}';
  }
}
