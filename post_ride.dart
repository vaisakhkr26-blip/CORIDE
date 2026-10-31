import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../places.dart';
import '../state.dart';
import '../widgets.dart';
import 'profile.dart';

class PostRideScreen extends StatefulWidget {
  const PostRideScreen({super.key});

  @override
  State<PostRideScreen> createState() => _PostRideScreenState();
}

class _PostRideScreenState extends State<PostRideScreen> {
  List<Json>? vehicles;
  Json? vehicle;
  Place? from;
  Place? to;
  final List<Place> stops = [];
  DateTime? depart;
  int seats = 1;
  bool womenOnly = false;
  final fuel = TextEditingController();
  final toll = TextEditingController();
  final plazas = TextEditingController();
  final notes = TextEditingController();
  double? suggested;
  double? maxFuel;
  double? maxToll;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    loadVehicles();
  }

  @override
  void dispose() {
    fuel.dispose();
    toll.dispose();
    plazas.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> loadVehicles() async {
    try {
      final r = await app.api.get('/vehicles');
      final all = listOf(r['vehicles']);
      if (!mounted) return;
      setState(() {
        vehicles = all;
        final ok = all.where((v) => v['status'] == 'verified').toList();
        if (ok.isNotEmpty && vehicle == null) _setVehicle(ok.first);
      });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  void _setVehicle(Json v) {
    vehicle = v;
    seats = v['passenger_seats'] as int;
    _estimate();
  }

  // Ask the server for a suggested petrol estimate and the maximum it allows.
  Future<void> _estimate() async {
    if (vehicle == null || from == null || to == null) return;
    if (from == to) return;
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
        maxToll = (r['max_toll'] as num).toDouble();
        fuel.text = suggested!.toStringAsFixed(0);
      });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> pickDepart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: depart ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    if (t == null) return;
    setState(() => depart = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  double get fuelValue => double.tryParse(fuel.text.trim()) ?? 0;
  double get tollValue => double.tryParse(toll.text.trim()) ?? 0;

  Future<void> submit() async {
    if (vehicle == null || from == null || to == null || depart == null) {
      toast(context, 'Choose a vehicle, the route and the departure time.');
      return;
    }
    setState(() => busy = true);
    final r = await guard(
      context,
      () => app.api.post('/rides', {
        'vehicle_id': vehicle!['id'],
        'origin': from!.toJson(),
        'destination': to!.toJson(),
        if (stops.isNotEmpty) 'stops': stops.map((s) => s.toJson()).toList(),
        'depart_at': depart!.toUtc().toIso8601String(),
        'seats_total': seats,
        'fuel_estimate': fuelValue,
        if (tollValue > 0) 'toll_amount': tollValue,
        if (tollValue > 0) 'toll_plazas': plazas.text.trim(),
        'women_only': womenOnly,
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
      }),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) {
      toast(context, 'Ride posted. Passengers can now ask to join.');
      setState(() {
        stops.clear();
        depart = null;
        toll.clear();
        plazas.clear();
        notes.clear();
        womenOnly = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = vehicles;
    final verified = (v ?? []).where((x) => x['status'] == 'verified').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Offer a ride')),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListenableBuilder(
                  listenable: app,
                  builder: (_, __) => VerifyBanner(
                    status: (app.user?['id_status'] ?? 'none').toString(),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyIdScreen())),
                  ),
                ),
                if (verified.isEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.directions_car_outlined),
                      title: const Text('You need a verified vehicle'),
                      subtitle: const Text('Add your vehicle documents. We check them before you can offer rides.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const VehiclesScreen()));
                        loadVehicles();
                      },
                    ),
                  )
                else
                  _form(verified),
              ],
            ),
    );
  }

  Widget _form(List<Json> verified) {
    final maxSeats = vehicle?['passenger_seats'] as int? ?? 1;
    final total = fuelValue + tollValue;
    final overCap = maxFuel != null && fuelValue > maxFuel!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: vehicle?['id'] as int?,
          decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder()),
          items: [
            for (final x in verified)
              DropdownMenuItem(value: x['id'] as int, child: Text('${x['make_model']} (${x['registration']})')),
          ],
          onChanged: (id) => setState(() => _setVehicle(verified.firstWhere((x) => x['id'] == id))),
        ),
        const SizedBox(height: 12),
        PlaceField(label: 'From', value: from, onChanged: (p) => setState(() { from = p; _estimate(); })),
        const SizedBox(height: 12),
        PlaceField(label: 'To', value: to, onChanged: (p) => setState(() { to = p; _estimate(); })),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final s in stops)
              InputChip(label: Text(s.name), onDeleted: () => setState(() => stops.remove(s))),
            if (stops.length < 5)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add a stop on the way'),
                onPressed: () async {
                  final p = await pickPlace(context);
                  if (p != null) setState(() => stops.add(p));
                },
              ),
          ],
        ),
        const Text('Stops let passengers join along your route, for example at Kollam.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: pickDepart,
          icon: const Icon(Icons.schedule),
          label: Text(depart == null ? 'Choose date and time' : fmtDateTime(depart!.toUtc().toIso8601String())),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: seats > maxSeats ? maxSeats : seats,
          decoration: const InputDecoration(labelText: 'Seats you can share', border: OutlineInputBorder()),
          items: [for (var i = 1; i <= maxSeats; i++) DropdownMenuItem(value: i, child: Text('$i'))],
          onChanged: (n) => setState(() => seats = n ?? 1),
        ),
        if (app.isFemale)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Women passengers only'),
            value: womenOnly,
            onChanged: (b) => setState(() => womenOnly = b),
          ),
        const SectionTitle('Expenses to share'),
        const Text(
          'This is only to share your petrol and toll. You cannot set a price or earn from a ride. Everyone, including you, pays an equal share.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: fuel,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Petrol estimate for the trip (₹)',
            border: const OutlineInputBorder(),
            helperText: suggested == null ? 'Choose the route to see a suggestion' : 'Suggested ${money(suggested!)}, maximum ${money(maxFuel!)}',
            errorText: overCap ? 'Too high. Maximum is ${money(maxFuel!)}' : null,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: toll,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Toll (₹), if any',
            border: const OutlineInputBorder(),
            helperText: maxToll == null ? null : 'Maximum ${money(maxToll!)}',
          ),
        ),
        if (tollValue > 0) ...[
          const SizedBox(height: 12),
          TextField(controller: plazas, decoration: const InputDecoration(labelText: 'Toll plaza name(s)', border: OutlineInputBorder())),
        ],
        const SizedBox(height: 12),
        if (total > 0)
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total to share: ${money(total)} (estimate)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  for (var n = 1; n <= seats; n++)
                    Text('$n passenger${n > 1 ? 's' : ''} + you: ${money(equalShare(total, n + 1))} each'),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Note for passengers (optional)', border: OutlineInputBorder()),
        ),
        FilledButton(onPressed: (busy || overCap) ? null : submit, child: Text(busy ? 'Posting...' : 'Post ride')),
      ],
    );
  }
}
