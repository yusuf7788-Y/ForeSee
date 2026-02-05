import 'dart:async';

class RefreshService {
  static final RefreshService instance = RefreshService._internal();
  RefreshService._internal();

  final _refreshController = StreamController<void>.broadcast();
  Stream<void> get refreshStream => _refreshController.stream;

  void triggerRefresh() {
    _refreshController.add(null);
  }

  void dispose() {
    _refreshController.close();
  }
}
