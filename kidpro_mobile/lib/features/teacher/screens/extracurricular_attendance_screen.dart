import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

/// Điểm danh lớp năng khiếu: bấm nút Có mặt / Vắng / Có phép, không quét mặt.
/// Chỉ hiện các lớp năng khiếu mà giáo viên được phân công.
class ExtracurricularAttendanceScreen extends StatefulWidget {
  const ExtracurricularAttendanceScreen({super.key});

  @override
  State<ExtracurricularAttendanceScreen> createState() => _ExtracurricularAttendanceScreenState();
}

enum _Mark { present, absent, excused }

extension on _Mark {
  String get api => switch (this) {
        _Mark.present => 'PRESENT',
        _Mark.absent => 'ABSENT',
        _Mark.excused => 'EXCUSED',
      };
  String get label => switch (this) {
        _Mark.present => 'Có mặt',
        _Mark.absent => 'Vắng',
        _Mark.excused => 'Có phép',
      };
  Color get color => switch (this) {
        _Mark.present => AppColors.present,
        _Mark.absent => AppColors.absentUnexcused,
        _Mark.excused => AppColors.onLeave,
      };
  IconData get icon => switch (this) {
        _Mark.present => Icons.check_circle_rounded,
        _Mark.absent => Icons.cancel_rounded,
        _Mark.excused => Icons.event_note_rounded,
      };
}

_Mark? _markFromApi(Object? v) => switch (v?.toString()) {
      'PRESENT' => _Mark.present,
      'ABSENT' => _Mark.absent,
      'EXCUSED' => _Mark.excused,
      _ => null,
    };

