import 'bodice.dart';
import 'circle_skirt.dart';
import 'garment.dart';
import 'long_dress.dart';
import 'straight_skirt.dart';
import 'trousers.dart';
import 'tshirt.dart';

/// Toate modelele disponibile în aplicație, în ordinea din listă.
const kGarments = <Garment>[
  StraightSkirt(),
  CircleSkirt(),
  TShirt(),
  BasicBodice(),
  LongDress(),
  Trousers(),
];
