enum FirmwareUpgradeState {
  idle,
  inProgress,
  downloaded,
  readyToReboot,
  failed,
  unknown,
}

enum FirmwareUpgradeFailureType {
  none,
  tftpTimeout,
  remoteDownloadFailed,
  md5Failed,
  genericDownloadFailed,
  serviceNotRunning,
  unknown,
}

class FirmwareUpgradeStatus {
  final FirmwareUpgradeState state;
  final FirmwareUpgradeFailureType failureType;
  final String userMessage;
  final String? imageFileName;
  final double? memoryMiB;
  final String? storageActivityHint;
  final bool serviceRunning;
  final bool tftpStarted;
  final bool md5Verified;
  final bool downloadSuccessful;
  final bool rebootPhaseEntered;
  final DateTime? lastEventTime;

  const FirmwareUpgradeStatus({
    required this.state,
    required this.failureType,
    required this.userMessage,
    required this.imageFileName,
    required this.memoryMiB,
    required this.storageActivityHint,
    required this.serviceRunning,
    required this.tftpStarted,
    required this.md5Verified,
    required this.downloadSuccessful,
    required this.rebootPhaseEntered,
    required this.lastEventTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'state': state.name,
      'failureType': failureType.name,
      'userMessage': userMessage,
      'imageFileName': imageFileName,
      'memoryMiB': memoryMiB,
      'storageActivityHint': storageActivityHint,
      'serviceRunning': serviceRunning,
      'tftpStarted': tftpStarted,
      'md5Verified': md5Verified,
      'downloadSuccessful': downloadSuccessful,
      'rebootPhaseEntered': rebootPhaseEntered,
      'lastEventTime': lastEventTime?.toIso8601String(),
    };
  }
}

class FirmwareUpgradeStatusParser {
  static final RegExp _activeLineRegex = RegExp(r'^\s*Active:\s*(.+)$');
  static final RegExp _memoryRegex = RegExp(r'^\s*Memory:\s*([0-9.]+\w+)');
  static final RegExp _downloadFileRegex =
      RegExp(r'Download successful\.\s*File:\s*([^ ]+)');
  static final RegExp _tftpFileRegex =
      RegExp(r'Using TFTP:\s*tftp\s+-g\s+-r\s+([^ ]+)');
  static final RegExp _timestampRegex = RegExp(
    r'^(\d{4})\s+([A-Za-z]{3})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})',
  );
  static final RegExp _bzip2WordRegex = RegExp(r'\bbzip2\b');

  static FirmwareUpgradeStatus parse(String chunk) {
    final lines = chunk.split('\n');

    double? memoryMiB;
    DateTime? lastEventTime;

    bool serviceRunning = false;
    bool tftpStarted = false;
    bool tftpTimeout = false;
    bool md5Verified = false;
    bool md5Failed = false;
    bool rebootPhaseEntered = false;
    bool fileExistsInBootPart = false;
    bool remoteDownloadFailed = false;
    bool genericDownloadFailed = false;
    bool bzip2ProcessVisible = false;
    bool decompressedImageLogged = false;
    bool rootSwitchLogged = false;

    var lastUsingTftpLineIndex = -1;
    var lastTftpTimeoutLineIndex = -1;
    var lastDownloadSuccessLineIndex = -1;
    var lastFailureLineIndex = -1;
    String? lastSuccessImageFileName;
    String? lastTftpImageFileName;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final activeMatch = _activeLineRegex.firstMatch(line);
      if (activeMatch != null) {
        serviceRunning = line.toLowerCase().contains('active (running)');
      }

      final memMatch = _memoryRegex.firstMatch(line);
      if (memMatch != null) {
        memoryMiB = _parseMemoryToMiB(memMatch.group(1));
      }

      final successFileMatch = _downloadFileRegex.firstMatch(line);
      if (successFileMatch != null) {
        lastDownloadSuccessLineIndex = i;
        lastSuccessImageFileName = successFileMatch.group(1);
      }

      final tftpFileMatch = _tftpFileRegex.firstMatch(line);
      if (tftpFileMatch != null) {
        lastTftpImageFileName = tftpFileMatch.group(1);
      }

      final lower = line.toLowerCase();
      if (lower.contains('using tftp')) {
        tftpStarted = true;
        lastUsingTftpLineIndex = i;
        lastFailureLineIndex = -1;
      }
      if (lower.contains('tftp: timeout')) {
        tftpTimeout = true;
        lastTftpTimeoutLineIndex = i;
        lastFailureLineIndex = i;
      }
      if (lower.contains('md5 verified successfully')) md5Verified = true;
      if (lower.contains('md5') && lower.contains('fail')) {
        md5Failed = true;
        lastFailureLineIndex = i;
      }
      if (lower.contains('entering fwupgrade_hal_download_reboot_now')) {
        rebootPhaseEntered = true;
      }
      if (lower.contains('file /mnt/bootpart/') && lower.contains(' exists')) {
        fileExistsInBootPart = true;
      }
      if (lower.contains('download from remote server failed')) {
        remoteDownloadFailed = true;
        lastFailureLineIndex = i;
      }
      if (lower.contains('failed download the image')) {
        genericDownloadFailed = true;
        lastFailureLineIndex = i;
      }
      if (_bzip2WordRegex.hasMatch(line)) {
        bzip2ProcessVisible = true;
      }
      if (lower.contains('decompressed image at:')) {
        decompressedImageLogged = true;
      }
      if (lower.contains('switching to root') ||
          lower.contains('currently booted from root')) {
        rootSwitchLogged = true;
      }

      final tsMatch = _timestampRegex.firstMatch(line);
      if (tsMatch != null) {
        final parsed = _parseTimestamp(tsMatch);
        if (parsed != null &&
            (lastEventTime == null || parsed.isAfter(lastEventTime))) {
          lastEventTime = parsed;
        }
      }
    }

