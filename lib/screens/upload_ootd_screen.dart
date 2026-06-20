import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';
import 'search_clothes_screen.dart';
import 'package:image/image.dart' as img;
import 'ootd_screen.dart';

class UploadOotdScreen extends StatefulWidget {
  final String? initialImageUrl;
  final Set<String>? initialTaggedClothes;

  const UploadOotdScreen({
    super.key,
    this.initialImageUrl,
    this.initialTaggedClothes,
  });

  @override
  State<UploadOotdScreen> createState() => _UploadOotdScreenState();
}

class _UploadOotdScreenState extends State<UploadOotdScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _descController = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageExtension;
  bool _isUploading = false;
  DateTime _selectedDate = DateTime.now();

  // 태그된 옷들의 문서 ID 목록
  final Set<String> _selectedClothesIds = {};
  
  // 전체 옷 목록을 메모리에 들고 있기 위한 변수
  List<QueryDocumentSnapshot> _allClothes = [];
  bool _isLoadingClothes = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialTaggedClothes != null) {
      _selectedClothesIds.addAll(widget.initialTaggedClothes!);
    }
    _fetchClothes();
  }

  Future<void> _fetchClothes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clothes')
          .where('userId', isEqualTo: _firebaseService.currentUserId)
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _allClothes = snapshot.docs;
        _isLoadingClothes = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingClothes = false;
      });
      debugPrint('옷 목록 불러오기 실패: $e');
    }
  }

  // JPEG 파일의 EXIF 바이너리를 직접 디코딩 없이 직접 스캔하여 실제 촬영 시각 추출
  DateTime? _parseExifDateTimeFromJpeg(Uint8List bytes) {
    try {
      if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
        return null;
      }
      
      int offset = 2;
      while (offset < bytes.length - 4) {
        if (bytes[offset] == 0xFF) {
          final marker = bytes[offset + 1];
          final length = (bytes[offset + 2] << 8) + bytes[offset + 3];
          
          if (marker == 0xE1) { // APP1 EXIF 영역
            final app1Offset = offset + 4;
            if (app1Offset + 6 < bytes.length &&
                bytes[app1Offset] == 0x45 &&
                bytes[app1Offset + 1] == 0x78 &&
                bytes[app1Offset + 2] == 0x69 &&
                bytes[app1Offset + 3] == 0x66 &&
                bytes[app1Offset + 4] == 0x00) {
              
              final tiffOffset = app1Offset + 6;
              final isLittleEndian = bytes[tiffOffset] == 0x49 && bytes[tiffOffset + 1] == 0x49;
              
              int readUint16(int o) {
                return isLittleEndian
                    ? bytes[o] + (bytes[o + 1] << 8)
                    : (bytes[o] << 8) + bytes[o + 1];
              }
              
              int readUint32(int o) {
                return isLittleEndian
                    ? bytes[o] + (bytes[o + 1] << 8) + (bytes[o + 2] << 16) + (bytes[o + 3] << 24)
                    : (bytes[o] << 24) + (bytes[o + 1] << 16) + (bytes[o + 2] << 8) + bytes[o + 3];
              }
              
              if (readUint16(tiffOffset + 2) != 0x002A) {
                return null;
              }
              
              final int ifd0Offset = readUint32(tiffOffset + 4);
              final int dirStart = tiffOffset + ifd0Offset;
              
              if (dirStart >= bytes.length) return null;
              
              final numEntries = readUint16(dirStart);
              int exifSubIfdOffset = 0;
              
              for (int i = 0; i < numEntries; i++) {
                final entryOffset = dirStart + 2 + (i * 12);
                if (entryOffset + 12 > bytes.length) break;
                
                final tag = readUint16(entryOffset);
                if (tag == 0x8769) {
                  exifSubIfdOffset = readUint32(entryOffset + 8);
                  break;
                }
              }
              
              if (exifSubIfdOffset > 0) {
                final subDirStart = tiffOffset + exifSubIfdOffset;
                if (subDirStart < bytes.length) {
                  final numSubEntries = readUint16(subDirStart);
                  for (int i = 0; i < numSubEntries; i++) {
                    final entryOffset = subDirStart + 2 + (i * 12);
                    if (entryOffset + 12 > bytes.length) break;
                    
                    final tag = readUint16(entryOffset);
                    if (tag == 0x9003) { // DateTimeOriginal
                      final valOffset = readUint32(entryOffset + 8);
                      final int dataStart = tiffOffset + valOffset;
                      
                      if (dataStart + 19 < bytes.length) {
                        final dateStr = String.fromCharCodes(bytes.sublist(dataStart, dataStart + 19));
                        final parts = dateStr.trim().split(' ');
                        if (parts.length == 2) {
                          final dateParts = parts[0].split(':');
                          final timeParts = parts[1].split(':');
                          if (dateParts.length == 3 && timeParts.length == 3) {
                            return DateTime(
                              int.parse(dateParts[0]),
                              int.parse(dateParts[1]),
                              int.parse(dateParts[2]),
                              int.parse(timeParts[0]),
                              int.parse(timeParts[1]),
                              int.parse(timeParts[2]),
                            );
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
          offset += 2 + length;
        } else {
          offset++;
        }
      }
    } catch (e) {
      debugPrint("🚩 Pure EXIF Parser error: $e");
    }
    return null;
  }

  // IfdDirectory 및 하위 서브 디렉토리를 재귀적으로 검색하여 EXIF 태그 탐색
  img.IfdValue? _findTagRecursively(img.IfdDirectory dir, int tag) {
    if (dir.containsKey(tag)) {
      return dir[tag];
    }
    for (final subDir in dir.sub.values) {
      final val = _findTagRecursively(subDir, tag);
      if (val != null) return val;
    }
    return null;
  }

  // 이미지 바이트의 EXIF 메타데이터에서 실제 촬영 일자 추출 (서브 디렉토리 재귀 탐색 포함)
  DateTime? _getExifDateTime(Uint8List bytes) {
    // 1. 순수 바이너리 직접 스캔 (가장 가볍고 컴파일 에러 걱정 없음)
    DateTime? parsedDate = _parseExifDateTimeFromJpeg(bytes);
    if (parsedDate != null) return parsedDate;

    // 2. 실패 시 이미지 라이브러리를 통한 exif 탐색 시도
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null && decoded.exif != null) {
        img.IfdValue? val;
        
        // 최상위 및 서브 디렉토리(exif 등) 재귀 탐색으로 DateTimeOriginal(0x9003) 조회
        for (final dir in decoded.exif.directories.values) {
          val = _findTagRecursively(dir, 0x9003);
          if (val != null) break;
        }
        
        // 실패 시 DateTime(0x0132) 조회
        if (val == null) {
          for (final dir in decoded.exif.directories.values) {
            val = _findTagRecursively(dir, 0x0132);
            if (val != null) break;
          }
        }
        
        if (val != null) {
          final String exifDateStr = val.toString().trim();
          if (exifDateStr.isNotEmpty) {
            // EXIF 표준 시간 포맷: "YYYY:MM:DD HH:MM:SS"
            final parts = exifDateStr.split(' ');
            if (parts.length == 2) {
              final dateParts = parts[0].split(':');
              final timeParts = parts[1].split(':');
              if (dateParts.length == 3 && timeParts.length == 3) {
                return DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                  int.parse(timeParts[0]),
                  int.parse(timeParts[1]),
                  int.parse(timeParts[2]),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("🚩 Failed to parse EXIF date via library: $e");
    }
    return null;
  }

  // 파일명 기반 날짜 유추 정규식 스캐너 (예: KakaoTalk_20260618_xxx, 2026-06-18_xxx 등)
  DateTime? _parseDateTimeFromFileName(String fileName) {
    try {
      // 2000년~2099년 사이 연도, 월, 일 매칭 정규식
      final regExp = RegExp(r'(20\d{2})[-_]?(0[1-9]|1[0-2])[-_]?(0[1-9]|[12]\d|3[01])');
      final match = regExp.firstMatch(fileName);
      
      if (match != null) {
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        
        final date = DateTime(year, month, day);
        // 달력 범위의 실제 존재하는 날짜 검증
        if (date.year == year && date.month == month && date.day == day) {
          return date;
        }
      }
    } catch (e) {
      debugPrint("🚩 Failed to parse date from filename: $e");
    }
    return null;
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    // 원본 파일명 및 EXIF 메타데이터 유실을 방지하기 위해 리사이징 옵션들을 해제합니다.
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      
      // 1. 파일명 기반 날짜 유추 시도
      DateTime? imgDate = _parseDateTimeFromFileName(image.name);
      
      // 2. 실패 시 EXIF 촬영일 파싱 시도
      if (imgDate == null) {
        imgDate = _getExifDateTime(bytes);
      }
      
      // 3. EXIF 실패 시 파일 수정일 획득 시도
      if (imgDate == null) {
        try {
          imgDate = await image.lastModified();
        } catch (_) {}
      }

      setState(() {
        _imageBytes = bytes;
        _imageExtension = ext;
        if (imgDate != null) {
          _selectedDate = imgDate;
        }
      });
    }
  }

  Future<void> _uploadOOTD() async {
    if (_imageBytes == null && widget.initialImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OOTD 사진을 선택해주세요.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // 1. 이미지 업로드
      String imageUrl;
      if (_imageBytes != null) {
        imageUrl = await _firebaseService.uploadImage(
          _imageBytes!,
          _imageExtension ?? 'jpg',
        );
      } else {
        imageUrl = widget.initialImageUrl!;
      }

      // 2. 태그된 옷 데이터 구성
      List<Map<String, dynamic>> taggedClothes = [];
      for (var doc in _allClothes) {
        if (_selectedClothesIds.contains(doc.id)) {
          final data = doc.data() as Map<String, dynamic>;
          String title = '${data['color'] ?? ''} ${data['pattern'] ?? ''}'.trim();
          if (title.isEmpty) title = data['brand'] ?? '';
          if (title.isEmpty) title = data['category'] ?? '옷 정보 없음';

          taggedClothes.add({
            'id': doc.id,
            'imageUrl': data['imageUrl'],
            'title': title,
          });
        }
      }

      // 3. Firestore 저장
      await _firebaseService.saveOOTDData(
        imageUrl: imageUrl,
        description: _descController.text.trim(),
        taggedClothes: taggedClothes,
        date: _selectedDate,
      );

      // 글로벌 새로고침 알림 트리거
      OotdScreen.refreshNotifier.value = !OotdScreen.refreshNotifier.value;

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OOTD가 성공적으로 업로드되었습니다!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('새로운 OOTD', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _uploadOOTD,
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('공유', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 이미지 선택 영역
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 350,
                color: Colors.grey[100],
                child: _imageBytes != null
                    ? Image.memory(_imageBytes!, fit: BoxFit.contain)
                    : widget.initialImageUrl != null
                        ? Image.network(widget.initialImageUrl!, fit: BoxFit.contain)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('OOTD 사진 선택', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),

            // 2. 날짜 선택 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: Colors.black87),
                  const SizedBox(width: 8),
                  const Text('날짜', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Colors.black,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // 3. 코멘트 입력
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '오늘의 코디에 대해 이야기해주세요...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // 3. 옷 태깅 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.sell_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Text('이 코디에 쓰인 옷 태그하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${_selectedClothesIds.length}개 선택됨', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchClothesScreen(
                        isSelectionMode: true,
                        initialSelectedIds: _selectedClothesIds,
                      ),
                    ),
                  );
                  
                  if (result != null && result is List<Map<String, dynamic>>) {
                    setState(() {
                      _selectedClothesIds.clear();
                      _selectedClothesIds.addAll(result.map((e) => e['id'] as String));
                    });
                  }
                },
                icon: const Icon(Icons.add, color: Colors.black),
                label: const Text('내 옷장에서 옷 선택하기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: const BorderSide(color: Colors.black26),
                ),
              ),
            ),

            // 선택된 옷 목록 가로 스크롤
            if (_isLoadingClothes)
              const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Colors.black)))
            else if (_allClothes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('옷장에 등록된 옷이 없습니다.', style: TextStyle(color: Colors.grey[500])),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _allClothes.where((doc) => _selectedClothesIds.contains(doc.id)).length,
                  itemBuilder: (context, index) {
                    final selectedDocs = _allClothes.where((doc) => _selectedClothesIds.contains(doc.id)).toList();
                    final doc = selectedDocs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    final isSelected = _selectedClothesIds.contains(doc.id);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedClothesIds.remove(doc.id);
                          } else {
                            _selectedClothesIds.add(doc.id);
                          }
                        });
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? Colors.black : Colors.transparent,
                                      width: 3,
                                    ),
                                    image: DecorationImage(
                                      image: NetworkImage(item['imageUrl'] ?? ''),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['category'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
