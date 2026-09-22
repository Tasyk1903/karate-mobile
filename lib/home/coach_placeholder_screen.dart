import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../theme/app_colors.dart';

class CoachPlaceholderScreen extends StatelessWidget {
  const CoachPlaceholderScreen({
    super.key,
    required this.strings,
    required this.email,
    required this.onLogout,
  });

  final AppStrings strings;
  final String? email;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppColors.backgroundImage(context), fit: BoxFit.cover),
          Container(color: AppColors.backgroundOverlay(context)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceFor(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(7),
                        child: Image.asset('assets/images/kr.jpg'),
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout_rounded),
                        tooltip: strings.logout,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    strings.stubTitle,
                    style: TextStyle(
                      color: AppColors.inkFor(context),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    strings.stubBody,
                    style: TextStyle(
                      color: AppColors.mutedFor(context),
                      fontSize: 18,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceFor(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderFor(context)),
                      ),
                      child: Text(
                        email!,
                        style: TextStyle(
                          color: AppColors.inkFor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
