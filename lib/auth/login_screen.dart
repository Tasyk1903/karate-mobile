import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.strings,
    required this.locale,
    required this.onLocaleChanged,
    required this.onSignIn,
    required this.onRegister,
    required this.recoveryUri,
    this.onRestore,
  });

  final Future<String?> Function(bool student) onRegister;
  final Uri recoveryUri;
  final VoidCallback? onRestore;
  final AppStrings strings;
  final AppLocale locale;
  final ValueChanged<AppLocale> onLocaleChanged;
  final Future<void> Function(String email, String password, bool remember)
  onSignIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _remember = true;
  var _obscurePassword = true;
  var _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onSignIn(
        _emailController.text.trim(),
        _passwordController.text,
        _remember,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openWeb(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Browser unavailable');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.strings.browserOpenFailed)));
    }
  }

  Future<void> _register() async {
    final student = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(widget.strings.studentRole),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(widget.strings.coach),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (student == null || !mounted) return;
    final email = await widget.onRegister(student);
    if (mounted && email != null) _emailController.text = email;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final usableHeight = size.height - padding.top - padding.bottom;
    final tight = usableHeight < 700;
    final compact = usableHeight < 820 || size.width < 430;
    final logoSize = tight ? 78.0 : (compact ? 104.0 : 138.0);
    final titleSize = tight ? 28.0 : (compact ? 30.0 : 34.0);
    final subtitleSize = tight ? 14.0 : (compact ? 15.0 : 17.0);
    final fieldGap = tight ? 10.0 : 14.0;
    final horizontalPadding = size.width < 390 ? 22.0 : 26.0;
    final languageTop = tight ? 4.0 : (compact ? 8.0 : 18.0);
    final afterLanguage = tight ? 8.0 : (compact ? 14.0 : 28.0);
    final afterLogo = tight ? 14.0 : (compact ? 18.0 : 40.0);
    final afterSubtitle = tight ? 14.0 : (compact ? 18.0 : 36.0);
    final beforeButton = tight ? 10.0 : (compact ? 14.0 : 28.0);
    final signupBottom = tight ? 0.0 : (compact ? 4.0 : 22.0);
    final narrow = size.width < 410;
    final primaryText = AppColors.isDark(context)
        ? AppColors.darkInk
        : AppColors.inkFor(context);
    final secondaryText = AppColors.isDark(context)
        ? AppColors.darkTextMuted
        : AppColors.mutedFor(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppColors.backgroundImage(context), fit: BoxFit.cover),
          Container(color: AppColors.backgroundOverlay(context)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: EdgeInsets.only(top: languageTop),
                          child: _LanguageSwitch(
                            locale: widget.locale,
                            onChanged: widget.onLocaleChanged,
                          ),
                        ),
                      ),
                      SizedBox(height: afterLanguage),
                      _LogoBlock(size: logoSize),
                      SizedBox(height: afterLogo),
                      Text(
                        widget.strings.loginTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                        ).copyWith(color: primaryText, fontSize: titleSize),
                      ),
                      SizedBox(height: tight ? 8 : 12),
                      Text(
                        widget.strings.loginSubtitle,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ).copyWith(
                              color: secondaryText,
                              fontSize: subtitleSize,
                            ),
                      ),
                      SizedBox(height: afterSubtitle),
                      _TextFieldShell(
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return widget.strings.emailRequired;
                            }
                            if (!text.contains('@')) {
                              return widget.strings.invalidEmail;
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: widget.strings.email,
                            prefixIcon: Icon(
                              Icons.mail_outline_rounded,
                              color: AppColors.accentFor(context),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: fieldGap),
                      _TextFieldShell(
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return widget.strings.passwordRequired;
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: widget.strings.password,
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.accentFor(context),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF8C929D),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: fieldGap),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: narrow ? 170 : 210,
                            child: Row(
                              children: [
                                _RememberCheck(
                                  checked: _remember,
                                  onChanged: (value) =>
                                      setState(() => _remember = value),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.strings.rememberMe,
                                    style: TextStyle(
                                      color: primaryText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _openWeb(widget.recoveryUri),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.red,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              widget.strings.forgotPassword,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: beforeButton),
                      SizedBox(
                        width: double.infinity,
                        height: tight ? 50 : (compact ? 54 : 62),
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.red,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.red.withValues(
                              alpha: 0.55,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 12,
                            shadowColor: AppColors.red.withValues(alpha: 0.28),
                          ),
                          child: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.strings.signIn,
                                  style: TextStyle(
                                    fontSize: tight ? 18 : 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: tight ? 8 : (compact ? 12 : 26)),
                      Padding(
                        padding: EdgeInsets.only(bottom: signupBottom),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 0,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              widget.strings.noAccount,
                              style: TextStyle(
                                color: AppColors.mutedFor(context),
                                fontSize: 16,
                              ).copyWith(color: secondaryText),
                            ),
                            TextButton(
                              onPressed: _isSubmitting ? null : _register,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.red,
                              ),
                              child: Text(
                                widget.strings.register,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (widget.onRestore != null)
                              TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : widget.onRestore,
                                child: Text(
                                  widget.strings.restoreAccount,
                                  style: const TextStyle(fontSize: 12),
                                ),
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
        ],
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: EdgeInsets.all(size < 100 ? 10 : 16),
      child: Image.asset('assets/images/kr.jpg', fit: BoxFit.contain),
    );
  }
}

class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch({required this.locale, required this.onChanged});

  final AppLocale locale;
  final ValueChanged<AppLocale> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LanguageButton(
            label: 'RU',
            active: locale == AppLocale.ru,
            onTap: () => onChanged(AppLocale.ru),
          ),
          Container(width: 1, height: 20, color: AppColors.borderFor(context)),
          _LanguageButton(
            label: 'EN',
            active: locale == AppLocale.en,
            onTap: () => onChanged(AppLocale.en),
          ),
        ],
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 54,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceFor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(19),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? AppColors.accentFor(context)
                : AppColors.mutedFor(context),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _TextFieldShell extends StatelessWidget {
  const _TextFieldShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RememberCheck extends StatelessWidget {
  const _RememberCheck({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => onChanged(!checked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: checked ? AppColors.red : AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: checked ? AppColors.red : AppColors.borderFor(context),
          ),
        ),
        child: checked
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}
