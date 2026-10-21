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
    super.key,
  });

  final String streamUrl;
  final VoidCallback onUnavailable;

  @override
  State<CameraLivePlayer> createState() => _CameraLivePlayerState();
}

class _CameraLivePlayerState extends State<CameraLivePlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

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
      await controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      _fail();
    }
  }

  void _onControllerUpdate() {
    final controller = _controller;
    if (controller != null && controller.value.hasError) {
      _fail();
    }
  }

  void _fail() {
    if (_failed || !mounted) return;
    _failed = true;
    widget.onUnavailable();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: () {
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, size: 10, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'TRỰC TIẾP',
            style: TextStyle(
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
