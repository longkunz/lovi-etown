import '../features/cameras/presentation/screens/camera_navigation_shell.dart';
import '../features/cameras/presentation/camera_feature_scope.dart';
import '../features/cameras/domain/camera_repository.dart';
import '../features/cameras/domain/favorites_repository.dart';
import '../features/cameras/domain/camera_map_repository.dart';
import '../features/cameras/domain/camera_location_gateway.dart';
import '../features/cameras/presentation/widgets/camera_map_view_config.dart';
import '../config/map_config.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_starter/src/middleware/app_route_observer.dart';
import 'package:flutter_starter/src/routing/global_navigator.dart';
import 'package:flutter_starter/src/routing/app_routes.dart';

import 'package:flutter_starter/src/features/onboarding/presentation/screens/onboarding_page.dart';

import 'package:flutter_starter/src/shared/widgets/ui/ui_showcase_screen.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_starter/src/features/cameras/presentation/camera_feature.dart';

GoRouter createAppRouter({
  GlobalKey<NavigatorState>? navigatorKey,
  String initialLocation = AppRoutes.map,
  CameraRepository? cameraRepository,
  FavoritesRepository? favoritesRepository,
  CameraMapRepository? mapRepository,
  CameraLocationGateway? locationGateway,
  CameraMapViewBuilder? mapBuilder,
  MapConnectionConfig? mapConnectionConfig,
}) {
  return GoRouter(
    navigatorKey: navigatorKey ?? rootNavigatorKey,
    initialLocation: initialLocation,
    observers: <NavigatorObserver>[AppRouteObserver()],
    routes: <RouteBase>[
      GoRoute(path: '/map', redirect: (_, __) => AppRoutes.map),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => CameraNavigationShell(
            navigationShell: navigationShell,
            cameraRepository: cameraRepository,
            favoritesRepository: favoritesRepository),
        branches: [
          StatefulShellBranch(preload: false, routes: [
            GoRoute(
                path: AppRoutes.map,
                name: 'map',
                builder: (context, state) => CameraMapFeature(
                    repository: mapRepository,
                    locationGateway: locationGateway,
                    mapBuilder: mapBuilder,
                    connectionConfig: mapConnectionConfig))
          ]),
          StatefulShellBranch(preload: false, routes: [
            GoRoute(
                path: AppRoutes.camera,
                name: 'camera',
                builder: (context, state) => const CameraFeature())
          ]),
        ],
      ),
      GoRoute(
        path: AppRoutes.cameraViewer,
        name: 'cameraViewer',
        builder: (context, state) => CameraViewerFeature(
          cameraId: state.pathParameters['id'] ?? '',
          cameraRepository: state.extra is CameraViewerDependencies
              ? (state.extra as CameraViewerDependencies).repository
              : cameraRepository,
          favoritesRepository: state.extra is CameraViewerDependencies
              ? (state.extra as CameraViewerDependencies).favorites
              : favoritesRepository,
        ),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
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
