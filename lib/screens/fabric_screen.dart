import 'package:flutter/material.dart';

import '../fabric/fabric_painter.dart';
import '../fabric/fabric_plan.dart';
import '../format.dart';

/// Desenul cu așezarea pieselor pe material, de folosit la croit.
class FabricScreen extends StatelessWidget {
  const FabricScreen({super.key, required this.plan, required this.garmentName});

  final FabricPlan plan;
  final String garmentName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Așezarea pe material · $garmentName')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Material lat de ${fmtCm(plan.fabricWidth)} cm, pliat în două pe lung, '
              'cu fața înăuntru. Linia roșie din stânga e îndoitura. Piesele '
              'marcate ×2 se taie o dată, prin ambele straturi.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(12),
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: InteractiveViewer(
                maxScale: 8,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: FabricPainter(plan: plan, ink: Colors.brown.shade700),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Lungime ocupată: ${fmtCm(plan.length.roundToDouble())} cm. '
              'Cumpără ${fmtCm(plan.metersToBuy)} m '
              '(include ${fmtCm(FabricPlan.extra)} cm pentru intrarea la spălat).',
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
