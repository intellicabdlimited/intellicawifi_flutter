/// Persisted alert bounds for a single metric (concentration base id, `relativeHumidity`, or `temperature`).
class StoredMinMax {
  final double min;
  final double max;

  const StoredMinMax({required this.min, required this.max});

  Map<String, dynamic> toJson() => {'min': min, 'max': max};

  factory StoredMinMax.fromJson(Map<String, dynamic> j) {
    return StoredMinMax(
      min: (j['min'] as num).toDouble(),
      max: (j['max'] as num).toDouble(),
    );
  }
}
