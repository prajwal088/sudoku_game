class LevelData {
  final Duration time;
  final int stars;
  final int hintsUsed;

  LevelData({required this.time, required this.stars, required this.hintsUsed});

  Map<String, dynamic> toJson() {
    return {
      'time': time.inSeconds,
      'stars': stars,
      'hintsUsed': hintsUsed,
    };
  }

  factory LevelData.fromJson(Map<String, dynamic> json) {
    return LevelData(
      time: Duration(seconds: json['time']),
      stars: json['stars'],
      hintsUsed: json['hintsUsed'],
    );
  }
}