import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../drawing/layout_painter.dart';
import '../theme.dart';
import 'guides.dart';
import 'sketches.dart';

/// O schiță de coasere desenată pe ecran.
class SketchView extends StatelessWidget {
  const SketchView({super.key, required this.sketch, this.width = 120});

  final Sketch sketch;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: width,
      height: width * sketchHeight / sketchWidth,
      child: CustomPaint(painter: _SketchPainter(sketch, color)),
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter(this.sketch, this.color);

  final Sketch sketch;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    drawSketch(
        FlutterPatternCanvas(canvas, size.width / sketchWidth, color), sketch);
  }

  @override
  bool shouldRepaint(_SketchPainter old) =>
      old.sketch != sketch || old.color != color;
}

/// Instrucțiunile de coasere: ce îți trebuie și pașii, cu bife care rămân
/// salvate, ca să știi unde ai rămas.
class SewingScreen extends StatefulWidget {
  const SewingScreen({
    super.key,
    required this.garmentId,
    required this.garmentName,
    required this.guide,
  });

  final String garmentId;
  final String garmentName;
  final SewingGuide guide;

  @override
  State<SewingScreen> createState() => _SewingScreenState();
}

class _SewingScreenState extends State<SewingScreen> {
  final Set<int> _done = {};

  // Pașii diferă după setări (de exemplu rochia din jerseu are mai puțini),
  // așa că bifele se salvează separat pentru fiecare variantă.
  String get _key => 'sewing_${widget.garmentId}_${widget.guide.steps.length}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_key) ?? const [];
      setState(() => _done.addAll(saved.map(int.tryParse).whereType<int>()));
    } catch (_) {
      // Fără bife salvate: începem de la zero.
    }
  }

  Future<void> _toggle(int i) async {
    setState(() => _done.contains(i) ? _done.remove(i) : _done.add(i));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [for (final d in _done) '$d']);
    } catch (_) {}
  }

  Future<void> _reset() async {
    setState(_done.clear);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guide = widget.guide;
    final total = guide.steps.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Cum se coase · ${widget.garmentName}'),
        actions: [
          if (_done.isNotEmpty)
            IconButton(
              tooltip: 'Ia-o de la capăt',
              icon: const Icon(Icons.restart_alt),
              onPressed: _reset,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          Wrap(
            spacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.signal_cellular_alt, size: 18),
                label: Text(guide.level),
              ),
              if (guide.time.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(guide.time),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('De ce ai nevoie',
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final s in guide.supplies)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2, right: 8),
                            child: Icon(Icons.check_circle_outline, size: 18),
                          ),
                          Expanded(child: Text(s)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : _done.length / total,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${_done.length} din $total pași'),
              ],
            ),
          ),
          for (var i = 0; i < total; i++) _stepCard(context, i, guide.steps[i]),
          if (total > 0 && _done.length == total)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  'Gata! Haina ta e cusută. O poți arăta în comunitate.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
        ],
      ),
    );
  }

  Widget _stepCard(BuildContext context, int i, SewingStep step) {
    final theme = Theme.of(context);
    final done = _done.contains(i);
    final accent = Accent.of(i);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _toggle(i),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: done ? accent.strong : accent.light,
                    foregroundColor: done ? Colors.white : accent.strong,
                    child: done
                        ? const Icon(Icons.check, size: 16)
                        : Text('${i + 1}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(step.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: done ? TextDecoration.lineThrough : null,
                        )),
                  ),
                  Checkbox(value: done, onChanged: (_) => _toggle(i)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(step.text,
                        style: done
                            ? TextStyle(
                                color: theme.colorScheme.onSurfaceVariant)
                            : null),
                  ),
                  if (step.sketch != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accent.light.withAlpha(120),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SketchView(sketch: step.sketch!, width: 110),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
