import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'format.dart';
import 'places.dart';

/// Runs an API call and shows the server's message in a snackbar if it fails.
/// Returns null on failure.
Future<T?> guard<T>(BuildContext context, Future<T> Function() fn) async {
  try {
    return await fn();
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message);
    return null;
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(BuildContext context, String title, String message, {String yes = 'Yes'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
      ],
    ),
  );
  return r == true;
}

// ---------------- place picker ----------------

Future<Place?> pickPlace(BuildContext context) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _PlaceSheet(),
  );
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet();

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final list = kPlaces.where((p) => p.name.toLowerCase().contains(q.toLowerCase())).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search a place',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => q = v),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('No place found'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(list[i].name),
                          onTap: () => Navigator.pop(context, list[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaceField extends StatelessWidget {
  final String label;
  final Place? value;
  final ValueChanged<Place> onChanged;
  final VoidCallback? onClear;

  const PlaceField({super.key, required this.label, required this.value, required this.onChanged, this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final p = await pickPlace(context);
        if (p != null) onChanged(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: (value != null && onClear != null)
              ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
              : const Icon(Icons.search),
        ),
        child: Text(value?.name ?? 'Select place'),
      ),
    );
  }
}

// ---------------- small pieces ----------------

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'accepted':
      case 'verified':
      case 'completed':
      case 'open':
        c = Colors.green;
        break;
      case 'rejected':
      case 'cancelled':
      case 'ended':
        c = Colors.red;
        break;
      default:
        c = Colors.orange;
    }
    return Chip(
      label: Text(status, style: TextStyle(color: c.withAlpha(255), fontSize: 12)),
      backgroundColor: c.withAlpha(30),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      );
}

class RatingText extends StatelessWidget {
  final Json rating;
  const RatingText(this.rating, {super.key});

  @override
  Widget build(BuildContext context) {
    final count = rating['count'] ?? 0;
    if (count == 0) return const Text('New member');
    return Text('★ ${rating['average']} ($count)');
  }
}

/// Shows the estimated cost split. Always labelled as an estimate.
class CostCard extends StatelessWidget {
  final Json cost;
  final bool showJoinShare;
  const CostCard({super.key, required this.cost, this.showJoinShare = true});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final toll = (cost['toll'] as num?) ?? 0;
    final fill = cost['if_seats_fill'] == null ? <Json>[] : listOf(cost['if_seats_fill']);
    Widget row(String a, String b, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(a),
              Text(b, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shared expenses (estimate)', style: t.titleSmall),
            const SizedBox(height: 8),
            row('Petrol', money(cost['fuel_estimate'] as num)),
            if (toll > 0) row('Toll${cost['toll_plazas'] != null ? ' (${cost['toll_plazas']})' : ''}', money(toll)),
            row('Total to share', money(cost['total_to_share'] as num), bold: true),
            const Divider(),
            row('People sharing now (incl. driver)', '${cost['people_sharing_now']}'),
            row('Each person pays now', money(cost['share_per_person_now'] as num), bold: true),
            if (showJoinShare) row('If you join, you pay about', money(cost['your_share_if_you_join'] as num), bold: true),
            if (fill.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Share per person as the seats fill', style: t.bodySmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final f in fill)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${f['passengers']} joined: ${money(f['share_per_person'] as num)}'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'The driver pays an equal share too. Pay your share directly to the driver (cash or UPI). The app never holds money.',
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner shown until the user's ID is verified.
class VerifyBanner extends StatelessWidget {
  final String status;
  final VoidCallback onTap;
  const VerifyBanner({super.key, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (status == 'verified') return const SizedBox.shrink();
    final text = {
          'none': 'Verify your ID to offer or join rides.',
          'pending': 'Your ID is being checked. You can offer or join rides once it is verified.',
          'rejected': 'Your ID was rejected. Please submit it again.',
        }[status] ??
        'Verify your ID to continue.';
    return Card(
      color: Colors.amber.shade100,
      child: ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: Text(text),
        trailing: status == 'pending' ? null : const Icon(Icons.chevron_right),
        onTap: status == 'pending' ? null : onTap,
      ),
    );
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, 'Copied');
}
