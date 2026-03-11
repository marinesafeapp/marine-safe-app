import 'package:flutter/material.dart';
import 'package:marine_safe_app_fixed/models/ramp.dart';
import 'package:marine_safe_app_fixed/data/ramp_data.dart';
import '../home_widgets.dart';

class RampCard extends StatelessWidget {
  final Color accent;
  final bool tripActive;

  final Ramp? selectedRamp;

  /// Favourite ramps (optional; shown as quick-select chips)
  final List<Ramp> favouriteRamps;

  final Future<bool> Function() confirmChangeRamp;
  final Future<void> Function(Ramp ramp) onRampSelected;

  /// Toggle favourite on the currently selected ramp (optional)
  final VoidCallback? onToggleFavouriteSelected;

  final bool isSelectedFavourite;

  /// When set, shows a "Use my location" button that finds nearest ramp by GPS.
  final Future<void> Function()? onNearMe;

  /// Ramps to show in the dropdown (e.g. local ramps by postcode). If null, uses all [australianRamps].
  final List<Ramp>? ramps;

  /// When set, shown above the dropdown (e.g. "Near your postcode (within 80 km)").
  final String? rampListSubtitle;

  const RampCard({
    super.key,
    required this.accent,
    required this.tripActive,
    required this.selectedRamp,
    this.favouriteRamps = const <Ramp>[],
    required this.confirmChangeRamp,
    required this.onRampSelected,
    this.onToggleFavouriteSelected,
    this.isSelectedFavourite = false,
    this.onNearMe,
    this.ramps,
    this.rampListSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final list = ramps ?? australianRamps;
    // ✅ Ensure selected ramp is in the list so dropdown doesn't throw.
    final listWithSelected = selectedRamp != null && !list.any((x) => x.id == selectedRamp!.id)
        ? <Ramp>[selectedRamp!, ...list]
        : list;
    final Ramp? safeValue =
    (selectedRamp != null && listWithSelected.any((x) => x.id == selectedRamp!.id))
        ? listWithSelected.firstWhere((x) => x.id == selectedRamp!.id)
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: sectionTitle(accent, Icons.anchor, "Ramp")),
              if (onNearMe != null)
                TextButton.icon(
                  onPressed: () async {
                    await onNearMe!();
                  },
                  icon: Icon(Icons.my_location, size: 16, color: accent),
                  label: const Text("Use my location"),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (rampListSubtitle != null && rampListSubtitle!.isNotEmpty) ...[
            Text(
              rampListSubtitle!,
              style: TextStyle(
                color: accent.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (favouriteRamps.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.star, color: accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  "Favourites",
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                if (selectedRamp != null && onToggleFavouriteSelected != null)
                  IconButton(
                    tooltip: isSelectedFavourite ? "Unfavourite" : "Favourite",
                    onPressed: onToggleFavouriteSelected,
                    icon: Icon(
                      isSelectedFavourite ? Icons.star : Icons.star_border,
                      color: isSelectedFavourite ? Colors.amber : Colors.white70,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: favouriteRamps.map((r) {
                final selected = selectedRamp?.id == r.id;
                return ActionChip(
                  label: Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  avatar: Icon(
                    Icons.anchor,
                    size: 16,
                    color: selected ? Colors.black : Colors.white70,
                  ),
                  onPressed: () async {
                    if (tripActive) {
                      final ok = await confirmChangeRamp();
                      if (!ok) return;
                    }
                    await onRampSelected(r);
                  },
                  backgroundColor: selected
                      ? accent.withValues(alpha:0.9)
                      : Colors.white.withValues(alpha:0.08),
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ] else ...[
            if (selectedRamp != null && onToggleFavouriteSelected != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: isSelectedFavourite ? "Unfavourite" : "Favourite",
                  onPressed: onToggleFavouriteSelected,
                  icon: Icon(
                    isSelectedFavourite ? Icons.star : Icons.star_border,
                    color: isSelectedFavourite ? Colors.amber : Colors.white70,
                  ),
                ),
              ),
          ],

          DropdownButtonFormField<Ramp>(
            initialValue: safeValue,
            isExpanded: true,
            dropdownColor: const Color(0xFF0A0F18),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha:0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: "Select launch ramp",
              hintStyle: const TextStyle(color: Colors.white54),
            ),
            items: listWithSelected
                .map(
                  (r) => DropdownMenuItem<Ramp>(
                value: r,
                child: Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            )
                .toList(),
            selectedItemBuilder: (context) {
              return listWithSelected.map((r) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                );
              }).toList();
            },
            onChanged: (r) async {
              if (r == null) return;

              if (tripActive) {
                final ok = await confirmChangeRamp();
                if (!ok) return;
              }

              await onRampSelected(r);
            },
          ),

          const SizedBox(height: 10),
          Text(
            tripActive
                ? "Ramp can be changed with confirmation."
                : "Choose the ramp you launched from.",
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
