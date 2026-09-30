import '../navigation/coach_route_observer.dart';

import 'dart:async';

import 'package:app_links/app_links.dart';

import '../tournaments/kata_payment_return_screen.dart';
import '../education/education_video_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../account/agreements_screen.dart';
import '../students/student_profile_setup_screen.dart';
import '../auth/auth_session.dart';
import '../auth/login_screen.dart';
import '../auth/registration_screen.dart';
import '../auth/restore_account_dialog.dart';
import '../auth/session_controller.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_navigation.dart';
import '../navigation/coach_shell.dart';
import '../theme/app_theme.dart';
import 'launch_splash.dart';

class KarateRatingApp extends StatefulWidget {
  const KarateRatingApp({super.key, required this.prefs, this.apiFactory});
  final SharedPreferences prefs;
  final ApiClient Function(AuthSession session)? apiFactory;

  @override
  State<KarateRatingApp> createState() => _KarateRatingAppState();
}

class _KarateRatingAppState extends State<KarateRatingApp>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _launch;
  bool _launchFinished = false;
  late final SessionController _auth;
  final _selected = ValueNotifier(CoachNavItem.feed);
  AppLocale _locale = AppLocale.ru;
  bool _shellStarted = false;
  var _navigator = GlobalKey<NavigatorState>();
  int _navigatorGeneration = 0;
  StreamSubscription<Uri>? _links;
  String? _pendingPayment;
  String? _openedPayment;
  int? _pendingEducation;

  AppStrings get _strings => AppStrings(_locale);

  @override
  void initState() {
    super.initState();
    _launch =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1000),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() => _launchFinished = true);
            _openPayment();
          }
        });
    _launch.forward();
    WidgetsBinding.instance.addObserver(this);
    _locale = widget.prefs.getString('app_locale') == 'en'
        ? AppLocale.en
        : AppLocale.ru;
    final session = AuthSession(widget.prefs);
    final api = widget.apiFactory?.call(session) ?? ApiClient(session: session);
    api.locale = _locale;
    _auth = SessionController(session, api);
    _auth.addListener(_sessionChanged);
    _auth.restore();
    if (widget.apiFactory == null) {
      final links = AppLinks();
      _links = links.uriLinkStream.listen(_paymentLink, onError: (_) {});
      links
          .getInitialLink()
          .then((uri) {
            if (uri != null && mounted) _paymentLink(uri);
          })
          .catchError((_) {});
    }
  }

  void _sessionChanged() {
    if (_navigatorGeneration != _auth.generation) {
      _navigatorGeneration = _auth.generation;
      _navigator = GlobalKey<NavigatorState>();
      _shellStarted = false;
    }
    if (_auth.status == SessionStatus.signedOut) {
      _selected.value = CoachNavItem.feed;
      _shellStarted = false;
    }
    if (_auth.status == SessionStatus.authorized &&
        !_auth.agreementsRequired &&
        !_auth.profileSetupRequired) {
      if (!_shellStarted) {
        _selected.value = _auth.api.isJudge
            ? CoachNavItem.judging
            : _auth.api.isMaster
            ? CoachNavItem.reviews
            : _auth.api.isStudent
            ? CoachNavItem.profile
            : CoachNavItem.feed;
      }
      _shellStarted = true;
    }
    if (mounted) {
      setState(() {});
      _openPayment();
    }
  }

  void _paymentLink(Uri uri) {
    if (uri.scheme == 'karaterating' &&
        uri.host == 'education' &&
        uri.pathSegments.length == 1) {
      final id = int.tryParse(uri.pathSegments.single);
      if (id != null && id > 0) {
        _pendingEducation = id;
        _openPayment();
      }
      return;
    }
    final id = kataPaymentId(uri);
    if (id == null || id == _openedPayment) return;
    _pendingPayment = id;
    _openPayment();
  }

  void _openPayment() {
    if (!_launchFinished) return;
    if (_auth.profileSetupRequired) return;
    if (_pendingEducation != null &&
        _auth.status == SessionStatus.authorized &&
        !_auth.agreementsRequired &&
        _auth.api.isStudent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _pendingEducation == null ||
            !_auth.api.isStudent ||
            _auth.agreementsRequired ||
            _auth.status != SessionStatus.authorized) {
          return;
        }
        final nav = _navigator.currentState;
        if (nav == null) return;
        final id = _pendingEducation!;
        _pendingEducation = null;
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => EducationVideoScreen(
              api: _auth.api,
              strings: _strings,
              video: const {},
              workId: id,
            ),
          ),
        );
      });
    }
    if (_pendingPayment == null ||
        _auth.status != SessionStatus.authorized ||
        !_auth.api.menuAvailable('payments') ||
        _auth.agreementsRequired) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _pendingPayment == null ||
          _auth.status != SessionStatus.authorized ||
          _auth.agreementsRequired) {
        return;
      }
      final nav = _navigator.currentState;
      if (nav == null) return;
      final id = _pendingPayment!;
      _pendingPayment = null;
      _openedPayment = id;
      nav
          .push(
            MaterialPageRoute<void>(
              builder: (_) => KataPaymentReturnScreen(
                api: _auth.api,
                strings: _strings,
                applicationId: id,
              ),
            ),
          )
          .whenComplete(() => _openedPayment = null);
    });
  }

  bool get _requiresConsent =>
      _auth.status == SessionStatus.authorized && _auth.agreementsRequired;

  @override
  Future<bool> didPopRoute() async =>
      _requiresConsent || _auth.profileSetupRequired;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _auth.revalidate();
  }

  @override
  void dispose() {
    _launch.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _links?.cancel();
    _auth.removeListener(_sessionChanged);
    _auth.dispose();
    _selected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey(_auth.generation),
      navigatorKey: _navigator,
      navigatorObservers: [coachRouteObserver],
      debugShowCheckedModeBanner: false,
      title: _strings.appTitle,
      locale: Locale(_locale.name),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) => CoachNavigation(
        selected: _selected,
        onLogout: _auth.logout,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              excluding:
                  !_launchFinished ||
                  _requiresConsent ||
                  _auth.profileSetupRequired,
              child: IgnorePointer(
                ignoring:
                    !_launchFinished ||
                    _requiresConsent ||
                    _auth.profileSetupRequired,
                child: child!,
              ),
            ),
            if (_auth.status == SessionStatus.authorized &&
                _auth.profileSetupRequired &&
                !_auth.agreementsRequired)
              Positioned.fill(
                child: HeroControllerScope.none(
                  child: Navigator(
                    key: ValueKey('profile-setup-${_auth.generation}'),
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => StudentProfileSetupScreen(
                        api: _auth.api,
                        strings: _strings,
                        onCompleted: _auth.refreshIdentity,
                        onLogout: _auth.logout,
                      ),
                    ),
                  ),
                ),
              ),
            if (_auth.status == SessionStatus.authorized &&
                _auth.agreementsRequired)
              Positioned.fill(
                child: HeroControllerScope.none(
                  child: Navigator(
                    key: ValueKey('consent-${_auth.generation}'),
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => AgreementsScreen(
                        api: _auth.api,
                        strings: _strings,
                        gate: true,
                        onCompleted: _auth.revalidate,
                        onLogout: _auth.logout,
                      ),
                    ),
                  ),
                ),
              ),
            if (!_launchFinished) const Positioned.fill(child: LaunchSplash()),
          ],
        ),
      ),
      home: switch (_auth.status) {
        SessionStatus.authorized =>
          !_shellStarted
              ? const SizedBox.shrink()
              : CoachShell(strings: _strings, api: _auth.api),
        SessionStatus.signedOut => LoginScreen(
          strings: _strings,
          locale: _locale,
          onLocaleChanged: (locale) {
            _auth.api.locale = locale;
            unawaited(widget.prefs.setString('app_locale', locale.name));
            setState(() => _locale = locale);
          },
          onSignIn: (email, password, remember) =>
              _auth.signIn(email, password, remember, _locale),
          onRegister: (student) => _navigator.currentState!.push<String>(
            MaterialPageRoute(
              builder: (_) => RegistrationScreen(
                api: _auth.api,
                strings: _strings,
                student: student,
                onRegistered: student ? _auth.acceptSession : null,
              ),
            ),
          ),
          recoveryUri: _auth.api.recoveryWebUri(),
          onRestore: () {
            final context = _navigator.currentContext;
            if (context != null) {
              restoreAccountDialog(context, _auth.api, _strings);
            }
          },
        ),
        SessionStatus.restoring => const LaunchSplash(),
        SessionStatus.unavailable => Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _strings.sessionCheckFailed,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _auth.restore,
                      child: Text(_strings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      },
    );
  }
}
