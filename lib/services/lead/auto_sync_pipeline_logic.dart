/// 自动同步管线中「解密之后是否抓取」的决策（纯函数，便于单测）。
enum CaptureDecision {
  /// 库有变更且已选监控群 → 抓取已选群
  captureSelected,

  /// 无库变更 → 跳过抓取，直接冷却
  skipNoDbChange,

  /// 库有变更但未选群 → 跳过抓取
  skipNoSelection,
}

CaptureDecision decideCaptureAfterDecrypt({
  required bool hadDbChanges,
  required bool hasSelectedGroups,
}) {
  if (!hadDbChanges) return CaptureDecision.skipNoDbChange;
  if (!hasSelectedGroups) return CaptureDecision.skipNoSelection;
  return CaptureDecision.captureSelected;
}

/// 对比前次抓取水位：当前最新消息时间未前进则跳过该群。
///
/// [lastCapturedMaxCreateTime] 为空表示从未抓取过 → 不跳过（首次抓取）。
/// [currentMaxCreateTime] 为空表示无消息 → 跳过。
bool shouldSkipUnchangedGroupCapture({
  required int? lastCapturedMaxCreateTime,
  required int? currentMaxCreateTime,
}) {
  if (currentMaxCreateTime == null) return true;
  if (lastCapturedMaxCreateTime == null) return false;
  return currentMaxCreateTime <= lastCapturedMaxCreateTime;
}

/// 用会话 [lastTimestamp] 做廉价预判（无需拉消息）。
/// 无法判断时返回 false（交给消息级确认）。
bool shouldSkipBySessionTimestamp({
  required int? lastCapturedMaxCreateTime,
  required int sessionLastTimestamp,
}) {
  if (lastCapturedMaxCreateTime == null) return false;
  if (sessionLastTimestamp <= 0) return false;
  return sessionLastTimestamp <= lastCapturedMaxCreateTime;
}

/// 管线阶段（UI 展示用）。
enum SyncPhase {
  idle,
  decrypting,
  capturing,
  cooldown,
  error,
}

String syncPhaseLabel(SyncPhase phase) {
  switch (phase) {
    case SyncPhase.idle:
      return '空闲';
    case SyncPhase.decrypting:
      return '增量解密';
    case SyncPhase.capturing:
      return '抓取已选群';
    case SyncPhase.cooldown:
      return '冷却中';
    case SyncPhase.error:
      return '出错';
  }
}
