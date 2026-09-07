import 'dart:io';

import 'app_path_service.dart';
import 'config_service.dart';
import 'database_service.dart';
import 'decrypt_service.dart';
import 'go_decrypt_ffi.dart';
import 'logger_service.dart';

/// 待增量更新的数据库文件快照。
class TrackedDbFile {
  TrackedDbFile({
    required this.originalPath,
    required this.fileName,
    required this.fileSize,
    required this.wxidName,
    required this.isDecrypted,
    required this.decryptedPath,
    this.originalModified,
    this.decryptedModified,
  });

  final String originalPath;
  final String fileName;
  final int fileSize;
  final String wxidName;
  final bool isDecrypted;
  final String decryptedPath;
  final DateTime? originalModified;
  final DateTime? decryptedModified;

  bool get needsUpdate {
    if (!isDecrypted) return false;
    if (originalModified == null || decryptedModified == null) return false;
    return originalModified!.isAfter(decryptedModified!);
  }
}

/// 一次增量解密的结果。
class IncrementalDecryptResult {
  const IncrementalDecryptResult({
    required this.scannedCount,
    required this.needsUpdateCount,
    required this.updatedCount,
    required this.failedCount,
    this.errorMessage,
  });

  final int scannedCount;
  final int needsUpdateCount;
  final int updatedCount;
  final int failedCount;
  final String? errorMessage;

  bool get hadChanges => updatedCount > 0;
  bool get ok => errorMessage == null;
}

/// 可注入的增量解密执行器（测试可替身，无需加载 decrypt.dll）。
abstract class IncrementalDecryptRunner {
  Future<IncrementalDecryptResult> runIncrementalUpdate({
    required DatabaseService databaseService,
    required Future<void> Function() reconnectDatabase,
    void Function(String status)? onStatus,
    void Function(int done, int total, String fileName)? onProgress,
    bool Function()? shouldCancel,
  });
}

/// 扫描微信源库并执行增量解密（与数据管理页逻辑对齐，可脱离页面调用）。
class IncrementalDecryptService implements IncrementalDecryptRunner {
  IncrementalDecryptService({
    ConfigService? configService,
    DecryptService? decryptService,
  })  : _config = configService ?? ConfigService(),
        _decryptOverride = decryptService;

  final ConfigService _config;
  final DecryptService? _decryptOverride;
  DecryptService? _decryptLazy;

  DecryptService get _decrypt =>
      _decryptOverride ?? (_decryptLazy ??= DecryptService());

  Future<List<TrackedDbFile>> scanFiles() async {
    final documentsDir = await AppPathService.getDocumentsDirectory(
      configService: _config,
    );
    final documentsPath = documentsDir.path;
    final systemDocumentsPath = await AppPathService.getSystemDocumentsPath();
    var configuredPath = await _config.getDatabasePath();
    final manualWxid = await _config.getManualWxid();

    if (configuredPath == null || configuredPath.isEmpty) {
      final homeDir = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          '';
      final candidates = <String>[
        if (homeDir.isNotEmpty)
          '$homeDir${Platform.pathSeparator}xwechat_files',
        '$systemDocumentsPath${Platform.pathSeparator}xwechat_files',
        if (homeDir.isNotEmpty)
          '$homeDir${Platform.pathSeparator}Documents${Platform.pathSeparator}WeChat Files',
      ];
      configuredPath = candidates.firstWhere(
        (path) => Directory(path).existsSync(),
        orElse: () => candidates.isNotEmpty
            ? candidates.first
            : '$systemDocumentsPath${Platform.pathSeparator}xwechat_files',
      );
    }

    final files = <TrackedDbFile>[];
    await _scanDatabasePath(
      configuredPath,
      documentsPath,
      files,
      manualWxid: manualWxid,
    );
    files.sort((a, b) => a.fileSize.compareTo(b.fileSize));
    return files;
  }

