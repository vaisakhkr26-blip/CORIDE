const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

/// 2026-11-05 (the format the API expects for dates)
String ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// "08:30" for the API
String hhmm(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

/// "Sat 5 Nov, 7:30 AM" from an ISO timestamp, shown in the phone's local time.
String fmtDateTime(String iso) {
  final d = DateTime.parse(iso).toLocal();
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}, $h:${_two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "₹1,100" or "₹366.66"
String money(num v) {
  final whole = v == v.roundToDouble();
  final s = whole ? v.toInt().toString() : v.toStringAsFixed(2);
  final parts = s.split('.');
  parts[0] = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '₹${parts.join('.')}';
}

/// Equal share in rupees, rounded DOWN to the paisa, like the server does.
double equalShare(double total, int people) => (total * 100).round() ~/ people / 100;
