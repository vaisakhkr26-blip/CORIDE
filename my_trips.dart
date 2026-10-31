import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../state.dart';
import '../widgets.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  List<Json>? bookings;
  List<Json>? driving;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final b = await app.api.get('/bookings/mine');
      final r = await app.api.get('/rides/mine');
      if (!mounted) return;
      setState(() {
        bookings = listOf(b['bookings']);
        driving = listOf(r['as_driver']);
        error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My trips'),
          bottom: const TabBar(tabs: [Tab(text: 'As passenger'), Tab(text: 'As driver')]),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: load)],
        ),
        body: error != null
            ? Center(child: Text(error!))
            : bookings == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [_passengerList(), _driverList()]),
      ),
    );
  }

  Widget _passengerList() {
    final list = bookings!;
    if (list.isEmpty) return const Center(child: Text('You have not joined any rides yet.'));
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final b in list)
            Card(
              child: ListTile(
                onTap: () => _open(BookingScreen(bookingId: b['id'] as int)),
                title: Text('${b['ride']['origin']} → ${b['ride']['destination']}'),
                subtitle: Text(fmtDateTime(b['ride']['depart_at'] as String)),
                trailing: StatusChip(b['status'] as String),
              ),
            ),
        ],
      ),
    );
  }

  Widget _driverList() {
    final list = driving!;
    if (list.isEmpty) return const Center(child: Text('You have not offered any rides yet.'));
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final r in list)
            Card(
              child: ListTile(
                onTap: () => _open(DriverRideScreen(rideId: r['id'] as int)),
                title: Text('${r['origin']['name']} → ${r['destination']['name']}'),
                subtitle: Text('${fmtDateTime(r['depart_at'] as String)}\n${r['seats_total'] - r['seats_available']} of ${r['seats_total']} seats taken'),
                isThreeLine: true,
                trailing: StatusChip(r['status'] as String),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------- passenger: one booking ----------------

class BookingScreen extends StatefulWidget {
  final int bookingId;
  const BookingScreen({super.key, required this.bookingId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Json? booking;
  Json? ride;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final all = await app.api.get('/bookings/mine');
      final b = listOf(all['bookings']).firstWhere((x) => x['id'] == widget.bookingId);
      final r = await app.api.get('/rides/${b['ride_id']}');
      if (mounted) setState(() { booking = b; ride = r; });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> cancel() async {
    if (!await confirm(context, 'Cancel this booking?', 'Cancelling after the driver accepted counts against your reliability.', yes: 'Cancel booking')) return;
    if (!mounted) return;
    final r = await guard(context, () => app.api.post('/bookings/${widget.bookingId}/cancel'));
    if (r != null) load();
  }

  @override
  Widget build(BuildContext context) {
    final b = booking, r = ride;
    return Scaffold(
      appBar: AppBar(title: const Text('Your booking')),
      body: error != null
          ? Center(child: Text(error!))
          : (b == null || r == null)
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('${r['origin']['name']} → ${r['destination']['name']}', style: Theme.of(context).textTheme.titleLarge),
                    Text(fmtDateTime(r['depart_at'] as String)),
                    const SizedBox(height: 8),
                    Row(children: [const Text('Status: '), StatusChip(b['status'] as String)]),
                    Text('Pickup: ${b['pickup']['name']}  •  Drop: ${b['drop']['name']}'),
                    if (b['pickup_otp'] != null)
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            const Text('Show this code to the driver when you get in'),
                            const SizedBox(height: 6),
                            Text(b['pickup_otp'].toString(), style: const TextStyle(fontSize: 40, letterSpacing: 8, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    if (b['boarded'] == true) const Card(child: ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('You have boarded'))),
                    const SectionTitle('Driver and vehicle'),
                    Card(
                      child: ListTile(
                        title: Text('${r['driver']['name']}'),
                        subtitle: Text('${r['vehicle']['make_model']}  •  ${r['vehicle']['registration']}'),
                      ),
                    ),
                    CostCard(cost: Map<String, dynamic>.from(r['cost'] as Map), showJoinShare: false),
                    if (b['status'] == 'accepted' || b['status'] == 'completed') ...[
                      const SectionTitle('Safety'),
                      SafetyButtons(rideId: r['id'] as int),
                    ],
                    if (b['status'] == 'completed')
                      FilledButton.icon(
                        onPressed: () => rateDialog(context, rideId: r['id'] as int, toUser: (r['driver']['id']) as int, who: '${r['driver']['name']}'),
                        icon: const Icon(Icons.star_outline),
                        label: const Text('Rate the driver'),
                      ),
                    if (b['status'] == 'pending' || b['status'] == 'accepted')
                      TextButton(onPressed: cancel, child: const Text('Cancel booking')),
                  ],
                ),
    );
  }
}

// ---------------- driver: one ride ----------------

class DriverRideScreen extends StatefulWidget {
  final int rideId;
  const DriverRideScreen({super.key, required this.rideId});

  @override
  State<DriverRideScreen> createState() => _DriverRideScreenState();
}

class _DriverRideScreenState extends State<DriverRideScreen> {
  Json? ride;
  List<Json> requests = [];
  Json? cost;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await app.api.get('/rides/${widget.rideId}');
      final b = await app.api.get('/rides/${widget.rideId}/bookings');
      if (!mounted) return;
      setState(() {
        ride = r;
        requests = listOf(b['bookings']);
        cost = Map<String, dynamic>.from(b['cost'] as Map);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> act(String path, [Json? body]) async {
    final r = await guard(context, () => app.api.post(path, body));
    if (r != null) load();
  }

  Future<void> board(Json b) async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Pickup code for ${b['passenger']['name']}'),
        content: TextField(controller: c, keyboardType: TextInputType.number, maxLength: 4, autofocus: true, decoration: const InputDecoration(hintText: '4-digit code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );
    c.dispose();
    if (code != null && mounted) act('/bookings/${b['id']}/board', {'otp': code});
  }

  @override
  Widget build(BuildContext context) {
    final r = ride;
    return Scaffold(
      appBar: AppBar(title: const Text('Your ride')),
      body: error != null
          ? Center(child: Text(error!))
          : r == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: load, child: _body(r)),
    );
  }

  Widget _body(Json r) {
    final open = r['status'] == 'open';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${r['origin']['name']} → ${r['destination']['name']}', style: Theme.of(context).textTheme.titleLarge),
        Text(fmtDateTime(r['depart_at'] as String)),
        Row(children: [const Text('Status: '), StatusChip(r['status'] as String)]),
        if (cost != null) CostCard(cost: cost!, showJoinShare: false),
        const SectionTitle('Requests'),
        if (requests.isEmpty) const Text('No requests yet.'),
        for (final b in requests)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text('${b['passenger']['name']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    StatusChip(b['status'] as String),
                  ]),
                  RatingText(Map<String, dynamic>.from(b['passenger']['rating'] as Map)),
                  Text('${b['pickup']['name']} → ${b['drop']['name']}'),
                  if (b['has_helmet'] == true) const Text('Has helmet'),
                  if (b['boarded'] == true) const Text('Boarded', style: TextStyle(color: Colors.green)),
                  Wrap(spacing: 8, children: [
                    if (b['status'] == 'pending') ...[
                      FilledButton(onPressed: () => act('/bookings/${b['id']}/accept'), child: const Text('Accept')),
                      OutlinedButton(onPressed: () => act('/bookings/${b['id']}/reject'), child: const Text('Decline')),
                    ],
                    if (b['status'] == 'accepted' && b['boarded'] != true)
                      FilledButton.tonal(onPressed: () => board(b), child: const Text('Enter pickup code')),
                    if (r['status'] == 'completed' && b['status'] == 'completed')
                      OutlinedButton(
                        onPressed: () => rateDialog(context, rideId: r['id'] as int, toUser: b['passenger']['id'] as int, who: '${b['passenger']['name']}'),
                        child: const Text('Rate'),
                      ),
                  ]),
                ],
              ),
            ),
          ),
        if (open) ...[
          const SectionTitle('Safety'),
          SafetyButtons(rideId: r['id'] as int),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              if (await confirm(context, 'Trip finished?', 'This marks the ride completed so everyone can rate each other.', yes: 'Complete')) {
                act('/rides/${r['id']}/complete');
              }
            },
            child: const Text('Complete ride'),
          ),
          TextButton(
            onPressed: () async {
              if (await confirm(context, 'Cancel this ride?', 'Everyone who asked to join will be told.', yes: 'Cancel ride')) {
                act('/rides/${r['id']}/cancel');
              }
            },
            child: const Text('Cancel ride'),
          ),
        ],
      ],
    );
  }
}

