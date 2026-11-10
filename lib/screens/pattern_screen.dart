import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../drawing/layout.dart';
import '../drawing/layout_painter.dart';
import '../export/pdf_export.dart';
import '../export/tiles.dart';
import '../fabric/fabric_plan.dart';
import '../format.dart';
import '../garments/garment.dart';
import '../geometry.dart';
import '../models/profile.dart';
import '../theme.dart';
import 'fabric_screen.dart';

/// Tiparul generat: previzualizare, setări și export PDF.
class PatternScreen extends StatefulWidget {
  const PatternScreen({super.key, required this.garment, required this.profile});

  final Garment garment;
  final Profile profile;

  @override
  State<PatternScreen> createState() => _PatternScreenState();
}

class _PatternScreenState extends State<PatternScreen> {
  late final Map<String, double> _options = widget.garment.defaultOptions;
  double _seam = 1;
  double _hem = 2;
  double _fabricWidth = 150;
  bool _busy = false;

  String get _fileName =>
      'patronette-${widget.garment.id}-${widget.profile.name.toLowerCase().replaceAll(RegExp(r'\s+'), '-')}.pdf';

  Future<void> _export({required bool print}) async {
    setState(() => _busy = true);
    try {
      final draft = widget.garment.draft(widget.profile.values, _options);
      final bytes = await buildPatternPdf(
        garment: widget.garment,
        draft: draft,
        profile: widget.profile,
        options: _options,
        seam: _seam,
        hem: _hem,
        fabricWidth: _fabricWidth,
      );
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: _fileName);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: _fileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nu am putut crea PDF-ul: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.garment.draft(widget.profile.values, _options);
    final layout = PatternLayout.build(draft.pieces, seam: _seam, hem: _hem);
    final pages = TileGrid(layout).usedCount;
    // Corsajul se oprește în talie: nu are tiv, deci nici glisor de tiv.
    final hasHem = draft.pieces
        .any((p) => p.outline.any((s) => s.kind == EdgeKind.hem));
    final fabric = FabricPlan.compute(draft.pieces,
        fabricWidth: _fabricWidth, seam: _seam, hem: _hem);

    final preview = Card(
      margin: const EdgeInsets.all(12),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        maxScale: 12,
        child: CustomPaint(
          size: Size.infinite,
          painter: LayoutPainter(
            layout: layout,
            color: PatronetteColors.ink,
            footer: '${widget.garment.name} · ${widget.profile.name}',
          ),
        ),
      ),
    );

    final panel = ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(
              avatar: const Icon(Icons.content_cut, size: 18),
              label: Text('${draft.pieces.length} piese')),
          Chip(
              avatar: const Icon(Icons.description_outlined, size: 18),
              label: Text('$pages pagini A4 + 1 de instrucțiuni')),
        ]),
        const SizedBox(height: 4),
        Text('Apropie cu două degete ca să vezi detaliile.',
            style: Theme.of(context).textTheme.bodySmall),
        for (final n in draft.notes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.info_outline),
            title: Text(n),
          ),
        const Divider(),
        for (final o in widget.garment.options) _optionControl(o),
        const Divider(),
        _slider('Rezervă de cusătură', _seam, 0, 2, 0.5,
            (v) => setState(() => _seam = v)),
        if (hasHem)
          _slider('Rezervă de tiv', _hem, 0, 4, 0.5,
              (v) => setState(() => _hem = v)),
        const Divider(),
        _fabricSection(fabric),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.garment.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('pe măsurile pentru ${widget.profile.name}',
                style: const TextStyle(color: Colors.white70)),
          ),
        ),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth > 760) {
          return Row(children: [
            Expanded(child: preview),
            SizedBox(width: 380, child: panel),
          ]);
        }
        return Column(children: [
          Expanded(flex: 5, child: preview),
          Expanded(flex: 4, child: panel),
        ]);
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _export(print: false),
                icon: const Icon(Icons.share),
                label: const Text('Salvează PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _export(print: true),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.print),
                label: const Text('Printează'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Calculatorul de material: lățimea materialului și câți metri trebuie.
  Widget _fabricSection(FabricPlan fabric) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text('Material necesar',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
        ),
        const Text('Lățimea materialului'),
        const SizedBox(height: 8),
        SegmentedButton<double>(
          segments: const [
            ButtonSegment(value: 110, label: Text('110 cm')),
            ButtonSegment(value: 140, label: Text('140 cm')),
            ButtonSegment(value: 150, label: Text('150 cm')),
          ],
          selected: {_fabricWidth},
          onSelectionChanged: (s) => setState(() => _fabricWidth = s.first),
        ),
        const SizedBox(height: 12),
        Card(
          color: fabric.fits
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cumpără ${fmtCm(fabric.metersToBuy)} m',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('Piesele ocupă ${fmtCm(fabric.length.roundToDouble())} cm '
                    'din lungime; am adăugat ${fmtCm(FabricPlan.extra)} cm pentru '
                    'intrarea la spălat.'),
                if (!fabric.fits) ...[
                  const SizedBox(height: 8),
                  Text('Nu încape pe materialul pliat: '
                      '${fabric.tooWide.join(', ')}. Alege un material mai lat '
                      'sau taie piesa din material desfăcut.'),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FabricScreen(
                          plan: fabric, garmentName: widget.garment.name),
                    )),
                    icon: const Icon(Icons.grid_view),
                    label: const Text('Vezi așezarea pe material'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _optionControl(GarmentOption o) {
    final value = widget.garment.option(_options, o.key);
    final choices = o.choices;
    if (choices != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.label),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              segments: [
                for (final e in choices.entries)
                  ButtonSegment(value: e.key, label: Text(e.value)),
              ],
              selected: {value},
              onSelectionChanged: (s) =>
                  setState(() => _options[o.key] = s.first),
            ),
          ],
        ),
      );
    }
    return _slider(o.label, value, o.min, o.max, o.step,
        (v) => setState(() => _options[o.key] = v));
  }

  Widget _slider(String label, double value, double min, double max,
      double step, ValueChanged<double> onChanged) {
    final text = fmtCm(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Expanded(child: Text(label)),
            Text('$text cm',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          label: '$text cm',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
