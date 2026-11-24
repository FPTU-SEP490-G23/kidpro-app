import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kidpro_mobile/core/constants/api_endpoints.dart';
import 'package:kidpro_mobile/core/constants/app_colors.dart';
import 'package:kidpro_mobile/core/network/api_client.dart';
import 'package:kidpro_mobile/features/parent/providers/parent_provider.dart';

// ─────────────────────────────────────────────────────────────
// Khảo sát ý kiến phụ huynh (G11-UC-06)
// ─────────────────────────────────────────────────────────────

class _SurveySummary {
  final String id;
  final String title;
  final String? description;
  final DateTime? endDate;
  final int questionsCount;
  final bool hasSubmitted;

  _SurveySummary.fromJson(Map<String, dynamic> j)
      : id = j['id'].toString(),
        title = j['title']?.toString() ?? 'Khảo sát',
        description = j['description']?.toString(),
        endDate = DateTime.tryParse(j['endDate']?.toString() ?? ''),
        questionsCount = (j['questionsCount'] as num?)?.toInt() ?? 0,
        hasSubmitted = j['hasSubmitted'] == true;
}

class _SurveyQuestion {
  final String id;
  final String text;
  final String type; // SINGLE_CHOICE, MULTIPLE_CHOICE, RATING, TEXT
  final bool required;
  final int order;
  final List<String> options;

  _SurveyQuestion.fromJson(Map<String, dynamic> j)
      : id = j['id'].toString(),
        text = j['questionText']?.toString() ?? '',
        type = j['questionType']?.toString() ?? 'TEXT',
        // DTO dùng boolean isRequired -> Jackson đặt tên "required"
        required = (j['required'] ?? j['isRequired']) == true,
        order = (j['orderIndex'] as num?)?.toInt() ?? 0,
        options = (j['options'] as List? ?? []).map((e) => e.toString()).toList();
}

String _errorMessage(Object e, String fallback) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
  }
  return fallback;
}

/// Danh sách khảo sát đang mở. [openTitle]: tự mở khảo sát có tiêu đề này (khi bấm từ thông báo).
class SurveyListScreen extends StatefulWidget {
  final String? openTitle;
  const SurveyListScreen({super.key, this.openTitle});

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  final Dio _dio = ApiClient().dio;
  List<_SurveySummary> _surveys = [];
  bool _loading = true;
  String? _error;
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get(ApiEndpoints.parentOpenSurveys);
      final data = res.data;
      final list = data is Map ? (data['data'] as List? ?? []) : (data as List? ?? []);
      _surveys = list.map((e) => _SurveySummary.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _surveys = [];
      _error = _errorMessage(e, 'Không tải được danh sách khảo sát.');
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _maybeAutoOpen();
  }

  void _maybeAutoOpen() {
    final title = widget.openTitle?.trim();
    if (_autoOpened || title == null || title.isEmpty) return;
    _autoOpened = true;
    for (final s in _surveys) {
      if (!s.hasSubmitted && title.contains(s.title)) {
        _open(s);
        return;
      }
    }
  }

