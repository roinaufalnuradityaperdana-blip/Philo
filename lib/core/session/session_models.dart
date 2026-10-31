enum TransferSessionState {
  idle,
  requestPending,
  transferring,
  completed,
  rejected,
  failed,
  cancelled,
}

class PeerDevice {
  final String id;
  final String name;
  final String os;
  final String host;
  final int port;
  final String? fingerprint;

  const PeerDevice({
    required this.id,
    required this.name,
    required this.os,
    required this.host,
    required this.port,
    this.fingerprint,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'os': os,
    'host': host,
    'port': port,
    'fingerprint': fingerprint,
  };

  factory PeerDevice.fromJson(Map<String, dynamic> json) => PeerDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    os: json['os'] as String,
    host: json['host'] as String,
    port: json['port'] as int,
    fingerprint: json['fingerprint'] as String?,
  );
}

class TransferItem {
  final String id;
  final String name;
  final int size;
  final String mime;

  const TransferItem({
    required this.id,
    required this.name,
    required this.size,
    required this.mime,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'mime': mime,
  };

  factory TransferItem.fromJson(Map<String, dynamic> json) => TransferItem(
    id: json['id'] as String,
    name: json['name'] as String,
    size: json['size'] as int,
    mime: json['mime'] as String,
  );
}

class TransferSession {
  final String sessionId;
  final PeerDevice peer;
  final List<TransferItem> items;
  final String? text;
  final bool isOutgoing;
  int bytesTransferred;

  TransferSession({
    required this.sessionId,
    required this.peer,
    required this.items,
    this.text,
    required this.isOutgoing,
    this.bytesTransferred = 0,
  });

  int get totalSize => items.fold(0, (sum, item) => sum + item.size);
  double get progressPercentage => totalSize == 0 ? 1.0 : (bytesTransferred / totalSize).clamp(0.0, 1.0);
}
