import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/camera/camera_preview_source.dart';
import '../../domain/entities/camera_error.dart';
import '../../domain/entities/camera_geometry.dart';
import '../../domain/entities/camera_lifecycle_signal.dart';
import '../../domain/entities/focus_request.dart';
import '../../domain/entities/zoom_preset.dart';
import '../batch/batch_cubit.dart';
import '../batch/batch_state.dart';
import '../platform/app_settings_launcher.dart';
import '../theme/app_motion.dart';
import '../theme/camera_palette.dart';
import '../uploads/sync_bloc.dart';
import '../uploads/sync_event.dart';
import '../uploads/sync_state.dart';
import '../uploads/upload_manager_screen.dart';
import 'camera_cubit.dart';
import 'camera_state.dart';
import 'widgets/camera_controls.dart';
import 'widgets/camera_status_panel.dart';
import 'widgets/focus_reticle.dart';
import 'widgets/zoom_controls.dart';

/// The application's primary surface: a full-bleed viewfinder with its controls
/// floating over it (`FLT-CAM-001`, `FLT-CAM-002`).
///
/// **There is no close control, and that is a decision rather than an omission**
/// (`ADR-F13`, `UX_SPEC.md` §3.1). An X over a live preview beside a batch of
/// unsaved captures can be read as "discard this batch" as easily as "leave",
/// and three of the four available readings are destructive. This screen is also
/// the launch destination — there is nothing behind it to return to. Navigation
/// is one-way outward, to Pending Uploads and back.
///
/// **The draft batch is never discarded by navigation.** Captures are durable on
/// the filesystem and in SQLite before this widget hears about them, so leaving,
/// backgrounding, or being killed costs nothing (`FLT-CAM-015`).
///
/// **Android back.** The camera is the root route, so the system back gesture
/// leaves the application, which is what an Android launch surface should do.
/// It is deliberately not intercepted: there is no unsaved work to guard, and a
/// confirmation dialog over a viewfinder would imply there is.
class CameraPreviewScreen extends StatefulWidget {
  /// Creates the screen.
  const CameraPreviewScreen({this.settingsLauncher, super.key});

