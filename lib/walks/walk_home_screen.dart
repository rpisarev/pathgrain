import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../platform/notification_permission.dart';
import 'walk_detail_screen.dart';
import 'walk_formatters.dart';
import 'walk_models.dart';
import 'walk_recording_controller.dart';
import 'walk_repository.dart';

class WalkHomeScreen extends StatefulWidget {
  const WalkHomeScreen({
    super.key,
    required this.controller,
    required this.repository,
  });

  final WalkRecordingController controller;
  final WalkRepository repository;

  @override
  State<WalkHomeScreen> createState() => _WalkHomeScreenState();
}

class _WalkHomeScreenState extends State<WalkHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localizations.appTitle)),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (widget.controller.phase == WalkRecordingPhase.initializing) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.controller.phase == WalkRecordingPhase.recording ||
                  widget.controller.phase == WalkRecordingPhase.stopping)
                _RecordingCard(controller: widget.controller, onStop: _stopWalk)
              else
                _StartCard(
                  controller: widget.controller,
                  onStart: _confirmAndStartWalk,
                ),
              if (widget.controller.problem != null) ...[
                const SizedBox(height: 12),
                _ProblemCard(
                  controller: widget.controller,
                  problem: widget.controller.problem!,
                ),
              ],
              const SizedBox(height: 24),
              Text(
                localizations.savedWalks,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (widget.controller.walks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(localizations.noSavedWalks),
                )
              else
                ...widget.controller.walks.map(_walkTile),
            ],
          );
        },
      ),
    );
  }

  Widget _walkTile(Walk walk) {
    final localizations = AppLocalizations.of(context);
    final localStart = walk.startedAt.toLocal();
    final materialLocalizations = MaterialLocalizations.of(context);
    final date = materialLocalizations.formatMediumDate(localStart);
    final time = materialLocalizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localStart),
    );
    final status = walk.status == WalkStatus.interrupted
        ? localizations.interruptedWalk
        : localizations.completedWalk;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.route_outlined),
        title: Text('$date · $time'),
        subtitle: Text(
          '$status · ${formatDuration(walk.duration)} · '
          '${formatDistance(localizations, walk.distanceMeters)} · '
          '${localizations.pointCount(walk.pointCount)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openWalk(walk),
      ),
    );
  }

  Future<void> _confirmAndStartWalk() async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.startExplanationTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.startExplanationBody),
            const SizedBox(height: 12),
            Text(localizations.startExplanationNotification),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations.continueAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await widget.controller.startWalk(
      notificationTitle: localizations.recordingNotificationTitle,
      notificationText: localizations.recordingNotificationText,
      notificationChannelName: localizations.recordingNotificationChannel,
    );
  }

  Future<void> _stopWalk() async {
    final walk = await widget.controller.stopWalk();
    if (!mounted || walk == null) {
      return;
    }
    await _openWalk(walk);
  }

  Future<void> _openWalk(Walk walk) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            WalkDetailScreen(walk: walk, repository: widget.repository),
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.controller, required this.onStart});

  final WalkRecordingController controller;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isStarting = controller.phase == WalkRecordingPhase.starting;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FilledButton.icon(
          onPressed: isStarting ? null : onStart,
          icon: isStarting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(
            isStarting ? localizations.startingWalk : localizations.startWalk,
          ),
        ),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.controller, required this.onStop});

  final WalkRecordingController controller;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isStopping = controller.phase == WalkRecordingPhase.stopping;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              localizations.activeWalk,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _LiveValue(
                    label: localizations.durationLabel,
                    value: formatDuration(controller.elapsed),
                  ),
                ),
                Expanded(
                  child: _LiveValue(
                    label: localizations.distanceLabel,
                    value: formatDistance(
                      localizations,
                      controller.activeDistanceMeters,
                    ),
                  ),
                ),
                Expanded(
                  child: _LiveValue(
                    label: localizations.pointsLabel,
                    value: controller.activePointCount.toString(),
                  ),
                ),
              ],
            ),
            if (controller.activePointCount == 0) ...[
              const SizedBox(height: 12),
              Text(localizations.waitingForGps),
            ],
            if (controller.hasReducedLocationAccuracy) ...[
              const SizedBox(height: 12),
              _InlineNotice(
                icon: Icons.location_disabled_outlined,
                text: localizations.preciseLocationRecommended,
              ),
            ],
            if (controller.notificationPermissionState ==
                    NotificationPermissionState.denied ||
                controller.notificationPermissionState ==
                    NotificationPermissionState.unavailable) ...[
              const SizedBox(height: 12),
              _InlineNotice(
                icon: Icons.notifications_off_outlined,
                text:
                    controller.notificationPermissionState ==
                        NotificationPermissionState.denied
                    ? localizations.notificationDeniedBody
                    : localizations.notificationUnavailableBody,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: isStopping ? null : onStop,
              icon: isStopping
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.stop),
              label: Text(
                isStopping
                    ? localizations.stoppingWalk
                    : localizations.stopWalk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.controller, required this.problem});

  final WalkRecordingController controller;
  final WalkRecordingProblem problem;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final message = switch (problem) {
      WalkRecordingProblem.locationServicesDisabled =>
        localizations.locationServicesDisabled,
      WalkRecordingProblem.locationPermissionDenied =>
        localizations.locationPermissionDenied,
      WalkRecordingProblem.locationPermissionDeniedForever =>
        localizations.locationPermissionDeniedForever,
      WalkRecordingProblem.recordingFailed => localizations.recordingFailed,
      WalkRecordingProblem.storageFailed => localizations.storageFailed,
    };
    final canOpenSettings =
        problem == WalkRecordingProblem.locationServicesDisabled ||
        problem == WalkRecordingProblem.locationPermissionDeniedForever;

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (canOpenSettings)
                  TextButton(
                    onPressed: () {
                      if (problem ==
                          WalkRecordingProblem.locationServicesDisabled) {
                        controller.openLocationSettings();
                      } else {
                        controller.openAppSettings();
                      }
                    },
                    child: Text(localizations.openSettings),
                  ),
                TextButton(
                  onPressed: controller.dismissProblem,
                  child: Text(localizations.dismiss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveValue extends StatelessWidget {
  const _LiveValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
