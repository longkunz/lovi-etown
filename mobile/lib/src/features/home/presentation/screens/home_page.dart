import 'package:flutter_starter/src/imports/core_imports.dart';
import 'package:flutter_starter/src/imports/packages_imports.dart';

import 'package:flutter_starter/src/features/auth/presentation/providers/session_bloc.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final session = context.watch<SessionBloc>().state;
    final user = session.userOrNull;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppTopBar(
        title: 'home.home_title'.tr(),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppIcon(
                icon: Icons.home_rounded,
                size: 60,
                color: colorScheme.primary,
                ),
              SizedBox(height: AppSpacing.lg),
              Text(
                user?.name ?? user?.email ?? ('home.welcome_home'.tr()),
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  fontSize: 28,
                ),
                ),
                            SizedBox(height: AppSpacing.md),
              Text(
                user != null && user.name != null ? user.email : ('home.home_subtitle'.tr()),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
                ),
                          ],
          ),
          ),
      ),
    );
  }
  }
