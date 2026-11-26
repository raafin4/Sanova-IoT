import 'package:http/http.dart' as http;
import 'dart:convert';

class SensorService {
  static const String _baseUrl = "http://192.168.100.143"; // IP ESP32
  static const Duration _timeout = Duration(seconds: 10);

  static Future<Map<String, dynamic>> getSensorData() async {
    try {
      final response = await http
          .get(Uri.parse("$_baseUrl/data"))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);

        // Validasi dan parsing data sesuai response ESP32
        double stockTisu = 0.0;
        double kapasitasSampah = 0.0;
        String status = "Tidak Diketahui";

        // Parse stok_tisu
        if (json['stok_tisu'] != null && json['stok_tisu'] is num) {
          stockTisu = (json['stok_tisu'] as num).toDouble();
        }

        // Parse kapasitas_sampah
        if (json['kapasitas_sampah'] != null && json['kapasitas_sampah'] is num) {
          kapasitasSampah = (json['kapasitas_sampah'] as num).toDouble();
        }

        // Parse status
        if (json['status'] != null) {
          status = json['status'].toString();
        }

        // Return data dengan key yang sama seperti response ESP32
        return {
          "stok_tisu": stockTisu,
          "kapasitas_sampah": kapasitasSampah,
          "status": status,
        };
      } else {
        throw Exception("HTTP Error: ${response.statusCode} - ${response.reasonPhrase}");
      }
    } on http.ClientException catch (e) {
      throw Exception("Network Error: $e");
    } on FormatException catch (e) {
      throw Exception("JSON Parse Error: $e");
    } catch (e) {
      throw Exception("Unexpected Error: $e");
    }
  }

  // Method helper untuk test koneksi
  static Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse("$_baseUrl/data"))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Method untuk mendapatkan info device (opsional)
  static Future<Map<String, dynamic>?> getDeviceInfo() async {
    try {
      final response = await http
          .get(Uri.parse("$_baseUrl/info"))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Failed to get device info: $e");
    }
    return null;
  }
}