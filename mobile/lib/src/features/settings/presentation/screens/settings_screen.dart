import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// Language settings (#52).
///
/// The default locale follows the device: [LocalizationWrapper] no longer
/// pins a start locale, so EasyLocalization resolves the device locale when
/// it is supported and falls back to Vietnamese otherwise. An explicit
/// choice here applies immediately (no restart) and persists on device via
/// EasyLocalization's `saveLocale`.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.locale;
    return Scaffold(
      appBar: AppBar(
        title: Text('settings.title'.tr()),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CameraUiTokens.spacing16,
              CameraUiTokens.spacing16,
              CameraUiTokens.spacing16,
              CameraUiTokens.spacing8,
            ),
            child: Text(
              'settings.language'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          RadioGroup<Locale>(
            groupValue: current,
            onChanged: (locale) {
              if (locale != null) context.setLocale(locale);
            },
            child: Column(
              children: [
                ListTile(
                  title: Text('settings.language_vietnamese'.tr()),
                  leading: const Radio<Locale>(value: Locale('vi')),
                  onTap: () => context.setLocale(const Locale('vi')),
                ),
                ListTile(
                  title: Text('settings.language_english'.tr()),
                  leading: const Radio<Locale>(value: Locale('en')),
                  onTap: () => context.setLocale(const Locale('en')),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(CameraUiTokens.spacing16),
            child: Text(
              'settings.language_note'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
