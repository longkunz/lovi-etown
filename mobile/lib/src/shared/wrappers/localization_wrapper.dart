import '../../imports/core_imports.dart';

/// A wrapper to initialize [EasyLocalization] with supported locales.
class LocalizationWrapper extends StatelessWidget {
  final Widget child;

  const LocalizationWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return EasyLocalization(
      supportedLocales: const [
        Locale('vi'),
        Locale('en'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('vi'),
      // No startLocale: EasyLocalization resolves the device locale when it
      // is supported and falls back to Vietnamese otherwise. An explicit
      // choice in SettingsScreen persists via saveLocale.
      saveLocale: true,
      child: child,
    );
  }
}
