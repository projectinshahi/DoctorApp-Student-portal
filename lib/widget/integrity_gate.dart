// lib/widget/integrity_gate.dart
//
// Stands in front of the whole app while the device is checked.
import 'package:flutter/material.dart';

import '../core/utils/device_integrity.dart';

const Color _kBg = Color(0xFFEFF4E2);

class IntegrityGate extends StatefulWidget {
  final Widget child;

  const IntegrityGate({super.key, required this.child});

  @override
  State<IntegrityGate> createState() => _IntegrityGateState();
}

class _IntegrityGateState extends State<IntegrityGate> {
  /// Held as a future rather than re-run in build: the native checks touch
  /// the filesystem, and running them on every rebuild would cost a frame
  /// each time.
  late final Future<IntegrityVerdict> _verdict = DeviceIntegrity.check();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IntegrityVerdict>(
      future: _verdict,
      builder: (context, snapshot) {
        // Nothing rendered until the answer is in. A one-frame flash of the
        // real app on a rooted device is a frame that can be captured.
        if (!snapshot.hasData) {
          return const ColoredBox(
            color: _kBg,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return switch (snapshot.data!) {
          IntegrityVerdict.ok => widget.child,
          IntegrityVerdict.compromised => const _Blocked(
              title: 'This device is not supported',
              body: 'Dr. SKM’s Academy does not run on rooted or '
                  'jailbroken devices, because course content cannot be '
                  'protected on them.\n\nPlease use a standard device.',
            ),
          IntegrityVerdict.emulator => const _Blocked(
              title: 'Emulators are not supported',
              body: 'Course content cannot be protected inside an emulator.\n\n'
                  'Please install the app on a phone or tablet.',
            ),
        };
      },
    );
  }
}

class _Blocked extends StatelessWidget {
  final String title;
  final String body;

  const _Blocked({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    // No Scaffold action and no retry: there is nothing the student can do
    // here, and a "try again" button would only invite patching.
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_bad_outlined, size: 56, color: Color(0xFF87986B)),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 12),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.5, color: Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }
}
