import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import '../session/session_models.dart';

class MdnsDiscoveryService extends ChangeNotifier {
  static const String serviceType = '_suoro._tcp';
  final Map<String, PeerDevice> _peers = {};
  nsd.Registration? _registration;
  nsd.Discovery? _discovery;

  List<PeerDevice> get peers => _peers.values.toList();

  void registerDiscoveredPeer(PeerDevice peer) {
    _peers[peer.id] = peer;
    notifyListeners();
  }

  void removePeer(String peerId) {
    if (_peers.remove(peerId) != null) {
      notifyListeners();
    }
  }

  Future<void> startAdvertising({
    required String deviceName,
    required String osName,
    required int port,
  }) async {
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: deviceName,
          type: serviceType,
          port: port,
          txt: {
            'os': Uint8List.fromList(osName.codeUnits),
            'name': Uint8List.fromList(deviceName.codeUnits),
          },
        ),
      );
    } catch (e) {
      debugPrint('mDNS advertising error: $e');
    }
  }

  Future<void> startDiscovery() async {
    try {
      _discovery = await nsd.startDiscovery(serviceType);
      _discovery?.addServiceListener((service, status) {
        if (status == nsd.ServiceStatus.found) {
          final host = service.host ?? '127.0.0.1';
          final port = service.port ?? 53317;
          final nameBytes = service.txt?['name'];
          final osBytes = service.txt?['os'];
          final name = nameBytes != null ? String.fromCharCodes(nameBytes) : service.name ?? 'Unknown Peer';
          final os = osBytes != null ? String.fromCharCodes(osBytes) : 'unknown';

          final peer = PeerDevice(
            id: '${host}_$port',
            name: name,
            os: os,
            host: host,
            port: port,
          );
          registerDiscoveredPeer(peer);
        }
      });
    } catch (e) {
      debugPrint('mDNS discovery error: $e');
    }
  }

  Future<void> stop() async {
    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }
    if (_discovery != null) {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
    }
    _peers.clear();
    notifyListeners();
  }
}
