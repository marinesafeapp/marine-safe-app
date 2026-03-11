import 'package:flutter/material.dart';

class StartTripButton extends StatefulWidget {
  final Function(bool) onToggle; // Returns true when trip starts

  const StartTripButton({super.key, required this.onToggle});

  @override
  State<StartTripButton> createState() => _StartTripButtonState();
}

class _StartTripButtonState extends State<StartTripButton>
    with SingleTickerProviderStateMixin {
  bool isActive = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void toggle() {
    setState(() {
      isActive = !isActive;
    });

    widget.onToggle(isActive); // Notify parent
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.green : Colors.blueGrey,
              boxShadow: [
                BoxShadow(
                  color: isActive
                      ? Colors.greenAccent.withValues(alpha:0.7)
                      : Colors.blueAccent.withValues(alpha:0.4),
                  blurRadius: isActive ? 30 : 18,
                  spreadRadius: isActive ? 10 : 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.navigation,
              size: 55,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
