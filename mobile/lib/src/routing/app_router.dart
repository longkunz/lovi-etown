import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_starter/src/middleware/app_route_observer.dart';
import 'package:flutter_starter/src/routing/global_navigator.dart';
import 'package:flutter_starter/src/routing/app_routes.dart';

import 'package:flutter_starter/src/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/src/features/auth/presentation/screens/signup_screen.dart';
import 'package:flutter_starter/src/features/auth/presentation/screens/forgot_password_screen.dart';

import 'package:flutter_starter/src/features/home/presentation/screens/home_page.dart';
import 'package:flutter_starter/src/features/onboarding/presentation/screens/onboarding_page.dart';

import 'package:flutter_starter/src/shared/widgets/ui/ui_showcase_screen.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_starter/src/features/cameras/presentation/camera_feature.dart';

GoRouter createAppRouter({
  GlobalKey<NavigatorState>? navigatorKey,
  String initialLocation = AppRoutes.camera,
}) {
  return GoRouter(
    navigatorKey: navigatorKey ?? rootNavigatorKey,
    initialLocation: initialLocation,
    observers: <NavigatorObserver>[AppRouteObserver()],
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.camera,
        name: 'camera',
        builder: (context, state) => const CameraFeature(),
      ),
      GoRoute(
        path: AppRoutes.cameraViewer,
        name: 'cameraViewer',
        builder: (context, state) => CameraViewerFeature(
          cameraId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.uiShowcase,
          name: 'uiShowcase',
          builder: (context, state) => const UiShowcaseScreen(),
        ),
    ],
  );
}

final GoRouter appRouter = createAppRouter();