// ---------------- shared bits ----------------

/// Trip-share link for family, and an SOS button. Both are for people on the ride.
class SafetyButtons extends StatelessWidget {
  final int rideId;
  const SafetyButtons({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.share_location),
            label: const Text('Share trip'),
            onPressed: () async {
              final r = await guard(context, () => app.api.post('/rides/$rideId/share'));
              if (r == null || !context.mounted) return;
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Trip link for family'),
                  content: Text('Anyone with this link can follow the trip until it expires:\n\n${r['link']}'),
                  actions: [
                    TextButton(onPressed: () => copyText(ctx, r['link'] as String), child: const Text('Copy')),
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.sos),
            label: const Text('SOS'),
            onPressed: () async {
              if (!await confirm(context, 'Send SOS?', 'Your emergency contacts and our team will be alerted. In danger, also call 112.', yes: 'Send SOS')) return;
              if (!context.mounted) return;
              final r = await guard(context, () => app.api.post('/rides/$rideId/sos', {}));
              if (r != null && context.mounted) {
                toast(context, '${r['contacts_alerted']} contact(s) alerted. If you are in danger, call 112 now.');
              }
            },
          ),
        ),
      ],
    );
  }
}

const _tagLabels = {
  'punctual': 'Punctual',
  'safe_driver': 'Safe driver',
  'friendly': 'Friendly',
  'clean_vehicle': 'Clean vehicle',
  'good_conversation': 'Good conversation',
  'respectful': 'Respectful',
  'not_punctual': 'Not punctual',
  'unsafe_driving': 'Unsafe driving',
  'rude': 'Rude',
};

Future<void> rateDialog(BuildContext context, {required int rideId, required int toUser, required String who}) async {
  int stars = 5;
  final tags = <String>{};
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text('Rate $who'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(i <= stars ? Icons.star : Icons.star_border, color: Colors.amber),
                      onPressed: () => setS(() => stars = i),
                    ),
                ],
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final e in _tagLabels.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: tags.contains(e.key),
                      onSelected: (s) => setS(() => s ? tags.add(e.key) : tags.remove(e.key)),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    ),
  );
  if (res == true && context.mounted) {
    final r = await guard(context, () => app.api.post('/rides/$rideId/ratings', {'to_user': toUser, 'stars': stars, 'tags': tags.toList()}));
    if (r != null && context.mounted) toast(context, 'Thanks for rating.');
  }
}
