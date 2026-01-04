import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class BorderEditorPage extends StatefulWidget {
  final File imageFile;
  final List<List<double>> initialContours;
  final double mmPerPixel;

  const BorderEditorPage({
    super.key,
    required this.imageFile,
    required this.initialContours,
    this.mmPerPixel = 0.0,
  });

  @override
  State<BorderEditorPage> createState() => _BorderEditorPageState();
}

class _BorderEditorPageState extends State<BorderEditorPage> {
  // Image info
  ui.Image? _image;
  bool _isImageLoaded = false;

  // Editor state
  late List<Offset> _points;
  // Index of the point currently being dragged
  int? _draggedPointIndex;

  // Metrics
  double _areaPx = 0;
  double _diameterPx = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
    // Convert List<List<double>> to List<Offset>
    // Note: API returns [x, y], so we map directly to Offset(x, y)
    _points = widget.initialContours.map((e) => Offset(e[0], e[1])).toList();
    _recalculateMetrics();
  }

  Future<void> _loadImage() async {
    final data = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    setState(() {
      _image = frame.image;
      _isImageLoaded = true;
    });
  }

  void _recalculateMetrics() {
    if (_points.isEmpty) {
      _areaPx = 0;
      _diameterPx = 0;
      return;
    }

    // Shoelace Formula
    double area = 0.0;
    for (int i = 0; i < _points.length; i++) {
      final p1 = _points[i];
      final p2 = _points[(i + 1) % _points.length];
      area += p1.dx * p2.dy;
      area -= p1.dy * p2.dx;
    }
    area = area.abs() / 2.0;

    // Equivalent Diameter
    double diameter = 2 * sqrt(area / pi);

    setState(() {
      _areaPx = area;
      _diameterPx = diameter;
    });
  }

  void _handleDragStart(
    DragStartDetails details,
    Size displaySize,
    Rect imageRect,
  ) {
    if (!_isImageLoaded || _image == null) return;

    // Convert touch to image coordinates
    final localPos = details.localPosition;
    final imagePos = _localToImage(localPos, displaySize, imageRect);

    // Find closest point within a threshold radius (e.g. 20px)
    // Visual touch target should be generous
    double minDist = double.infinity;
    int? closestIndex;

    // Hit test radius in image pixels. Since image might be large,
    // we need to scale the touch radius.
    // Let's use a dynamic radius based on scale
    final scale = imageRect.width / _image!.width;
    final touchRadius = 25.0 / scale; // 25 screen pixels

    for (int i = 0; i < _points.length; i++) {
      final dist = (imagePos - _points[i]).distance;
      if (dist < minDist && dist < touchRadius) {
        minDist = dist;
        closestIndex = i;
      }
    }

    setState(() {
      _draggedPointIndex = closestIndex;
    });
  }

  void _handleDragUpdate(
    DragUpdateDetails details,
    Size displaySize,
    Rect imageRect,
  ) {
    if (_draggedPointIndex == null) return;

    final localPos = details.localPosition;
    final imagePos = _localToImage(localPos, displaySize, imageRect);

    setState(() {
      _points[_draggedPointIndex!] = imagePos;
      _recalculateMetrics();
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _draggedPointIndex = null;
    });
  }

  // Coordinate transforms
  Offset _localToImage(Offset local, Size displaySize, Rect imageRect) {
    // Offset relative to the image Rect
    final dx = (local.dx - imageRect.left) / imageRect.width * _image!.width;
    final dy = (local.dy - imageRect.top) / imageRect.height * _image!.height;
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Éditeur de Segmentation"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // Return the new contours (optional feature to save back)
              // For now, just pop
              Navigator.pop(context);
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body:
          !_isImageLoaded
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (ctx, constraints) {
                  // Determine image rect to fit containment
                  final displaySize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final src = Size(
                    _image!.width.toDouble(),
                    _image!.height.toDouble(),
                  );

                  final fittedSizes = applyBoxFit(
                    BoxFit.contain,
                    src,
                    displaySize,
                  );
                  final destSize = fittedSizes.destination;

                  final dx = (displaySize.width - destSize.width) / 2;
                  final dy = (displaySize.height - destSize.height) / 2;
                  final imageRect = Rect.fromLTWH(
                    dx,
                    dy,
                    destSize.width,
                    destSize.height,
                  );

                  return Stack(
                    children: [
                      // Interactive Area
                      GestureDetector(
                        onPanStart:
                            (d) => _handleDragStart(d, displaySize, imageRect),
                        onPanUpdate:
                            (d) => _handleDragUpdate(d, displaySize, imageRect),
                        onPanEnd: _handleDragEnd,
                        child: CustomPaint(
                          size: displaySize,
                          painter: _EditorPainter(
                            image: _image!,
                            points: _points,
                            imageRect: imageRect,
                          ),
                        ),
                      ),

                      // Floating Metrics Card
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Card(
                          color: Colors.black87,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildMetricRow(
                                  "Aire (px)",
                                  _areaPx.toStringAsFixed(0),
                                ),
                                const SizedBox(height: 8),
                                _buildMetricRow(
                                  "Diamètre (px)",
                                  _diameterPx.toStringAsFixed(1),
                                ),
                                if (widget.mmPerPixel > 0) ...[
                                  const Divider(color: Colors.white24),
                                  _buildMetricRow(
                                    "Diamètre (mm)",
                                    (_diameterPx * widget.mmPerPixel)
                                        .toStringAsFixed(2),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _EditorPainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> points;
  final Rect imageRect;

  _EditorPainter({
    required this.image,
    required this.points,
    required this.imageRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Image
    paintImage(
      canvas: canvas,
      rect: imageRect,
      image: image,
      fit: BoxFit.contain,
    );

    // 2. Draw Polygon
    if (points.isNotEmpty) {
      final scaleX = imageRect.width / image.width;
      final scaleY = imageRect.height / image.height;

      // Map image tokens to screen tokens
      final screenPoints =
          points.map((p) {
            return Offset(
              imageRect.left + p.dx * scaleX,
              imageRect.top + p.dy * scaleY,
            );
          }).toList();

      final paintPath =
          Paint()
            ..color = Colors.blueAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;

      final path = Path()..addPolygon(screenPoints, true);
      canvas.drawPath(path, paintPath);

      // 3. Draw Points
      final paintDot =
          Paint()
            ..color = Colors.yellowAccent
            ..style = PaintingStyle.fill;

      for (var p in screenPoints) {
        canvas.drawCircle(p, 4.0, paintDot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