  /// How "Open settings" reaches the OS.
  ///
  /// Injected so the recovery path can be exercised without a platform channel;
  /// the app supplies [MethodChannelAppSettingsLauncher].
  final AppSettingsLauncher? settingsLauncher;

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: AppMotion.quick,
  );
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: AppMotion.deliberate,
  );

  Offset? _reticleAt;
  bool _reticleVisible = false;
  Timer? _reticleHoldTimer;
  Timer? _reticleRemoveTimer;
  String? _lastSeenCaptureId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The camera plugin has not owned lifecycle since 0.5.0, so the app does
    // (`FLT-CAM-012`). The widget's only job is the translation; every decision
    // about what to release and when lives in the cubit, where it is testable.
    unawaited(context.read<CameraCubit>().acquire());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraLifecycleSignal signal = switch (state) {
      AppLifecycleState.resumed => CameraLifecycleSignal.resumed,
      AppLifecycleState.inactive => CameraLifecycleSignal.inactive,
      AppLifecycleState.paused ||
      AppLifecycleState.hidden => CameraLifecycleSignal.paused,
      AppLifecycleState.detached => CameraLifecycleSignal.detached,
    };
    unawaited(context.read<CameraCubit>().handleLifecycle(signal));

    if (state == AppLifecycleState.resumed) {
      // The resume half of `FLT-SYNC-012`: work left behind — including work
      // whose drain request was refused — is found and rescheduled here rather
      // than waiting for the user to do something (`RS-11`).
      context.read<SyncBloc>().add(const SyncResumed());
    }
  }

  @override
  void dispose() {
    _reticleHoldTimer?.cancel();
    _reticleRemoveTimer?.cancel();
    _flash.dispose();
    _travel.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CameraPalette.panel,
      body: BlocConsumer<CameraCubit, CameraState>(
        listenWhen: (CameraState previous, CameraState current) =>
            current is CameraReady,
        listener: _onCameraState,
        builder: (BuildContext context, CameraState state) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _body(context, state),
              // The chrome is drawn over every state, broken ones included, so
              // the queue is reachable from all of them.
              _TopChrome(
                onOpenUploads: () => _openUploads(context),
                showOffline: _shouldShowOffline(context),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // States
  // ---------------------------------------------------------------------------

  Widget _body(BuildContext context, CameraState state) {
    switch (state) {
      case CameraInitial():
      case CameraPreparing():
      case CameraReleased():
        return CameraStatusPanel(
          isBusy: true,
          icon: Icons.photo_camera_outlined,
          title: _preparingTitle(state),
          message: 'One moment.',
        );

      case CameraReady():
        return _ReadyLayer(
          state: state,
          reticleAt: _reticleAt,
          reticleVisible: _reticleVisible,
          flash: _flash,
          travel: _travel,
          onTapFocus: _focusAt,
          onPinchStart: () => context.read<CameraCubit>().beginPinch(),
          onPinchUpdate: (double scale) =>
              unawaited(context.read<CameraCubit>().updatePinch(scale)),
          onPinchEnd: () => context.read<CameraCubit>().endPinch(),
          onZoom: (double value) =>
              unawaited(context.read<CameraCubit>().setZoom(value)),
          onPreset: (ZoomPreset preset) =>
              unawaited(context.read<CameraCubit>().applyPreset(preset)),
          onCapture: () => unawaited(context.read<CameraCubit>().capture()),
          onSwitchCamera: () =>
              unawaited(context.read<CameraCubit>().switchToNextCamera()),
          onFinishBatch: () => unawaited(_finishBatch(context)),
          onOpenUploads: () => _openUploads(context),
        );

      case CameraPermissionDenied(
        :final bool canRetry,
        :final int consecutiveDenials,
      ):
        return CameraStatusPanel(
          icon: Icons.no_photography_outlined,
          title: 'Camera access is off',
          message: canRetry
              ? 'PresenceLens needs the camera to take photos.'
              : 'PresenceLens needs the camera to take photos. You can turn '
                    'access back on in Settings.',
          reassurance: _queuedReassurance(context),
          primaryAction: canRetry
              ? CameraPanelAction(
                  label: 'Allow camera',
                  icon: Icons.photo_camera_outlined,
                  onPressed: () =>
                      unawaited(context.read<CameraCubit>().retry()),
                )
              : CameraPanelAction(
                  label: 'Open settings',
                  icon: Icons.settings_outlined,
                  onPressed: () => unawaited(_openSettings()),
                ),
          // **Escalation of what is offered, never a claim about the verdict**
          // (`ADR-F22`). Android reports one denial code and no permanent
          // variant, so the app counts refusals and widens its offer; it does
          // not decide that the OS said no forever.
          secondaryAction: canRetry && consecutiveDenials >= 2
              ? CameraPanelAction.secondary(
                  label: 'Open settings',
                  onPressed: () => unawaited(_openSettings()),
                )
              : null,
        );

      case CameraUnavailable(:final CameraUnavailableReason reason):
        return CameraStatusPanel(
          icon: Icons.videocam_off_outlined,
          title: reason == CameraUnavailableReason.noBackCamera
              ? 'No rear camera'
              : 'No camera found',
          message: reason == CameraUnavailableReason.noBackCamera
              ? 'This device has no rear-facing camera, so captures are not '
                    'possible here.'
              : 'This device did not report a usable camera.',
          reassurance: _queuedReassurance(context),
        );

      case CameraFailed(:final CameraFailure failure):
        return CameraStatusPanel(
          icon: Icons.error_outline,
          title: failure.kind == CameraErrorKind.cameraUnavailable
              ? "Camera isn't available"
              : "Camera didn't start",
          // The plugin's own message is deliberately not shown. An exception
          // string is not copy (`§34`).
          message: 'Another app may be using the camera. Try again.',
          reassurance: _queuedReassurance(context),
          primaryAction: CameraPanelAction(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: () => unawaited(context.read<CameraCubit>().retry()),
          ),
        );
    }
  }

  static String _preparingTitle(CameraState state) {
    if (state is! CameraPreparing) {
      return 'Reopening the camera';
    }
    return switch (state.phase) {
      CameraPreparingPhase.discovering => 'Finding your cameras',
      CameraPreparingPhase.initializing => 'Starting the camera',
      CameraPreparingPhase.switching => 'Switching camera',
      CameraPreparingPhase.restoring => 'Reopening the camera',
    };
  }

  /// The sentence that keeps a broken camera from looking like lost work.
  String? _queuedReassurance(BuildContext context) {
    final int pending = context.watch<SyncBloc>().state.pendingCount;
    if (pending == 0) {
      return null;
    }
    return pending == 1
        ? 'Your 1 queued photo is safe'
        : 'Your $pending queued photos are safe';
  }

  bool _shouldShowOffline(BuildContext context) {
    final SyncState sync = context.watch<SyncBloc>().state;
    // Only when there is something queued *and* no link. Offline with an empty
    // queue is not news.
    return !sync.hasLink && sync.hasPendingWork;
  }

  // ---------------------------------------------------------------------------
  // Interaction
  // ---------------------------------------------------------------------------

  void _onCameraState(BuildContext context, CameraState state) {
    if (state is! CameraReady) {
      return;
    }
    final String? captureId = state.lastCaptureImageId;
    if (captureId == null || captureId == _lastSeenCaptureId) {
      return;
    }
    _lastSeenCaptureId = captureId;

    // The signature sequence, and it runs **only on a successful capture**: the
    // motion asserts that the image reached durable storage, so playing it on a
    // failed write would be a lie (`UX_SPEC.md` §7.1).
    unawaited(HapticFeedback.lightImpact());
    if (AppMotion.isReduced(context)) {
      // Reduced motion removes the movement, not the meaning. The count still
      // increments and the thumbnail still updates; nothing travels.
      return;
    }
    unawaited(_flash.forward(from: 0).then((void _) => _flash.reverse()));
    unawaited(_travel.forward(from: 0));
  }

  void _focusAt(Offset local, PreviewLayout layout) {
    unawaited(
      context.read<CameraCubit>().focusAt(
        tapX: local.dx,
        tapY: local.dy,
        layout: layout,
      ),
    );

    // Positioned in **widget** coordinates, at the point the finger actually
    // landed. Mapping the normalised point back through the preview geometry
    // would put the ring near the tap rather than on it.
    _reticleHoldTimer?.cancel();
    _reticleRemoveTimer?.cancel();
    setState(() {
      _reticleAt = local;
      _reticleVisible = true;
    });

    // The lifecycle `FLT-CAM-010` asks for: appear, hold, dismiss. Reduced
    // motion lengthens the hold and drops the fade, so the ring is still shown
    // and still legible — feedback survives, movement does not (`RU-03`).
    final bool reduced = AppMotion.isReduced(context);
    final Duration hold = reduced
        ? AppMotion.reticleHoldReduced
        : AppMotion.reticleHold;
    final Duration fade = reduced ? Duration.zero : AppMotion.standard;
    _reticleHoldTimer = Timer(hold, () {
      if (mounted) {
        setState(() => _reticleVisible = false);
      }
    });
    _reticleRemoveTimer = Timer(hold + fade, () {
      if (mounted) {
        setState(() => _reticleAt = null);
      }
    });
  }

  Future<void> _finishBatch(BuildContext context) async {
    final BatchCubit batch = context.read<BatchCubit>();
    final SyncBloc sync = context.read<SyncBloc>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final String? finished = await batch.finish();
    if (finished == null) {
      if (batch.state.failure == BatchActionFailure.finishFailed) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't finish the batch. Your photos are safe."),
          ),
        );
        batch.acknowledgeFailure();
      }
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    sync.add(const SyncBatchFinished());
  }

  Future<void> _openSettings() async {
    final AppSettingsLauncher launcher =
        widget.settingsLauncher ?? const MethodChannelAppSettingsLauncher();
    final bool opened = await launcher.openAppSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open settings on this device.")),
      );
    }
  }

  void _openUploads(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) => const UploadManagerScreen(),
        ),
      ),
    );
  }
}

