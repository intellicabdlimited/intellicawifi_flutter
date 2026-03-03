import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../repositories/firmware_repository.dart';
import '../viewmodels/router_viewmodel.dart';
import '../utils/ui_state.dart';

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
          ],
        ),
      ),
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
                  child: Icon(
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
      final results = await _firmwareRepo.triggerFirmwareUpgrade(
        protocol: info.firmwareDownloadProtocol,
        location: info.firmwareLocation,
        filename: info.firmwareFilename,
      );
      if (!mounted) return;
      setState(() => _upgradeInProgress = false);
      final ctx = context;
      _showUpgradeSuccessDialog(ctx, results);
    } catch (e) {
      if (mounted) {
        setState(() => _upgradeInProgress = false);
        final ctx = context;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text("Upgrade failed: $e"),
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showUpgradeSuccessDialog(BuildContext context, List<({String name, bool success})> results) {
    final allOk = results.every((r) => r.success);
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              allOk ? Icons.schedule_rounded : Icons.info_rounded,
              color: allOk ? theme.colorScheme.primary : theme.colorScheme.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(allOk ? "Please wait" : "Upgrade issue"),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (allOk) ...[
                const Text(
                  "The upgrade has been started. The device is now downloading and will apply the firmware. This may take several minutes.",
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Keep the router powered on. Do not unplug until the upgrade is complete. The device may reboot when done.",
                  style: TextStyle(height: 1.4, fontWeight: FontWeight.w500),
                ),
              ] else ...[
                const Text("Some steps did not complete. Details:"),
                const SizedBox(height: 8),
                ...results.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            r.success ? Icons.check_circle : Icons.cancel,
                            size: 18,
                            color: r.success ? Colors.green : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(r.name, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
