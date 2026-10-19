import 'dart:async';
import 'dart:ui' as ui;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'src/imports/core_imports.dart';
import 'src/imports/packages_imports.dart';
import 'src/app.dart';

Future<void> main() async {
  await runZonedGuarded(_bootstrap, (error, stackTrace) {
    AppLogger.error(
      'Unhandled asynchronous error',
      error: error,
      stackTrace: stackTrace,
      category: LogCategory.app,
    );
  });
}

Future<void> _bootstrap() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  FlutterError.onError = (details) {
    AppLogger.error(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack ?? StackTrace.current,
      category: LogCategory.app,
      context: {'library': details.library ?? 'unknown'},
    );
    FlutterError.presentError(details);
  };

  ui.PlatformDispatcher.instance.onError = (error, stackTrace) {
    AppLogger.error(
      'Unhandled platform error',
      error: error,
      stackTrace: stackTrace,
      category: LogCategory.app,
    );
    return false;
  };

  AppLogger.info('Application bootstrap started', category: LogCategory.app);

  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);

  await StorageService.instance.init();
  AppLogger.success('Storage service initialized', category: LogCategory.app);

  await AppConfig.init();
  AppLogger.success(
    'Application configuration initialized',
    category: LogCategory.backend,
  );

  try {
    await LiquidGlassWidgets.initialize(
      enablePerformanceMonitor: false,
      warmUpMode: GlassWarmUpMode.auto,
    );
  } catch (e, st) {
    AppLogger.error(
      'LiquidGlassWidgets initialization warning',
      error: e,
      stackTrace: st,
      category: LogCategory.app,
    );
  }

  FlutterNativeSplash.remove();

  runApp(
    const LocalizationWrapper(
      child: StateWrapper(
        child: App(),
      ),
    ),
  );

  AppLogger.success('Application started', category: LogCategory.app);
}