    final hasValidTftpSessionForDeclaredSuccess =
        lastTftpTimeoutLineIndex < 0 ||
            lastUsingTftpLineIndex > lastTftpTimeoutLineIndex;
    final downloadSuccessful = lastDownloadSuccessLineIndex >= 0 &&
        hasValidTftpSessionForDeclaredSuccess &&
        lastDownloadSuccessLineIndex > lastUsingTftpLineIndex &&
        lastDownloadSuccessLineIndex > lastFailureLineIndex;

    final imageFileName = downloadSuccessful
        ? (lastSuccessImageFileName ?? lastTftpImageFileName)
        : (lastTftpImageFileName ?? lastSuccessImageFileName);

    final failureType = _resolveFailureType(
      serviceRunning: serviceRunning,
      tftpTimeout: tftpTimeout,
      remoteDownloadFailed: remoteDownloadFailed,
      md5Failed: md5Failed,
      genericDownloadFailed: genericDownloadFailed,
    );

    final state = _resolveState(
      failureType: failureType,
      rebootPhaseEntered: rebootPhaseEntered,
      fileExistsInBootPart: fileExistsInBootPart,
      downloadSuccessful: downloadSuccessful,
      tftpStarted: tftpStarted,
      serviceRunning: serviceRunning,
      bzip2ProcessVisible: bzip2ProcessVisible,
      decompressedImageLogged: decompressedImageLogged,
      rootSwitchLogged: rootSwitchLogged,
    );

    final userMessage = _buildUserMessage(
      state,
      failureType,
      bzip2ProcessVisible: bzip2ProcessVisible,
      postDownloadProcessing: state == FirmwareUpgradeState.inProgress &&
          !bzip2ProcessVisible &&
          (rebootPhaseEntered || fileExistsInBootPart),
    );
    final storageActivityHint = _buildStorageActivityHint(
      memoryMiB: memoryMiB,
      tftpStarted: tftpStarted,
      downloadSuccessful: downloadSuccessful,
      rebootPhaseEntered: rebootPhaseEntered,
      fileExistsInBootPart: fileExistsInBootPart,
      bzip2ProcessVisible: bzip2ProcessVisible,
      decompressedImageLogged: decompressedImageLogged,
    );

