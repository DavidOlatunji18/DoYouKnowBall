import 'package:flutter/foundation.dart';

/// Announces that the player finished a round, so screens showing scores
/// (Profile's stats and recent games, the leaderboard) can reload.
class GameEvents extends ChangeNotifier {
  void gameFinished() => notifyListeners();
}
