class ModelInfo {
  const ModelInfo({
    required this.id,
    required this.label,
    required this.groupLabel,
    required this.isSmart,
    required this.path,
    required this.tokenizerPath,
    required this.index,
    required this.numLayers,
    required this.numKvHeads,
    required this.headDim,
    required this.vocabSize,
    required this.eosTokenId,
    required this.bosTokenId,
    required this.roleStartId,
    required this.roleEndId,
    required this.turnEndId,
  });

  final String id;
  final String label;
  final String groupLabel;
  final bool isSmart;
  final String path;
  final String tokenizerPath;
  final int index;
  final int numLayers;
  final int numKvHeads;
  final int headDim;
  final int vocabSize;
  final int eosTokenId;
  final int bosTokenId;
  final int roleStartId;
  final int roleEndId;
  final int turnEndId;

  @override
  bool operator ==(Object other) {
    return other is ModelInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
