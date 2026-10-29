import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../game_events.dart';

/// Loads the player's XP and level and rebuilds when it arrives, and again
/// after every finished round. [builder] gets null until the first load succeeds
/// (or if it fails), so screens can show the rest of their content right away
/// and add the level details when they're ready.
class ProgressBuilder extends StatefulWidget {
  const ProgressBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Progress? progress) builder;

  @override
  State<ProgressBuilder> createState() => _ProgressBuilderState();
}

class _ProgressBuilderState extends State<ProgressBuilder> {
  Progress? _progress;
  late final GameEvents _events = context.read<GameEvents>();

  @override
  void initState() {
    super.initState();
    _events.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _events.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final progress = await context.read<ApiClient>().progress();
      if (mounted) setState(() => _progress = progress);
    } catch (_) {
      // Network or unexpected data: keep whatever was shown before. The level
      // line is a nice-to-have, so it never takes the screen down with it.
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _progress);
}
