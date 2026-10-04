import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _baht = NumberFormat.currency(locale: 'en_US', symbol: '฿', decimalDigits: 0);
  static final _dayShort = DateFormat('EEE');
  static final _dayNum = DateFormat('d');
  static final _monthShort = DateFormat('MMM');
  static final _longDate = DateFormat('EEE, d MMM yyyy');
  static final _mediumDate = DateFormat('EEE, d MMM');
  static final _releaseDate = DateFormat('d MMM yyyy');
  static final _monthYear = DateFormat('MMMM yyyy');
  static final _isoDate = DateFormat('yyyy-MM-dd');

  static String baht(num value) => _baht.format(value);

  static String duration(int? minutes) {
    if (minutes == null || minutes <= 0) return 'TBA';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static String isoDate(DateTime d) => _isoDate.format(d);
  static DateTime parseIsoDate(String s) => _isoDate.parse(s);

  static String dayShort(DateTime d) => _dayShort.format(d);
  static String dayNumber(DateTime d) => _dayNum.format(d);
  static String monthShort(DateTime d) => _monthShort.format(d);
  static String longDate(DateTime d) => _longDate.format(d);
  static String mediumDate(DateTime d) => _mediumDate.format(d);
  static String releaseDate(DateTime d) => _releaseDate.format(d);
  static String monthYear(DateTime d) => _monthYear.format(d);

  /// "Today", "Tomorrow" or "Wed".
  static String relativeDay(DateTime d, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final diff = _dateOnly(d).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return dayShort(d);
  }

  /// "Starts in 2 days", "Starts in 3h", "Started".
  static String countdown(DateTime start, {DateTime? now}) {
    final diff = start.difference(now ?? DateTime.now());
    if (diff.isNegative) return 'Screened';
    if (diff.inDays >= 2) return 'In ${diff.inDays} days';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inHours >= 1) return 'In ${diff.inHours}h ${diff.inMinutes % 60}m';
    return 'In ${diff.inMinutes} min';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return _firstChar(parts.first).toUpperCase();
    return (_firstChar(parts.first) + _firstChar(parts.last)).toUpperCase();
  }

  static String seatList(Iterable<String> seats) => sortSeats(seats).join(', ');

  /// Natural seat ordering: A2 < A10 < B1.
  static List<String> sortSeats(Iterable<String> seats) {
    final list = seats.toList();
    list.sort(compareSeats);
    return list;
  }

  static int compareSeats(String a, String b) {
    final rowCompare = a.substring(0, 1).compareTo(b.substring(0, 1));
    if (rowCompare != 0) return rowCompare;
    return (int.tryParse(a.substring(1)) ?? 0).compareTo(int.tryParse(b.substring(1)) ?? 0);
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _firstChar(String s) => String.fromCharCodes(s.runes.take(1));