class _ExtracurricularAttendanceScreenState extends State<ExtracurricularAttendanceScreen> {
  String? _classId;
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  bool _loadingClasses = true;
  bool _loadingSheet = false;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _students = [];
  final Map<String, _Mark> _marks = {};
  Map<String, _Mark> _savedMarks = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final prov = context.read<TeacherProvider>();
    await prov.loadExtracurricularClasses();
    if (!mounted) return;
    setState(() {
      _loadingClasses = false;
      if (prov.extracurricularClasses.isNotEmpty) {
        _classId = prov.extracurricularClasses.first['extracurricularClassId']?.toString();
      }
    });
    if (_classId != null) await _loadSheet();
  }

  Future<void> _loadSheet() async {
    final classId = _classId;
    if (classId == null) return;
    setState(() {
      _loadingSheet = true;
      _error = null;
    });
    try {
      final sheet = await context.read<TeacherProvider>().fetchExtracurricularAttendance(classId, _date);
      final list = (sheet['students'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final saved = <String, _Mark>{};
      for (final s in list) {
        final m = _markFromApi(s['attendanceStatus']);
        if (m != null) saved[s['studentId'].toString()] = m;
      }
      if (!mounted) return;
      setState(() {
        _students = list;
        _savedMarks = saved;
        _marks
          ..clear()
          ..addAll(saved);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _students = [];
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loadingSheet = false);
    }
  }

  bool get _isDirty {
    if (_marks.length != _savedMarks.length) return true;
    for (final e in _marks.entries) {
      if (_savedMarks[e.key] != e.value) return true;
    }
    return false;
  }

  int _count(_Mark m) => _marks.values.where((v) => v == m).length;

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chưa lưu điểm danh'),
        content: const Text('Các thay đổi chưa lưu sẽ bị bỏ. Tiếp tục?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ở lại')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bỏ thay đổi')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _changeClass(String id) async {
    if (id == _classId) return;
    if (!await _confirmDiscardIfDirty()) return;
    setState(() => _classId = id);
    await _loadSheet();
  }

  Future<void> _changeDate(DateTime d) async {
    final day = DateUtils.dateOnly(d);
    final today = DateUtils.dateOnly(DateTime.now());
    if (day.isAfter(today) || day == _date) return;
    if (!await _confirmDiscardIfDirty()) return;
    setState(() => _date = day);
    await _loadSheet();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
      helpText: 'Chọn ngày điểm danh',
    );
    if (picked != null) await _changeDate(picked);
  }

  void _markAllPresent() {
    setState(() {
      for (final s in _students) {
        _marks[s['studentId'].toString()] = _Mark.present;
      }
    });
  }

  Future<void> _save() async {
    final classId = _classId;
    if (classId == null || _marks.isEmpty) return;
    final prov = context.read<TeacherProvider>();

    final unmarked = _students.length - _marks.length;
    if (unmarked > 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Còn bé chưa điểm danh'),
          content: Text('Còn $unmarked bé chưa được đánh dấu. Vẫn lưu những bé đã điểm danh?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Quay lại')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vẫn lưu')),
          ],
        ),
      );
      if (go != true) return;
    }

    setState(() => _saving = true);
    final records = _marks.entries
        .map((e) => {'studentId': e.key, 'status': e.value.api})
        .toList();
    final err = await prov.saveExtracurricularAttendance(classId, _date, records);
    if (!mounted) return;
    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context);
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _savedMarks = Map.of(_marks));
    messenger.showSnackBar(SnackBar(
      content: Text('Đã lưu điểm danh: ${_count(_Mark.present)} có mặt, '
          '${_count(_Mark.absent)} vắng, ${_count(_Mark.excused)} có phép'),
      backgroundColor: AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<TeacherProvider>().extracurricularClasses;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscardIfDirty()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldLight,
        appBar: AppBar(
          title: const Text('Điểm danh lớp năng khiếu',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryDark,
          elevation: 0,
          actions: [
            if (_classId != null)
              IconButton(
                tooltip: 'Tải lại',
                onPressed: _loadingSheet ? null : () async {
                  if (await _confirmDiscardIfDirty()) await _loadSheet();
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        body: _loadingClasses
            ? const Center(child: CircularProgressIndicator())
            : classes.isEmpty
                ? _buildNoAssignment()
                : Column(
                    children: [
                      _buildHeader(classes),
                      Expanded(child: _buildBody()),
                    ],
                  ),
        bottomNavigationBar: (classes.isEmpty || _students.isEmpty) ? null : _buildSaveBar(),
      ),
    );
  }

  Widget _buildNoAssignment() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.palette_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Bạn chưa được phân công lớp năng khiếu nào',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Khi Ban giám hiệu phân công, lớp sẽ hiện ở đây để điểm danh.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<Map<String, dynamic>> classes) {
    final current = classes.firstWhere(
      (c) => c['extracurricularClassId']?.toString() == _classId,
      orElse: () => classes.first,
    );
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = _date == today;
    final dateText = DateFormat('EEEE, dd/MM/yyyy', 'vi').format(_date);
    final schedule = current['scheduleDescription']?.toString() ?? '';
    final room = current['roomName']?.toString() ?? '';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (classes.length > 1) ...[
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: classes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = classes[i];
                  final id = c['extracurricularClassId']?.toString() ?? '';
                  final selected = id == _classId;
                  return ChoiceChip(
                    label: Text(c['className']?.toString() ?? ''),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Colors.grey.shade700,
                    ),
                    onSelected: (_) => _changeClass(id),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(current['className']?.toString() ?? '',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
          if (schedule.isNotEmpty || room.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              [if (schedule.isNotEmpty) schedule, if (room.isNotEmpty) 'Phòng $room'].join(' · '),
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 10),
          // Chọn ngày
          Container(
            decoration: BoxDecoration(
              color: AppColors.scaffoldLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Ngày trước',
                  onPressed: () => _changeDate(_date.subtract(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isToday ? 'Hôm nay · $dateText' : dateText,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Ngày sau',
                  onPressed: isToday ? null : () => _changeDate(_date.add(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingSheet) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _loadSheet, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (_students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Chưa có bé nào được duyệt vào lớp này tại ngày đã chọn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final unmarked = _students.length - _marks.length;
    return RefreshIndicator(
      onRefresh: () async {
        if (await _confirmDiscardIfDirty()) await _loadSheet();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('Có mặt', _count(_Mark.present), AppColors.present),
              _summaryChip('Vắng', _count(_Mark.absent), AppColors.absentUnexcused),
              _summaryChip('Có phép', _count(_Mark.excused), AppColors.onLeave),
              _summaryChip('Chưa điểm danh', unmarked, AppColors.notArrived),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${_students.length} bé',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              TextButton.icon(
                onPressed: _markAllPresent,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Tất cả có mặt'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final s in _students) ...[
            _buildStudentCard(s),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $count',
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> s) {
    final id = s['studentId'].toString();
    final name = s['fullName']?.toString() ?? '';
    final code = s['studentCode']?.toString() ?? '';
    final mainClass = s['mainClassName']?.toString() ?? '';
    final mark = _marks[id];
    final initials = name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).last[0].toUpperCase();
    final accent = mark?.color ?? AppColors.notArrived;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: mark == null ? Colors.black.withValues(alpha: 0.06) : accent.withValues(alpha: 0.45),
          width: mark == null ? 1 : 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Text(initials,
                    style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(
                      [if (code.isNotEmpty) code, if (mainClass.isNotEmpty) mainClass].join(' · '),
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final m in _Mark.values) ...[
                Expanded(child: _markButton(id, m, selected: mark == m)),
                if (m != _Mark.values.last) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _markButton(String studentId, _Mark m, {required bool selected}) {
    return Material(
      color: selected ? m.color : m.color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          if (selected) {
            _marks.remove(studentId); // bấm lại để bỏ chọn
          } else {
            _marks[studentId] = m;
          }
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(m.icon, size: 16, color: selected ? Colors.white : m.color),
              const SizedBox(width: 4),
              Text(m.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : m.color,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveBar() {
    final marked = _marks.length;
    final total = _students.length;
    final canSave = !_saving && marked > 0 && _isDirty;
    final allSaved = !_isDirty && _savedMarks.isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: canSave ? _save : null,
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(allSaved ? Icons.cloud_done_rounded : Icons.save_rounded),
            label: Text(
              allSaved ? 'Đã lưu điểm danh ($marked/$total)' : 'Lưu điểm danh ($marked/$total)',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
