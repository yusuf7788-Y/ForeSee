class HomeWidgetService {
  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  Future<void> updateAllWidgets() async {}
  Future<void> updateRecapWidget() async {}
  Future<void> updateInputWidget() async {}
  Future<void> updateStatsWidget() async {}
}
