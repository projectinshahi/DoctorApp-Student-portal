// lib/core/utils/device_integrity.dart
//
// Whether this device is one the app is willing to run on.
//
// A rooted or jailbroken device can read another app's memory, strip
// FLAG_SECURE with a Magisk module, and hook the video player directly — so
// every other protection in the app rests on this one being true. Blocking
// here is not about the device owner; it is about the lessons.
//
// **This is a client-side check, and a determined attacker on a rooted device
// can patch it out.** It stops the casual case, which is most of it. Making
// it un-patchable means server-side attestation — see `verifyEndpoint` below.
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';

enum IntegrityVerdict {
  ok,

  /// Rooted (Android) or jailbroken (iOS).
  compromised,

  /// An emulator. Blocked in release only — the whole team develops on these.
  emulator,
}

class DeviceIntegrity {
  const DeviceIntegrity._();

  /// Runs the checks. Never throws: a plugin that fails to answer must not
  /// lock every student out of the app.
  static Future<IntegrityVerdict> check() async {
    // Debug and profile builds run on emulators all day. Enforcing there
    // would make the app undevelopable, and an attacker cannot ship a debug
    // build to the store anyway.
    if (kDebugMode || kProfileMode) return IntegrityVerdict.ok;

    try {
      if (await SafeDevice.isJailBroken) return IntegrityVerdict.compromised;

      // Not a real device: an emulator can be inspected frame by frame, which
      // defeats the capture guard entirely.
      if (!await SafeDevice.isRealDevice) return IntegrityVerdict.emulator;

      return IntegrityVerdict.ok;
    } catch (_) {
      // Fail open, deliberately. A student whose device the plugin cannot
      // read is far more likely to be on an unusual-but-honest phone than to
      // be an attacker — and an attacker would simply patch this out anyway.
      // Locking them out would cost a paying customer to stop nobody.
      return IntegrityVerdict.ok;
    }
  }
}