  Future<void> _open(_SurveySummary s) async {
    if (s.hasSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quý phụ huynh đã hoàn thành khảo sát này. Xin cảm ơn!')),
      );
      return;
    }
    final submitted = await context.push<bool>('/parent/surveys/${s.id}');
    if (submitted == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Khảo sát ý kiến')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _surveys.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Icon(Icons.fact_check_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(_error ?? 'Hiện chưa có khảo sát nào đang mở',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _surveys.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final s = _surveys[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _open(s),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(s.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (s.hasSubmitted ? AppColors.success : Colors.orange)
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          s.hasSubmitted ? 'ĐÃ GỬI' : 'CHƯA LÀM',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: s.hasSubmitted ? AppColors.success : Colors.orange.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (s.description != null && s.description!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(s.description!,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                  ],
                                  const SizedBox(height: 10),
                                  Text(
                                    '${s.questionsCount} câu hỏi'
                                    '${s.endDate != null ? ' • Hạn: ${df.format(s.endDate!)}' : ''}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  if (!s.hasSubmitted) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _open(s),
                                        icon: const Icon(Icons.edit_note),
                                        label: const Text('Làm khảo sát'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// Màn điền khảo sát. Trả về `true` qua pop khi nộp thành công.
class SurveyFillScreen extends StatefulWidget {
  final String surveyId;
  const SurveyFillScreen({super.key, required this.surveyId});

  @override
  State<SurveyFillScreen> createState() => _SurveyFillScreenState();
}

class _SurveyFillScreenState extends State<SurveyFillScreen> {
  final Dio _dio = ApiClient().dio;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String _title = '';
  String? _description;
  List<_SurveyQuestion> _questions = [];

  // Câu trả lời theo questionId
  final Map<String, String> _single = {};
  final Map<String, Set<String>> _multi = {};
  final Map<String, int> _rating = {};
  final Map<String, TextEditingController> _text = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get(ApiEndpoints.surveyDetail(widget.surveyId));
      final data = res.data is Map && res.data['data'] != null ? res.data['data'] : res.data;
      _title = data['title']?.toString() ?? 'Khảo sát';
      _description = data['description']?.toString();
      _questions = (data['questions'] as List? ?? [])
          .map((e) => _SurveyQuestion.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final q in _questions) {
        if (q.type == 'TEXT') _text[q.id] = TextEditingController();
      }
    } catch (e) {
      _error = _errorMessage(e, 'Không tải được phiếu khảo sát.');
    }
    if (mounted) setState(() => _loading = false);
  }

  String? _answerOf(_SurveyQuestion q) {
    switch (q.type) {
      case 'SINGLE_CHOICE':
        return _single[q.id];
      case 'MULTIPLE_CHOICE':
        final s = _multi[q.id];
        // Giữ thứ tự đáp án như phiếu gốc; BE thống kê bằng cách tìm từng đáp án trong chuỗi
        return (s == null || s.isEmpty) ? null : q.options.where(s.contains).join(', ');
      case 'RATING':
        final r = _rating[q.id];
        return r == null ? null : '$r';
      default:
        final t = _text[q.id]?.text.trim() ?? '';
        return t.isEmpty ? null : t;
    }
  }

  Future<void> _submit() async {
    final answers = <Map<String, dynamic>>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final a = _answerOf(q);
      if (a == null) {
        if (q.required) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Vui lòng trả lời câu ${i + 1}: ${q.text}'),
            backgroundColor: AppColors.error,
          ));
          return;
        }
        continue;
      }
      answers.add({'questionId': q.id, 'answerValue': a});
    }
    if (answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng trả lời ít nhất một câu hỏi.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _submitting = true);
    final studentId = context.read<ParentProvider>().selectedStudentId;
    try {
      await _dio.post(ApiEndpoints.surveySubmit(widget.surveyId), data: {
        if (studentId.isNotEmpty) 'studentId': studentId,
        'answers': answers,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cảm ơn Quý phụ huynh đã gửi ý kiến khảo sát!'),
        backgroundColor: AppColors.success,
      ));
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_errorMessage(e, 'Gửi khảo sát thất bại. Vui lòng thử lại.')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _buildQuestion(int index, _SurveyQuestion q) {
    Widget input;
    switch (q.type) {
      case 'SINGLE_CHOICE':
        input = RadioGroup<String>(
          groupValue: _single[q.id],
          onChanged: (v) {
            if (v != null) setState(() => _single[q.id] = v);
          },
          child: Column(
            children: q.options
                .map((o) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(o),
                      value: o,
                    ))
                .toList(),
          ),
        );
        break;
      case 'MULTIPLE_CHOICE':
        final selected = _multi.putIfAbsent(q.id, () => <String>{});
        input = Column(
          children: q.options
              .map((o) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(o),
                    value: selected.contains(o),
                    onChanged: (v) => setState(() => v == true ? selected.add(o) : selected.remove(o)),
                  ))
              .toList(),
        );
        break;
      case 'RATING':
        final current = _rating[q.id] ?? 0;
        input = Row(
          children: List.generate(5, (i) {
            final star = i + 1;
            return IconButton(
              iconSize: 34,
              onPressed: () => setState(() => _rating[q.id] = star),
              icon: Icon(star <= current ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber.shade700),
            );
          }),
        );
        break;
      default:
        input = TextField(
          controller: _text[q.id],
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'Nhập ý kiến của Quý phụ huynh...',
            border: OutlineInputBorder(),
          ),
        );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'Câu ${index + 1}. ${q.text}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (q.required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
            ])),
            const SizedBox(height: 6),
            input,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Làm khảo sát')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(_title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_description != null && _description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_description!, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                    const SizedBox(height: 6),
                    Text('Câu có dấu * là bắt buộc.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _questions.length; i++) _buildQuestion(i, _questions[i]),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                        label: Text(_submitting ? 'Đang gửi...' : 'Gửi khảo sát'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}
