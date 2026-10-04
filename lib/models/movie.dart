import 'json.dart';

enum MovieStatus {
  nowShowing('now_showing'),
  comingSoon('coming_soon');

  const MovieStatus(this.key);
  final String key;

  static MovieStatus parse(Object? value) =>
      value == MovieStatus.comingSoon.key ? MovieStatus.comingSoon : MovieStatus.nowShowing;
}

class CastMember {
  const CastMember({required this.name, required this.character, this.photoUrl});

  final String name;
  final String character;
  final String? photoUrl;

  factory CastMember.fromMap(Map<String, dynamic> map) => CastMember(
    name: asString(map['name']),
    character: asString(map['character']),
    photoUrl: asStringOrNull(map['photoUrl']),
  );

  Map<String, dynamic> toMap() => {'name': name, 'character': character, if (photoUrl != null) 'photoUrl': photoUrl};
}

class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genres,
    required this.synopsis,
    required this.ageRating,
    required this.posterUrl,
    required this.backdropUrl,
    required this.cast,
    required this.status,
    required this.accentHex,
    this.rating,
    this.durationMin,
    this.releaseDate,
    this.featured = false,
    this.tag,
  });

  final String id;
  final String title;
  final List<String> genres;
  final String synopsis;
  final String ageRating;
  final String posterUrl;
  final String backdropUrl;
  final List<CastMember> cast;
  final MovieStatus status;
  final String accentHex;
  final double? rating;
  final int? durationMin;
  final DateTime? releaseDate;
  final bool featured;

  /// Optional marketing label, e.g. "IMAX Re-release".
  final String? tag;

  bool get isNowShowing => status == MovieStatus.nowShowing;
  bool get isComingSoon => status == MovieStatus.comingSoon;

  factory Movie.fromMap(String id, Map<String, dynamic> map) {
    final release = asStringOrNull(map['releaseDate']);
    return Movie(
      id: id,
      title: asString(map['title'], 'Untitled'),
      genres: asStringList(map['genres']),
      synopsis: asString(map['synopsis']),
      ageRating: asString(map['ageRating'], 'TBC'),
      posterUrl: asString(map['posterUrl']),
      backdropUrl: asString(map['backdropUrl']),
      cast: asList(map['cast']).map((e) => CastMember.fromMap(asMap(e))).toList(),
      status: MovieStatus.parse(map['status']),
      accentHex: asString(map['accentHex'], '#FF6B5A'),
      rating: asDoubleOrNull(map['rating']),
      durationMin: asIntOrNull(map['durationMin']),
      releaseDate: release == null ? null : DateTime.tryParse(release),
      featured: asBool(map['featured']),
      tag: asStringOrNull(map['tag']),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'genres': genres,
    'synopsis': synopsis,
    'ageRating': ageRating,
    'posterUrl': posterUrl,
    'backdropUrl': backdropUrl,
    'cast': cast.map((c) => c.toMap()).toList(),
    'status': status.key,
    'accentHex': accentHex,
    if (rating != null) 'rating': rating,
    if (durationMin != null) 'durationMin': durationMin,
    if (releaseDate != null) 'releaseDate': releaseDate!.toIso8601String().substring(0, 10),
    'featured': featured,
    if (tag != null) 'tag': tag,
  };

  @override
  bool operator ==(Object other) => other is Movie && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
