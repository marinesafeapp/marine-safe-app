import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/trip_cloud_service.dart';

class JoinBoatScreen extends StatefulWidget {
  const JoinBoatScreen({super.key});

  @override
  State<JoinBoatScreen> createState() => _JoinBoatScreenState();
}

class _JoinBoatScreenState extends State<JoinBoatScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _trip;

  static const int _codeLength = 6;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != _codeLength) {
      setState(() {
        _error = 'Enter a $_codeLength-character code';
        _trip = null;
      });
      return;
    }
    setState(() {
      _error = null;
      _trip = null;
      _loading = true;
    });
    try {
      final trip = await TripCloudService.instance.lookupTripByCode(code);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _trip = trip;
        if (trip == null) _error = 'Invalid or expired code';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a boat'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Enter the 6-character code from the skipper to view the same trip.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                focusNode: _codeFocus,
                textCapitalization: TextCapitalization.characters,
                maxLength: _codeLength,
                decoration: InputDecoration(
                  labelText: 'Join code',
                  hintText: 'e.g. ABC123',
                  counterText: '',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(_codeLength),
                ],
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _join,
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join'),
              ),
              if (_trip != null) ...[
                const SizedBox(height: 32),
                _CrewTripCard(trip: _trip!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CrewTripCard extends StatelessWidget {
  final Map<String, dynamic> trip;

  const _CrewTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final rampName = trip['rampName'] as String? ?? '—';
    final etaIso = trip['etaIso'] as String? ?? '';
    final isOverdue = trip['isOverdue'] as bool? ?? false;
    final name = trip['name'] as String? ?? 'Skipper';
    DateTime? eta;
    if (etaIso.isNotEmpty) {
      try {
        eta = DateTime.parse(etaIso);
      } catch (_) {}
    }
    String etaStr = '—';
    if (eta != null) {
      final h = eta.hour.toString().padLeft(2, '0');
      final m = eta.minute.toString().padLeft(2, '0');
      etaStr = '$h:$m';
    }

    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_boat_rounded, color: Colors.teal.shade300),
                const SizedBox(width: 8),
                Text(
                  'Crew view — $name\'s trip',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(Icons.pin_drop_rounded, 'Ramp', rampName),
            const SizedBox(height: 6),
            _row(Icons.schedule_rounded, 'ETA', etaStr),
            if (isOverdue) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade300, size: 20),
                    const SizedBox(width: 8),
                    Text('Trip marked overdue', style: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
