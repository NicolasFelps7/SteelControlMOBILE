// Isola respostas por sessão e impede que snapshots antigos restaurem exclusões.
class MachineSyncScope {
  int _generation = 0;
  final Set<int> _removed = {};
  int get generation => _generation;
  bool accepts(int generation) => generation == _generation;
  bool isRemoved(int id) => _removed.contains(id);
  void remove(int id) => _removed.add(id);
  void reset() {
    _generation++;
    _removed.clear();
  }
}
