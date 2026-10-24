import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_state.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_icon_button.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_surface.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

Future<void> showCameraImageViewer(
  BuildContext context, {
  required CameraPreviewCubit preview,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      pageBuilder: (context, _, __) {
        return CameraImageViewer(preview: preview);
      },
    ),
  );
}

class CameraImageViewer extends StatefulWidget {
  const CameraImageViewer({
    required this.preview,
    super.key,
  });

  final CameraPreviewCubit preview;

  @override
  State<CameraImageViewer> createState() => _CameraImageViewerState();
}

class _CameraImageViewerState extends State<CameraImageViewer> {
  late final TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.2) {
      // Reset to 1.0
      _transformationController.value = Matrix4.identity();
    } else {
      // Zoom to 2.5x
      final matrix = Matrix4.diagonal3Values(2.5, 2.5, 1);
      _transformationController.value = matrix;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CameraPreviewCubit, CameraPreviewState>(
      bloc: widget.preview,
      builder: (context, state) {
        final cameraName = state.camera?.name ?? '';
        final frame = state.currentFrame;

        Widget contentWidget;
        if (frame != null && frame.bytes.isNotEmpty) {
          contentWidget = Image.memory(
            frame.bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        } else if (state.camera?.thumbnailEndpoint != null &&
            state.camera!.thumbnailEndpoint!.startsWith('assets/')) {
          contentWidget = Image.asset(
            state.camera!.thumbnailEndpoint!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        } else {
          contentWidget = _buildFallback();
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // Top viewer bar
                CameraGlassSurface(
                  role: CameraGlassRole.header,
                  brightness: Brightness.dark,
                  borderRadius: BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CameraUiTokens.spacing8,
                      vertical: CameraUiTokens.spacing8,
                    ),
                    child: Row(
                      children: [
                        CameraGlassIconButton(
                          key: const ValueKey('viewer_close_button'),
                          icon: Icons.close,
                          label: 'shared.close'.tr(),
                          embedded: true,
                          iconColor: Colors.white,
                          iconSize: 28,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: CameraUiTokens.spacing8),
                        Expanded(
                          child: Text(
                            cameraName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Interactive zoomable image
                Expanded(
                  child: GestureDetector(
                    onDoubleTap: _handleDoubleTap,
                    child: Center(
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 1,
                        maxScale: 5,
                        clipBehavior: Clip.none,
                        child: contentWidget,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallback() {
    return const Center(
      child: Icon(
        Icons.videocam_outlined,
        color: Colors.white54,
        size: 64,
      ),
    );
  }
}
