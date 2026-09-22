import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../account/delete_account_dialog.dart';
import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';
import 'student_models.dart';
import 'student_actions.dart';

class StudentEditScreen extends StatefulWidget {
  const StudentEditScreen({
    super.key,
    required this.strings,
    required this.api,
    required this.student,
    this.documents = const [],
    this.onPreview,
    this.setup = false,
    this.onCompleted,
    this.onLogout,
  });

  final AppStrings strings;
  final ApiClient api;
  final StudentDetail student;
  final List<StudentDocument> documents;
  final ValueChanged<StudentDocument>? onPreview;
  final bool setup;
  final Future<void> Function()? onCompleted, onLogout;

  @override
  State<StudentEditScreen> createState() => _StudentEditScreenState();
}

class _StudentEditScreenState extends State<StudentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _patronymic;
  late String _gender;
  File? _avatar;
  bool _removeAvatar = false;
  late final TextEditingController _birthday;
  late final TextEditingController _email;
  late final TextEditingController _weight;
  late final TextEditingController _height;
  late final TextEditingController _cityTraining;
  late final TextEditingController _brandNumber;
  late final TextEditingController _ikoNumber;
  late final TextEditingController _certificateNumber;
  late final TextEditingController _lastExamDate;
  late final TextEditingController _lastExamCity;
  late final TextEditingController _lastReceiving;
  final _imagePicker = ImagePicker();
  final _documentFiles = <String, File>{};
  final _removed = <String>{};
  late String _rang;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _firstName = TextEditingController(text: student.firstName);
    _lastName = TextEditingController(text: student.lastName);
    _patronymic = TextEditingController(text: student.patronymic);
    _gender = student.gender;
    _birthday = TextEditingController(
      text: student.birthday == '—' ? '' : student.birthday,
    );
    _email = TextEditingController(text: student.email);
    _weight = TextEditingController(
      text: student.weight == '—' ? '' : student.weight,
    );
    _height = TextEditingController(
      text: student.height == '—' ? '' : student.height,
    );
    _cityTraining = TextEditingController(text: student.cityTraining);
    _brandNumber = TextEditingController(text: student.brandNumber);
    _ikoNumber = TextEditingController(text: student.ikoNumber);
    _certificateNumber = TextEditingController(text: student.certificateNumber);
    _lastExamDate = TextEditingController(text: student.lastExamDate);
    _lastExamCity = TextEditingController(text: student.lastExamCity);
    _lastReceiving = TextEditingController(text: student.lastReceiving);
    _rang = student.rang == '—' ? '' : student.rang;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _patronymic.dispose();
    _birthday.dispose();
    _email.dispose();
    _weight.dispose();
    _height.dispose();
    _cityTraining.dispose();
    _brandNumber.dispose();
    _ikoNumber.dispose();
    _certificateNumber.dispose();
    _lastExamDate.dispose();
    _lastExamCity.dispose();
    _lastReceiving.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await widget.api.postMultipartFiles(
        '/students/${widget.student.id}',
        fields: {
          if (widget.api.isStudent) ...{
            'first_name': _firstName.text.trim(),
            'last_name': _lastName.text.trim(),
            if (!widget.setup) 'patronymic': _patronymic.text.trim(),
            if (_gender.isNotEmpty) 'gender': _gender,
            if (_removeAvatar) 'remove_avatar': '1',
          },
          'locale': widget.strings.locale.isRu ? 'ru' : 'en',
          if (widget.student.canEdit('birthday'))
            'birthday': _birthday.text.trim(),
          if (!widget.setup) 'email': _email.text.trim(),
          if (!widget.api.isStudent || widget.student.canEdit('weight'))
            'weight': _weight.text.trim(),
          'height': _height.text.trim(),
          if (widget.student.canEdit('rang')) 'rang': _rang,
          for (var i = 0; i < _removed.length; i++)
            'remove_documents[$i]': _removed.elementAt(i),
          'city_training': _cityTraining.text.trim(),
          if (!widget.setup) ...{
            'number_brand': _brandNumber.text.trim(),
            'number_iko': _ikoNumber.text.trim(),
            'number_certificate': _certificateNumber.text.trim(),
            'last_examination_date': _lastExamDate.text.trim(),
            'last_examination_city': _lastExamCity.text.trim(),
            'last_receiving': _lastReceiving.text.trim(),
          },
        },
        files: {..._documentFiles, 'avatar': ?_avatar},
      );
      if (!mounted) return;
      if (widget.setup) {
        await widget.onCompleted?.call();
      } else {
        Navigator.of(context).pop();
      }
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

  Future<void> _pickDocument(String key) async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );

    if (file == null || !mounted) return;

    setState(() {
      _documentFiles[key] = File(file.path);
      _removed.remove(key);
    });
  }

  Widget _identityFields() {
    final s = widget.strings;
    final image = _avatar != null
        ? FileImage(_avatar!) as ImageProvider
        : (!_removeAvatar && widget.student.avatarUrl != null
              ? NetworkImage(widget.student.avatarUrl!)
              : null);
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: image,
              onBackgroundImageError: image == null ? null : (_, _) {},
              child: image == null ? const Icon(Icons.person_outline) : null,
            ),
            IconButton(
              tooltip: s.chooseFile,
              icon: const Icon(Icons.add_a_photo_outlined),
              onPressed: _isSaving
                  ? null
                  : () async {
                      final file = await _imagePicker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1600,
                        imageQuality: 88,
                      );
                      if (file != null && mounted) {
                        setState(() {
                          _avatar = File(file.path);
                          _removeAvatar = false;
                        });
                      }
                    },
            ),
            if (image != null)
              IconButton(
                tooltip: s.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (await confirmStudentAction(
                              context,
                              s,
                              s.removeDocumentConfirm,
                              s.delete,
                            ) &&
                            mounted) {
                          setState(() {
                            _avatar = null;
                            _removeAvatar = true;
                          });
                        }
                      },
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Field(
          controller: _lastName,
          label: s.lastName,
          requiredField: widget.setup,
        ),
        _Field(
          controller: _firstName,
          label: s.firstName,
          requiredField: widget.setup,
        ),
        if (!widget.setup) _Field(controller: _patronymic, label: s.patronymic),
        DropdownButtonFormField<String>(
          isExpanded: true,
          style: TextStyle(fontSize: 13, color: AppColors.inkFor(context)),
          initialValue: ['m', 'f'].contains(_gender) ? _gender : null,
          decoration: InputDecoration(
            labelText: widget.setup ? '${s.gender} *' : s.gender,
          ),
          validator: (value) =>
              widget.setup && value == null ? s.requiredField : null,
          items: [
            DropdownMenuItem(value: 'm', child: Text(s.male)),
            DropdownMenuItem(value: 'f', child: Text(s.female)),
          ],
          onChanged: _isSaving
              ? null
              : (value) => setState(() => _gender = value ?? ''),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _documentTile(String field, String label) {
    final s = widget.strings;
    final stored = widget.documents.where((d) => d.field == field).firstOrNull;
    final selected = _documentFiles.containsKey(field);
    final removed = _removed.contains(field);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          removed
              ? s.documentRemoved
              : selected
              ? s.fileSelected
              : stored?.fileUrl != null
              ? s.savedFile
              : s.chooseFile,
          style: const TextStyle(fontSize: 11),
        ),
        onTap: _isSaving ? null : () => _pickDocument(field),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stored?.fileUrl != null && !removed && !selected)
              IconButton(
                tooltip: label,
                onPressed: () => widget.onPreview?.call(stored!),
                icon: const Icon(Icons.visibility_outlined, size: 20),
              ),
            IconButton(
              tooltip: s.chooseFile,
              onPressed: _isSaving ? null : () => _pickDocument(field),
              icon: const Icon(Icons.upload_file_outlined, size: 20),
            ),
            if (selected || stored?.fileUrl != null || removed)
              IconButton(
                tooltip: removed ? s.cancel : s.delete,
                icon: Icon(
                  removed ? Icons.undo : Icons.delete_outline,
                  size: 20,
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (removed || selected) {
                          setState(() {
                            _removed.remove(field);
                            _documentFiles.remove(field);
                          });
                          return;
                        }
                        if (await confirmStudentAction(
                              context,
                              s,
                              s.removeDocumentConfirm,
                              s.delete,
                            ) &&
                            mounted) {
                          setState(() => _removed.add(field));
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;

    return PopScope(
      canPop: !widget.setup && !_isSaving,
      child: Scaffold(
        backgroundColor: AppColors.pageFor(context),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                AppColors.backgroundImage(context),
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: ColoredBox(color: AppColors.backgroundOverlay(context)),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                children: [
                  Row(
                    children: [
                      if (!widget.setup)
                        _CircleButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      Expanded(
                        child: Text(
                          widget.setup
                              ? strings.studentProfileSetup
                              : widget.api.isStudent
                              ? strings.editProfile
                              : strings.editStudent,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.inkFor(context),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (widget.setup)
                        IconButton(
                          tooltip: strings.logout,
                          icon: const Icon(Icons.logout),
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  try {
                                    await widget.onLogout?.call();
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(error.toString()),
                                            ),
                                          );
                                    }
                                  }
                                },
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceFor(context),
                      borderRadius: BorderRadius.circular(
                        widget.setup ? 8 : 24,
                      ),
                      boxShadow: _softShadow,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (widget.api.isStudent) _identityFields(),
                          if (!widget.setup &&
                              widget.api.isStudent &&
                              widget.student.canEdit('delete_account'))
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: strings.deleteAccount,
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: _isSaving
                                    ? null
                                    : () => showDeleteAccountDialog(
                                        context,
                                        widget.api,
                                        strings,
                                      ),
                              ),
                            ),
                          _Field(
                            controller: _birthday,
                            label: strings.birthDate,
                            requiredField: widget.setup,
                            onTap:
                                widget.setup &&
                                    widget.student.canEdit('birthday')
                                ? () async {
                                    final today = DateUtils.dateOnly(
                                      DateTime.now(),
                                    );
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          DateTime.tryParse(_birthday.text) ??
                                          DateTime(
                                            today.year - 10,
                                            today.month,
                                            today.day,
                                          ),
                                      firstDate: DateTime(1900),
                                      lastDate: today,
                                    );
                                    if (date != null) {
                                      _birthday.text =
                                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                    }
                                  }
                                : null,
                            enabled: widget.student.canEdit('birthday'),
                          ),
                          if (!widget.setup)
                            _Field(controller: _email, label: strings.email),
                          _Field(
                            controller: _weight,
                            label: strings.weight,
                            requiredField: widget.setup,
                            validator: widget.setup
                                ? (value) {
                                    final weight = int.tryParse(value ?? '');
                                    return weight == null ||
                                            weight < 1 ||
                                            weight > 300
                                        ? strings.invalidWeight
                                        : null;
                                  }
                                : null,
                            enabled:
                                !widget.api.isStudent ||
                                widget.student.canEdit('weight'),
                            keyboardType: TextInputType.number,
                          ),
                          _Field(
                            controller: _height,
                            label: strings.height,
                            keyboardType: TextInputType.number,
                          ),
                          _RangSelect(
                            strings: strings,
                            value: _rang,
                            requiredField: widget.setup,
                            onChanged: widget.student.canEdit('rang')
                                ? (value) => setState(() => _rang = value)
                                : null,
                          ),
                          _Field(
                            controller: _cityTraining,
                            label: strings.trainingCity,
                            requiredField: widget.setup,
                          ),
                          if (!widget.setup) ...[
                            Divider(
                              height: 28,
                              color: AppColors.borderFor(context),
                            ),
                            _Field(
                              controller: _brandNumber,
                              label: strings.brandNumber,
                            ),
                            _Field(
                              controller: _ikoNumber,
                              label: strings.ikoNumber,
                            ),
                            _Field(
                              controller: _certificateNumber,
                              label: strings.certificateNumber,
                            ),
                            _Field(
                              controller: _lastExamDate,
                              label: strings.lastExamDate,
                            ),
                            _Field(
                              controller: _lastExamCity,
                              label: strings.lastExamCity,
                            ),
                            _Field(
                              controller: _lastReceiving,
                              label: strings.lastReceiving,
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                strings.documentUploads,
                                style: TextStyle(
                                  color: AppColors.inkFor(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            for (final entry in {
                              'passport': strings.passport,
                              'brand': strings.brand,
                              'insurance': strings.insurance,
                              'iko_card': strings.ikoCard,
                              'certificate': strings.certificate,
                            }.entries)
                              _documentTile(entry.key, entry.value),
                          ],
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: widget.setup ? null : 48,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                backgroundColor: AppColors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      widget.setup
                                          ? strings.finishRegistration
                                          : strings.save,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
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
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.enabled = true,
    this.requiredField = false,
    this.validator,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool enabled;
  final bool requiredField;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        readOnly: onTap != null,
        onTap: onTap,
        validator:
            validator ??
            (value) => requiredField && (value ?? '').trim().isEmpty
                ? AppStrings(
                    Localizations.localeOf(context).languageCode == 'ru'
                        ? AppLocale.ru
                        : AppLocale.en,
                  ).requiredField
                : null,
        style: const TextStyle(fontSize: 13),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: requiredField ? '$label *' : label,
          filled: true,
          fillColor: AppColors.surfaceFor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppColors.borderFor(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppColors.borderFor(context)),
          ),
        ),
      ),
    );
  }
}

class _RangSelect extends StatelessWidget {
  const _RangSelect({
    required this.strings,
    required this.value,
    required this.onChanged,
    this.requiredField = false,
  });

  final AppStrings strings;
  final String value;
  final ValueChanged<String>? onChanged;
  final bool requiredField;

  static const _values = [
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value.isEmpty ? null : value,
        validator: (value) => requiredField && (value ?? '').isEmpty
            ? strings.requiredField
            : null,
        style: TextStyle(fontSize: 13, color: AppColors.inkFor(context)),
        items: [
          for (final item in {..._values, if (value.isNotEmpty) value})
            DropdownMenuItem(value: item, child: Text(strings.rankValue(item))),
        ],
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) onChanged!(value);
              },
        decoration: InputDecoration(
          labelText: requiredField ? '${strings.kyuDan} *' : strings.kyuDan,
          filled: true,
          fillColor: AppColors.surfaceFor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppColors.borderFor(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppColors.borderFor(context)),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          shape: BoxShape.circle,
          boxShadow: _softShadow,
        ),
        child: Icon(icon, color: AppColors.inkFor(context), size: 25),
      ),
    );
  }
}

final _softShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.07),
    blurRadius: 24,
    offset: const Offset(0, 10),
  ),
];
