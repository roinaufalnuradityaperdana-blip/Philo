import 'package:test/test.dart';
import 'package:suoro/core/network/mdns_service.dart';
import 'package:suoro/core/session/session_models.dart';

void main() {
  group('MdnsDiscoveryService Peer Registry Tests', () {
    test('peer added and updated in registry', () {
      final service = MdnsDiscoveryService();
      const peer = PeerDevice(id: 'peer-1', name: 'Android-Pixel', os: 'android', host: '192.168.1.50', port: 53317);

      service.registerDiscoveredPeer(peer);
      expect(service.peers.length, equals(1));
      expect(service.peers.first.name, equals('Android-Pixel'));

      service.removePeer('peer-1');
      expect(service.peers.isEmpty, isTrue);
    });
  });
}
