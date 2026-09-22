import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../l10n/app_locale.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.api,
    required this.strings,
    required this.student,
    this.onRegistered,
  });
  final ApiClient api;
  final AppStrings strings;
  final bool student;
  final Future<void> Function(Map<String, dynamic>)? onRegistered;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _joinCode = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  final _code = TextEditingController();
  bool _existing = false, _busy = false, _reveal = false, _completed = false;
  String? _challenge, _error;
  Map<String, dynamic>? _registeredSession;

  @override
  void dispose() {
    for (final controller in [
      _email,
      _joinCode,
      _first,
      _last,
      _password,
      _repeat,
      _code,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final kind = widget.student ? 'student' : 'trainer';
    try {
      final result =
          _registeredSession ??
          await widget.api.postJson(
            '/auth/registration/$kind${_challenge == null ? '' : '/confirm'}',
            authenticated: false,
            body: _challenge != null
                ? {'challenge_token': _challenge, 'code': _code.text.trim()}
                : {
                    'email': _email.text.trim(),
                    widget.student ? 'coach_code' : 'organization_code':
                        _joinCode.text.trim(),
                    'existing_account': _existing,
                    'password': _password.text,
                    if (!_existing) ...{
                      'password_confirmation': _repeat.text,
                      'first_name': _first.text.trim(),
                      'last_name': _last.text.trim(),
                    },
                  },
          );
      if (!mounted) return;
      if (_challenge != null) {
        if (result['registered'] != true) {
          throw ApiException(widget.strings.registrationFailed);
        }
        if (widget.student && widget.onRegistered != null) {
          _registeredSession = result;
          await widget.onRegistered!(result);
          return;
        }
        _password.clear();
        _repeat.clear();
        _code.clear();
        setState(() {
          _completed = true;
          _challenge = null;
        });
      } else {
        final token = result['challenge_token'];
        if (result['verification_required'] != true ||
            token is! String ||
            token.length != 64) {
          throw ApiException(widget.strings.registrationFailed);
        }
        setState(() => _challenge = token);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    TextEditingController controller,
    String label, {
    bool password = false,
    TextInputType? keyboard,
    String? Function(String)? validate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        key: ValueKey(key),
        controller: controller,
        enabled: !_busy,
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        obscureText: password && !_reveal,
        autocorrect: false,
        enableSuggestions: !password,
        maxLength: key == 'join-code' ? 20 : 255,
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          suffixIcon: key == 'password'
              ? IconButton(
                  tooltip: _reveal
                      ? widget.strings.hidePassword
                      : widget.strings.showPassword,
                  onPressed: () => setState(() => _reveal = !_reveal),
                  icon: Icon(
                    _reveal
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                )
              : null,
        ),
        validator: (value) {
          if ((value ?? '').trim().isEmpty) return widget.strings.requiredField;
          return validate?.call(value!);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.student ? s.studentRegistration : s.coachRegistration,
            style: const TextStyle(fontSize: 17),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _completed
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(s.registrationComplete),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, _email.text.trim()),
                            child: Text(s.signIn),
                          ),
                        ],
                      )
                    : Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_challenge == null) ...[
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: Text(s.existingAccount),
                                value: _existing,
                                onChanged: _busy
                                    ? null
                                    : (value) => setState(() {
                                        _existing = value;
                                        _error = null;
                                      }),
                              ),
                              _field(
                                'join-code',
                                _joinCode,
                                widget.student
                                    ? s.coachCode
                                    : s.organizationCode,
                              ),
                              _field(
                                'email',
                                _email,
                                s.email,
                                keyboard: TextInputType.emailAddress,
                                validate: (value) =>
                                    value.contains('@') ? null : s.invalidEmail,
                              ),
                              if (!_existing) ...[
                                _field('last-name', _last, s.lastName),
                                _field('first-name', _first, s.firstName),
                              ],
                              _field(
                                'password',
                                _password,
                                s.password,
                                password: true,
                                validate: (value) =>
                                    !_existing && value.length < 8
                                    ? s.registrationPasswordLength
                                    : null,
                              ),
                              if (!_existing)
                                _field(
                                  'password-confirmation',
                                  _repeat,
                                  s.confirmPassword,
                                  password: true,
                                  validate: (value) => value == _password.text
                                      ? null
                                      : s.passwordMismatch,
                                ),
                            ] else ...[
                              Text(s.registrationCodeSent(_email.text.trim())),
                              const SizedBox(height: 16),
                              TextFormField(
                                key: const ValueKey('email-code'),
                                controller: _code,
                                enabled: !_busy,
                                keyboardType: TextInputType.number,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                decoration: InputDecoration(
                                  labelText: s.verificationCode,
                                ),
                                validator: (value) => value?.length == 6
                                    ? null
                                    : s.registrationCodeLength,
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _challenge == null
                                          ? s.continueLabel
                                          : s.register,
                                    ),
                            ),
                            if (_challenge != null)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(() {
                                        _challenge = null;
                                        _code.clear();
                                        _error = null;
                                      }),
                                child: Text(s.backToRegistration),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