/// The always-present top chrome: offline hint on the left, uploads on the right.
class _TopChrome extends StatelessWidget {
  const _TopChrome({required this.onOpenUploads, required this.showOffline});

  final VoidCallback onOpenUploads;
  final bool showOffline;

  @override
  Widget build(BuildContext context) {
    final int pending = context.watch<SyncBloc>().state.pendingCount;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: CameraPalette.topScrim),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if (showOffline)
                  const CameraOfflineChip()
                else
                  const SizedBox(height: 48),
                UploadsEntry(pendingCount: pending, onPressed: onOpenUploads),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything drawn while the camera is live.
class _ReadyLayer extends StatelessWidget {
  const _ReadyLayer({
    required this.state,
    required this.reticleAt,
    required this.reticleVisible,
    required this.flash,
    required this.travel,
    required this.onTapFocus,
    required this.onPinchStart,
    required this.onPinchUpdate,
    required this.onPinchEnd,
    required this.onZoom,
    required this.onPreset,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onFinishBatch,
    required this.onOpenUploads,
  });

  final CameraReady state;
  final Offset? reticleAt;
  final bool reticleVisible;
  final AnimationController flash;
  final AnimationController travel;
  final void Function(Offset local, PreviewLayout layout) onTapFocus;
  final VoidCallback onPinchStart;
  final ValueChanged<double> onPinchUpdate;
  final VoidCallback onPinchEnd;
  final ValueChanged<double> onZoom;
  final ValueChanged<ZoomPreset> onPreset;
  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final VoidCallback onFinishBatch;
  final VoidCallback onOpenUploads;

