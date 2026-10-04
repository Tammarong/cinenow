import 'json.dart';

enum SeatType {
  standard('standard', 'Standard'),
  deluxe('deluxe', 'Deluxe');

  const SeatType(this.key, this.label);
  final String key;
  final String label;

  static SeatType parse(Object? value) => value == SeatType.deluxe.key ? SeatType.deluxe : SeatType.standard;
}

class SeatRow {
  const SeatRow({required this.label, required this.seats, required this.type, this.aisleAfter = const []});

  final String label;
  final int seats;
  final SeatType type;

  /// Seat numbers after which an aisle gap is drawn.
  final List<int> aisleAfter;

  List<String> get seatIds => [for (var i = 1; i <= seats; i++) '$label$i'];

  factory SeatRow.fromMap(Map<String, dynamic> map) => SeatRow(
    label: asString(map['label'], 'A'),
    seats: asInt(map['seats'], 10),
    type: SeatType.parse(map['type']),
    aisleAfter: asList(map['aisleAfter']).map(asInt).toList(),
  );

  Map<String, dynamic> toMap() => {'label': label, 'seats': seats, 'type': type.key, 'aisleAfter': aisleAfter};
}

class SeatLayout {
  const SeatLayout({required this.id, required this.name, required this.rows});

  final String id;
  final String name;
  final List<SeatRow> rows;

  int get capacity => rows.fold(0, (sum, r) => sum + r.seats);
  int get maxSeatsInRow => rows.fold(0, (m, r) => r.seats > m ? r.seats : m);
  Iterable<String> get allSeatIds => rows.expand((r) => r.seatIds);

  SeatType typeOf(String seatId) {
    final row = rows.where((r) => seatId.startsWith(r.label) && int.tryParse(seatId.substring(r.label.length)) != null);
    return row.isEmpty ? SeatType.standard : row.first.type;
  }

  factory SeatLayout.fromMap(String id, Map<String, dynamic> map) => SeatLayout(
    id: id,
    name: asString(map['name'], id),
    rows: asList(map['rows']).map((e) => SeatRow.fromMap(asMap(e))).toList(),
  );

  Map<String, dynamic> toMap() => {'name': name, 'rows': rows.map((r) => r.toMap()).toList()};
}
