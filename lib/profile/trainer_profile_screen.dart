import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../account/delete_account_dialog.dart';
import '../l10n/app_locale.dart';
import '../navigation/coach_bottom_nav.dart';
import '../theme/app_colors.dart';
import 'trainer_profile_models.dart';

class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({
    super.key,
    required this.strings,
    required this.api,
  });

  final AppStrings strings;
  final ApiClient api;

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  TrainerProfile? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TrainerProfileEditSheet(
        strings: widget.strings,
        api: widget.api,
        profile: profile,
      ),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await widget.api.getJson('/trainer/profile');
      final trainer = response['trainer'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _profile = TrainerProfile.fromJson(trainer);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = widget.strings.profileLoadFailed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageFor(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              AppColors.backgroundImage(context),
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.46),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ProfileHeader(
                  title: widget.strings.profile,
                  onEdit: _profile == null ? null : _openEditProfile,
                  editLabel: widget.strings.edit,
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.red,
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.red,
                          onRefresh: _loadProfile,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                            children: [
                              if (_error != null) ...[
                                _ErrorBanner(
                                  message: _error!,
                                  retryLabel: widget.strings.retry,
                                  onRetry: _loadProfile,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_profile != null)
                                _TrainerHero(
                                  strings: widget.strings,
                                  profile: _profile!,
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CoachBottomNav(
        strings: widget.strings,
        api: widget.api,
        active: CoachNavItem.profile,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.title,
    this.onEdit,
    required this.editLabel,
  });

  final String title;
  final VoidCallback? onEdit;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Row(
        children: [
          const SizedBox(width: 54),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            tooltip: editLabel,
            onPressed: onEdit,
            icon: Icon(
              Icons.edit_outlined,
              color: AppColors.accentFor(context),
              size: 21,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceFor(context),
              fixedSize: const Size(40, 40),
              shadowColor: Colors.black.withValues(alpha: 0.16),
              elevation: 4,
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _TrainerProfileEditSheet extends StatefulWidget {
  const _TrainerProfileEditSheet({
    required this.strings,
    required this.api,
    required this.profile,
  });

  final AppStrings strings;
  final ApiClient api;
  final TrainerProfile profile;

  @override
  State<_TrainerProfileEditSheet> createState() =>
      _TrainerProfileEditSheetState();
}

class _TrainerProfileEditSheetState extends State<_TrainerProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _patronymic;
  late final TextEditingController _email;
  late final TextEditingController _weight;
  late final TextEditingController _height;
  late final TextEditingController _birthday;
  late final TextEditingController _club;
  late final TextEditingController _cityTraining;
  late String _gender;
  late String _rang;
  File? _avatar;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _firstName = TextEditingController(text: profile.firstName);
    _lastName = TextEditingController(text: profile.lastName);
    _patronymic = TextEditingController(text: profile.patronymic);
    _email = TextEditingController(
      text: profile.email == '—' ? '' : profile.email,
    );
    _weight = TextEditingController(
      text: profile.weight == '—' ? '' : profile.weight,
    );
    _height = TextEditingController(
      text: profile.height == '—' ? '' : profile.height,
    );
    _birthday = TextEditingController(
      text: profile.birthday == '—' ? '' : profile.birthday,
    );
    _club = TextEditingController(
      text: profile.club == '—' ? '' : profile.club,
    );
    _cityTraining = TextEditingController(text: profile.cityTraining);
    _gender = profile.genderCode;
    _rang = profile.rang == '—' ? '' : profile.rang;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _patronymic.dispose();
    _email.dispose();
    _weight.dispose();
    _height.dispose();
    _birthday.dispose();
    _club.dispose();
    _cityTraining.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;
    setState(() => _avatar = File(file.path));
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final avatar = _avatar;
    try {
      await widget.api.postMultipartFiles(
        '/trainer/profile',
        fields: {
          'first_name': _firstName.text.trim(),
          'last_name': _lastName.text.trim(),
          'patronymic': _patronymic.text.trim(),
          'email': _email.text.trim(),
          'gender': _gender,
          if (widget.profile.canEdit('weight')) 'weight': _weight.text.trim(),
          'height': _height.text.trim(),
          if (widget.profile.canEdit('birthday'))
            'birthday': _birthday.text.trim(),
          if (widget.profile.canEdit('rang')) 'rang': _rang,
          'club': _club.text.trim(),
          'city_training': _cityTraining.text.trim(),
          'locale': widget.strings.locale.name,
        },
        files: {'avatar': ?avatar},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final strings = widget.strings;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.editProfile,
                      style: TextStyle(
                        color: AppColors.inkFor(context),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      _Avatar(
                        url: _avatar == null ? widget.profile.avatarUrl : null,
                        size: 86,
                      ),
                      if (_avatar != null)
                        CircleAvatar(
                          radius: 43,
                          backgroundImage: FileImage(_avatar!),
                        ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _EditField(
                controller: _lastName,
                label: strings.lastName,
                isRequired: true,
              ),
              _EditField(
                controller: _firstName,
                label: strings.firstName,
                isRequired: true,
              ),
              _EditField(controller: _patronymic, label: strings.patronymic),
              _EditField(
                controller: _email,
                label: strings.email,
                keyboardType: TextInputType.emailAddress,
                isRequired: true,
              ),
              Row(
                children: [
                  Expanded(
                    child: _SelectField(
                      label: strings.gender,
                      value: _gender,
                      items: [
                        DropdownMenuItem(
                          value: 'm',
                          child: Text(strings.maleShort),
                        ),
                        DropdownMenuItem(
                          value: 'f',
                          child: Text(strings.femaleShort),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _gender = value ?? _gender),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SelectField(
                      label: strings.kyuDan,
                      value: _rang,
                      items: {..._rankOptions, _rang}
                          .map(
                            (rank) => DropdownMenuItem(
                              value: rank,
                              child: Text(widget.strings.rankValue(rank)),
                            ),
                          )
                          .toList(),
                      onChanged: widget.profile.canEdit('rang')
                          ? (value) => setState(() => _rang = value ?? _rang)
                          : null,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _EditField(
                      controller: _birthday,
                      label: strings.birthDate,
                      hint: strings.dateFormatHint,
                      enabled: widget.profile.canEdit('birthday'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EditField(
                      controller: _weight,
                      enabled: widget.profile.canEdit('weight'),
                      label: strings.weight,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              _EditField(
                controller: _height,
                label: strings.height,
                keyboardType: TextInputType.number,
              ),
              _EditField(controller: _club, label: strings.club),
              _EditField(
                controller: _cityTraining,
                label: strings.trainingCity,
              ),
              if (widget.profile.canEdit('delete_account'))
                TextButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => showDeleteAccountDialog(
                          context,
                          widget.api,
                          strings,
                        ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(strings.deleteAccount),
                ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        strings.save,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.isRequired = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool isRequired;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        validator: isRequired
            ? (value) => (value == null || value.trim().isEmpty) ? label : null
            : null,
        style: TextStyle(
          color: AppColors.inkFor(context),
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: _inputDecoration(context, label, hint),
      ),
    );
  }
}

const _rankOptions = [
  '0 кю',
  '10 кю',
  '9 кю',
  '8 кю',
  '7 кю',
  '6 кю',
  '5 кю',
  '4 кю',
  '3 кю',
  '2 кю',
  '1 кю',
  '1 дан',
  '2 дан',
  '3 дан',
  '4 дан',
  '5 дан',
  '6 дан',
  '7 дан',
  '8 дан',
  '9 дан',
  '10 дан',
];

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        style: TextStyle(
          color: AppColors.inkFor(context),
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        decoration: _inputDecoration(context, label, null),
      ),
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context,
  String label,
  String? hint,
) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(
      color: AppColors.mutedFor(context),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    filled: true,
    fillColor: AppColors.surfaceFor(context),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.borderFor(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.borderFor(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.red, width: 1.2),
    ),
  );
}

class _TrainerHero extends StatelessWidget {
  const _TrainerHero({required this.strings, required this.profile});

  final AppStrings strings;
  final TrainerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(url: profile.avatarUrl, size: 68),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: TextStyle(
                        color: AppColors.inkFor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InfoLine(
                      icon: Icons.home_work_outlined,
                      text: '${strings.club}: ${profile.club}',
                    ),
                    const SizedBox(height: 5),
                    _InfoLine(
                      icon: Icons.mail_outline_rounded,
                      text: profile.email,
                    ),
                    const SizedBox(height: 10),
                    _BeltProgress(belt: profile.belt),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          strings.rankValue(profile.rang),
                          style: TextStyle(
                            color: AppColors.inkFor(context),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        _BeltBadge(
                          label: _beltLabel(strings, profile.belt.labelKey),
                          belt: profile.belt,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(12.5) / 12.5;
              final columns = scale > 1.5 ? 1 : (scale > 1.1 ? 2 : 3);
              final width =
                  (constraints.maxWidth - 8 * (columns - 1)) / columns;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FactTile(
                    width: width,
                    icon: Icons.person_search_outlined,
                    value: profile.age,
                  ),
                  _FactTile(
                    width: width,
                    icon: Icons.transgender_rounded,
                    value: profile.gender,
                  ),
                  _FactTile(
                    width: width,
                    icon: Icons.calendar_month_outlined,
                    value: profile.birthday,
                  ),
                  _FactTile(
                    width: width,
                    icon: Icons.monitor_weight_outlined,
                    value: profile.weight == '—'
                        ? '—'
                        : '${profile.weight} ${strings.kg}',
                  ),
                  _FactTile(
                    width: width,
                    icon: Icons.height_rounded,
                    value: profile.height == '—'
                        ? '—'
                        : '${profile.height} ${strings.cm}',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BeltBadge extends StatelessWidget {
  const _BeltBadge({required this.label, required this.belt});

  final String label;
  final TrainerBelt belt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: belt.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: belt.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: belt.accent.computeLuminance() > 0.65
              ? const Color(0xFF9A6A00)
              : belt.accent,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.mutedFor(context), size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.mutedFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ),
      ],
    );
  }
}

class _BeltProgress extends StatelessWidget {
  const _BeltProgress({required this.belt});

  final TrainerBelt belt;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Stack(
        children: [
          Container(height: 8, color: belt.color),
          Positioned(
            right: 18,
            top: 0,
            bottom: 0,
            child: Container(width: 12, color: belt.accent),
          ),
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.width,
    required this.icon,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.inkFor(context), size: 18),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceFor(context),
      backgroundImage: url == null ? null : NetworkImage(url!),
      child: url == null
          ? Icon(
              Icons.person_rounded,
              color: AppColors.mutedFor(context),
              size: size * 0.42,
            )
          : null,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.accentFor(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.inkFor(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              retryLabel,
              style: TextStyle(
                color: AppColors.accentFor(context),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _beltLabel(AppStrings strings, String key) {
  return switch (key) {
    'whiteBelt' => strings.whiteBelt,
    'orangeBelt' => strings.orangeBelt,
    'blueBelt' => strings.blueBelt,
    'yellowBelt' => strings.yellowBelt,
    'greenBelt' => strings.greenBelt,
    'brownBelt' => strings.brownBelt,
    'blackBelt' => strings.blackBelt,
    _ => strings.beltNotSet,
  };
}

final _softShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 24,
    offset: const Offset(0, 12),
  ),
];
