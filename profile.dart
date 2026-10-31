import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../state.dart';
import '../widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    app.refreshMe().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final u = app.user ?? {};
        final idStatus = (u['id_status'] ?? 'none').toString();
        void go(Widget s) => Navigator.push(context, MaterialPageRoute(builder: (_) => s));
        return Scaffold(
          appBar: AppBar(title: const Text('Me')),
          body: ListView(
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(u['name']?.toString() ?? 'Add your name'),
                subtitle: Text(u['phone']?.toString() ?? ''),
                trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => go(const EditProfileScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('ID verification'),
                subtitle: Text(idStatus == 'rejected' ? 'Rejected: ${u['id_reject_reason'] ?? ''}' : idStatus),
                trailing: idStatus == 'verified' ? const Icon(Icons.verified, color: Colors.green) : const Icon(Icons.chevron_right),
                onTap: idStatus == 'verified' || idStatus == 'pending' ? null : () => go(const VerifyIdScreen()),
              ),
              ListTile(leading: const Icon(Icons.directions_car_outlined), title: const Text('My vehicles'), trailing: const Icon(Icons.chevron_right), onTap: () => go(const VehiclesScreen())),
              ListTile(leading: const Icon(Icons.contact_phone_outlined), title: const Text('Emergency contacts'), subtitle: const Text('Alerted when you press SOS'), trailing: const Icon(Icons.chevron_right), onTap: () => go(const EmergencyContactsScreen())),
              ListTile(leading: const Icon(Icons.notifications_outlined), title: const Text('Notifications'), trailing: const Icon(Icons.chevron_right), onTap: () => go(const NotificationsScreen())),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () async {
                  if (await confirm(context, 'Log out?', 'You can log in again with your mobile number.', yes: 'Log out')) await app.logout();
                },
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('CoRide only helps people share real travel expenses. Drivers cannot charge fares or earn money from rides.', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------- edit profile ----------------

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController name = TextEditingController(text: app.user?['name']?.toString() ?? '');
  String? gender = app.user?['gender']?.toString();
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || gender == null) {
      toast(context, 'Enter your name and choose your gender.');
      return;
    }
    setState(() => busy = true);
    final r = await guard(context, () => app.api.put('/me', {'name': name.text.trim(), 'gender': gender}));
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) {
      await app.refreshMe();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: gender,
            decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder(), helperText: 'Used for women-only rides'),
            items: const [
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => gender = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Saving...' : 'Save')),
        ],
      ),
    );
  }
}

// ---------------- ID verification ----------------

class VerifyIdScreen extends StatefulWidget {
  const VerifyIdScreen({super.key});

  @override
  State<VerifyIdScreen> createState() => _VerifyIdScreenState();
}

class _VerifyIdScreenState extends State<VerifyIdScreen> {
  String type = 'driving_licence';
  final last4 = TextEditingController();
  final file = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    last4.dispose();
    file.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => busy = true);
    final r = await guard(context, () => app.api.put('/me/id', {'id_doc_type': type, 'id_doc_last4': last4.text.trim(), 'id_doc_file': file.text.trim()}));
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) {
      await app.refreshMe();
      if (mounted) {
        toast(context, 'Submitted. We will check it soon.');
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your ID')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Everyone on CoRide is ID-verified so riders and drivers can trust each other. We keep only the last 4 characters of your ID number.'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'ID type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'driving_licence', child: Text('Driving licence')),
              DropdownMenuItem(value: 'voter_id', child: Text('Voter ID')),
              DropdownMenuItem(value: 'passport', child: Text('Passport')),
              DropdownMenuItem(value: 'aadhaar_masked', child: Text('Aadhaar (masked copy)')),
            ],
            onChanged: (v) => setState(() => type = v ?? type),
          ),
          const SizedBox(height: 12),
          TextField(controller: last4, maxLength: 4, decoration: const InputDecoration(labelText: 'Last 4 characters of ID number', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
            controller: file,
            decoration: const InputDecoration(
              labelText: 'Photo of ID (link)',
              border: OutlineInputBorder(),
              helperText: 'Photo upload comes in the next version. For now paste the link of the uploaded photo.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Submitting...' : 'Submit for verification')),
        ],
      ),
    );
  }
}

