const String unknownDurationLabel = '--:--';

/// Formats as `m:ss`, or `h:mm:ss` from one hour up. Negative values clamp to 0.
String formatDuration(Duration duration) {
  final total = duration.isNegative ? 0 : duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  }
  return '$minutes:$ss';
}

String formatDurationOrUnknown(Duration? duration) =>
    duration == null ? unknownDurationLabel : formatDuration(duration);
