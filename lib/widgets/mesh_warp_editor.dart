import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 의류 실루엣 펴기 (Mesh Warp) 편집기 위젯
class MeshWarpEditor extends StatefulWidget {
  final Uint8List imageBytes;

  const MeshWarpEditor({
    super.key,
    required this.imageBytes,
  });

  @override
  State<MeshWarpEditor> createState() => _MeshWarpEditorState();
}

class _MeshWarpEditorState extends State<MeshWarpEditor> {
  ui.Image? _uiImage;
  bool _isLoading = true;

  // 3x3 사각형 격자 (꼭짓점은 가로 4개, 세로 4개로 총 16개 제어점)
  final int _gridSize = 3;
  late List<Offset> _controlPoints; // 현재 실시간 왜곡된 제어점들 (화면 좌표계)
  late List<Offset> _originalPoints; // 초기 제어점들 (화면 좌표계, UV 매핑 기준)
  late List<int> _indices; // 삼각형 그리기 인덱스 테이블

  double _viewWidth = 0.0;
  double _viewHeight = 0.0;
  int _activePointIndex = -1; // 드래그 중인 점의 인덱스

  @override
  void initState() {
    super.initState();
    _loadImage();
    _initIndices();
  }

  // 3x3 사각형 그리드를 삼각형들로 나누기 위한 인덱싱
  void _initIndices() {
    _indices = [];
    final int pointsPerSide = _gridSize + 1; // 4
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        // 사각형 셀의 꼭짓점 4개의 인덱스 계산
        int tl = r * pointsPerSide + c;
        int tr = r * pointsPerSide + (c + 1);
        int bl = (r + 1) * pointsPerSide + c;
        int br = (r + 1) * pointsPerSide + (c + 1);

        // 삼각형 1: 좌상 - 우상 - 좌하
        _indices.addAll([tl, tr, bl]);
        // 삼각형 2: 우상 - 우하 - 좌하
        _indices.addAll([tr, br, bl]);
      }
    }
  }

  // Dart uiImage 디코딩 수행
  Future<void> _loadImage() async {
    try {
      final Completer<ui.Image> completer = Completer();
      ui.decodeImageFromList(widget.imageBytes, (ui.Image img) {
        completer.complete(img);
      });
      final ui.Image img = await completer.future;
      if (mounted) {
        setState(() {
          _uiImage = img;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("MeshWarp image decode error: $e");
    }
  }

  // 뷰 크기에 맞춰 16개의 제어점 균등 분포 배치 초기화
  void _initControlPoints(double width, double height) {
    _viewWidth = width;
    _viewHeight = height;

    _controlPoints = [];
    _originalPoints = [];

    final int pointsPerSide = _gridSize + 1; // 4
    for (int j = 0; j < pointsPerSide; j++) {
      double y = (j / _gridSize) * height;
      for (int i = 0; i < pointsPerSide; i++) {
        double x = (i / _gridSize) * width;
        _controlPoints.add(Offset(x, y));
        _originalPoints.add(Offset(x, y));
      }
    }
  }

  // 격자 원복 (초기화)
  void _resetPoints() {
    setState(() {
      _controlPoints = List.from(_originalPoints);
    });
  }

  // 터치 시작 시 가장 근접한 핀 탐색
  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPos = renderBox.globalToLocal(details.globalPosition);

    double minDist = 32.0; // 드래그 감지 반경 32px
    int targetIdx = -1;

    for (int i = 0; i < _controlPoints.length; i++) {
      double dist = (localPos - _controlPoints[i]).distance;
      if (dist < minDist) {
        minDist = dist;
        targetIdx = i;
      }
    }

    setState(() {
      _activePointIndex = targetIdx;
    });
  }

  // 터치 이동 시 드래그 중인 핀 좌표 이동
  void _onPanUpdate(DragUpdateDetails details) {
    if (_activePointIndex == -1) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPos = renderBox.globalToLocal(details.globalPosition);

    setState(() {
      _controlPoints[_activePointIndex] = Offset(
        localPos.dx.clamp(0.0, _viewWidth),
        localPos.dy.clamp(0.0, _viewHeight),
      );
    });
  }

  // 터치 끝
  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _activePointIndex = -1;
    });
  }

  // 원본 이미지 크기 해상도 그대로 왜곡 렌더링 후 저장용 Uint8List PNG 추출
  Future<void> _applyAndSave() async {
    if (_uiImage == null) return;

    setState(() => _isLoading = true);

    try {
      final int origW = _uiImage!.width;
      final int origH = _uiImage!.height;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, origW.toDouble(), origH.toDouble()));

      final paint = Paint()
        ..shader = ImageShader(
          _uiImage!,
          ui.TileMode.clamp,
          ui.TileMode.clamp,
          Float64List.fromList(Matrix4.identity().storage),
        );

      final double scaleX = origW / _viewWidth;
      final double scaleY = origH / _viewHeight;

      final List<ui.Offset> positions = _controlPoints.map((o) {
        return ui.Offset(o.dx * scaleX, o.dy * scaleY);
      }).toList();

      final List<ui.Offset> textureCoords = _originalPoints.map((o) {
        return ui.Offset(o.dx * scaleX, o.dy * scaleY);
      }).toList();

      final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: textureCoords,
        indices: _indices,
      );

      canvas.drawVertices(vertices, BlendMode.srcOver, paint);

      final picture = recorder.endRecording();
      final warpedImage = await picture.toImage(origW, origH);
      final byteData = await warpedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List resultBytes = byteData.buffer.asUint8List();
        if (mounted) {
          Navigator.pop(context, resultBytes);
        }
      } else {
        throw Exception('이미지 데이터 변환 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('보정 결과 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // 다크 테마 배경
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '의류 실루엣 펴기',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _applyAndSave,
            child: const Text(
              '적용',
              style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading || _uiImage == null
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 가용한 최대 영역 내에서 이미지 비율을 맞춘 핏 사이즈 계산
                          final double maxW = constraints.maxWidth;
                          final double maxH = constraints.maxHeight;

                          final double imgW = _uiImage!.width.toDouble();
                          final double imgH = _uiImage!.height.toDouble();

                          final double srcAR = imgW / imgH;
                          final double destAR = maxW / maxH;

                          double fitW, fitH;
                          if (srcAR > destAR) {
                            fitW = maxW;
                            fitH = maxW / srcAR;
                          } else {
                            fitH = maxH;
                            fitW = maxH * srcAR;
                          }

                          // 레이아웃이 처음 결정되거나 크기가 바뀐 경우 제어점 리스트 초기화
                          if (_viewWidth != fitW || _viewHeight != fitH) {
                            _initControlPoints(fitW, fitH);
                          }

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 1. Mesh Warp를 그리는 캔버스 영역
                              GestureDetector(
                                onPanStart: (d) => _onPanStart(d, constraints),
                                onPanUpdate: _onPanUpdate,
                                onPanEnd: _onPanEnd,
                                child: CustomPaint(
                                  size: Size(fitW, fitH),
                                  painter: MeshWarpPainter(
                                    image: _uiImage!,
                                    controlPoints: _controlPoints,
                                    originalPoints: _originalPoints,
                                    indices: _indices,
                                  ),
                                ),
                              ),

                              // 2. 16개의 격자 핀(핸들) 오버레이
                              ...List.generate(_controlPoints.length, (index) {
                                final point = _controlPoints[index];
                                final isDragging = _activePointIndex == index;

                                return Positioned(
                                  left: point.dx - 12,
                                  top: point.dy - 12,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isDragging
                                            ? Colors.cyanAccent.withOpacity(0.9)
                                            : Colors.white.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDragging ? Colors.white : Colors.black87,
                                          width: 2.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          )
                                        ],
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: isDragging ? Colors.black : Colors.black45,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // 하단 보정 조작 가이드 & 초기화 버튼
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '옷 외곽의 꼭짓점 핀을 손가락으로 드래그하여 비뚤어지거나 찌그러진 부위를 반듯하게 밀고 당겨서 펴보세요.',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: _resetPoints,
                              icon: const Icon(Icons.refresh, color: Colors.grey),
                              label: const Text('초기화', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            Text(
                              '총 16개 핀 작동 중',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
    );
  }
}

/// Mesh Warp 실시간 렌더러
class MeshWarpPainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> controlPoints;
  final List<Offset> originalPoints;
  final List<int> indices;

  MeshWarpPainter({
    required this.image,
    required this.controlPoints,
    required this.originalPoints,
    required this.indices,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 화면 크기와 원본 이미지 크기 간의 배율 계산
    final double scaleX = image.width / size.width;
    final double scaleY = image.height / size.height;

    // UV 좌표를 셰이더 내부 픽셀에 매핑해주기 위해 스케일 셰이더 매트릭스 변환 적용
    final Matrix4 matrix = Matrix4.identity();
    matrix.scale(scaleX, scaleY);

    final paint = Paint()
      ..shader = ImageShader(
        image,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        matrix.storage,
      );

    // 캔버스 drawVertices용 Float32List 좌표 구축
    final List<ui.Offset> positions = controlPoints.map((o) => ui.Offset(o.dx, o.dy)).toList();
    final List<ui.Offset> textureCoords = originalPoints.map((o) => ui.Offset(o.dx, o.dy)).toList();

    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: textureCoords,
      indices: indices,
    );

    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
  }

  @override
  bool shouldRepaint(covariant MeshWarpPainter oldDelegate) {
    return oldDelegate.controlPoints != controlPoints || oldDelegate.image != image;
  }
}
