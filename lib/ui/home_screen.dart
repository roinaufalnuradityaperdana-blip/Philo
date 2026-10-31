import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import '../core/network/http_client_node.dart';
import '../core/network/mdns_service.dart';
import '../core/session/session_models.dart';
import '../core/session/transfer_state_machine.dart';
import '../core/storage/storage_service.dart';
import 'transfer_modal.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final TransferStateMachine stateMachine;
  final MdnsDiscoveryService mdnsService;
  final HttpClientNode clientNode;
  final PeerDevice localDevice;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.stateMachine,
    required this.mdnsService,
    required this.clientNode,
    required this.localDevice,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDragging = false;
  final TextEditingController _textController = TextEditingController();

  void _sendFilesToPeer(PeerDevice peer, List<File> files) async {
    final items = files.map((f) => TransferItem(
      id: f.path,
      name: f.uri.pathSegments.last,
      size: f.lengthSync(),
      mime: 'application/octet-stream',
    )).toList();

    widget.stateMachine.startOutgoingRequest(peer: peer, items: items);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransferModal(
        stateMachine: widget.stateMachine,
        onCancel: () => widget.stateMachine.cancel(),
      ),
    );

    final accepted = await widget.clientNode.requestTransfer(
      peer: peer,
      sessionId: widget.stateMachine.currentSession!.sessionId,
      sender: widget.localDevice,
      items: items,
    );

    if (accepted) {
      widget.stateMachine.markApproved();
      for (final f in files) {
        await widget.clientNode.streamFile(
          peer: peer,
          sessionId: widget.stateMachine.currentSession!.sessionId,
          file: f,
          onProgress: (sent, total) => widget.stateMachine.updateProgress(bytes: sent),
        );
      }
      widget.stateMachine.markCompleted();
    } else {
      widget.stateMachine.markRejected();
    }
  }

  void _sendTextToPeer(PeerDevice peer) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final ok = await widget.clientNode.sendText(peer: peer, text: text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Teks terkirim ke ${peer.name}' : 'Gagal mengirim teks')),
      );
      if (ok) _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) {
        setState(() => _isDragging = false);
        final files = detail.files.map((x) => File(x.path)).toList();
        if (files.isNotEmpty && widget.mdnsService.peers.isNotEmpty) {
          _sendFilesToPeer(widget.mdnsService.peers.first, files);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Suoro Drop'),
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lokasi: ${widget.storageService.baseDirectory.path}')),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isDragging)
              Container(
                height: 80,
                color: Theme.of(context).colorScheme.primaryContainer,
                alignment: Alignment.center,
                child: const Text('Lepaskan file di sini untuk mengirim', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Ketik pesan atau tempel teks / URL...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Kirim'),
                    onPressed: widget.mdnsService.peers.isEmpty ? null : () => _sendTextToPeer(widget.mdnsService.peers.first),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Perangkat di Sekitar (${widget.mdnsService.peers.length})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.mdnsService,
                builder: (context, _) {
                  final peers = widget.mdnsService.peers;
                  if (peers.isEmpty) {
                    return const Center(child: Text('Mencari perangkat Suoro di Wi-Fi lokal...'));
                  }
                  return ListView.builder(
                    itemCount: peers.length,
                    itemBuilder: (context, idx) {
                      final peer = peers[idx];
                      return ListTile(
                        leading: Icon(peer.os == 'windows' ? Icons.laptop_windows : Icons.phone_android),
                        title: Text(peer.name),
                        subtitle: Text('${peer.host}:${peer.port}'),
                        trailing: ElevatedButton(
                          child: const Text('Kirim File'),
                          onPressed: () {
                            // Handler dialog file
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
