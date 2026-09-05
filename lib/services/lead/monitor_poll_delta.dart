/// 群监控轮询增量：根据上次见到的 createTime 判断是否仅建基线、以及哪些是新消息。
class MonitorPollDelta {
  const MonitorPollDelta({
    required this.baselineOnly,
    required this.freshCreateTimes,
    required this.newestCreateTime,
  });

  /// 首次见到该会话：只建立基线，不把历史当新消息。
  final bool baselineOnly;
  final List<int> freshCreateTimes;
  final int? newestCreateTime;
}

MonitorPollDelta computeMonitorPollDelta({
  required int? lastSeenCreateTime,
  required List<int> messageCreateTimes,
}) {
  if (messageCreateTimes.isEmpty) {
    return const MonitorPollDelta(
      baselineOnly: false,
      freshCreateTimes: <int>[],
      newestCreateTime: null,
    );
  }
  final newest = messageCreateTimes.reduce((a, b) => a > b ? a : b);
  if (lastSeenCreateTime == null) {
    return MonitorPollDelta(
      baselineOnly: true,
      freshCreateTimes: const <int>[],
      newestCreateTime: newest,
    );
  }
  if (newest <= lastSeenCreateTime) {
    return MonitorPollDelta(
      baselineOnly: false,
      freshCreateTimes: const <int>[],
      newestCreateTime: newest,
    );
  }
  return MonitorPollDelta(
    baselineOnly: false,
    freshCreateTimes:
        messageCreateTimes.where((t) => t > lastSeenCreateTime).toList(),
    newestCreateTime: newest,
  );
}
