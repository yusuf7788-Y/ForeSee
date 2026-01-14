import 'package:foresee/screens/theme_screen.dart';
import 'package:foresee/screens/cookie_screen.dart';
import 'package:foresee/screens/search_screen.dart';

void main() {
  print('Testing imports...');
  
  // Test SearchScreen
  final searchScreen = SearchScreen();
  print('SearchScreen created: ${searchScreen.runtimeType}');
  
  // Test ThemeScreen  
  final themeScreen = ThemeScreen();
  print('ThemeScreen created: ${themeScreen.runtimeType}');
  
  // Test CookieScreen
  final cookieScreen = CookieScreen();
  print('CookieScreen created: ${cookieScreen.runtimeType}');
  
  print('All imports successful!');
}
