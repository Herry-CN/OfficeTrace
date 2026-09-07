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
