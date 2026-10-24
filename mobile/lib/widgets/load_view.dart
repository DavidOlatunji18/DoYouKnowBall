import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../screens/splash_screen.dart';
import '../theme.dart';
import 'chunky_button.dart';

/// Loads data and shows a spinner while waiting, a friendly message with a
/// "Try again" button if it fails, or [builder]'s content once it arrives.
/// Reloads whenever [reloadWhen] fires, or when [LoadViewState.reload] is called
/// (e.g. from pull-to-refresh).
class LoadView<T> extends StatefulWidget {
  const LoadView({
    super.key,
    required this.load,
    required this.builder,
    this.reloadWhen,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final Listenable? reloadWhen;

  @override
  State<LoadView<T>> createState() => LoadViewState<T>();
}

class LoadViewState<T> extends State<LoadView<T>> {
  late Future<T> _future = widget.load();

  /// Loads again. A pull-to-refresh keeps showing the current content while it
  /// works; "Try again" and [LoadView.reloadWhen] show the spinner.
  Future<void> reload({bool quiet = false}) {
    final next = widget.load();
    if (quiet) {
      // Swap in the new data only once it has arrived.
      return next.then(
        (_) {
          if (mounted) setState(() => _future = next);
        },
        onError: (Object _) {
          if (mounted) setState(() => _future = next);
        },
      );
    }
    // Block body: an arrow here would return the Future, which setState rejects.
    setState(() {
      _future = next;
    });
    return next.then((_) {}, onError: (Object _) {});
  }

  void _retry() => reload();

  @override
  void initState() {
    super.initState();
    widget.reloadWhen?.addListener(_retry);
  }

  @override
  void didUpdateWidget(LoadView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadWhen != widget.reloadWhen) {
      oldWidget.reloadWhen?.removeListener(_retry);
      widget.reloadWhen?.addListener(_retry);
    }
  }

  @override
  void dispose() {
    widget.reloadWhen?.removeListener(_retry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        // While a retry is loading, the snapshot still carries the old error, so
        // check for "still waiting" first.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: SpiralLoader(size: 40));
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return _ErrorState(
            message: error is ApiError ? error.message : ApiError.unknown,
            onRetry: _retry,
          );
        }
        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.muted,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: appFont(
                16,
                weight: 600,
                color: AppColors.muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 200,
              child: ChunkyButton(label: 'Try again', onPressed: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}
