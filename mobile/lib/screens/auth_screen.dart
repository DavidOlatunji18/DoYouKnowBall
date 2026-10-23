import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../auth/password_rules.dart';
import '../auth/session.dart';
import '../auth/username_rules.dart';
import '../theme.dart';
import '../widgets/auth_field.dart';
import '../widgets/chunky_button.dart';
import '../widgets/error_banner.dart';
import '../widgets/marker_headline.dart';
import '../widgets/mode_toggle.dart';

enum AuthMode { signUp, logIn }

/// Sign up and Log in share one screen; the toggle switches between them in place.
/// On success the session is saved and the router moves the player to Home.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.initialMode});

  final AuthMode initialMode;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthMode _mode = widget.initialMode;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  Map<String, String> _fieldErrors = {};
  String? _serverError;
  int _shakeKey = 0;
  bool _loading = false;

  bool get _signUp => _mode == AuthMode.signUp;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Both corner balls are ready before the first toggle (normally already cached by the splash).
    for (final name in _SpinningBall.assets) {
      precacheImage(AssetImage('assets/balls/$name.png'), context);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    if (mode == _mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _mode = mode;
      _fieldErrors = {};
      _serverError = null;
    });
  }

  void _clearError(String field) {
    if (_fieldErrors.containsKey(field) || _serverError != null) {
      setState(() {
        _fieldErrors = {..._fieldErrors}..remove(field);
        _serverError = null;
      });
    }
  }

  /// Mirrors the API's rules so most mistakes are caught before a network call.
  Map<String, String> _validate() {
    final errors = <String, String>{};
    final usernameProblem = _signUp ? UsernameRules.validate(_name.text) : null;
    if (usernameProblem != null) errors['name'] = usernameProblem;
    final login = _email.text.trim();
    if (_signUp && !AuthScreen._emailPattern.hasMatch(login)) {
      errors['email'] = 'Enter a valid email address.';
    } else if (!_signUp && login.isEmpty) {
      errors['email'] = 'Enter your email or username.';
    }
    final passwordProblem = _signUp
        ? PasswordRules.validate(
            _password.text,
            username: _name.text,
            email: login,
          )
        : (_password.text.isEmpty ? 'Enter your password.' : null);
    if (passwordProblem != null) errors['password'] = passwordProblem;
    return errors;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final errors = _validate();
    setState(() {
      _fieldErrors = errors;
      _serverError = null;
    });
    if (errors.isNotEmpty) return;

    final api = context.read<ApiClient>();
    final session = context.read<Session>();
    setState(() => _loading = true);
    try {
      final result = _signUp
          ? await api.register(
              email: _email.text.trim(),
              password: _password.text,
              displayName: _name.text,
            )
          : await api.login(
              emailOrUsername: _email.text.trim(),
              password: _password.text,
            );
      TextInput.finishAutofillContext();
      await session.signIn(result);
    } on ApiError catch (e) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _serverError = e.message;
        _shakeKey++;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: AutofillGroup(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CircleBackButton(
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/welcome'),
                      ),
                      const Spacer(),
                      _SpinningBall(
                        asset: _signUp
                            ? _SpinningBall.assets.first
                            : _SpinningBall.assets.last,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: _fadeSlide,
                    child: _signUp
                        ? const MarkerHeadline(
                            key: ValueKey('signup'),
                            lead: 'Join the',
                            marked: 'league.',
                          )
                        : const MarkerHeadline(
                            key: ValueKey('login'),
                            lead: 'Welcome',
                            marked: 'back.',
                          ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: _fadeSlide,
                    child: Text(
                      _signUp
                          ? 'Create your account to play rounds and climb the leaderboard.'
                          : 'Log in and prove you still know ball.',
                      key: ValueKey(_mode),
                      style: appFont(
                        16.5,
                        weight: 500,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ModeToggle(
                    options: const ['Sign up', 'Log in'],
                    selected: _signUp ? 0 : 1,
                    onChanged: (i) =>
                        _switchMode(i == 0 ? AuthMode.signUp : AuthMode.logIn),
                  ),
                  const SizedBox(height: 26),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _signUp
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: AuthField(
                              label: 'Username',
                              hint: 'kobe.bryant24',
                              prefixText: '@',
                              controller: _name,
                              errorText: _fieldErrors['name'],
                              autofillHints: const [AutofillHints.newUsername],
                              inputFormatters: UsernameRules.inputFormatters,
                              onChanged: (_) => _clearError('name'),
                              footer: _fieldErrors['name'] == null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        UsernameRules.hint,
                                        style: appFont(
                                          13,
                                          weight: 500,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  AuthField(
                    label: _signUp ? 'Email' : 'Email or username',
                    hint: _signUp
                        ? 'you@example.com'
                        : 'kobe24 or you@example.com',
                    controller: _email,
                    errorText: _fieldErrors['email'],
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: _signUp
                        ? const [AutofillHints.email]
                        : const [AutofillHints.username, AutofillHints.email],
                    onChanged: (_) => _clearError('email'),
                  ),
                  const SizedBox(height: 20),
                  AuthField(
                    label: 'Password',
                    hint: _signUp
                        ? 'At least ${PasswordRules.minLength} characters'
                        : 'Your password',
                    controller: _password,
                    errorText: _fieldErrors['password'],
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: [
                      _signUp
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    onChanged: (_) => _clearError('password'),
                    onSubmitted: (_) => _submit(),
                    footer: _signUp && _fieldErrors['password'] == null
                        ? _PasswordCheck(
                            password: _password,
                            username: _name,
                            email: _email,
                          )
                        : null,
                  ),
                  const SizedBox(height: 26),
                  if (_serverError != null) ...[
                    ErrorBanner(message: _serverError!, shakeKey: _shakeKey),
                    const SizedBox(height: 18),
                  ],
                  ChunkyButton(
                    label: _signUp ? 'Create account' : 'Log in',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _signUp ? 'Already have an account?' : 'New here?',
                          style: appFont(15, color: AppColors.muted),
                        ),
                        TextButton(
                          onPressed: () => _switchMode(
                            _signUp ? AuthMode.logIn : AuthMode.signUp,
                          ),
                          child: Text(_signUp ? 'Log in' : 'Create an account'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _fadeSlide(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(2, 2)),
            ],
          ),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
        ),
      ),
    );
  }
}

/// A ball in the corner that spins in each time the mode changes.
class _SpinningBall extends StatelessWidget {
  const _SpinningBall({required this.asset});

  /// Sign up shows the soccer ball, Log in the football.
  static const assets = ['soccer', 'football'];

  final String asset;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) => RotationTransition(
        turns: Tween(begin: -0.5, end: 0.0).animate(animation),
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: Image.asset(
        'assets/balls/$asset.png',
        key: ValueKey(asset),
        width: 46,
        height: 46,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// Live checklist under the sign-up password field: length first, then whether the
/// password is hard to guess (not common, not a simple run, no username or email).
class _PasswordCheck extends StatelessWidget {
  const _PasswordCheck({
    required this.password,
    required this.username,
    required this.email,
  });

  final TextEditingController password;
  final TextEditingController username;
  final TextEditingController email;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([password, username, email]),
      builder: (context, _) {
        final text = password.text;
        final longEnough = text.length >= PasswordRules.minLength;
        final problem = longEnough
            ? PasswordRules.validate(
                text,
                username: username.text,
                email: email.text.trim(),
              )
            : null;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CheckRow(
                ok: longEnough,
                label: '${PasswordRules.minLength}+ characters',
              ),
              const SizedBox(height: 6),
              _CheckRow(
                ok: longEnough && problem == null,
                label: problem ?? 'Hard to guess',
                warning: problem != null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.ok,
    required this.label,
    this.warning = false,
  });

  final bool ok;
  final String label;

  /// Shown in red with a cross when a rule is actively broken.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: ok
                ? AppColors.green
                : (warning ? AppColors.dangerSoft : AppColors.card),
            shape: BoxShape.circle,
            border: Border.all(
              color: warning ? AppColors.danger : AppColors.ink,
              width: 1.6,
            ),
          ),
          child: ok || warning
              ? Icon(
                  ok ? Icons.check_rounded : Icons.close_rounded,
                  size: 14,
                  color: warning ? AppColors.danger : AppColors.ink,
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: appFont(
              13.5,
              weight: 600,
              color: warning
                  ? AppColors.danger
                  : (ok ? AppColors.ink : AppColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}
