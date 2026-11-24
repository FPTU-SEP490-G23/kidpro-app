import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/features/teacher/models/teacher_models.dart';
import 'package:kidpro_mobile/features/teacher/providers/teacher_provider.dart';

/// Điểm danh xe buýt theo trạm (G5-UC-02) và chốt an toàn khoang xe (G5-UC-03, BR-024).
class BusAttendanceScreen extends StatefulWidget {
  const BusAttendanceScreen({super.key});

  @override
  State<BusAttendanceScreen> createState() => _BusAttendanceScreenState();
}

class _BusAttendanceScreenState extends State<BusAttendanceScreen> {
  final _qrTokenCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController();
  String? _selectedStopId;
  bool _uploadingPhoto = false;
  final Set<String> _busyStudents = {};

  @override
  void initState() {
    super.initState();
    // Lấy tuyến xe được phân công cho giáo viên, tự tải chuyến đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TeacherProvider>().loadBusRoutes();
    });
  }

  @override
  void dispose() {
    _qrTokenCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  void _showResult(String? msg) {
    if (!mounted || msg == null) return;
    final failed = context.read<TeacherProvider>().lastActionFailed;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: failed ? AppColors.error : AppColors.success,
      ),
    );
  }

  /// Trạm đang chọn; mặc định trạm đầu (lên xe) – trạm cuối là điểm trả (xuống xe).
  BusStopInfo? _currentStop(BusTripInfo trip) {
    if (trip.stops.isEmpty) return null;
    return trip.stops.firstWhere(
      (s) => s.stopId == _selectedStopId,
      orElse: () => trip.stops.first,
    );
  }

  List<BusStudentInfo> _studentsAtStop(BusTripInfo trip, BusStopInfo stop) {
    if (stop.isDestination) {
      return trip.students
          .where((student) => student.isOnboard || student.isDeboarded)
          .toList();
    }
    return trip.students
        .where((student) => student.stopId == stop.stopId)
        .toList();
  }

  Future<void> _mark(
    BusTripInfo trip,
    BusStudentInfo student,
    String action,
  ) async {
    final stop = _currentStop(trip);
    setState(() => _busyStudents.add(student.studentId));
    final msg = await context.read<TeacherProvider>().submitBusCheckin(
      tripId: trip.tripId,
      studentId: student.studentId,
      stopId: stop?.stopId ?? '',
      actionType: action,
    );
    if (mounted) setState(() => _busyStudents.remove(student.studentId));
    _showResult(msg);
  }

  void _showSafetyClosureModal() {
    final trip = context.read<TeacherProvider>().currentBusTrip;
    final remainingCount = trip?.remainingCount ?? 0;
    final closed = trip?.isSafetyClosed == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_user,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kiểm tra khoang xe & Đóng chuyến (BR-024)',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: remainingCount == 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: remainingCount == 0 ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      remainingCount == 0 ? Icons.check_circle : Icons.error,
                      color: remainingCount == 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        closed
                            ? 'Chuyến xe hôm nay đã được đóng.'
                            : remainingCount == 0
                            ? 'Đã xác nhận 0 học sinh còn sót lại trên xe.'
                            : 'CẢNH BÁO: Còn $remainingCount học sinh chưa xuống xe! Không thể đóng chuyến.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: remainingCount == 0
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: _uploadingPhoto
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _photoUrlCtrl.text.isNotEmpty
                            ? Icons.check_circle
                            : Icons.camera_alt,
                        color: _photoUrlCtrl.text.isNotEmpty
                            ? AppColors.success
                            : null,
                      ),
                label: Text(
                  _photoUrlCtrl.text.isNotEmpty
                      ? 'Đã chụp ảnh khoang xe rỗng (chạm để chụp lại)'
                      : 'Chụp ảnh khoang xe rỗng *',
                ),
                onPressed: _uploadingPhoto
                    ? null
                    : () async {
                        final photo = await ImagePicker().pickImage(
                          source: ImageSource.camera,
                          maxWidth: 1280,
                          imageQuality: 85,
                        );
                        if (photo == null || !mounted) return;
                        setSheet(() => _uploadingPhoto = true);
                        try {
                          final url = await context
                              .read<TeacherProvider>()
                              .uploadTeacherPhoto(photo.path, 'bus-safety');
                          _photoUrlCtrl.text = url;
                        } catch (_) {
                          _photoUrlCtrl.clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Không tải được ảnh khoang xe, vui lòng chụp lại.',
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                        setSheet(() => _uploadingPhoto = false);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qrTokenCtrl,
                decoration: InputDecoration(
                  labelText: 'Mã QR dán ở đuôi xe *',
                  hintText: trip != null ? 'VD: ${trip.plateNumber}' : null,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('Xác nhận An toàn & Đóng Chuyến (MSG-100)'),
                  onPressed: trip == null || closed
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final msg = await context
                              .read<TeacherProvider>()
                              .performBusSafetyClosure(
                                tripId: trip.tripId,
                                photoUrl: _photoUrlCtrl.text.trim(),
                                qrTailScanToken: _qrTokenCtrl.text.trim(),
                              );
                          _showResult(msg ?? 'Đã hoàn tất đóng chuyến');
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<TeacherProvider>();
    final trip = prov.currentBusTrip;
    final currentStop = trip != null ? _currentStop(trip) : null;
    final stationStudents = trip != null && currentStop != null
        ? _studentsAtStop(trip, currentStop)
        : const <BusStudentInfo>[];
    final unassignedCount =
        trip?.students
            .where(
              (student) => student.stopId == null || student.stopId!.isEmpty,
            )
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh Xe Buýt Tuyến'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => prov.loadBusRoutes(),
          ),
        ],
      ),
      body: prov.loading && trip == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (prov.availableBusRoutes.length > 1) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(trip?.tripId),
                    initialValue: trip?.tripId,
                    decoration: const InputDecoration(
                      labelText: 'Tuyến xe được phân công',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alt_route),
                    ),
                    items: prov.availableBusRoutes.map((route) {
                      final busId = route['busId']?.toString() ?? '';
                      final routeName =
                          route['routeName']?.toString() ?? 'Tuyến xe buýt';
                      final plate =
                          route['plateNumber']?.toString() ??
                          route['busNumber']?.toString() ??
                          '';
                      return DropdownMenuItem<String>(
                        value: busId,
                        child: Text(
                          plate.isEmpty ? routeName : '$routeName · $plate',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (busId) {
                      if (busId != null) prov.selectBusRoute(busId);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                // Thẻ thông tin chuyến đi
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                trip == null || trip.plateNumber.isEmpty
                                    ? '—'
                                    : trip.plateNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            if (trip != null)
                              Text(
                                trip.isSafetyClosed
                                    ? 'Đã đóng chuyến'
                                    : 'Đang hoạt động',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: trip.isSafetyClosed
                                      ? Colors.grey
                                      : AppColors.success,
                                ),
                              ),
                          ],
                        ),
                        if (trip != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            trip.routeName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (trip.driverName != null &&
                              trip.driverName!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Tài xế: ${trip.driverName}${trip.driverPhone != null ? ' - ${trip.driverPhone}' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              'Tổng học sinh',
                              '${trip?.totalStudents ?? 0}',
                              Colors.blue,
                            ),
                            _buildStatItem(
                              'Trên xe',
                              '${trip?.onboardCount ?? 0}',
                              Colors.orange,
                            ),
                            _buildStatItem(
                              'Đã xuống xe',
                              '${trip?.deboardedCount ?? 0}',
                              Colors.green,
                            ),
                            _buildStatItem(
                              'Còn lại',
                              '${trip?.remainingCount ?? 0}',
                              Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (trip == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Chưa được phân công tuyến xe buýt nào',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Danh sách trạm đón / trả',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Chạm vào trạm để chọn trạm hiện tại khi điểm danh.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (trip.stops.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Tuyến này chưa có điểm dừng',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...trip.stops.map(
                      (stop) => _buildStopTile(
                        stop,
                        selected: currentStop?.stopId == stop.stopId,
                        onTap: () =>
                            setState(() => _selectedStopId = stop.stopId),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    currentStop == null
                        ? 'Học sinh tại trạm'
                        : 'Học sinh tại ${currentStop.stopName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (unassignedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '$unassignedCount học sinh chưa được gán trạm đón.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  if (stationStudents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          currentStop?.isDestination == true
                              ? 'Chưa có học sinh lên xe. Chọn trạm đón để điểm danh lên xe.'
                              : 'Không có học sinh có đăng ký đã duyệt và còn hiệu lực tại trạm này hôm nay',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...stationStudents.map(
                      (s) => _buildStudentTile(trip, currentStop!, s),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.fact_check),
                    label: const Text(
                      'Quy trình Kiểm tra An toàn & Đóng chuyến (BR-024)',
                    ),
                    onPressed: _showSafetyClosureModal,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStopTile(
    BusStopInfo stop, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: stop.isDestination
              ? Colors.red.shade100
              : Colors.blue.shade100,
          child: Icon(
            stop.isDestination ? Icons.school : Icons.directions_bus,
            color: stop.isDestination ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(
          stop.stopName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          [
            if (stop.stopAddress.isNotEmpty) stop.stopAddress,
            'Dự kiến: ${stop.estimatedTime.isEmpty ? '—' : stop.estimatedTime}',
            if (!stop.isDestination) '${stop.studentCount} học sinh đăng ký',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Text(
            stop.isDestination
                ? 'Trả: ${stop.deboardedCount}'
                : 'Đón: ${stop.boardedCount}/${stop.studentCount}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTile(
    BusTripInfo trip,
    BusStopInfo stop,
    BusStudentInfo s,
  ) {
    final busy = _busyStudents.contains(s.studentId);
    final closed = trip.isSafetyClosed;
    final (label, color) = switch (s.status) {
      'ONBOARD' => ('Trên xe', Colors.orange),
      'DEBOARDED' => ('Đã xuống', Colors.green),
      _ => ('Chưa lên xe', Colors.grey),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    [
                      if (s.className != null) s.className!,
                      if (stop.isDestination && s.stopName != null)
                        'Đón tại: ${s.stopName}',
                      if (s.pickupAddress != null) s.pickupAddress!,
                      if (s.parentPhone != null && s.parentPhone!.isNotEmpty)
                        'PH: ${s.parentPhone}',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.lastTime != null ? '$label · ${s.lastTime}' : label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (!closed && !stop.isDestination && s.status == 'WAITING')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _mark(trip, s, 'BOARDING'),
                child: const Text('Điểm danh lên xe'),
              )
            else if (!closed && stop.isDestination && s.isOnboard)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _mark(trip, s, 'DEBOARDING'),
                child: const Text('Điểm danh xuống xe'),
              ),
          ],
        ),
      ),
    );
  }
}
