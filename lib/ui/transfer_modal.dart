import 'package:flutter/material.dart';
import '../core/session/session_models.dart';
import '../core/session/transfer_state_machine.dart';

class TransferModal extends StatelessWidget {
  final TransferStateMachine stateMachine;
  final VoidCallback onCancel;

  const TransferModal({
    super.key,
    required this.stateMachine,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final session = stateMachine.currentSession;
    final state = stateMachine.state;

    return AlertDialog(
      title: Text(state == TransferSessionState.completed ? 'Transfer Selesai' : 'Mentransfer Data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session != null) ...[
            Text('Target: ${session.peer.name} (${session.peer.os})'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: session.progressPercentage),
            const SizedBox(height: 8),
            Text('${(session.progressPercentage * 100).toStringAsFixed(1)}% (${session.bytesTransferred} / ${session.totalSize} bytes)'),
          ],
          if (state == TransferSessionState.failed)
            Text('Gagal: ${stateMachine.failureReason ?? "Kesalahan jaringan"}', style: const TextStyle(color: Colors.red)),
          if (state == TransferSessionState.rejected)
            const Text('Penerima menolak transfer.', style: TextStyle(color: Colors.orange)),
        ],
      ),
      actions: [
        if (state == TransferSessionState.completed || state == TransferSessionState.failed || state == TransferSessionState.rejected)
          TextButton(
            child: const Text('Tutup'),
            onPressed: () {
              stateMachine.reset();
              Navigator.of(context).pop();
            },
          )
        else
          TextButton(
            onPressed: () {
              onCancel();
              Navigator.of(context).pop();
            },
            child: const Text('Batal'),
          ),
      ],
    );
  }
}
