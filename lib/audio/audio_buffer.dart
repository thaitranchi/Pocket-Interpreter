class AudioBuffer {
  final List<int> _buffer = [];

  void add(List<int> chunk) {
    _buffer.addAll(chunk);
  }

  List<int> toList() => List.from(_buffer);

  void clear() => _buffer.clear();

  int get length => _buffer.length;

  bool get isEmpty => _buffer.isEmpty;
}
