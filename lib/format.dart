/// Un număr de centimetri scris românește, cu virgulă: „1,5”, „60”.
String fmtCm(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceAll('.', ',');
