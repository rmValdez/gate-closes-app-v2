/// Path constants for go_router. Reference these instead of raw strings.
class RouteNames {
  RouteNames._();

  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String home = '/';
  static const String worldMap = '/worldMap';
  static const String feed = '/feed';
  static const String createEcho = '/feed/create';
  static const String echoThread = '/feed/thread/:echoId';
  static String echoThreadFor(String echoId) => '/feed/thread/$echoId';
  static const String airportSearch = '/feed/airport-search';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String changePassword = '/profile/change-password';
  static const String addBoardingPass = '/add-boarding-pass';
}
