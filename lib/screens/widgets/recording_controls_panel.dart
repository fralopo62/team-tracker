import 'package:flutter/material.dart';
import '../../main.dart';

class RecordingControlsPanel extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final String selectedSport;
  final Map<String, IconData> sports;
  final ValueChanged<String> onSportSelected;
  final VoidCallback onStart;
  final VoidCallback onPauseResume;
  final VoidCallback onDiscard;
  final VoidCallback onFinish;

  const RecordingControlsPanel({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.selectedSport,
    required this.sports,
    required this.onSportSelected,
    required this.onStart,
    required this.onPauseResume,
    required this.onDiscard,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24).withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isRecording) ...[
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: sports.entries.map((entry) {
                  final sportKey = entry.key;
                  final sportIcon = entry.value;
                  final isSelected = selectedSport == sportKey;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(sportIcon,
                              size: 16,
                              color: isSelected ? Colors.white : Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            strings.sportLabel(sportKey),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      selectedColor: const Color(0xFFFC5200),
                      backgroundColor: const Color(0xFF252A34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFFFC5200)
                              : Colors.white10,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) onSportSelected(sportKey);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          !isRecording
              ? ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        strings.startRoute,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: onDiscard,
                      iconSize: 32,
                      icon: const Icon(Icons.delete_forever, color: Colors.grey),
                      tooltip: strings.discardRoute,
                    ),
                    ElevatedButton.icon(
                      onPressed: onPauseResume,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isPaused ? Colors.green : const Color(0xFFFC5200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: Icon(
                        isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                      ),
                      label: Text(
                        isPaused ? strings.resume : strings.pause,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: onFinish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        strings.finish,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}