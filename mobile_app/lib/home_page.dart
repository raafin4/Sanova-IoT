import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sanova/sensor_service.dart';
import 'package:sanova/notification_service.dart';
import 'package:sanova/auth_service.dart';
import 'package:sanova/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double tisuPercent = 0.0;
  double sampahPercent = 0.0;
  bool isLoading = true;
  String status = "Menghubungkan...";
  Timer? _timer;
  bool _tisuNotificationSent = false;
  bool _sampahNotificationSent = false;
  DateTime? _lastTisuNotification;
  DateTime? _lastSampahNotification;

  @override
  void initState() {
    super.initState();
    fetchData();
    // Auto-refresh setiap 5 detik
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Method logout yang ditambahkan
  Future<void> _logout() async {
    try {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      print("Error during logout: $e");
      // Tampilkan pesan error jika diperlukan
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal logout. Silakan coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> fetchData() async {
    try {
      var data = await SensorService.getSensorData();
      setState(() {
        // Sesuaikan dengan response ESP32
        tisuPercent = (data['stok_tisu'] ?? 0.0).toDouble();
        sampahPercent = (data['kapasitas_sampah'] ?? 0.0).toDouble();
        status = data['status'] ?? "Tidak Diketahui";
        isLoading = false;
      });

      // Smart notification untuk tisu dengan cooldown
      if (tisuPercent < 25) {
        final now = DateTime.now();
        if (!_tisuNotificationSent ||
            (_lastTisuNotification != null &&
                now.difference(_lastTisuNotification!).inMinutes >= 30)) {
          await NotificationService.showTisuCriticalNotification(tisuPercent);
          _tisuNotificationSent = true;
          _lastTisuNotification = now;
        }
      } else if (tisuPercent >= 50) {
        // Reset notification saat kondisi membaik
        _tisuNotificationSent = false;
        await NotificationService.clearTisuNotification();
      }

      // Smart notification untuk sampah dengan cooldown
      if (sampahPercent > 80) {
        final now = DateTime.now();
        if (!_sampahNotificationSent ||
            (_lastSampahNotification != null &&
                now.difference(_lastSampahNotification!).inMinutes >= 30)) {
          await NotificationService.showSampahCriticalNotification(sampahPercent);
          _sampahNotificationSent = true;
          _lastSampahNotification = now;
        }
      } else if (sampahPercent <= 60) {
        // Reset notification saat kondisi membaik
        _sampahNotificationSent = false;
        await NotificationService.clearSampahNotification();
      }

    } catch (e) {
      print("Gagal mengambil data: $e");
      setState(() {
        status = "Koneksi Gagal";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isTisuCritical = tisuPercent < 25;
    bool isSampahCritical = sampahPercent > 80;
    bool isSystemOk = !isLoading && status != "Koneksi Gagal" && !isTisuCritical && !isSampahCritical;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Header with Logo and Profile
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SANOVA',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      // Popup menu untuk profile dengan opsi refresh dan logout
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'logout') {
                            _logout();
                          } else if (value == 'refresh') {
                            setState(() {
                              isLoading = true;
                            });
                            fetchData();
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'refresh',
                            child: ListTile(
                              leading: Icon(Icons.refresh),
                              title: Text('Refresh'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'logout',
                            child: ListTile(
                              leading: Icon(Icons.logout, color: Colors.red),
                              title: Text('Logout', style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[300],
                            image: const DecorationImage(
                              image: AssetImage('assets/profile.jpg'), // Ganti dengan path gambar profil Anda
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.grey,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Status Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Center(
                      child: Text(
                        'Status',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Status Indicator Circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLoading
                          ? Colors.orange[200]
                          : (isSystemOk ? Colors.green[200] : Colors.red[200]),
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLoading
                              ? Colors.orange
                              : (isSystemOk ? Colors.green : Colors.red),
                        ),
                        child: isLoading
                            ? const Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                            : Icon(
                          isSystemOk ? Icons.check : Icons.warning,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Monitoring Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Center(
                      child: Text(
                        'Monitoring',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tissue Dispenser Card
                  ModernMonitoringCard(
                    icon: Icons.inventory_2_outlined,
                    title: "Tissue Dispenser",
                    subtitle: "Tissue Stock Availability",
                    percentage: tisuPercent,
                    isReversed: true, // Untuk tisu: 100% = penuh, 0% = kosong
                    isCritical: isTisuCritical,
                  ),

                  const SizedBox(height: 16),

                  // Trash Can Card
                  ModernMonitoringCard(
                    icon: Icons.delete_outline,
                    title: "Trash Can",
                    subtitle: "Trash Can Capacity",
                    percentage: sampahPercent,
                    isReversed: false, // Untuk sampah: 100% = penuh, 0% = kosong
                    isCritical: isSampahCritical,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ModernMonitoringCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double percentage;
  final bool isReversed;
  final bool isCritical;

  const ModernMonitoringCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.percentage,
    this.isReversed = false,
    this.isCritical = false,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate progress for display
    double displayProgress = isReversed
        ? (100 - percentage) / 100  // For tissue: show emptiness
        : percentage / 100;         // For trash: show fullness

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header with Icon and Text
          Row(
            children: [
              // Icon Circle
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress Bar and Percentage
          Row(
            children: [
              // Progress Bar
              Expanded(
                child: Container(
                  height: 25,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12.5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: displayProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12.5),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Percentage Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${percentage.toInt()}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Critical Status Indicator (if needed)
          if (isCritical) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.red[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isReversed ? "Tissue Running Low!" : "Trash Can Full!",
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}