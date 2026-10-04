import 'json.dart';

class Hall {
  const Hall({required this.id, required this.name, required this.layoutId, required this.format});

  final String id;
  final String name;
  final String layoutId;
  final String format;

  factory Hall.fromMap(String id, Map<String, dynamic> map) => Hall(
    id: id,
    name: asString(map['name'], id),
    layoutId: asString(map['layoutId'], 'classic'),
    format: asString(map['format'], '2D'),
  );

  Map<String, dynamic> toMap() => {'name': name, 'layoutId': layoutId, 'format': format};
}

class Cinema {
  const Cinema({
    required this.id,
    required this.name,
    required this.city,
    required this.area,
    required this.address,
    required this.formats,
    required this.halls,
  });

  final String id;
  final String name;
  final String city;
  final String area;
  final String address;
  final List<String> formats;
  final Map<String, Hall> halls;

  factory Cinema.fromMap(String id, Map<String, dynamic> map) {
    final halls = asMap(map['halls']);
    return Cinema(
      id: id,
      name: asString(map['name'], id),
      city: asString(map['city']),
      area: asString(map['area']),
      address: asString(map['address']),
      formats: asStringList(map['formats']),
      halls: {for (final e in halls.entries) e.key: Hall.fromMap(e.key, asMap(e.value))},
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'city': city,
    'area': area,
    'address': address,
    'formats': formats,
    'halls': {for (final e in halls.entries) e.key: e.value.toMap()},
  };

  @override
  bool operator ==(Object other) => other is Cinema && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
