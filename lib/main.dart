import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'core/network/http_client_node.dart';
import 'core/network/http_server_node.dart';
import 'core/network/mdns_service.dart';
import 'core/session/session_models.dart';
import 'core/session/transfer_state_machine.dart';
import 'core/storage/storage_service.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  final docsDir = await getApplicationDocumentsDirectory();
  final storageDir = Directory('${docsDir.path}/Suoro');
  final storage = StorageService(baseDirectory: storageDir);
  final stateMachine = TransferStateMachine();
  final mdns = MdnsDiscoveryService();
  final client = HttpClientNode();

  final myName = Platform.isWindows ? 'Windows-PC' : 'Android-Phone';
  final myOs = Platform.operatingSystem;
  final localNode = PeerDevice(id: 'local_node', name: myName, os: myOs, host: '0.0.0.0', port: 53317);

  final server = HttpServerNode(
    deviceInfo: localNode,
    storageService: storage,
    stateMachine: stateMachine,
  );
  await server.start(port: 53317);

  await mdns.startAdvertising(deviceName: myName, osName: myOs, port: 53317);
  await mdns.startDiscovery();

  runApp(SuoroApp(
    storageService: storage,
    stateMachine: stateMachine,
    mdnsService: mdns,
    clientNode: client,
    localDevice: localNode,
  ));
}

class SuoroApp extends StatelessWidget {
  final StorageService storageService;
  final TransferStateMachine stateMachine;
  final MdnsDiscoveryService mdnsService;
  final HttpClientNode clientNode;
  final PeerDevice localDevice;

  const SuoroApp({
    super.key,
    required this.storageService,
    required this.stateMachine,
    required this.mdnsService,
    required this.clientNode,
    required this.localDevice,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suoro - P2P Zero-Cloud Drop',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: HomeScreen(
        storageService: storageService,
        stateMachine: stateMachine,
        mdnsService: mdnsService,
        clientNode: clientNode,
        localDevice: localDevice,
      ),
    );
  }
}
