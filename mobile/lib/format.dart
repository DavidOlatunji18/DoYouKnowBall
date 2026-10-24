const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A short, friendly date: "Today", "Yesterday", "3 days ago", or "Oct 23"
/// (with the year if it isn't this year).
String friendlyDate(DateTime date, {DateTime? now}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final daysAgo = today.difference(day).inDays;

  if (daysAgo <= 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  if (daysAgo < 7) return '$daysAgo days ago';
  final short = '${_months[date.month - 1]} ${date.day}';
  return date.year == now.year ? short : '$short, ${date.year}';
}
