import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TripManageSheet extends StatelessWidget {
  final String rampName;
  final DateTime eta;
  final int personsOnBoard;
  final VoidCallback onEditPeople;

  final VoidCallback onExtend30m;
  final VoidCallback onExtend1h;

  final bool showAcknowledge;
  final VoidCallback? onAcknowledgeOverdue;

  final Future<void> Function() onEndTrip;

  /// When personsOnBoard > 1, call to get join code and show invite UI.
  final Future<String?> Function()? onInviteCrew;

  const TripManageSheet({
    super.key,
    required this.rampName,
    required this.eta,
    required this.personsOnBoard,
    required this.onEditPeople,
    required this.onExtend30m,
    required this.onExtend1h,
    required this.showAcknowledge,
    required this.onAcknowledgeOverdue,
    required this.onEndTrip,
    this.onInviteCrew,
  });

  String _fmt(DateTime dt) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = rampName.isEmpty ? 'Manage Trip' : 'Manage Trip — $rampName';
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Material(
      color: Colors.black.withValues(alpha:0.55),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: Colors.white12),
          ),
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomPad),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // grab handle
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'ETA: ${_fmt(eta)}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              const SizedBox(height: 12),
              // People on board — tap row or Change to open simple +/- picker
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onEditPeople,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.groups_rounded, size: 20, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text(
                              'People on board: $personsOnBoard',
                              style: const TextStyle(fontSize: 14, color: Colors.white70),
                            ),
                          ],
                        ),
                        Text(
                          'Change',
                          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
                const SizedBox(height: 16),

                // Extend buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onExtend30m,
                        child: const Text('+ 30 min'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onExtend1h,
                        child: const Text('+ 1 hour'),
                      ),
                    ),
                  ],
                ),

                if (showAcknowledge) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onAcknowledgeOverdue,
                    child: const Text('Acknowledge Overdue'),
                  ),
                ],

                if (personsOnBoard > 1 && onInviteCrew != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      String? code;
                      try {
                        code = await onInviteCrew!();
                      } catch (e) {
                        if (!context.mounted) return;
                        final msg = e.toString().contains('PERMISSION_DENIED') || e.toString().contains('permission-denied')
                            ? 'Invite code needs Firestore rules. Deploy firestore.rules in Firebase Console → Firestore → Rules.'
                            : 'Couldn\'t create invite code. Check connection or try again.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg), backgroundColor: Colors.orange),
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      if (code == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Couldn\'t create invite code. Check connection or try again.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      final joinCode = code;
                      await showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => _InviteCrewSheet(joinCode: joinCode),
                      );
                    },
                    icon: const Icon(Icons.group_add_rounded, size: 20),
                    label: const Text('Invite crew'),
                  ),
                ],

                const SizedBox(height: 12),

                // End trip (async)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    await onEndTrip();
                  },
                  child: const Text('End Trip'),
                ),

                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteCrewSheet extends StatelessWidget {
  final String joinCode;

  const _InviteCrewSheet({required this.joinCode});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: Colors.white12),
          ),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Invite crew', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Share this code or QR so others can view this trip:', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                const SizedBox(height: 16),
                // QR code: encode join code so crew can scan instead of typing
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: joinCode,
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SelectableText(
                      joinCode,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: joinCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: const Text('Copy code'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