// ---------------- vehicles ----------------

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<Json>? vehicles;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await app.api.get('/vehicles');
      if (mounted) setState(() { vehicles = listOf(r['vehicles']); error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = vehicles;
    return Scaffold(
      appBar: AppBar(title: const Text('My vehicles')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add vehicle'),
        onPressed: () async {
          final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddVehicleScreen()));
          if (ok == true) load();
        },
      ),
      body: error != null
          ? Center(child: Text(error!))
          : list == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  children: [
                    const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Only private vehicles with valid insurance and licence can be used. Every vehicle is checked before it can offer rides.'))),
                    if (list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No vehicles added yet.'))),
                    for (final v in list)
                      Card(
                        child: ListTile(
                          isThreeLine: true,
                          leading: Icon(v['type'] == 'bike' ? Icons.two_wheeler : Icons.directions_car),
                          title: Text('${v['make_model']}  •  ${v['registration']}'),
                          subtitle: Text(
                            v['status'] == 'rejected'
                                ? 'Rejected: ${v['reject_reason']}'
                                : 'Documents valid until ${v['documents_valid_until']}',
                          ),
                          trailing: StatusChip(v['status'] as String),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  String type = 'car';
  String plate = 'white';
  bool privateUse = true;
  int seats = 4;
  final reg = TextEditingController();
  final model = TextEditingController();
  final rc = TextEditingController();
  final ins = TextEditingController();
  final dl = TextEditingController();
  final photo = TextEditingController();
  DateTime? insExpiry;
  DateTime? dlExpiry;
  bool busy = false;

  @override
  void dispose() {
    for (final c in [reg, model, rc, ins, dl, photo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _date(DateTime? cur) => showDatePicker(
        context: context,
        initialDate: cur ?? DateTime.now().add(const Duration(days: 180)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
      );

  Future<void> submit() async {
    if (insExpiry == null || dlExpiry == null) {
      toast(context, 'Choose the insurance and licence expiry dates.');
      return;
    }
    setState(() => busy = true);
    final r = await guard(
      context,
      () => app.api.post('/vehicles', {
        'type': type,
        'reg_number': reg.text.trim(),
        'make_model': model.text.trim(),
        'plate_color': plate,
        'usage_type': privateUse ? 'non_transport' : 'transport',
        if (type == 'car') 'passenger_seats': seats,
        'rc_doc': rc.text.trim(),
        'insurance_doc': ins.text.trim(),
        'insurance_expiry': ymd(insExpiry!),
        'licence_doc': dl.text.trim(),
        'licence_expiry': ymd(dlExpiry!),
        'photo_doc': photo.text.trim(),
      }),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) {
      toast(context, 'Submitted. We will verify your documents.');
      Navigator.pop(context, true);
    }
  }

  Widget _field(TextEditingController c, String label, {String? help}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), helperText: help)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a vehicle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'car', label: Text('Car'), icon: Icon(Icons.directions_car)),
              ButtonSegment(value: 'bike', label: Text('Bike'), icon: Icon(Icons.two_wheeler)),
            ],
            selected: {type},
            onSelectionChanged: (s) => setState(() => type = s.first),
          ),
          const SizedBox(height: 16),
          _field(reg, 'Registration number', help: 'For example KL07AB1234'),
          _field(model, 'Make and model'),
          DropdownButtonFormField<String>(
            initialValue: plate,
            decoration: const InputDecoration(labelText: 'Number plate colour', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'white', child: Text('White (private)')),
              DropdownMenuItem(value: 'green', child: Text('Green (private electric)')),
              DropdownMenuItem(value: 'yellow', child: Text('Yellow (taxi / commercial)')),
              DropdownMenuItem(value: 'black', child: Text('Black (rental)')),
            ],
            onChanged: (v) => setState(() => plate = v ?? plate),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: privateUse,
            onChanged: (v) => setState(() => privateUse = v ?? true),
            title: const Text('RC says "Non-transport" (private use)'),
          ),
          if (type == 'car')
            DropdownButtonFormField<int>(
              initialValue: seats,
              decoration: const InputDecoration(labelText: 'Seats you can share', border: OutlineInputBorder()),
              items: [for (var i = 1; i <= 4; i++) DropdownMenuItem(value: i, child: Text('$i'))],
              onChanged: (v) => setState(() => seats = v ?? 4),
            ),
          const SectionTitle('Documents'),
          const Text('Photo upload comes in the next version. For now paste the link of each uploaded photo.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          _field(rc, 'RC (registration certificate)'),
          _field(ins, 'Insurance certificate'),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(insExpiry == null ? 'Insurance expiry date' : 'Insurance valid until ${ymd(insExpiry!)}'),
            onPressed: () async {
              final d = await _date(insExpiry);
              if (d != null) setState(() => insExpiry = d);
            },
          ),
          const SizedBox(height: 12),
          _field(dl, 'Driving licence'),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(dlExpiry == null ? 'Licence expiry date' : 'Licence valid until ${ymd(dlExpiry!)}'),
            onPressed: () async {
              final d = await _date(dlExpiry);
              if (d != null) setState(() => dlExpiry = d);
            },
          ),
          const SizedBox(height: 12),
          _field(photo, 'Photo of the vehicle showing the number plate'),
          FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Submitting...' : 'Submit for verification')),
        ],
      ),
    );
  }
}

