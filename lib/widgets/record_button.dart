import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The shutter: tap to start, tap again to stop.
///
/// That is a mode, and the audit contested it (humane-interface-01 wants
/// hold-to-record). The floor both sides accepted: the control carries its
/// own state. So the shape changes (circle to rounded square) AND the
/// button says, in a word under it and to a screen reader, what a tap does
/// now: Record, or Stop.
class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.recording,
    required this.onTap,
    this.pulse,
  });

  final bool recording;
  final VoidCallback? onTap;

  /// Drives the gentle pulse while recording (0..1); null for none.
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    Widget shutter(double scale) => Transform.scale(
          scale: scale,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Center(
              child: Container(
                width: recording ? 30 : 60,
                height: recording ? 30 : 60,
                decoration: BoxDecoration(
                  shape: recording ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: recording ? BorderRadius.circular(4) : null,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );

    return Semantics(
      button: true,
      label: recording ? 'Stop recording' : 'Start recording',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pulse != null && recording)
              AnimatedBuilder(
                animation: pulse!,
                builder: (_, __) => shutter(1.0 + pulse!.value * 0.1),
              )
            else
              shutter(1.0),
            const SizedBox(height: 6),
            Text(
              recording ? 'Stop' : 'Record',
              style: AppTheme.monoFont(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
