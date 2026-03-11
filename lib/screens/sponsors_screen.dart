import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SponsorsScreen extends StatelessWidget {
  const SponsorsScreen({super.key});

  static const Color _bg = Color(0xFF02050A);

  static const List<_Sponsor> _sponsors = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          "Sponsors",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: const Text(
                "Sponsor listings will appear here. Contact us to become a partner.",
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _sponsors.isEmpty
                  ? const Center(
                      child: Text(
                        "No sponsors yet",
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: _sponsors.length,
                      itemBuilder: (context, index) {
                        final s = _sponsors[index];
                        return _SponsorCard(
                          sponsor: s,
                          onTap: () => _openUrl(context, s.url),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open link")),
        );
      }
    }
  }
}

class _SponsorCard extends StatelessWidget {
  final _Sponsor sponsor;
  final VoidCallback onTap;

  const _SponsorCard({required this.sponsor, required this.onTap});

  static const Color _accent = Color(0xFF2CB6FF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha:0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha:0.5)),
                ),
                child: const Icon(Icons.business_rounded, color: _accent, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                sponsor.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sponsor.subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha:0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Tap to open",
                style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sponsor {
  final String name;
  final String subtitle;
  final String url;

  const _Sponsor({
    required this.name,
    required this.subtitle,
    required this.url,
  });
}
