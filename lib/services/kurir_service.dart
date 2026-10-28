import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class KurirService {
  Future<Map<String, dynamic>> fetchKurirReports({
    required String userId,
    String? dateFrom,
    String? dateTo,
    int? kurirId,
    String? tipeAktivitas,
    String? search,
  }) async {
    final queryParams = <String, String>{
      'user_id': userId,
    };
    if (dateFrom != null && dateFrom.isNotEmpty) queryParams['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) queryParams['date_to'] = dateTo;
    if (kurirId != null && kurirId > 0) queryParams['kurir_id'] = kurirId.toString();
    if (tipeAktivitas != null && tipeAktivitas.isNotEmpty && tipeAktivitas != 'semua') {
      queryParams['tipe_aktivitas'] = tipeAktivitas;
    }
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('${AppConstants.baseUrl}/get_kurir_reports').replace(
      queryParameters: queryParams,
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? {},
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal memuat data laporan kurir',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'HTTP ${response.statusCode}: Gagal menghubungi server',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Kesalahan jaringan: $e',
      };
    }
  }
}
