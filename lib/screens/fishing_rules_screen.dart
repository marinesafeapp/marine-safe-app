import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// QLD recreational fishing rules — possession/size limits, closed seasons, and links to official source.
class FishingRulesScreen extends StatefulWidget {
  const FishingRulesScreen({super.key});

  @override
  State<FishingRulesScreen> createState() => _FishingRulesScreenState();
}

class _FishingRulesScreenState extends State<FishingRulesScreen> {
  static const Color _bg = Color(0xFF02050A);
  static const Color _accent = Color(0xFF2CB6FF);
  static const String _rulesUrl = 'https://www.qld.gov.au/recreation/activities/boating-fishing/rec-fishing/rules';
  static const String _tidalUrl = 'https://www.qld.gov.au/recreation/activities/boating-fishing/rec-fishing/rules/limits-tidal';
  static const String _freshUrl = 'https://www.qld.gov.au/recreation/activities/boating-fishing/rec-fishing/rules/limits-fresh';
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Could not open link. Try again or open in a browser.')),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          "QLD Fishing Rules",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottomPad),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              "A quick reference for Queensland recreational fishing — limits, sizes, closed seasons. Always check the official QLD Government site for current rules.",
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.45),
            ),
          ),
          _section("Possession limits", Icons.inventory_2_rounded, [
            "A general possession limit of 20 applies to species not specifically listed (tidal and freshwater).",
            "Possession limit = total you can have at any time, including at home — not a daily limit.",
            "Many species have lower limits or no-take; check the official guides.",
          ]),
          const SizedBox(height: 20),
          _section("Size limits", Icons.straighten_rounded, [
            "Minimum and maximum size limits apply to many species (e.g. barramundi, mud crab).",
            "Undersized or oversized fish must be returned to the water immediately.",
            "Measure from the tip of the snout to the end of the tail (total length) unless stated otherwise.",
          ]),
          const SizedBox(height: 20),
          _section("Closed seasons & no-take", Icons.block_rounded, [
            "Some species have closed seasons (e.g. barramundi in certain areas).",
            "No-take species must not be kept. Green zones and other areas may have extra restrictions.",
            "Check the current rules for your area and target species.",
          ]),
          const SizedBox(height: 24),
          _linkCard(
            context,
            icon: Icons.gavel_rounded,
            title: "Full rules (QLD Gov)",
            subtitle: "Recreational fishing rules — limits, closed seasons, zones",
            onTap: () => _openUrl(_rulesUrl),
          ),
          const SizedBox(height: 12),
          _linkCard(
            context,
            icon: Icons.waves_rounded,
            title: "Tidal waters — size & possession",
            subtitle: "Size and bag limits for tidal (saltwater) species",
            onTap: () => _openUrl(_tidalUrl),
          ),
          const SizedBox(height: 12),
          _linkCard(
            context,
            icon: Icons.water_drop_rounded,
            title: "Fresh waters — size & possession",
            subtitle: "Size and bag limits for freshwater species",
            onTap: () => _openUrl(_freshUrl),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha:0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha:0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: _accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Rules change. For the latest limits, closed seasons, and zone maps use the official QLD Government pages or the Qld Fishing app.",
                    style: TextStyle(color: Colors.white.withValues(alpha:0.9), fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<String> bullets) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accent, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha:0.8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(color: Colors.white.withValues(alpha:0.85), fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _linkCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
                color: Colors.black.withValues(alpha:0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accent.withValues(alpha:0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha:0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accent.withValues(alpha:0.45)),
                ),
                child: Icon(icon, color: _accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, color: _accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