    return FirmwareUpgradeStatus(
      state: state,
      failureType: failureType,
      userMessage: userMessage,
      imageFileName: imageFileName,
      memoryMiB: memoryMiB,
      storageActivityHint: storageActivityHint,
      serviceRunning: serviceRunning,
      tftpStarted: tftpStarted,
      md5Verified: md5Verified,
      downloadSuccessful: downloadSuccessful,
      rebootPhaseEntered: rebootPhaseEntered,
      lastEventTime: lastEventTime,
    );
  }

  static FirmwareUpgradeFailureType _resolveFailureType({
    required bool serviceRunning,
    required bool tftpTimeout,
    required bool remoteDownloadFailed,
    required bool md5Failed,
    required bool genericDownloadFailed,
  }) {
    if (!serviceRunning) return FirmwareUpgradeFailureType.serviceNotRunning;
    if (remoteDownloadFailed) {
      return FirmwareUpgradeFailureType.remoteDownloadFailed;
    }
    if (tftpTimeout) return FirmwareUpgradeFailureType.tftpTimeout;
    if (md5Failed) return FirmwareUpgradeFailureType.md5Failed;
    if (genericDownloadFailed) {
      return FirmwareUpgradeFailureType.genericDownloadFailed;
    }
    return FirmwareUpgradeFailureType.none;
  }

  static FirmwareUpgradeState _resolveState({
    required FirmwareUpgradeFailureType failureType,
    required bool rebootPhaseEntered,
    required bool fileExistsInBootPart,
    required bool downloadSuccessful,
    required bool tftpStarted,
    required bool serviceRunning,
    required bool bzip2ProcessVisible,
    required bool decompressedImageLogged,
    required bool rootSwitchLogged,
  }) {
    if (failureType != FirmwareUpgradeFailureType.none) {
      return FirmwareUpgradeState.failed;
    }
    if (bzip2ProcessVisible) {
      return FirmwareUpgradeState.inProgress;
    }
    final readyForRebootLogged =
        decompressedImageLogged || rootSwitchLogged;
    if (readyForRebootLogged) {
      return FirmwareUpgradeState.readyToReboot;
    }
    if (rebootPhaseEntered || fileExistsInBootPart) {
      return FirmwareUpgradeState.inProgress;
    }
    if (downloadSuccessful) return FirmwareUpgradeState.downloaded;
    if (tftpStarted) return FirmwareUpgradeState.inProgress;
    if (serviceRunning) return FirmwareUpgradeState.idle;
    return FirmwareUpgradeState.unknown;
  }

  static String _buildUserMessage(
    FirmwareUpgradeState state,
    FirmwareUpgradeFailureType failureType, {
    bool bzip2ProcessVisible = false,
    bool postDownloadProcessing = false,
  }) {
    if (state == FirmwareUpgradeState.failed) {
      switch (failureType) {
        case FirmwareUpgradeFailureType.tftpTimeout:
          return 'Firmware download failed: TFTP timeout.';
        case FirmwareUpgradeFailureType.remoteDownloadFailed:
          return 'Firmware download failed on device.';
        case FirmwareUpgradeFailureType.md5Failed:
          return 'Firmware verification failed (MD5).';
        case FirmwareUpgradeFailureType.genericDownloadFailed:
          return 'Firmware download failed.';
        case FirmwareUpgradeFailureType.serviceNotRunning:
          return 'Firmware upgrade service is not running.';
        case FirmwareUpgradeFailureType.unknown:
        case FirmwareUpgradeFailureType.none:
          return 'Firmware upgrade failed.';
      }
    }

    switch (state) {
      case FirmwareUpgradeState.readyToReboot:
        return 'Firmware image is ready; device will switch root / reboot when complete.';
      case FirmwareUpgradeState.downloaded:
        return 'Firmware downloaded successfully.';
      case FirmwareUpgradeState.inProgress:
        if (bzip2ProcessVisible) {
          return 'Firmware image is being decompressed (bzip2).';
        }
        if (postDownloadProcessing) {
          return 'Firmware downloaded; image processing in progress (not ready to reboot yet).';
        }
        return 'Firmware download is in progress.';
      case FirmwareUpgradeState.idle:
        return 'Firmware upgrade service is idle.';
      case FirmwareUpgradeState.unknown:
      case FirmwareUpgradeState.failed:
        return 'Firmware upgrade status is unknown.';
    }
  }

  static DateTime? _parseTimestamp(RegExpMatch m) {
    final year = int.tryParse(m.group(1)!);
    final monthText = m.group(2)!;
    final day = int.tryParse(m.group(3)!);
    final hour = int.tryParse(m.group(4)!);
    final minute = int.tryParse(m.group(5)!);
    final second = int.tryParse(m.group(6)!);

    final month = _monthFromShortName(monthText);
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }
    return DateTime.utc(year, month, day, hour, minute, second);
  }

  static int? _monthFromShortName(String m) {
    switch (m.toLowerCase()) {
      case 'jan':
        return 1;
      case 'feb':
        return 2;
      case 'mar':
        return 3;
      case 'apr':
        return 4;
      case 'may':
        return 5;
      case 'jun':
        return 6;
      case 'jul':
        return 7;
      case 'aug':
        return 8;
      case 'sep':
        return 9;
      case 'oct':
        return 10;
      case 'nov':
        return 11;
      case 'dec':
        return 12;
      default:
        return null;
    }
  }

  static double? _parseMemoryToMiB(String? memoryText) {
    if (memoryText == null || memoryText.isEmpty) return null;
    final match = RegExp(r'^([0-9]+(?:\.[0-9]+)?)([KMG])B?$')
        .firstMatch(memoryText.trim().toUpperCase());
    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);
    final unit = match.group(2)!;
    if (value == null) return null;

    switch (unit) {
      case 'K':
        return value / 1024.0;
      case 'M':
        return value;
      case 'G':
        return value * 1024.0;
      default:
        return null;
    }
  }

  static String? _buildStorageActivityHint({
    required double? memoryMiB,
    required bool tftpStarted,
    required bool downloadSuccessful,
    required bool rebootPhaseEntered,
    required bool fileExistsInBootPart,
    required bool bzip2ProcessVisible,
    required bool decompressedImageLogged,
  }) {
    if (bzip2ProcessVisible) {
      return 'bzip2 is running; .wic.bz2 is being decompressed to .wic on boot partition.';
    }
    if (decompressedImageLogged) {
      return 'Decompressed .wic reported in logs; root switch / reboot may follow.';
    }
    if (memoryMiB == null) return null;
    if (memoryMiB >= 256) {
      return 'High memory usage: likely image extraction/decompression in progress.';
    }
    if (rebootPhaseEntered || fileExistsInBootPart) {
      return 'Image is on boot partition; processing or decompression may still be running.';
    }
    if (downloadSuccessful) {
      return 'Download complete; post-download processing may be running.';
    }
    if (tftpStarted && memoryMiB >= 64) {
      return 'Download active with moderate memory usage.';
    }
    return 'Low memory usage; upgrade may be idle or early stage.';
  }
}
