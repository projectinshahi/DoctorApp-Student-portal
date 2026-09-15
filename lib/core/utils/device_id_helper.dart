// lib/core/utils/device_id_helper.dart
//
// The identifier the server binds an account to.
//
// This has to survive a reinstall. Device binding exists to stop one person
// running several accounts on one phone to share a subscription — and a UUID
// kept in SharedPreferences defeats that completely, because clearing app
// data or reinstalling mints a brand new one. Anybody wanting a second
// account would simply reinstall.
//
// So the id comes from the platform wherever the platform offers something
// durable:
//
//  * **Android** — `ANDROID_ID`. Unique per (device, user, app signing key),
//    survives reinstalling, and resets only on a factory reset.
//
//  * **iOS** — `identifierForVendor`. Survives reinstalling *while another
//    app from the same vendor is installed*, and otherwise resets. Weaker
//    than Android's, and worth knowing when reading the numbers: on iOS a
//    determined user can still cycle it by deleting the app. Closing that
//    properly means keeping a UUID in the Keychain, which outlives deletion.
//
// The stored UUID remains the fallback for anything else and for a platform
// call that fails, so a device is never left without an id.
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdHelper {
  static const String _key = 'device_id';

  /// Cached for the process: the platform call crosses a channel, and login
  /// is not the only caller.
  static String? _cached;

  static Future<String> getDeviceId() async {
    final cached = _cached;
    if (cached != null) return cached;

    final platformId = await _platformId();
    if (platformId != null && platformId.isNotEmpty) {
      // Mirrored into prefs so a later platform failure cannot silently
      // change the device's identity and lock the student out.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, platformId);
      _cached = platformId;
      return platformId;
    }

    return _cached = await _storedOrNewUuid();
  }

  static Future<String?> _platformId() async {
    try {
      final info = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        // NOT AndroidDeviceInfo.id — that is Build.ID, the OS build label,
        // identical across every device on the same firmware.
        const channel = MethodChannel('dr_app/device');
        return await channel.invokeMethod<String>('getAndroidId');
      }
      if (Platform.isIOS) {
        return (await info.iosInfo).identifierForVendor;
      }
    } catch (e) {
      // A platform that cannot answer is not a reason to block a login — the
      // UUID fallback still identifies the install.
      debugPrint('DeviceIdHelper: platform id unavailable ($e)');
    }
    return null;
  }

  static Future<String> _storedOrNewUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null && stored.isNotEmpty) return stored;

    final generated = const Uuid().v4();
    await prefs.setString(_key, generated);
    return generated;
  }
}
