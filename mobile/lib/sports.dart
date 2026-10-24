/// How each sport is shown in the app: a friendly name, its ball icon and a short
/// blurb. The API's sport names (e.g. "NFL") stay as they are in the database; this
/// only changes what players see (e.g. "Football").
class SportStyle {
  const SportStyle({
    required this.label,
    required this.ball,
    required this.blurb,
  });

  /// The name shown in the app.
  final String label;

  /// Name of the icon in assets/balls/.
  final String ball;
  final String blurb;

  String get asset => 'assets/balls/$ball.png';

  static const _football = SportStyle(
    label: 'Football',
    ball: 'football',
    blurb: 'History, records & players',
  );
  static const _soccer = SportStyle(
    label: 'Soccer',
    ball: 'soccer',
    blurb: 'Top 5 leagues & internationals',
  );
  static const _basketball = SportStyle(
    label: 'Basketball',
    ball: 'basketball',
    blurb: 'History, records & players',
  );
  static const _baseball = SportStyle(
    label: 'Baseball',
    ball: 'baseball',
    blurb: 'History, records & players',
  );
  static const _hockey = SportStyle(
    label: 'Hockey',
    ball: 'hockey',
    blurb: 'History, records & players',
  );

  /// Looked up by the API's sport name or by the display label.
  static const _byName = {
    'NFL': _football,
    'Football': _football,
    'Soccer': _soccer,
    'NBA': _basketball,
    'Basketball': _basketball,
    'MLB': _baseball,
    'Baseball': _baseball,
    'NHL': _hockey,
    'Hockey': _hockey,
  };

  /// Shown on Home as "coming soon" until the API has a sport with the same label.
  static const comingSoon = [_basketball, _baseball, _hockey];

  static SportStyle of(String name) =>
      _byName[name] ??
      SportStyle(label: name, ball: 'soccer', blurb: 'Test your knowledge');
}
