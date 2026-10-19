import 'package:flutter_starter/src/imports/core_imports.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';

class App extends StatelessWidget {
  final RouterConfig<Object>? routerConfig;

  const App({super.key, this.routerConfig});

  @override
  Widget build(BuildContext context) {
    Widget current = _buildCupertinoApp(context);
    current = LiquidGlassWidgets.wrap(
      theme: CameraGlassTheme.themeData,
      child: current,
    );
    current = AppPlatformScope(
      style: AppPlatformStyle.cupertino,
      child: current,
    );
    return current;
  }

  Widget _buildCupertinoApp(BuildContext context) {
    const tealHex = '#00796B';

    return CupertinoApp.router(
      title: 'TTGT TP.HCM',
      debugShowCheckedModeBanner: false,
      theme: buildCupertinoTheme(primaryColorHex: tealHex),
      routerConfig: routerConfig ?? appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) {
        Widget current = child!;
        current = SkeletonWrapper(child: current);
        current = SessionListenerWrapper(child: current);

        // Ensure Material themes (tokens, widget styles like dialogs/buttons/inputs)
        // are available even in Cupertino mode, as many apps use a mix of both.
        current = Theme(
          data: (MediaQuery.of(context).platformBrightness == Brightness.dark)
              ? buildDarkTheme(primaryColorHex: tealHex)
              : buildLightTheme(primaryColorHex: tealHex),
          child: current,
        );

        return current;
      },
    );
  }
}
