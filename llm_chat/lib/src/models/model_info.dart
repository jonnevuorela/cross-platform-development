class ModelInfo {
  const ModelInfo({
    required this.id,
    required this.label,
    required this.path,
    required this.index,
  });

  final String id;
  final String label;
  final String path;
  final int index;

  @override
  bool operator ==(Object other) {
    return other is ModelInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
