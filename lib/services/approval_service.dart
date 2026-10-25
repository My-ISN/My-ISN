import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ApprovalItem {
  final String approvalId;
  final String agentId;
  final String agentName;
  final String category;
  final String task;
  final String summary;
  final String state;
  final String? createdAt;
  final String? decidedAt;
  final String? nextStep;
  final String? divisi;
  final String? kepala;
  final String? mutuPenjelasan;
  final dynamic total;
  final String? jenis;
  final String? pemilik;

  ApprovalItem({
    required this.approvalId,
    this.agentId = '',
    this.agentName = '',
    this.category = '',
    this.task = '',
    this.summary = '',
    this.state = 'PENDING',
    this.createdAt,
    this.decidedAt,
    this.nextStep,
    this.divisi,
    this.kepala,
    this.mutuPenjelasan,
    this.total,
    this.jenis,
    this.pemilik,
  });

  factory ApprovalItem.fromJson(Map<String, dynamic> json) {
    return ApprovalItem(
      approvalId: (json['approval_id'] ?? json['id'] ?? '').toString(),
      agentId: (json['agent_id'] ?? '').toString(),
      agentName: (json['agent_name'] ?? json['pemohon'] ?? json['agent'] ?? '').toString(),
      category: (json['category'] ?? json['kategori'] ?? '').toString(),
      task: (json['task'] ?? json['judul'] ?? '').toString(),
      summary: (json['summary'] ?? json['ringkasan'] ?? json['penjelasan'] ?? '').toString(),
      state: (json['state'] ?? json['status'] ?? 'PENDING').toString().toUpperCase(),
      createdAt: json['created_at']?.toString() ?? json['tanggal']?.toString(),
      decidedAt: json['decided_at']?.toString(),
      nextStep: json['next_step']?.toString(),
      divisi: json['divisi']?.toString(),
      kepala: json['kepala']?.toString(),
      mutuPenjelasan: json['mutu_penjelasan']?.toString(),
      total: json['total'],
      jenis: json['jenis']?.toString(),
      pemilik: json['pemilik']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'approval_id': approvalId,
    'agent_id': agentId,
    'agent_name': agentName,
    'category': category,
    'task': task,
    'summary': summary,
    'state': state,
    'created_at': createdAt,
    'decided_at': decidedAt,
    'next_step': nextStep,
    'divisi': divisi,
    'kepala': kepala,
    'mutu_penjelasan': mutuPenjelasan,
    'total': total,
    'jenis': jenis,
    'pemilik': pemilik,
  };

  bool get isPending => state == 'PENDING';
  bool get isApproved =>
      state == 'APPROVED' || state == 'ACC' || state == 'DISETUJUI';
  bool get isRejected =>
      state == 'REJECTED' || state == 'TOLAK' || state == 'DITOLAK';

  String get displayAgent =>
      agentName.isNotEmpty ? agentName : (agentId.isNotEmpty ? agentId : 'Agen ISKOM');
  String get displayTitle =>
      task.isNotEmpty ? task : (category.isNotEmpty ? category : 'Tiket Persetujuan');
}

class ApprovalResponse {
  final bool status;
  final String? message;
  final int pendingCount;
  final int totalPending;
  final List<ApprovalItem> pending;
  final List<ApprovalItem> selesai;

  ApprovalResponse({
    required this.status,
    this.message,
    this.pendingCount = 0,
    this.totalPending = 0,
    required this.pending,
    required this.selesai,
  });
}

class ApprovalService {
  static const String baseUrl = AppConstants.baseUrl;

  /// Membaca antrean persetujuan tiket & tugas dari endpoint mobileapi.
  Future<ApprovalResponse> getApprovals({
    required int userId,
    bool all = true,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/get_agent_approvals?user_id=$userId&all=${all ? 1 : 0}',
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final dynamic raw = json.decode(response.body);
        if (raw is Map<String, dynamic> && raw['status'] == true) {
          final List<dynamic> pendingList =
              raw['pending'] is List ? raw['pending'] : [];
          final List<dynamic> selesaiList =
              raw['selesai'] is List ? raw['selesai'] : [];

          return ApprovalResponse(
            status: true,
            pendingCount:
                (raw['pending_count'] as num?)?.toInt() ?? pendingList.length,
            totalPending:
                (raw['total_pending'] as num?)?.toInt() ?? pendingList.length,
            pending: pendingList
                .map((e) => ApprovalItem.fromJson(Map<String, dynamic>.from(e)))
                .toList(),
            selesai: selesaiList
                .map((e) => ApprovalItem.fromJson(Map<String, dynamic>.from(e)))
                .toList(),
          );
        }

        return ApprovalResponse(
          status: false,
          message: raw is Map<String, dynamic>
              ? (raw['message']?.toString() ?? 'Gagal memuat data persetujuan')
              : 'Format respons tidak valid',
          pending: [],
          selesai: [],
        );
      }

      String errMsg = 'Server error (${response.statusCode})';
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          errMsg = decoded['message'].toString();
        }
      } catch (_) {}

      return ApprovalResponse(
        status: false,
        message: errMsg,
        pending: [],
        selesai: [],
      );
    } catch (e) {
      return ApprovalResponse(
        status: false,
        message: 'Gagal terhubung ke server: $e',
        pending: [],
        selesai: [],
      );
    }
  }

  /// Mengirim keputusan Owner (APPROVED / REJECTED) beserta alasan (opsional).
  Future<Map<String, dynamic>> decide({
    required int userId,
    required String approvalId,
    required String decision,
    String? reason,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/decide_agent_approval');
      final body = <String, String>{
        'user_id': userId.toString(),
        'approval_id': approvalId,
        'decision': decision,
      };
      if (reason != null && reason.trim().isNotEmpty) {
        body['reason'] = reason.trim();
      }

      final response = await http
          .post(uri, body: body)
          .timeout(const Duration(seconds: 25));

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (decoded is Map<String, dynamic>) {
        final bool isSuccess =
            decoded['status'] == true || response.statusCode == 200;
        return {
          'status': isSuccess && decoded['status'] == true,
          'message': decoded['message']?.toString() ??
              (isSuccess
                  ? 'Keputusan berhasil disimpan.'
                  : (response.statusCode == 403
                      ? 'Akses ditolak (HTTP 403): Akun tidak berwenang.'
                      : 'Gagal memproses keputusan (HTTP ${response.statusCode}).')),
          'data': decoded,
        };
      }

      if (response.statusCode == 403) {
        return {
          'status': false,
          'message': 'Akses ditolak (HTTP 403): Memerlukan hak akses Super Admin/Owner.',
        };
      }

      return {
        'status': response.statusCode == 200,
        'message': 'Respons server: HTTP ${response.statusCode}',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Gagal mengirim keputusan: $e',
      };
    }
  }
}
