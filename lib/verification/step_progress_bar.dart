import 'package:flutter/material.dart';

class StepProgressBar extends StatelessWidget {
  final int currentStep; // 1, 2, or 3

  const StepProgressBar({super.key, required this.currentStep});

  static const _labels = ['Profile', 'Education', 'ID'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final step = i + 1;
        final isDone = step < currentStep;
        final isActive = step == currentStep;

        return Expanded(
          child: Row(
            children: [
              // Circle
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
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
                              color: Colors.white, size: 18)
                          : Text(
                              '$step',
                              style: TextStyle(
                                color: isActive
                                    ? const Color(0xFF1A6B1A)
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      color: isActive || isDone ? Colors.white : Colors.white38,
                      fontSize: 10,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              // Connector line (not after last step)
              if (step < 3)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: isDone ? const Color(0xFF4CAF50) : Colors.white24,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
