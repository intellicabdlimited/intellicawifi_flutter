import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../repositories/firmware_repository.dart';
import '../viewmodels/router_viewmodel.dart';
import '../utils/ui_state.dart';
import '../utils/fw_upgrade_status_parser.dart';

class FirmwareUpgradeScreen extends StatefulWidget {
  const FirmwareUpgradeScreen({super.key});

  @override
  State<FirmwareUpgradeScreen> createState() => _FirmwareUpgradeScreenState();
}

class _FirmwareUpgradeScreenState extends State<FirmwareUpgradeScreen> {
  final FirmwareRepository _firmwareRepo = FirmwareRepository();
  UiState<XConfFirmwareInfo> _xconfState = UiState.loading();
  bool _upgradeInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadFirmwareInfo();
    _ensureRouterInfoLoaded();
  }

  void _ensureRouterInfoLoaded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<RouterViewModel>();
      if (viewModel.routerInfo.status != UiStatus.success) {
        viewModel.loadRouterInfo();
      }
    });
  }

  Future<void> _loadFirmwareInfo() async {
    setState(() => _xconfState = UiState.loading());
    try {
      final info = await _firmwareRepo.getXconfFirmwareInfo();
      if (mounted) setState(() => _xconfState = UiState.success(info));
    } catch (e) {
      if (mounted) setState(() => _xconfState = UiState.error(e.toString()));
    }
  }

  /// Refresh both XConf firmware info and current device software version.
  Future<void> _onRefresh() async {
    context.read<RouterViewModel>().loadRouterInfo();
    await _loadFirmwareInfo();
  }

  String _softwareVersion(BuildContext context) {
    final viewModel = context.watch<RouterViewModel>();
    final info = viewModel.routerInfo.data;
    return info?.softwareVersion ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Firmware upgrade"),
        actions: [
          if (_xconfState.status != UiStatus.loading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _upgradeInProgress ? null : _onRefresh,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: _buildContent(context),
            ),
          ),
          _buildUpgradeButtonSection(context),
        ],
      ),
    );
  }

  bool _isAlreadyUpToDate(BuildContext context) {
    if (_xconfState.status != UiStatus.success || _xconfState.data == null) return false;
    final remote = _xconfState.data!.displayFilename.trim();
    final current = _softwareVersion(context).trim();
    return remote.isNotEmpty && current.isNotEmpty && remote == current;
  }

  bool _canTriggerUpgrade(BuildContext context) {
    if (_upgradeInProgress ||
        _xconfState.status != UiStatus.success ||
        _xconfState.data == null ||
        _xconfState.data!.firmwareFilename.isEmpty ||
        _xconfState.data!.firmwareLocation.isEmpty) {
      return false;
    }
    return !_isAlreadyUpToDate(context);
  }

  Widget _buildUpgradeButtonSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = _canTriggerUpgrade(context);
    final isUpToDate = _isAlreadyUpToDate(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUpToDate)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Already on latest version",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: enabled ? () => _showUpgradeConfirmation(context) : null,
                icon: _upgradeInProgress
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.system_update_rounded,
                        size: 22,
                        color: enabled ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                label: Text(
                  _upgradeInProgress ? "Upgrading…" : "Upgrade Firmware",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: enabled ? AppTheme.primaryColor : colorScheme.surfaceContainerHighest,
                  foregroundColor: enabled ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.38),
                  disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                  disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
                  elevation: enabled ? 1 : 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showUpgradeProgressDialog(context),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text("Show Upgrade Progress"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUpgradeProgressDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _UpgradeProgressDialog(repository: _firmwareRepo),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_xconfState.status == UiStatus.loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_xconfState.status == UiStatus.error) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              "Could not load firmware info",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _xconfState.message ?? "Unknown error",
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadFirmwareInfo,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    final info = _xconfState.data!;
    return _buildFirmwareDetailsCard(context, info);
  }

  Widget _buildFirmwareDetailsCard(BuildContext context, XConfFirmwareInfo info) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.65);
    final softwareVersion = _softwareVersion(context);
    final remote = info.displayFilename.trim();
    final current = softwareVersion.trim();
    final versionsDiffer = remote.isNotEmpty && current.isNotEmpty && remote != current;
    final showReleaseNotes = versionsDiffer && info.info.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 26,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  "Firmware information",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoBlock(
              context,
              label: "Remote firmware version",
              value: info.displayFilename,
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
            const SizedBox(height: 20),
            _buildInfoBlock(
              context,
              label: "Current software version",
              value: softwareVersion,
            ),
            if (showReleaseNotes) ...[
              const SizedBox(height: 20),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              const SizedBox(height: 20),
              Text(
                "Release notes",
                style: theme.textTheme.titleSmall?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: SelectableText(
                  info.info.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Full-width block: heading on top, value below so long text can wrap.
  Widget _buildInfoBlock(BuildContext context, {required String label, required String value}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurface = colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: muted,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  void _showUpgradeConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Upgrade Firmware"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Keep the router plugged in. Do not unplug or power off during the upgrade.",
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 16),
            Text(
              "Start upgrade now?",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runFirmwareUpgrade(context);
            },
            child: const Text("Start upgrade"),
          ),
        ],
      ),
    );
  }

  Future<void> _runFirmwareUpgrade(BuildContext context) async {
    final info = _xconfState.data!;
    setState(() => _upgradeInProgress = true);

    try {
      final statusResult = await _firmwareRepo.fetchFirmwareUpgradeStatus();
      final status = statusResult.parsedStatus;
      if (status.state != FirmwareUpgradeState.idle &&
          status.state != FirmwareUpgradeState.failed) {
        throw Exception(
          "Current status is ${status.state.name}. ${status.userMessage}",
        );
      }
      final results = await _firmwareRepo.triggerFirmwareUpgrade(
        protocol: info.firmwareDownloadProtocol,
        location: info.firmwareLocation,
        filename: info.firmwareFilename,
      );
      if (!context.mounted) return;
      setState(() => _upgradeInProgress = false);
      final allOk = results.every((r) => r.success);
      if (!allOk) {
        throw Exception("One or more firmware trigger steps failed.");
      }
      _showUpgradeProgressDialog(context);
    } catch (e) {
      if (context.mounted) {
        setState(() => _upgradeInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upgrade failed: $e"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _UpgradeProgressDialog extends StatefulWidget {
  final FirmwareRepository repository;

  const _UpgradeProgressDialog({required this.repository});

  @override
  State<_UpgradeProgressDialog> createState() => _UpgradeProgressDialogState();
}

class _UpgradeProgressDialogState extends State<_UpgradeProgressDialog> {
  FirmwareStatusResult? _result;
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchStatus(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final result = await widget.repository.fetchFirmwareUpgradeStatus();
      if (!mounted) return;
      setState(() {
        _result = result;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: AppTheme.primaryColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upgrade progress',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                child: _loading && _result == null
                    ? _buildLoadingBody(context)
                    : _error != null
                        ? _buildErrorBody(context, _error!)
                        : _result != null
                            ? _buildStatusBody(context, _result!.parsedStatus)
                            : _buildLoadingBody(context),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.paddingOf(context).bottom * 0.25),
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                label: const Text('Close'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Contacting device…',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching firmware upgrade service status.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBody(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, color: scheme.error, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load status',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onErrorContainer,
                      ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBody(BuildContext context, FirmwareUpgradeStatus status) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stateColor = _stateAccentColor(context, status.state);
    final stateIcon = _stateIcon(status.state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                stateColor.withValues(alpha: 0.14),
                stateColor.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: stateColor.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: stateColor.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(stateIcon, color: stateColor, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stateTitle(status.state),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status.userMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (status.storageActivityHint != null &&
                  status.storageActivityHint!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.tips_and_updates_outlined,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status.storageActivityHint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Details',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        _statusDetailTile(
          context,
          icon: Icons.dns_rounded,
          label: 'Upgrade service',
          value: status.serviceRunning ? 'Running' : 'Not running',
          valueStyle: TextStyle(
            color: status.serviceRunning ? const Color(0xFF2E7D32) : scheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        _statusDetailTile(
          context,
          icon: Icons.cloud_download_rounded,
          label: 'TFTP download',
          value: status.tftpStarted ? 'Started' : 'Not started',
          valueStyle: TextStyle(
            color: status.tftpStarted ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        _statusDetailTile(
          context,
          icon: status.downloadSuccessful ? Icons.verified_rounded : Icons.hourglass_empty_rounded,
          label: 'Download',
          value: status.downloadSuccessful ? 'Successful' : 'Not completed',
          valueStyle: TextStyle(
            color: status.downloadSuccessful ? const Color(0xFF2E7D32) : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (status.imageFileName != null && status.imageFileName!.isNotEmpty)
          _statusDetailTile(
            context,
            icon: Icons.insert_drive_file_outlined,
            label: 'Image file',
            value: status.imageFileName!,
            valueMaxLines: 3,
          ),
        if (status.memoryMiB != null)
          _statusDetailTile(
            context,
            icon: Icons.memory_rounded,
            label: 'Memory use',
            value: '${status.memoryMiB!.toStringAsFixed(1)} MiB',
          ),
      ],
    );
  }

  Widget _statusDetailTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    TextStyle? valueStyle,
    int valueMaxLines = 2,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: scheme.primary.withValues(alpha: 0.85)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: valueMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.35,
                        color: scheme.onSurface,
                      ).merge(valueStyle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _stateTitle(FirmwareUpgradeState state) {
    switch (state) {
      case FirmwareUpgradeState.idle:
        return 'Status: Idle';
      case FirmwareUpgradeState.inProgress:
        return 'Status: In progress';
      case FirmwareUpgradeState.downloaded:
        return 'Status: Downloaded';
      case FirmwareUpgradeState.readyToReboot:
        return 'Status: Ready to reboot';
      case FirmwareUpgradeState.failed:
        return 'Status: Failed';
      case FirmwareUpgradeState.unknown:
        return 'Status: Unknown';
    }
  }

  IconData _stateIcon(FirmwareUpgradeState state) {
    switch (state) {
      case FirmwareUpgradeState.idle:
        return Icons.pause_circle_outline_rounded;
      case FirmwareUpgradeState.inProgress:
        return Icons.downloading_rounded;
      case FirmwareUpgradeState.downloaded:
        return Icons.download_done_rounded;
      case FirmwareUpgradeState.readyToReboot:
        return Icons.restart_alt_rounded;
      case FirmwareUpgradeState.failed:
        return Icons.error_outline_rounded;
      case FirmwareUpgradeState.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color _stateAccentColor(BuildContext context, FirmwareUpgradeState state) {
    final scheme = Theme.of(context).colorScheme;
    switch (state) {
      case FirmwareUpgradeState.idle:
        return scheme.onSurfaceVariant;
      case FirmwareUpgradeState.inProgress:
        return AppTheme.primaryColor;
      case FirmwareUpgradeState.downloaded:
        return const Color(0xFF2E7D32);
      case FirmwareUpgradeState.readyToReboot:
        return const Color(0xFFE65100);
      case FirmwareUpgradeState.failed:
        return scheme.error;
      case FirmwareUpgradeState.unknown:
        return scheme.outline;
    }
  }
}