  /// 关闭数据库 → 增量解密需更新的文件 → 再通过 [reconnectDatabase] 重连。
  ///
  /// 若扫描后无需更新，不关闭连接，直接返回 [hadChanges]=false。
  @override
  Future<IncrementalDecryptResult> runIncrementalUpdate({
    required DatabaseService databaseService,
    required Future<void> Function() reconnectDatabase,
    void Function(String status)? onStatus,
    void Function(int done, int total, String fileName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    bool cancelled() => shouldCancel?.call() ?? false;

    onStatus?.call('扫描数据库文件…');
    final all = await scanFiles();
    if (cancelled()) {
      return const IncrementalDecryptResult(
        scannedCount: 0,
        needsUpdateCount: 0,
        updatedCount: 0,
        failedCount: 0,
        errorMessage: '已取消',
      );
    }

    final filesToUpdate = all.where((f) => f.needsUpdate).toList();
    if (filesToUpdate.isEmpty) {
      onStatus?.call('所有文件都是最新的');
      return IncrementalDecryptResult(
        scannedCount: all.length,
        needsUpdateCount: 0,
        updatedCount: 0,
        failedCount: 0,
      );
    }

    final key = await _config.getDecryptKey();
    if (key == null || key.isEmpty) {
      return IncrementalDecryptResult(
        scannedCount: all.length,
        needsUpdateCount: filesToUpdate.length,
        updatedCount: 0,
        failedCount: 0,
        errorMessage: '请先在设置页面配置密钥',
      );
    }

    onStatus?.call('关闭数据库连接…');
    await databaseService.close();
    await Future.delayed(const Duration(milliseconds: 1000));
    await databaseService.close();
    await Future.delayed(const Duration(milliseconds: 2000));

    final goFfi = GoDecryptFFI();
    for (final file in filesToUpdate) {
      try {
        goFfi.closeSelfFileHandles(file.originalPath);
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 500));

    var updated = 0;
    var failed = 0;
    for (var i = 0; i < filesToUpdate.length; i++) {
      if (cancelled()) break;
      final file = filesToUpdate[i];
      onStatus?.call('解密 ${file.fileName} (${i + 1}/${filesToUpdate.length})');
      onProgress?.call(i, filesToUpdate.length, file.fileName);
      try {
        final decryptedPath = await _decrypt.decryptDatabase(
          file.originalPath,
          key,
          (_, __) {},
        );
        await _replaceDecryptedFile(file, decryptedPath, goFfi);
        updated++;
        onProgress?.call(i + 1, filesToUpdate.length, file.fileName);
      } catch (e, st) {
        failed++;
        await logger.error(
          'IncrementalDecryptService',
          '增量更新失败: ${file.fileName}',
          e,
          st,
        );
      }
    }

    onStatus?.call('等待文件系统稳定…');
    await Future.delayed(const Duration(milliseconds: 2500));
    onStatus?.call('重新连接数据库…');
    try {
      await reconnectDatabase();
    } catch (e, st) {
      await logger.error(
        'IncrementalDecryptService',
        '重新连接数据库失败',
        e,
        st,
      );
      return IncrementalDecryptResult(
        scannedCount: all.length,
        needsUpdateCount: filesToUpdate.length,
        updatedCount: updated,
        failedCount: failed,
        errorMessage: '重新连接数据库失败: $e',
      );
    }

    return IncrementalDecryptResult(
      scannedCount: all.length,
      needsUpdateCount: filesToUpdate.length,
      updatedCount: updated,
      failedCount: failed,
    );
  }

  Future<void> _replaceDecryptedFile(
    TrackedDbFile file,
    String decryptedPath,
    GoDecryptFFI goFfi,
  ) async {
    final targetFile = File(file.decryptedPath);
    if (await targetFile.exists()) {
      var deleteSucceeded = false;
      for (var i = 0; i < 10; i++) {
        try {
          await targetFile.delete();
          deleteSucceeded = true;
          break;
        } catch (_) {
          if (i < 9) {
            await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
          }
        }
      }
      if (!deleteSucceeded && await targetFile.exists()) {
        try {
          goFfi.forceUnlockFile(file.decryptedPath);
          await Future.delayed(const Duration(milliseconds: 500));
          await targetFile.delete();
          deleteSucceeded = true;
        } catch (_) {}
      }
      if (!deleteSucceeded && await targetFile.exists()) {
        final oldPath =
            '${file.decryptedPath}.old.${DateTime.now().millisecondsSinceEpoch}';
        try {
          await targetFile.rename(oldPath);
        } catch (_) {}
      }
    }
    await File(decryptedPath).copy(file.decryptedPath);
    try {
      await File(decryptedPath).delete();
    } catch (_) {}
  }

  Future<void> _scanDatabasePath(
    String basePath,
    String documentsPath,
    List<TrackedDbFile> out, {
    String? manualWxid,
  }) async {
    final baseDir = Directory(basePath);
    if (!await baseDir.exists()) return;

    final pathParts = basePath.split(Platform.pathSeparator);
    final lastPart = pathParts.isNotEmpty ? pathParts.last : '';
    final normalizedManual = _normalizeWxid(manualWxid);

    if (lastPart == 'db_storage') {
      var accountName = 'unknown';
      if (pathParts.length >= 2) {
        accountName = _cleanAccountDirName(pathParts[pathParts.length - 2]);
      }
      if (normalizedManual != null &&
          _normalizeWxid(accountName) != normalizedManual) {
        return;
      }
      await _scanDbStorageDirectory(baseDir, accountName, documentsPath, out);
      return;
    }

    var foundAnyAccount = false;
    await for (final entity in baseDir.list()) {
      if (entity is! Directory) continue;
      final accountDirName = entity.path.split(Platform.pathSeparator).last;
      final cleanedAccountName = _cleanAccountDirName(accountDirName);
      if (normalizedManual != null &&
          _normalizeWxid(cleanedAccountName) != normalizedManual) {
        continue;
      }
      final dbStorageDir = Directory(
        '${entity.path}${Platform.pathSeparator}db_storage',
      );
      if (await dbStorageDir.exists()) {
        foundAnyAccount = true;
        await _scanDbStorageDirectory(
          dbStorageDir,
          cleanedAccountName,
          documentsPath,
          out,
        );
      }
    }

    if (!foundAnyAccount &&
        manualWxid != null &&
        manualWxid.isNotEmpty) {
      await for (final entity in baseDir.list()) {
        if (entity is! Directory) continue;
        final dbStorageDir = Directory(
          '${entity.path}${Platform.pathSeparator}db_storage',
        );
        if (!await dbStorageDir.exists()) continue;
        final dirName = entity.path.split(Platform.pathSeparator).last;
        if (normalizedManual != null &&
            _normalizeWxid(dirName) != normalizedManual) {
          continue;
        }
        await _scanDbStorageDirectory(
          dbStorageDir,
          manualWxid,
          documentsPath,
          out,
        );
        break;
      }
    }
  }

  Future<void> _scanDbStorageDirectory(
    Directory dbStorageDir,
    String accountName,
    String documentsPath,
    List<TrackedDbFile> out,
  ) async {
    final dbFiles = await _findAllDbFiles(dbStorageDir);
    for (final dbFile in dbFiles) {
      final fileName = dbFile.path.split(Platform.pathSeparator).last;
      final fileSize = await dbFile.length();
      final originalModified = (await dbFile.stat()).modified;
      final ourWorkDir = Directory(
        '$documentsPath${Platform.pathSeparator}EchoTrace',
      );
      final decryptedFileName = '${fileName.split('.').first}.db';
      final decryptedFilePath =
          '${ourWorkDir.path}${Platform.pathSeparator}$accountName${Platform.pathSeparator}$decryptedFileName';
      final decryptedFile = File(decryptedFilePath);
      final isDecrypted = await decryptedFile.exists();
      DateTime? decryptedModified;
      if (isDecrypted) {
        decryptedModified = (await decryptedFile.stat()).modified;
      }
      out.add(
        TrackedDbFile(
          originalPath: dbFile.path,
          fileName: fileName,
          fileSize: fileSize,
          wxidName: accountName,
          isDecrypted: isDecrypted,
          decryptedPath: decryptedFilePath,
          originalModified: originalModified,
          decryptedModified: decryptedModified,
        ),
      );
    }
  }

  Future<List<File>> _findAllDbFiles(Directory dir) async {
    final dbFiles = <File>[];
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.db')) {
          dbFiles.add(entity);
        }
      }
    } catch (_) {}
    return dbFiles;
  }

  String _cleanAccountDirName(String dirName) {
    final trimmed = dirName.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.toLowerCase().startsWith('wxid_')) {
      final match =
          RegExp(r'^(wxid_[^_]+)', caseSensitive: false).firstMatch(trimmed);
      if (match != null) return match.group(1)!;
      return trimmed;
    }
    final suffixMatch = RegExp(r'^(.+)_([a-zA-Z0-9]{4})$').firstMatch(trimmed);
    if (suffixMatch != null) return suffixMatch.group(1)!;
    return trimmed;
  }

  String? _normalizeWxid(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.toLowerCase().startsWith('wxid_')) {
      final suffixMatch =
          RegExp(r'^(.+)_([a-zA-Z0-9]{4})$').firstMatch(trimmed);
      if (suffixMatch != null) return suffixMatch.group(1);
      return trimmed;
    }
    final match =
        RegExp(r'^(wxid_[^_]+)', caseSensitive: false).firstMatch(trimmed);
    if (match != null) return match.group(1)!.toLowerCase();
    return trimmed.toLowerCase();
  }
}