  @override
  Widget build(BuildContext context) {
    final BatchState batch = context.watch<BatchCubit>().state;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size box = Size(constraints.maxWidth, constraints.maxHeight);
        // The UI supplies the geometry; the engine never guesses it, and no
        // prototype dimension is hard-coded anywhere (`ADR-F23`).
        final PreviewLayout layout = PreviewLayout(
          widgetWidth: box.width,
          widgetHeight: box.height,
          previewAspectRatio:
              state.capabilities.previewAspectRatio ??
              (box.height == 0 ? 1 : box.width / box.height),
        );

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) =>
                  onTapFocus(details.localPosition, layout),
              onScaleStart: (ScaleStartDetails _) => onPinchStart(),
              onScaleUpdate: (ScaleUpdateDetails details) =>
                  onPinchUpdate(details.scale),
              onScaleEnd: (ScaleEndDetails _) => onPinchEnd(),
              child: Semantics(
                label: 'Camera preview. Double tap to focus.',
                image: true,
                child: buildCameraPreview(
                  state.session,
                  placeholder: const ColoredBox(color: Color(0xFF0B0F11)),
                ),
              ),
            ),
            if (reticleAt != null)
              Positioned(
                left: reticleAt!.dx - FocusReticle.diameter / 2,
                top: reticleAt!.dy - FocusReticle.diameter / 2,
                child: AnimatedOpacity(
                  opacity: reticleVisible ? 1 : 0,
                  duration: AppMotion.resolve(context, AppMotion.standard),
                  child: FocusReticle(
                    key: ValueKey<int>(state.focusRequest?.sequence ?? 0),
                    request:
                        state.focusRequest ??
                        const FocusRequest(
                          sequence: 0,
                          point: NormalizedPoint.center,
                          outcome: FocusOutcome.pending,
                        ),
                  ),
                ),
              ),
            _CaptureFlash(controller: flash),
            _CaptureTravel(controller: travel, box: box),
            _BottomChrome(
              state: state,
              batch: batch,
              onZoom: onZoom,
              onPreset: onPreset,
              onCapture: onCapture,
              onSwitchCamera: onSwitchCamera,
              onFinishBatch: onFinishBatch,
              onOpenUploads: onOpenUploads,
            ),
          ],
        );
      },
    );
  }
}

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.state,
    required this.batch,
    required this.onZoom,
    required this.onPreset,
    required this.onCapture,
    required this.onSwitchCamera,
    required this.onFinishBatch,
    required this.onOpenUploads,
  });

  final CameraReady state;
  final BatchState batch;
  final ValueChanged<double> onZoom;
  final ValueChanged<ZoomPreset> onPreset;
  final VoidCallback onCapture;
  final VoidCallback onSwitchCamera;
  final VoidCallback onFinishBatch;
  final VoidCallback onOpenUploads;

  @override
  Widget build(BuildContext context) {
    final bool adjustable = state.zoomRange.isAdjustable;
    return Stack(
      children: <Widget>[
        if (adjustable)
          Positioned(
            right: 4,
            bottom: 260,
            child: ZoomSlider(
              range: state.zoomRange,
              value: state.currentZoom,
              onChanged: onZoom,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: CameraPalette.bottomScrim,
            ),
            child: SafeArea(
              top: false,
              child: MediaQuery.withClampedTextScaling(
                // Camera labels are capped so a large accessibility setting
                // cannot push the preset row up over the preview
                // (`UX_SPEC.md` §2.3).
                maxScaleFactor: 1.3,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (adjustable)
                        ZoomPresetRow(
                          presets: state.presets,
                          currentZoom: state.currentZoom,
                          onSelected: onPreset,
                        ),
                      if (batch.hasCaptures) ...<Widget>[
                        const SizedBox(height: 12),
                        _FinishBatchAction(
                          count: batch.imageCount,
                          isBusy: batch.isFinishing,
                          onPressed: onFinishBatch,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            BatchThumbnail(
                              count: batch.imageCount,
                              imagePath: batch.latestCapture?.localPath,
                              onTap: onOpenUploads,
                            ),
                            ShutterButton(
                              isCapturing: state.isCapturing,
                              onPressed: onCapture,
                            ),
                            CameraSelectorButton(
                              cameras: state.backCameras,
                              current: state.device,
                              // Refused mid-capture: switching would dispose
                              // the controller the photograph is being taken on.
                              onNext: state.isCapturing ? null : onSwitchCamera,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Finish batch (n)" — a completion mark, never a send glyph (`ADR-F14`).
///
/// Pressing it is a purely local, durable act: it closes the batch, moves its
/// images to `PENDING` in one transaction, and asks the OS to schedule a drain.
/// **It works, and is offered, while the device is offline** — which is why the
/// label must not promise a transfer.
class _FinishBatchAction extends StatelessWidget {
  const _FinishBatchAction({
    required this.count,
    required this.isBusy,
    required this.onPressed,
  });

  final int count;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isBusy,
      label: 'Finish batch',
      value: count == 1 ? '1 photo' : '$count photos',
      child: ExcludeSemantics(
        child: FilledButton.icon(
          onPressed: isBusy ? null : onPressed,
          icon: const Icon(Icons.check_rounded, size: 20),
          label: Text('Finish batch ($count)'),
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(const Size(0, 48)),
            backgroundColor: WidgetStateProperty.all(CameraPalette.accent),
            foregroundColor: WidgetStateProperty.all(const Color(0xFF06231B)),
          ),
        ),
      ),
    );
  }
}

class _CaptureFlash extends StatelessWidget {
  const _CaptureFlash({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          if (controller.value == 0) {
            return const SizedBox.shrink();
          }
          return ColoredBox(
            color: Colors.white.withValues(alpha: 0.3 * controller.value),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

/// Step ⑥ of the signature sequence: the captured frame contracting into the
/// batch stack (`UX_SPEC.md` §7.1).
///
/// It exists to make the shutter press and the count increment read as **one**
/// causal event rather than two unrelated ones separated by the ~400 ms of real
/// work that persists the file and inserts the row. It is fire-and-forget: it
/// never blocks a second capture, and the badge increments on the database
/// write, not on this animation.
class _CaptureTravel extends StatelessWidget {
  const _CaptureTravel({required this.controller, required this.box});

  final AnimationController controller;
  final Size box;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          if (controller.value == 0 || controller.value == 1) {
            return const SizedBox.shrink();
          }
          // Straight, decelerating travel. No arc, no overshoot: an arc reads
          // as decoration, and this is a statement about where the file went.
          final double t = Curves.easeInOutCubic.transform(controller.value);
          final Offset from = Offset(box.width / 2, box.height / 2);
          final Offset to = Offset(
            24 + BatchThumbnail.size / 2,
            box.height - 108,
          );
          final Offset at = Offset.lerp(from, to, t)!;
          final double side = 180 - (128 * t);
          return Stack(
            children: <Widget>[
              Positioned(
                left: at.dx - side / 2,
                top: at.dy - side / 2,
                child: Opacity(
                  opacity: 1 - (t * 0.35),
                  child: Container(
                    width: side,
                    height: side,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: CameraPalette.control.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