// ---------------- emergency contacts ----------------

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final List<TextEditingController> names = [];
  final List<TextEditingController> phones = [];
  bool loaded = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [...names, ...phones]) {
      c.dispose();
    }
    super.dispose();
  }

  void _add([String n = '', String p = '']) {
    names.add(TextEditingController(text: n));
    phones.add(TextEditingController(text: p));
  }

  Future<void> _load() async {
    try {
      final r = await app.api.get('/me/emergency-contacts');
      for (final c in listOf(r['contacts'])) {
        _add(c['name'].toString(), c['phone'].toString());
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (names.isEmpty) _add();
    if (mounted) setState(() => loaded = true);
  }

  Future<void> save() async {
    final contacts = <Json>[
      for (var i = 0; i < names.length; i++)
        if (names[i].text.trim().isNotEmpty || phones[i].text.trim().isNotEmpty) {'name': names[i].text.trim(), 'phone': phones[i].text.trim()},
    ];
    setState(() => busy = true);
    final r = await guard(context, () => app.api.put('/me/emergency-contacts', {'contacts': contacts}));
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) {
      toast(context, 'Saved.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency contacts')),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('These people get a message with your location when you press SOS during a ride. Add up to 3.'),
                const SizedBox(height: 12),
                for (var i = 0; i < names.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Expanded(child: TextField(controller: names[i], decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: phones[i], keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile', border: OutlineInputBorder()))),
                    ]),
                  ),
                if (names.length < 3) TextButton.icon(onPressed: () => setState(_add), icon: const Icon(Icons.add), label: const Text('Add another')),
                FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Saving...' : 'Save')),
              ],
            ),
    );
  }
}

// ---------------- notifications ----------------

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Json>? items;

  static const _text = {
    'booking_requested': 'Someone asked to join your ride.',
    'booking_accepted': 'Your request was accepted.',
    'booking_rejected': 'Your request was declined.',
    'booking_cancelled': 'A passenger cancelled.',
    'ride_cancelled': 'A ride you joined was cancelled.',
    'ride_completed': 'Your ride is complete. Please rate it.',
    'vehicle_verified': 'Your vehicle was verified. You can offer rides.',
    'vehicle_rejected': 'Your vehicle was rejected. Open My vehicles for the reason.',
    'id_verified': 'Your ID was verified.',
    'id_rejected': 'Your ID was rejected. Open Me for the reason.',
    'partner_requested': 'Someone wants to be your commute partner.',
    'partner_accepted': 'Your commute partner request was accepted.',
    'partner_rejected': 'Your commute partner request was declined.',
    'partner_ended': 'A commute partnership ended.',
    'partner_skipped': 'Your partner skipped a day.',
    'driver_skipped': 'Your driver will not ride on one day. Check the date.',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await guard(context, () => app.api.get('/me/notifications'));
    if (r == null || !mounted) return;
    setState(() => items = listOf(r['notifications']));
    app.api.post('/me/notifications/read-all').catchError((_) => <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? const Center(child: Text('Nothing yet.'))
              : ListView(
                  children: [
                    for (final n in list)
                      ListTile(
                        leading: Icon(n['read'] == true ? Icons.notifications_none : Icons.notifications_active),
                        title: Text(_text[n['type']] ?? n['type'].toString()),
                        subtitle: Text(fmtDateTime(n['created_at'] as String)),
                      ),
                  ],
                ),
    );
  }
}
