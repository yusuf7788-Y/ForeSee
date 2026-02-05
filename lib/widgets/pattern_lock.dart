import 'package:flutter/material.dart';

class PatternLock extends StatefulWidget {
  final Function(List<int>) onInputComplete;
  final int dimension;

  const PatternLock({
    super.key,
    required this.onInputComplete,
    this.dimension = 3,
  });

  @override
  State<PatternLock> createState() => _PatternLockState();
}

class _PatternLockState extends State<PatternLock> {
  final List<int> _selectedPoints = [];
  Offset? _currentDragPosition;
  final GlobalKey _containerKey = GlobalKey();

  void _handlePanStart(DragStartDetails details) {
    _selectedPoints.clear();
    _handlePanUpdate(
      DragUpdateDetails(
        globalPosition: details.globalPosition,
        delta: Offset.zero,
        primaryDelta: null,
        sourceTimeStamp: details.sourceTimeStamp,
      ),
    );
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    RenderBox? renderBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final size = renderBox.size;
    final cellWidth = size.width / widget.dimension;
    final cellHeight = size.height / widget.dimension;

    // Boundary check
    if (localPosition.dx < 0 ||
        localPosition.dx > size.width ||
        localPosition.dy < 0 ||
        localPosition.dy > size.height) {
      setState(() => _currentDragPosition = localPosition);
      return;
    }

    final col = (localPosition.dx / cellWidth).floor();
    final row = (localPosition.dy / cellHeight).floor();
    final index = row * widget.dimension + col;

    if (index >= 0 && index < widget.dimension * widget.dimension) {
      if (!_selectedPoints.contains(index)) {
        // HapticFeedback.selectionClick(); // Optional
        _selectedPoints.add(index);
      }
    }

    setState(() {
      _currentDragPosition = localPosition;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() => _currentDragPosition = null);
    if (_selectedPoints.isNotEmpty) {
      widget.onInputComplete(List.from(_selectedPoints));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: Container(
        key: _containerKey,
        color: Colors.transparent, // Capture taps
        child: CustomPaint(
          painter: _LockPainter(
            points: _selectedPoints,
            currentDragPosition: _currentDragPosition,
            dimension: widget.dimension,
            color: Theme.of(context).primaryColor,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _LockPainter extends CustomPainter {
  final List<int> points;
  final Offset? currentDragPosition;
  final int dimension;
  final Color color;

  _LockPainter({
    required this.points,
    required this.currentDragPosition,
    required this.dimension,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / dimension;
    final cellHeight = size.height / dimension;
    final dotRadius = 8.0; // Fixed radius for dots

    // Draw all dots
    final dotPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final selectedDotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dimension * dimension; i++) {
      final col = i % dimension;
      final row = i ~/ dimension;
      final center = Offset(
        col * cellWidth + cellWidth / 2,
        row * cellHeight + cellHeight / 2,
      );

      canvas.drawCircle(
        center,
        dotRadius,
        points.contains(i) ? selectedDotPaint : dotPaint,
      );

      // Draw outer circle for selected
      if (points.contains(i)) {
        canvas.drawCircle(
          center,
          dotRadius * 2.5, // Outer glow ring
          Paint()
            ..color = color.withOpacity(0.2)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Draw lines
    if (points.isNotEmpty) {
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();

      Offset getCenter(int index) {
        final col = index % dimension;
        final row = index ~/ dimension;
        return Offset(
          col * cellWidth + cellWidth / 2,
          row * cellHeight + cellHeight / 2,
        );
      }

      path.moveTo(getCenter(points.first).dx, getCenter(points.first).dy);

      for (int i = 1; i < points.length; i++) {
        final center = getCenter(points[i]);
        path.lineTo(center.dx, center.dy);
      }

      if (currentDragPosition != null) {
        path.lineTo(currentDragPosition!.dx, currentDragPosition!.dy);
      }

      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LockPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.currentDragPosition != currentDragPosition;
  }
}
