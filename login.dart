import 'package:flutter/material.dart';

import '../api.dart';
import '../state.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = TextEditingController();
  final otp = TextEditingController();
  final name = TextEditingController();
  String? gender;
  bool otpSent = false;
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    otp.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> sendOtp() async {
    setState(() => busy = true);
    final r = await guard(context, () => app.api.post('/auth/request-otp', {'phone': phone.text.trim()}));
    if (!mounted) return;
    setState(() => busy = false);
    if (r == null) return;
    // The server only returns dev_otp in development, so testing is easy. Real users get an SMS.
    if (r['dev_otp'] != null) otp.text = r['dev_otp'].toString();
    setState(() => otpSent = true);
  }

  Future<void> verify() async {
    setState(() => busy = true);
    final r = await guard(
      context,
      () => app.api.post('/auth/verify-otp', {
        'phone': phone.text.trim(),
        'otp': otp.text.trim(),
        if (name.text.trim().isNotEmpty) 'name': name.text.trim(),
        if (gender != null) 'gender': gender,
      }),
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (r == null) return;
    await app.login(r['token'] as String, Map<String, dynamic>.from(r['user'] as Map));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.directions_car_filled, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('CoRide', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'Share travel expenses with verified people going your way.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: phone,
                    enabled: !otpSent,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixText: '+91 ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!otpSent)
                    FilledButton(onPressed: busy ? null : sendOtp, child: Text(busy ? 'Sending...' : 'Send OTP'))
                  else ...[
                    TextField(
                      controller: otp,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: '6-digit OTP', border: OutlineInputBorder()),
                    ),
                    const Text('New here? Add your name so people know who is travelling.'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: gender,
                      decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => gender = v),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: busy ? null : verify, child: Text(busy ? 'Checking...' : 'Verify and continue')),
                    TextButton(
                      onPressed: busy ? null : () => setState(() => otpSent = false),
                      child: const Text('Change number'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
