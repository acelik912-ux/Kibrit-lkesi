import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kibrit kutusunu parmakla sağa sola sallatır.
/// Her yön değişimi bir sallama sayılır; parmak kalkınca kutu atılır.
class ShakeBox extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback onShake;
  final VoidCallback onRelease;

  const ShakeBox({
    super.key,
    required this.child,
    required this.enabled,
    required this.onShake,
    required this.onRelease,
  });

  @override
  State<ShakeBox> createState() => _ShakeBoxState();
}

class _ShakeBoxState extends State<ShakeBox> {
  static const _minSwing = 10.0; // bir sallama için gereken en az yol
  static const _maxOffset = 26.0;

  double _offset = 0;
  int _dir = 0;
  double _travel = 0;
  int _count = 0;

  void _start(DragStartDetails _) {
    _dir = 0;
    _travel = 0;
    _count = 0;
  }

  void _update(DragUpdateDetails d) {
    if (!widget.enabled) return;
    final dx = d.delta.dx;
    setState(() => _offset = (_offset + dx).clamp(-_maxOffset, _maxOffset));
    final dir = dx > 0 ? 1 : (dx < 0 ? -1 : 0);
    if (dir == 0) return;
    if (dir == _dir) {
      _travel += dx.abs();
      return;
    }
    if (_dir != 0 && _travel >= _minSwing) {
      _count++;
      HapticFeedback.selectionClick();
      widget.onShake();
    }
    _dir = dir;
    _travel = dx.abs();
  }

  void _end(DragEndDetails _) {
    // Son savuruş da sayılsın.
    if (widget.enabled && _dir != 0 && _travel >= _minSwing) {
      _count++;
      widget.onShake();
    }
    setState(() => _offset = 0);
    if (widget.enabled && _count > 0) {
      HapticFeedback.mediumImpact();
      widget.onRelease();
    }
    _count = 0;
    _dir = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _start,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      child: AnimatedContainer(
        duration: Duration(milliseconds: _offset == 0 ? 180 : 0),
        transform: Matrix4.translationValues(_offset, 0, 0)
          ..rotateZ(_offset * 0.012),
        transformAlignment: Alignment.bottomCenter,
        child: widget.child,
      ),
    );
  }
}
