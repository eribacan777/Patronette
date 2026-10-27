import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import '../models/measurements.dart';
import '../models/profile.dart';
import '../widgets/measure_figure.dart';

/// Formularul în care se introduc numele și măsurile unei persoane.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.store, this.profile});

  final ProfileStore store;

  /// null = profil nou.
  final Profile? profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final Map<String, TextEditingController> _fields;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _fields = {
      for (final d in kMeasurements)
        d.key: TextEditingController(text: _format(p?.values[d.key])),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _format(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  /// Acceptă și virgulă, și punct: „88,5” sau „88.5”.
  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final values = {
      for (final e in _fields.entries) e.key: _parse(e.value.text)!,
    };
    final profile = widget.profile?.copyWith(
          name: _name.text.trim(),
          values: values,
        ) ??
        Profile(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: _name.text.trim(),
          values: values,
        );
    await widget.store.save(profile);
    if (mounted) Navigator.of(context).pop();
  }

  void _showGuide(MeasurementDef def) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, height: 190, child: MeasureFigure(highlight: def.key)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.label, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(def.howTo),
                  const SizedBox(height: 8),
                  Text(
                    'Valori obișnuite: ${def.min.toStringAsFixed(0)}–'
                    '${def.max.toStringAsFixed(0)} cm',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile == null ? 'Profil nou' : 'Editează profilul'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nume',
                hintText: 'ex. Ana',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Scrie un nume' : null,
            ),
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Măsoară peste lenjerie, cu un centimetru de croitorie ținut '
                  'paralel cu podeaua, fără să strângi. Apasă pe ⓘ ca să vezi '
                  'cum se ia fiecare măsură.',
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final d in kMeasurements) _measurementField(d),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: const Text('Salvează'),
      ),
    );
  }

  Widget _measurementField(MeasurementDef d) {
    final value = _parse(_fields[d.key]!.text);
    final unusual = value != null && (value < d.min || value > d.max);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: _fields[d.key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: d.label,
          hintText: 'ex. ${d.example.toStringAsFixed(0)}',
          suffixText: 'cm',
          border: const OutlineInputBorder(),
          helperText: unusual
              ? 'Valoare neobișnuită. Verifică măsura (de obicei '
                  '${d.min.toStringAsFixed(0)}–${d.max.toStringAsFixed(0)} cm).'
              : null,
          helperStyle: TextStyle(color: Theme.of(context).colorScheme.tertiary),
          suffixIcon: IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Cum se măsoară',
            onPressed: () => _showGuide(d),
          ),
        ),
        validator: (v) {
          final x = _parse(v ?? '');
          if (x == null) return 'Introdu un număr';
          if (x <= 0 || x > 250) return 'Valoarea nu pare corectă';
          return null;
        },
      ),
    );
  }
}
