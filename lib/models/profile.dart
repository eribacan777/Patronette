import 'measurements.dart';

/// Un profil: o persoană și măsurile ei.
class Profile {
  Profile({required this.id, required this.name, required this.values});

  final String id;
  final String name;
  final Measurements values;

  Profile copyWith({String? name, Measurements? values}) =>
      Profile(id: id, name: name ?? this.name, values: values ?? this.values);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'values': values};

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        values: (json['values'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      );
}
