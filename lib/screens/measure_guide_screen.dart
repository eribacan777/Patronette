import 'package:flutter/material.dart';

import '../models/measurements.dart';
import '../widgets/measure_figure.dart';

/// Ghidul de măsurare: fiecare măsură, cu desen și explicație.
class MeasureGuideScreen extends StatelessWidget {
  const MeasureGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ghid de măsurare')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ai nevoie de un centimetru de croitorie și de o sfoară legată în '
            'talie, ca reper. Cel mai ușor e să te ajute cineva.',
          ),
          const SizedBox(height: 12),
          for (final d in kMeasurements)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 64,
                        height: 120,
                        child: MeasureFigure(highlight: d.key)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.label, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(d.howTo),
                        ],
                      ),
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
