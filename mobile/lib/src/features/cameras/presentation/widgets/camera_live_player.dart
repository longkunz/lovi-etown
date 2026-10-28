import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// HLS live player for cameras with a public stream URL (T14).
/// Uses the platform player via video_player (ExoPlayer/AVPlayer handle
/// HLS natively). Any initialization/playback failure calls
/// [onUnavailable] exactly once so the sheet can fall back to snapshots.
class CameraLivePlayer extends StatefulWidget {
  const CameraLivePlayer({
    required this.streamUrl,
    required this.onUnavailable,
    this.active = true,
    super.key,
  });

  final String streamUrl;
  final VoidCallback onUnavailable;

  /// Inactive players retain their controller but must not play offscreen.
  final bool active;

  @override
  State<CameraLivePlayer> createState() => _CameraLivePlayerState();
}

class _CameraLivePlayerState extends State<CameraLivePlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _routePopped = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamUrl),
    );
    _controller = controller;
    controller.addListener(_onControllerUpdate);
    try {
      await controller.initialize();
      if (!mounted || _routePopped) return;
      if (widget.active) await controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      _fail();
    }
  }

  @override
  void didUpdateWidget(CameraLivePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_routePopped || oldWidget.active == widget.active) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.active) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (controller != null && controller.value.hasError) {
      _fail();
    }
  }

  void _fail() {
    if (_failed || !mounted || _routePopped) return;
    _failed = true;
    widget.onUnavailable();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    // Stop playback immediately while native disposal finishes asynchronously.
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // The underlying route resumes before the reverse transition disposes
        // this player. Pause now so the two routes never play together.
        _routePopped = true;
        _controller?.pause();
      },
      child: _buildPlayer(),
    );
  }

  Widget _buildPlayer() {
    final controller = _controller;
    if (controller == null || !_ready) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(controller),
            GestureDetector(
              onTap: !widget.active
                  ? null
                  : () {
                      if (_routePopped) return;
                      if (controller.value.isPlaying) {
                        controller.pause();
                      } else {
                        controller.play();
                      }
                      setState(() {});
                    },
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: controller.value.isPlaying
                    ? const SizedBox.shrink()
                    : const Icon(
                        Icons.play_circle_fill,
                        color: Colors.white70,
                        size: 56,
                      ),
              ),
            ),
            const Positioned(
              top: CameraUiTokens.spacing8,
              left: CameraUiTokens.spacing8,
              child: _LiveBadge(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing8,
        vertical: CameraUiTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: CameraUiTokens.errorRed,
        borderRadius: BorderRadius.circular(CameraUiTokens.radius8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fiber_manual_record, size: 10, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            'camera.live_upper'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
