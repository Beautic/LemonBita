import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

class OotdCalendarScreen extends StatefulWidget {
  const OotdCalendarScreen({super.key});

  @override
  State<OotdCalendarScreen> createState() => _OotdCalendarScreenState();
}

class _OotdCalendarScreenState extends State<OotdCalendarScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  // 날짜별 OOTD 데이터 맵
  Map<DateTime, List<QueryDocumentSnapshot>> _ootdEvents = {};
  
  // 현재 선택된 날짜의 OOTD 리스트
  List<QueryDocumentSnapshot> _selectedEvents = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    
    _loadEventsForMonth(_focusedDay);
  }

  Future<void> _loadEventsForMonth(DateTime month) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final docs = await _firebaseService.getOOTDsByMonth(month.year, month.month);
      
      if (mounted) {
        setState(() {
          _groupEvents(docs);
          _selectedEvents = _getEventsForDay(_selectedDay);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('OOTD 달력 데이터 로드 에러: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // DateTime의 시분초를 제외하고 년, 월, 일만 반환
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  // 스트림에서 받은 문서들을 날짜별로 그룹화
  void _groupEvents(List<QueryDocumentSnapshot> docs) {
    _ootdEvents = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['createdAt'] != null) {
        final dt = (data['createdAt'] as Timestamp).toDate();
        final normalizedDt = _normalizeDate(dt);
        
        if (_ootdEvents[normalizedDt] == null) {
          _ootdEvents[normalizedDt] = [];
        }
        _ootdEvents[normalizedDt]!.add(doc);
      }
    }
  }

  List<QueryDocumentSnapshot> _getEventsForDay(DateTime day) {
    return _ootdEvents[_normalizeDate(day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('OOTD 달력', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading && _ootdEvents.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TableCalendar<QueryDocumentSnapshot>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: _onDaySelected,
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                      _loadEventsForMonth(focusedDay);
                    },
                    eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(color: Colors.black),
                    markersMaxCount: 1,
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox();

                      // 첫 번째 OOTD 이미지를 썸네일로 표시
                      final item = events.first.data() as Map<String, dynamic>;
                      final imageUrl = item['imageUrl'] as String?;

                      if (imageUrl == null || imageUrl.isEmpty) {
                        return Positioned(
                          bottom: 1,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.redAccent,
                            ),
                          ),
                        );
                      }

                      // 썸네일 이미지를 뱃지처럼 추가
                      return Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            image: DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2, offset: const Offset(0, 1)),
                            ],
                          ),
                          // 여러 개인 경우 개수 표시
                          child: events.length > 1
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+${events.length - 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _selectedEvents.isEmpty
                    ? _buildEmptyState()
                    : _buildEventList(),
              ),
            ],
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            DateFormat('M월 d일').format(_selectedDay) + '에는 등록된 OOTD가 없어요.',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: _selectedEvents.length,
      itemBuilder: (context, index) {
        final doc = _selectedEvents[index];
        final item = doc.data() as Map<String, dynamic>;
        final taggedClothes = item['taggedClothes'] ?? [];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // OOTD 메인 사진
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  item['imageUrl'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[100],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
              ),
              // 정보 영역
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item['memo'] != null && item['memo'].toString().isNotEmpty) ...[
                      Text(
                        item['memo'],
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.checkroom, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '태그된 옷 ${taggedClothes.length}개',
                          style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.calendar_month, size: 18, color: Colors.grey),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            final initialDate = item['createdAt'] != null ? (item['createdAt'] as Timestamp).toDate() : DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
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
                            if (picked != null && !isSameDay(picked, initialDate)) {
                              await _firebaseService.updateOOTDDate(doc.id, picked);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('날짜가 수정되었습니다.')),
                                );
                              }
                              _loadEventsForMonth(_focusedDay);
                            }
                          },
                        ),
                      ],
                    ),
                    if (taggedClothes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: taggedClothes.length,
                          itemBuilder: (context, tagIndex) {
                            final cloth = taggedClothes[tagIndex];
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[100],
                                image: DecorationImage(
                                  image: NetworkImage(cloth['imageUrl'] ?? ''),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
