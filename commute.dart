import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../places.dart';
import '../state.dart';
import '../widgets.dart';
import 'profile.dart';

const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

class CommuteScreen extends StatefulWidget {
  const CommuteScreen({super.key});

  @override
  State<CommuteScreen> createState() => _CommuteScreenState();
}

class _CommuteScreenState extends State<CommuteScreen> {
  List<Json>? mine;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await app.api.get('/commutes/mine');
      if (mounted) setState(() { mine = listOf(r['commutes']); error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _create() async {
    final made = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const NewCommuteScreen()));
    if (made == true) load();
  }

  @override
  Widget build(BuildContext context) {
    final list = mine;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily commute partner')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('New commute')),
      body: error != null
          ? Center(child: Text(error!))
          : list == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: [
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Ride to work every day? Post your usual trip to find a partner, or say where you need to go and find someone going your way. Costs are shared equally, and only on the days you both ride.'),
                        ),
                      ),
                      if (list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No commutes yet. Tap "New commute".'))),
                      for (final c in list)
                        Card(
                          child: ListTile(
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => CommuteDetailScreen(commute: c)));
                              load();
                            },
                            leading: Icon(c['kind'] == 'offer' ? Icons.directions_car : Icons.person_search),
                            title: Text('${c['origin']['name']} → ${c['destination']['name']}'),
                            subtitle: Text('${c['kind'] == 'offer' ? 'I am driving' : 'I need a partner'}  •  ${c['depart_time']}\n${(c['days'] as List).join(' ')}'),
                            isThreeLine: true,
                            trailing: c['active'] == true ? const Icon(Icons.chevron_right) : const Text('Stopped'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class NewCommuteScreen extends StatefulWidget {
  const NewCommuteScreen({super.key});

  @override
  State<NewCommuteScreen> createState() => _NewCommuteScreenState();
}

class _NewCommuteScreenState extends State<NewCommuteScreen> {
  String kind = 'seek';
  List<Json> vehicles = [];
  Json? vehicle;
  String seekType = 'any';
  Place? from;
  Place? to;
  TimeOfDay time = const TimeOfDay(hour: 8, minute: 30);
  final Set<String> days = {'MON', 'TUE', 'WED', 'THU', 'FRI'};
  bool helmet = false;
  bool womenOnly = false;
  final fuel = TextEditingController();
  final toll = TextEditingController();
  final plazas = TextEditingController();
  double? suggested;
  double? maxFuel;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    fuel.dispose();
    toll.dispose();
    plazas.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final r = await app.api.get('/vehicles');
      if (!mounted) return;
      setState(() => vehicles = listOf(r['vehicles']).where((v) => v['status'] == 'verified').toList());
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _estimate() async {
    if (kind != 'offer' || vehicle == null || from == null || to == null || from == to) return;
    try {
      final r = await app.api.post('/rides/estimate', {
        'vehicle_type': vehicle!['type'],
        'origin': from!.toJson(),
        'destination': to!.toJson(),
      });
      if (!mounted) return;
      setState(() {
        suggested = (r['suggested_fuel_estimate'] as num).toDouble();
        maxFuel = (r['max_fuel_estimate'] as num).toDouble();
        fuel.text = suggested!.toStringAsFixed(0);
      });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> submit() async {
    if (from == null || to == null) { toast(context, 'Choose where you start and where you go.'); return; }
    if (days.isEmpty) { toast(context, 'Choose at least one day.'); return; }
    if (kind == 'offer' && vehicle == null) { toast(context, 'Choose a verified vehicle.'); return; }
    final tollV = double.tryParse(toll.text.trim()) ?? 0;
    setState(() => busy = true);
    final body = <String, dynamic>{
      'kind': kind,
      'origin': from!.toJson(),
      'destination': to!.toJson(),
      'depart_time': hhmm(time.hour, time.minute),
      'days': _days.where(days.contains).toList(),
      'women_only': womenOnly,
      if (kind == 'offer') ...{
        'vehicle_id': vehicle!['id'],
        'fuel_estimate': double.tryParse(fuel.text.trim()) ?? 0,
        if (tollV > 0) 'toll_amount': tollV,
        if (tollV > 0) 'toll_plazas': plazas.text.trim(),
      } else ...{
        'vehicle_type': seekType,
        'has_helmet': helmet,
      },
    };
    final r = await guard(context, () => app.api.post('/commutes', body));
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final overCap = maxFuel != null && (double.tryParse(fuel.text.trim()) ?? 0) > maxFuel!;
    return Scaffold(
      appBar: AppBar(title: const Text('New daily commute')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'seek', label: Text('I need a partner'), icon: Icon(Icons.person_search)),
              ButtonSegment(value: 'offer', label: Text('I am driving'), icon: Icon(Icons.directions_car)),
            ],
            selected: {kind},
            onSelectionChanged: (s) => setState(() => kind = s.first),
          ),
          const SizedBox(height: 16),
          if (!app.idVerified)
            VerifyBanner(
              status: (app.user?['id_status'] ?? 'none').toString(),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyIdScreen())),
            ),
          PlaceField(label: 'From (home)', value: from, onChanged: (p) => setState(() { from = p; _estimate(); })),
          const SizedBox(height: 12),
          PlaceField(label: 'To (work)', value: to, onChanged: (p) => setState(() { to = p; _estimate(); })),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text('Leave at ${time.format(context)}'),
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: time);
              if (t != null) setState(() => time = t);
            },
          ),
          const SectionTitle('Days'),
          Wrap(
            spacing: 6,
            children: [
              for (final d in _days)
                FilterChip(label: Text(d), selected: days.contains(d), onSelected: (s) => setState(() => s ? days.add(d) : days.remove(d))),
            ],
          ),
          const SizedBox(height: 8),
          if (kind == 'seek') ...[
            DropdownButtonFormField<String>(
              initialValue: seekType,
              decoration: const InputDecoration(labelText: 'Ride with', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'any', child: Text('Bike or car')),
                DropdownMenuItem(value: 'bike', child: Text('Bike only')),
                DropdownMenuItem(value: 'car', child: Text('Car only')),
              ],
              onChanged: (v) => setState(() => seekType = v ?? 'any'),
            ),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: helmet, onChanged: (v) => setState(() => helmet = v ?? false), title: const Text('I have my own helmet')),
          ] else ...[
            if (vehicles.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('You need a verified vehicle first. Add one from the Me tab.')))
            else
              DropdownButtonFormField<int>(
                initialValue: vehicle?['id'] as int?,
                decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder()),
                items: [for (final v in vehicles) DropdownMenuItem(value: v['id'] as int, child: Text('${v['make_model']} (${v['registration']})'))],
                onChanged: (id) => setState(() { vehicle = vehicles.firstWhere((v) => v['id'] == id); _estimate(); }),
              ),
            const SectionTitle('Petrol and toll for one trip'),
            const Text('Shared equally with your partner(s). You cannot set a price or earn from it.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: fuel,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Petrol estimate per trip (₹)',
                border: const OutlineInputBorder(),
                helperText: suggested == null ? 'Choose route and vehicle to see a suggestion' : 'Suggested ${money(suggested!)}, maximum ${money(maxFuel!)}',
                errorText: overCap ? 'Too high. Maximum is ${money(maxFuel!)}' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: toll, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Toll per trip (₹), if any', border: OutlineInputBorder())),
            if ((double.tryParse(toll.text.trim()) ?? 0) > 0) ...[
              const SizedBox(height: 12),
              TextField(controller: plazas, decoration: const InputDecoration(labelText: 'Toll plaza name(s)', border: OutlineInputBorder())),
            ],
          ],
          if (kind == 'seek' ? true : app.isFemale)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(kind == 'seek' ? 'Match me only with women drivers' : 'Women partners only'),
              value: womenOnly,
              onChanged: (b) => setState(() => womenOnly = b),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: (busy || overCap) ? null : submit, child: Text(busy ? 'Saving...' : 'Save commute')),
        ],
      ),
    );
  }
}

