import 'package:flutter/material.dart';

class StepProgressBar extends StatelessWidget {
  final int currentStep; // Profile, ID, or Face (1-3)

  const StepProgressBar({super.key, required this.currentStep});

  static const _labels = ['Profile', 'ID', 'Face'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (i) {
        final step = i + 1;
        final isDone = step < currentStep;
        final isActive = step == currentStep;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  // Left half-connector (hidden for first step)
                  Expanded(
                    child: step == 1
                        ? const SizedBox()
                        : Container(
                            height: 2,
                            color: (isActive || isDone)
                                ? const Color(0xFF4CAF50)
                                : Colors.white24,
                          ),
                  ),
                  // Circle
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? const Color(0xFF4CAF50)
                          : isActive
                              ? Colors.white
                              : Colors.white24,
                      border: isActive
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : Text(
                              '$step',
                              style: TextStyle(
                                color: isActive
                                    ? const Color(0xFF0B3D2E)
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                  // Right half-connector (hidden for last step)
                  Expanded(
                    child: step == _labels.length
                        ? const SizedBox()
                        : Container(
                            height: 2,
                            color: isDone
                                ? const Color(0xFF4CAF50)
                                : Colors.white24,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _labels[i],
                style: TextStyle(
                  color: isActive || isDone ? Colors.white : Colors.white38,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
