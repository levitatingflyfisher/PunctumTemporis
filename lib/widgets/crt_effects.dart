import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// CRT scanline overlay effect — auto-disabled in modern mode
class CrtOverlay extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final double intensity;

  const CrtOverlay({
    super.key,
    required this.child,
    this.enabled = true,
    this.intensity = 0.03,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled || !AppTheme.isRetro) return child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ScanlinePainter(intensity: intensity),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final double intensity;

  _ScanlinePainter({this.intensity = 0.03});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(intensity)
      ..strokeWidth = 1;

    // Draw horizontal scanlines
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Retro button with hard drop shadow / Modern button with soft shadow
class RetroButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final double shadowOffset;
  final EdgeInsets padding;

  const RetroButton({
    super.key,
    this.onPressed,
    required this.child,
    this.color,
    this.shadowOffset = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  });

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = widget.color ?? theme.colorScheme.primary;

    if (AppTheme.isHearth) {
      return GestureDetector(
        onTapDown: widget.onPressed != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onPressed != null
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: IntrinsicWidth(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: widget.padding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: buttonColor,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(44, 24, 16, _pressed ? 0.08 : 0.18),
                  offset: Offset(0, _pressed ? 1 : 3),
                  blurRadius: _pressed ? 4 : 8,
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      );
    }

    if (AppTheme.isModern) {
      return GestureDetector(
        onTapDown: widget.onPressed != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onPressed != null
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: IntrinsicWidth(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: widget.padding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: buttonColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: buttonColor.withOpacity(0.8), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_pressed ? 0.1 : 0.2),
                  offset: Offset(0, _pressed ? 1 : 3),
                  blurRadius: _pressed ? 4 : 8,
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      );
    }

    final offset = _pressed ? 0.0 : widget.shadowOffset;

    return GestureDetector(
      onTapDown: widget.onPressed != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: IntrinsicWidth(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          transform: Matrix4.translationValues(
            _pressed ? widget.shadowOffset : 0,
            _pressed ? widget.shadowOffset : 0,
            0,
          ),
          child: Container(
            padding: widget.padding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: buttonColor,
              border: Border.all(color: buttonColor.withOpacity(0.8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black87,
                  offset: Offset(offset, offset),
                  blurRadius: 0,
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Retro icon button (circular)
class RetroIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? color;
  final double size;
  final String? tooltip;

  const RetroIconButton({
    super.key,
    this.onPressed,
    required this.icon,
    this.color,
    this.size = 48,
    this.tooltip,
  });

  @override
  State<RetroIconButton> createState() => _RetroIconButtonState();
}

class _RetroIconButtonState extends State<RetroIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = widget.color ?? theme.colorScheme.primary;

    Widget button;

    if (!AppTheme.isRetro) {
      button = GestureDetector(
        onTapDown: widget.onPressed != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onPressed != null
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: buttonColor, width: 1),
            borderRadius: BorderRadius.circular(widget.size / 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.isHearth
                    ? const Color(0x1A2C1810)
                    : Colors.black.withOpacity(0.15),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: buttonColor,
            size: widget.size * 0.5,
          ),
        ),
      );
    } else {
      final offset = _pressed ? 0.0 : 3.0;

      button = GestureDetector(
        onTapDown: widget.onPressed != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.onPressed != null
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          transform: Matrix4.translationValues(
            _pressed ? 3 : 0,
            _pressed ? 3 : 0,
            0,
          ),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: buttonColor, width: 2),
            borderRadius: BorderRadius.circular(widget.size / 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                offset: Offset(offset, offset),
                blurRadius: 0,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: buttonColor,
            size: widget.size * 0.5,
          ),
        ),
      );
    }

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}

/// Progress bar — pixelated in retro, smooth in modern
class RetroProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double height;
  final Color? color;
  final Color? backgroundColor;

  const RetroProgressBar({
    super.key,
    required this.value,
    this.height = 16,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor = color ?? theme.colorScheme.primary;
    final bgColor = backgroundColor ?? theme.colorScheme.surface;

    if (!AppTheme.isRetro) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fillColor.withOpacity(0.3), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(color: fillColor),
          ),
        ),
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: fillColor, width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * value.clamp(0.0, 1.0);
          // Create pixelated effect
          final blockSize = height - 4;
          final numBlocks = (fillWidth / blockSize).floor();

          return Row(
            children: List.generate(numBlocks, (i) {
              return Container(
                width: blockSize - 2,
                height: blockSize,
                margin: const EdgeInsets.only(left: 2),
                color: fillColor,
              );
            }),
          );
        },
      ),
    );
  }
}

/// Glowing border effect
class GlowBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double glowRadius;
  final double borderWidth;

  const GlowBorder({
    super.key,
    required this.child,
    required this.color,
    this.glowRadius = 8,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (!AppTheme.isRetro) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5), width: 1),
          borderRadius: BorderRadius.circular(AppTheme.isHearth ? 12 : 8),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: glowRadius,
              spreadRadius: 0,
            ),
          ],
        ),
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: glowRadius,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Animated blinking cursor/indicator
class BlinkingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const BlinkingIndicator({
    super.key,
    required this.color,
    this.size = 12,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<BlinkingIndicator> createState() => _BlinkingIndicatorState();
}

class _BlinkingIndicatorState extends State<BlinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: !AppTheme.isRetro
                  ? BorderRadius.circular(widget.size / 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated recording indicator (pulsing circle)
class RecordingIndicator extends StatefulWidget {
  final double size;

  const RecordingIndicator({super.key, this.size = 16});

  @override
  State<RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5 + _controller.value * 0.5),
                blurRadius: 4 + _controller.value * 8,
                spreadRadius: _controller.value * 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Card with hard shadow (retro) or soft shadow (modern)
class RetroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double shadowOffset;
  final Color? borderColor;

  const RetroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.shadowOffset = 4,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = borderColor ?? theme.colorScheme.primary;

    if (!AppTheme.isRetro) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppTheme.isHearth
                  ? const Color(0x172C1810)
                  : Colors.black.withOpacity(0.12),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: child,
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: border, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            offset: Offset(shadowOffset, shadowOffset),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Terminal-style text with optional typing animation
class TerminalText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool showCursor;

  const TerminalText(
    this.text, {
    super.key,
    this.style,
    this.showCursor = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: style ??
              TextStyle(
                fontFamily: 'VT323',
                fontSize: 16,
                color: theme.colorScheme.primary,
              ),
        ),
        if (showCursor)
          BlinkingIndicator(
            color: theme.colorScheme.primary,
            size: 10,
          ),
      ],
    );
  }
}
