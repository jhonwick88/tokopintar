import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/main_layout.dart';

class DeveloperContactScreen extends StatelessWidget {
  const DeveloperContactScreen({Key? key}) : super(key: key);

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  void _launchWhatsApp() {
    // 0821 3293 5169 -> 6282132935169
    _launchUrl('https://wa.me/6282132935169?text=Halo%20PintarLabs,%20saya%20ingin%20bertanya%20seputar%20aplikasi%20TokoPintar.');
  }

  void _launchEmail() {
    _launchUrl('mailto:labspintar@gmail.com?subject=Tanya%20TokoPintar&body=Halo%20PintarLabs,%20');
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/settings',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hubungi Developer'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.rocket_launch_rounded,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'TokoPintar by PintarLabs',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tingkatkan skala bisnis Anda dengan fitur-fitur premium dari TokoPintar! Kami siap membantu mewujudkan solusi kasir dan inventori terbaik yang sesuai dengan kebutuhan unik bisnis Anda.\n\nPunya pertanyaan, kendala, atau ingin kustomisasi fitur baru? Jangan ragu untuk menghubungi tim developer kami.',
                            style: TextStyle(fontSize: 16, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 24),
                          
                          // WhatsApp Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 54),
                            ),
                            onPressed: _launchWhatsApp,
                            icon: const Icon(Icons.chat),
                            label: const Text(
                              'Hubungi via WhatsApp\n0821 3293 5169',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Email Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 54),
                            ),
                            onPressed: _launchEmail,
                            icon: const Icon(Icons.email),
                            label: const Text(
                              'Kirim Email\nlabspintar@gmail.com',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
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