class CommuteDetailScreen extends StatefulWidget {
  final Json commute;
  const CommuteDetailScreen({super.key, required this.commute});

  @override
  State<CommuteDetailScreen> createState() => _CommuteDetailScreenState();
}

class _CommuteDetailScreenState extends State<CommuteDetailScreen> {
  List<Json>? matches;
  List<Json> partners = [];
  String? error;

  bool get isOffer => widget.commute['kind'] == 'offer';
  int get id => widget.commute['id'] as int;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final m = await app.api.get('/commutes/$id/matches');
      final p = await app.api.get('/commutes/$id/partners');
      if (!mounted) return;
      setState(() { matches = listOf(m['matches']); partners = listOf(p['partnerships']); error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> act(String path, [Json? body]) async {
    final r = await guard(context, () => app.api.post(path, body));
    if (r != null) load();
  }

  Future<void> _request(Json m) async {
    final avail = (m['free_days'] as List).cast<String>();
    final chosen = {...avail};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Which days?'),
          content: Wrap(
            spacing: 6,
            children: [
              for (final d in avail)
                FilterChip(label: Text(d), selected: chosen.contains(d), onSelected: (s) => setS(() => s ? chosen.add(d) : chosen.remove(d))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: chosen.isEmpty ? null : () => Navigator.pop(ctx, true), child: const Text('Send request')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      final r = await guard(context, () => app.api.post('/commutes/$id/partners', {'offer_id': m['commute']['id'], 'days': _days.where(chosen.contains).toList()}));
      if (r != null && mounted) { toast(context, 'Request sent.'); load(); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.commute;
    return Scaffold(
      appBar: AppBar(title: const Text('Commute')),
      body: error != null
          ? Center(child: Text(error!))
          : matches == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('${c['origin']['name']} → ${c['destination']['name']}', style: Theme.of(context).textTheme.titleLarge),
                      Text('${c['depart_time']}  •  ${(c['days'] as List).join(' ')}'),
                      if (isOffer && c['cost_per_trip'] != null)
                        Text('Trip cost ${money(c['cost_per_trip']['total_to_share'] as num)} (estimate). With one partner each pays ${money(c['cost_per_trip']['share_if_one_partner'] as num)}.'),
                      const SectionTitle('Partners'),
                      if (partners.isEmpty) const Text('No partner requests yet.'),
                      for (final p in partners) _partnerCard(p),
                      SectionTitle(isOffer ? 'People looking for a partner' : 'Drivers going your way'),
                      if (matches!.isEmpty) const Text('No matches yet. We match nearby start and end points, a similar time and shared days.'),
                      for (final m in matches!) _matchCard(m),
                      const SizedBox(height: 16),
                      if (c['active'] == true)
                        TextButton(
                          onPressed: () async {
                            if (!await confirm(context, 'Stop this commute?', 'It will no longer appear in searches.', yes: 'Stop')) return;
                            if (!mounted) return;
                            final r = await guard(context, () => app.api.post('/commutes/$id/deactivate'));
                            if (r != null && mounted) Navigator.pop(context);
                          },
                          child: const Text('Stop this commute'),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _matchCard(Json m) {
    final who = (isOffer ? m['rider'] : m['driver']) as Map;
    final cm = m['commute'] as Map;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${who['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            RatingText(Map<String, dynamic>.from(who['rating'] as Map)),
            Text('${cm['origin']['name']} → ${cm['destination']['name']} at ${cm['depart_time']}'),
            Text('Common days: ${(m['free_days'] as List).join(' ')}  •  ${m['time_difference_min']} min apart'),
            if (!isOffer) Text('Your share per trip: about ${money(m['share_per_trip_if_you_join'] as num)} (estimate)'),
            if (!isOffer) Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () => _request(m), child: const Text('Ask to partner'))),
          ],
        ),
      ),
    );
  }

  Widget _partnerCard(Json p) {
    final who = (p['rider'] ?? p['driver']) as Map;
    final status = p['status'] as String;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: Text('${who['name']}', style: const TextStyle(fontWeight: FontWeight.w600))), StatusChip(status)]),
            Text('Days: ${(p['days'] as List).join(' ')}'),
            Wrap(spacing: 8, children: [
              if (status == 'pending' && isOffer) ...[
                FilledButton(onPressed: () => act('/partnerships/${p['id']}/accept'), child: const Text('Accept')),
                OutlinedButton(onPressed: () => act('/partnerships/${p['id']}/reject'), child: const Text('Decline')),
              ],
              if (status == 'accepted') ...[
                OutlinedButton(onPressed: () => _skip(p), child: const Text('Skip a day')),
                OutlinedButton(onPressed: () => _summary(p), child: const Text('Monthly cost')),
              ],
              if (status == 'pending' || status == 'accepted')
                TextButton(
                  onPressed: () async {
                    if (await confirm(context, 'End this arrangement?', 'Your partner will be told.', yes: 'End')) act('/partnerships/${p['id']}/end');
                  },
                  child: const Text('End'),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _skip(Json p) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
    if (d == null || !mounted) return;
    final r = await guard(context, () => app.api.post('/partnerships/${p['id']}/skip', {'date': ymd(d)}));
    if (r != null && mounted) toast(context, 'Skipped ${r['date']}. Your partner was told, and you are not charged for that day.');
  }

  Future<void> _summary(Json p) async {
    final r = await guard(context, () => app.api.get('/partnerships/${p['id']}/summary'));
    if (r == null || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cost for ${r['month']}'),
        content: Text('${r['riding_days']} riding days, ${r['skipped_days']} skipped.\n\nYour estimated share: ${money(r['total_share_for_month'] as num)}\n\nPay directly to your partner. The app never holds money.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}
