import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  final TextEditingController _textController = TextEditingController();
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickAndSendFiles(PeerDevice peer) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      final files = result.paths.whereType<String>().map((p) => File(p)).toList();
      if (files.isNotEmpty) {
        _sendFilesToPeer(peer, files);
      }
    }
  }

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
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(ok ? 'Teks berhasil terkirim ke ${peer.name}' : 'Gagal mengirim teks'),
        ),
      );
      if (ok) _textController.clear();
    }
  }

  void _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _textController.text = data.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF2563EB);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Suoro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(
                    'Perangkat ini: ${widget.localDevice.name}',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Buka Folder Download',
              icon: const Icon(Icons.folder_outlined),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Folder penyimpanan: ${widget.storageService.baseDirectory.path}'),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Drag & Drop Header Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _isDragging ? primaryColor.withOpacity(0.08) : cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDragging ? primaryColor : borderColor,
                      width: _isDragging ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 40,
                        color: _isDragging ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isDragging ? 'Lepaskan file untuk mengirim' : 'Tarik & Lepas File ke Sini',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Atau pilih perangkat di bawah untuk mulai kirim',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Quick Text / Clipboard Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Ketik pesan, catatan, atau tempel link...',
                            hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                            isDense: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tempel dari Clipboard',
                        icon: const Icon(Icons.content_paste_outlined, size: 20),
                        onPressed: _pasteClipboard,
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: widget.mdnsService.peers.isEmpty
                            ? null
                            : () => _sendTextToPeer(widget.mdnsService.peers.first),
                        child: const Text('Kirim'),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Nearby Devices List Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Perangkat Sekitar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    AnimatedBuilder(
                      animation: _radarController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: (0.4 + (_radarController.value * 0.6)),
                          child: Row(
                            children: const [
                              Icon(Icons.wifi_tethering, size: 16, color: primaryColor),
                              SizedBox(width: 4),
                              Text('Mencari...', style: TextStyle(fontSize: 12, color: primaryColor)),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // 4. Peers List
              Expanded(
                child: AnimatedBuilder(
                  animation: widget.mdnsService,
                  builder: (context, _) {
                    final peers = widget.mdnsService.peers;
                    if (peers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.radar, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                            const SizedBox(height: 12),
                            const Text('Menunggu perangkat lain di Wi-Fi...', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(
                              'Pastikan HP Android & PC Windows terhubung ke Wi-Fi / Hotspot yang sama.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: peers.length,
                      itemBuilder: (context, idx) {
                        final peer = peers[idx];
                        final isWin = peer.os == 'windows';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (isWin ? Colors.blue : Colors.green).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isWin ? Icons.laptop_windows : Icons.phone_android,
                                  color: isWin ? Colors.blue : Colors.green,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(peer.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(
                                      isWin ? 'Windows PC' : 'Android Smartphone',
                                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.attach_file, size: 16),
                                label: const Text('Kirim'),
                                onPressed: () => _pickAndSendFiles(peer),
                              ),
                            ],
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
