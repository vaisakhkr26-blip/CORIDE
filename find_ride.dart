import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../places.dart';
import '../state.dart';
import '../widgets.dart';
import 'profile.dart';

class FindRideScreen extends StatefulWidget {
  const FindRideScreen({super.key});

  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  Place? from;
  Place? to;
  DateTime date = DateTime.now();
  List<Json>? rides;
  bool loading = false;

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d != null) setState(() => date = d);
  }

  Future<void> search() async {
    if (from == null || to == null) {
      toast(context, 'Choose where you are starting and where you are going.');
      return;
    }
    setState(() => loading = true);
    final r = await guard(
      context,
      () => app.api.get('/rides', query: {
        'from_lat': '${from!.lat}',
        'from_lng': '${from!.lng}',
        'to_lat': '${to!.lat}',
        'to_lng': '${to!.lng}',
        'date': ymd(date),
      }),
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      if (r != null) rides = listOf(r['rides']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a ride')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListenableBuilder(
            listenable: app,
            builder: (_, __) => VerifyBanner(
              status: (app.user?['id_status'] ?? 'none').toString(),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyIdScreen())),
            ),
          ),
          PlaceField(label: 'From', value: from, onChanged: (p) => setState(() => from = p)),
          const SizedBox(height: 12),
          PlaceField(label: 'To', value: to, onChanged: (p) => setState(() => to = p)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text('Date: ${ymd(date)}'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : search,
            icon: const Icon(Icons.search),
            label: Text(loading ? 'Searching...' : 'Search rides'),
          ),
          const SizedBox(height: 8),
          const Text(
            'You will also find rides that pass through your pickup point, not only rides that start there.',
            style: TextStyle(fontSize: 12),
          ),
          if (rides != null) ...[
            const SectionTitle('Available rides'),
            if (rides!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No rides found for this route and date. Try another day.')),
              ),
            for (final r in rides!) RideTile(ride: r, onTap: () => _open(r['id'] as int)),
          ],
        ],
      ),
    );
  }

  Future<void> _open(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(rideId: id, from: from, to: to)));
    if (mounted && rides != null) search();
  }
}

class RideTile extends StatelessWidget {
  final Json ride;
  final VoidCallback onTap;
  const RideTile({super.key, required this.ride, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final driver = ride['driver'] as Map;
    final vehicle = ride['vehicle'] as Map;
    final cost = ride['cost'] as Map;
    return Card(
      child: ListTile(
        onTap: onTap,
        isThreeLine: true,
        leading: Icon(vehicle['type'] == 'bike' ? Icons.two_wheeler : Icons.directions_car),
        title: Text('${ride['origin']['name']} → ${ride['destination']['name']}'),
        subtitle: Text(
          '${fmtDateTime(ride['depart_at'] as String)}\n'
          '${driver['name'] ?? 'Driver'}  •  ${(driver['rating']['count'] ?? 0) == 0 ? 'New' : '★ ${driver['rating']['average']}'}'
          '  •  ${ride['seats_available']} seat(s) left${ride['women_only'] == true ? '  •  Women only' : ''}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(cost['your_share_if_you_join'] as num), style: const TextStyle(fontWeight: FontWeight.bold)),
            const Text('your share', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class RideDetailScreen extends StatefulWidget {
  final int rideId;
  final Place? from;
  final Place? to;
  const RideDetailScreen({super.key, required this.rideId, this.from, this.to});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  Json? ride;
  String? error;
  Place? pickup;
  Place? drop;
  bool helmet = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    pickup = widget.from;
    drop = widget.to;
    load();
  }

  Future<void> load() async {
    try {
      final r = await app.api.get('/rides/${widget.rideId}');
      if (mounted) setState(() => ride = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> join() async {
    setState(() => busy = true);
    final r = await guard(
      context,
      () => app.api.post('/rides/${widget.rideId}/bookings', {
        // Searching already told us where this person gets on and off along the route.
        if (pickup != null) 'pickup': pickup!.toJson(),
        if (drop != null) 'drop': drop!.toJson(),
        'has_helmet': helmet,
      }),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) {
      toast(context, 'Request sent. The driver will accept or decline.');
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ride;
    return Scaffold(
      appBar: AppBar(title: const Text('Ride details')),
      body: error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)))
          : r == null
              ? const Center(child: CircularProgressIndicator())
              : _body(r),
    );
  }

  Widget _body(Json r) {
    final driver = r['driver'] as Map;
    final vehicle = r['vehicle'] as Map;
    final stops = listOf(r['stops']);
    final mine = r['my_booking'] as Map?;
    final isBike = vehicle['type'] == 'bike';
    final canJoin = r['is_mine'] != true && r['status'] == 'open' && mine == null && (r['seats_available'] as int) > 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${r['origin']['name']} → ${r['destination']['name']}', style: Theme.of(context).textTheme.titleLarge),
        if (stops.isNotEmpty) Text('Via ${stops.map((s) => s['name']).join(', ')}'),
        const SizedBox(height: 4),
        Text(fmtDateTime(r['depart_at'] as String)),
        Text('${r['distance_km']} km  •  ${r['seats_available']} of ${r['seats_total']} seats free'),
        if (r['women_only'] == true) const Chip(label: Text('Women only'), visualDensity: VisualDensity.compact),
        if ((r['notes'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Note: ${r['notes']}')),
        const SectionTitle('Driver'),
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(((driver['name'] ?? '?') as String).substring(0, 1).toUpperCase())),
            title: Row(children: [
              Flexible(child: Text(driver['name'] ?? 'Driver')),
              if (driver['id_verified'] == true) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, size: 18, color: Colors.green)),
            ]),
            subtitle: RatingText(Map<String, dynamic>.from(driver['rating'] as Map)),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(isBike ? Icons.two_wheeler : Icons.directions_car),
            title: Text('${vehicle['make_model']}'),
            subtitle: Text('Number: ${vehicle['registration']}  •  Verified vehicle'),
          ),
        ),
        const SectionTitle('Cost'),
        CostCard(cost: Map<String, dynamic>.from(r['cost'] as Map), showJoinShare: canJoin),
        if (mine != null) Card(child: ListTile(title: const Text('Your request'), trailing: StatusChip(mine['status'] as String))),
        if (canJoin) ...[
          const SectionTitle('Join this ride'),
          if (!app.idVerified)
            VerifyBanner(
              status: (app.user?['id_status'] ?? 'none').toString(),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyIdScreen())),
            ),
          PlaceField(label: 'Your pickup point', value: pickup, onChanged: (p) => setState(() => pickup = p), onClear: () => setState(() => pickup = null)),
          const SizedBox(height: 12),
          PlaceField(label: 'Your drop point', value: drop, onChanged: (p) => setState(() => drop = p), onClear: () => setState(() => drop = null)),
          const Text('Leave empty to use the ride start and end.', style: TextStyle(fontSize: 12)),
          if (isBike)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: helmet,
              onChanged: (v) => setState(() => helmet = v ?? false),
              title: const Text('I will bring my own helmet'),
            ),
          const SizedBox(height: 8),
          FilledButton(onPressed: busy ? null : join, child: Text(busy ? 'Sending...' : 'Request to join')),
        ],
      ],
    );
  }
}
