import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../modules/presentation/children/control/presenter/cubit/cubit.dart';
import '../services/app_prefs_service.dart';
import 'remote_page.dart';
import 'remote_protocol.dart';
import 'remote_server.dart';

class RemoteStatus extends Equatable {
  const RemoteStatus({
    this.enabled = false,
    this.pin = '',
    this.port,
    this.addresses = const [],
    this.devices = 0,
    this.failed = false,
  });

  final bool enabled;
  final String pin;
  final int? port;

  /// Where a phone can reach this computer, best first. Empty means the
  /// computer is on no network a phone could share.
  final List<String> addresses;

  final int devices;

  /// The server could not start: every port it tried was taken.
  final bool failed;

  /// The address to open on a phone, PIN included for the QR code.
  String? get pairingUrl =>
      port == null || addresses.isEmpty ? null : 'http://${addresses.first}:$port/#pin=$pin';

  String? get address => port == null || addresses.isEmpty ? null : '${addresses.first}:$port';

  RemoteStatus copyWith({
    bool? enabled,
    String? pin,
    int? port,
    bool clearPort = false,
    List<String>? addresses,
    int? devices,
    bool? failed,
  }) => RemoteStatus(
    enabled: enabled ?? this.enabled,
    pin: pin ?? this.pin,
    port: clearPort ? null : port ?? this.port,
    addresses: addresses ?? this.addresses,
    devices: devices ?? this.devices,
    failed: failed ?? this.failed,
  );

  @override
  List<Object?> get props => [enabled, pin, port, addresses, devices, failed];
}

/// Lets phones on this network control the presenter.
///
/// Off until the operator turns it on, and remembered from then: the phone
/// the worship leader paired last Sunday should work this Sunday without
/// anyone looking for a QR code during the first song.
class RemoteControl {
  RemoteControl(
    this._control,
    this._prefs, {
    int port = 8765,
    Future<List<String>> Function()? addresses,
  }) : _port = port,
       _addresses = addresses ?? localAddresses;

  final ControlCubit _control;
  final AppPrefsService _prefs;
  final int _port;
  final Future<List<String>> Function() _addresses;

  final status = ValueNotifier(const RemoteStatus());

  RemoteServer? _server;
  StreamSubscription<ControlState>? _stateSub;
  StreamSubscription<int>? _deviceSub;
  Set<String> _tokens = {};

  /// Picks up where the last session left off.
  Future<void> restore() async {
    final saved = await _prefs.loadRemote() ?? const {};
    final pin = saved['pin'] is String && (saved['pin'] as String).length == 6
        ? saved['pin'] as String
        : newRemotePin();
    _tokens = {for (final t in saved['tokens'] as List? ?? const []) ?(t is String ? t : null)};
    status.value = status.value.copyWith(pin: pin);
    if (saved['enabled'] == true) await enable();
  }

  Future<void> enable() async {
    if (_server != null) return;
    if (status.value.pin.isEmpty) status.value = status.value.copyWith(pin: newRemotePin());
    final server = RemoteServer(
      page: remotePageHtml,
      pin: status.value.pin,
      tokens: _tokens,
      preferredPort: _port,
      onCommand: (message) {
        final command = RemoteCommand.parse(message);
        if (command != null) applyRemoteCommand(_control, command);
      },
      onTokensChanged: (tokens) {
        _tokens = tokens;
        unawaited(_save());
      },
    );
    try {
      await server.start();
    } catch (_) {
      status.value = status.value.copyWith(enabled: false, failed: true, clearPort: true);
      return;
    }
    _server = server;
    _deviceSub = server.devices.listen((n) => status.value = status.value.copyWith(devices: n));
    _publish(_control.state);
    _stateSub = _control.stream.listen(_publish);
    status.value = status.value.copyWith(
      enabled: true,
      failed: false,
      port: server.port,
      addresses: await _addresses(),
    );
    await _save();
  }

  Future<void> disable() async {
    await _shutdown();
    status.value = status.value.copyWith(enabled: false, devices: 0, clearPort: true);
    await _save();
  }

  /// A new PIN, and every paired phone forgotten.
  Future<void> renewPin() async {
    final pin = newRemotePin();
    _tokens = {};
    status.value = status.value.copyWith(pin: pin);
    await _server?.renew(pin);
    await _save();
  }

  /// Looks for the network again, for when the computer joined a different
  /// one since the remote was turned on.
  Future<void> refreshAddresses() async {
    status.value = status.value.copyWith(addresses: await _addresses());
  }

  Future<void> dispose() async {
    await _shutdown();
    status.dispose();
  }

  Future<void> _shutdown() async {
    await _stateSub?.cancel();
    await _deviceSub?.cancel();
    _stateSub = null;
    _deviceSub = null;
    final server = _server;
    _server = null;
    await server?.dispose();
  }

  void _publish(ControlState state) {
    if (state is ControlLoadedState) _server?.publish(remoteSnapshot(state.model));
  }

  Future<void> _save() => _prefs.saveRemote({
    'enabled': status.value.enabled,
    'pin': status.value.pin,
    'tokens': [..._tokens],
  });
}
