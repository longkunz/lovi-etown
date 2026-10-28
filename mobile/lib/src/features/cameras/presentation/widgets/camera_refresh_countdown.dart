import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_state.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// Displays the cubit's scheduled refresh; never starts a network request.
class CameraRefreshCountdown extends StatefulWidget {
  const CameraRefreshCountdown({required this.state, super.key});

  final CameraPreviewState state;

  @override
  State<CameraRefreshCountdown> createState() => _CameraRefreshCountdownState();
}

class _CameraRefreshCountdownState extends State<CameraRefreshCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    );
    _syncSchedule();
  }

  @override
  void didUpdateWidget(CameraRefreshCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.nextRefreshAt != widget.state.nextRefreshAt ||
        oldWidget.state.refreshDelay != widget.state.refreshDelay ||
        oldWidget.state.isForeground != widget.state.isForeground) {
      _syncSchedule();
    }
  }

  void _syncSchedule() {
    _controller.stop();
    final due = widget.state.nextRefreshAt;
    final delay = widget.state.refreshDelay;
    if (!widget.state.isForeground || due == null || delay == null) return;
    _controller.duration = delay;
    final remaining = due.difference(DateTime.now()).inMicroseconds;
    final fraction = (remaining / delay.inMicroseconds).clamp(0.0, 1.0);
    _controller.reverse(from: fraction);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (!state.isForeground ||
        (state.nextRefreshAt == null && !state.snapshotState.isLoading)) {
      return const SizedBox.shrink();
    }
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final seconds = ((state.refreshDelay?.inMilliseconds ?? 0) *
                _controller.value /
                1000)
            .ceil();
        final waiting = state.nextRefreshAt != null && seconds > 0;
        final label = waiting
            ? 'camera.refresh_after'.tr(args: ['$seconds'])
            : 'camera.refreshing_now'.tr();
        return Semantics(
          label: label,
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CameraUiTokens.spacing8,
              vertical: CameraUiTokens.spacing4,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(CameraUiTokens.radius8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: CameraUiTokens.controlIconSize,
                  child: reducedMotion
                      ? const Icon(Icons.refresh,
                          size: CameraUiTokens.controlIconSize,
                          color: Colors.white)
                      : CircularProgressIndicator(
                          key: const ValueKey('camera_refresh_progress'),
                          value: waiting ? _controller.value : 0,
                          strokeWidth: 2,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                ),
                const SizedBox(width: CameraUiTokens.spacing8),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
