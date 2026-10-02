import 'package:http/http.dart' as http;

import 'network_health.dart';

class SpeedResult {
  final double download, upload, ping, packetLoss;
  final int score;
  final String status;
  SpeedResult(this.download, this.upload, this.ping, this.packetLoss,
      this.score, this.status);
}

class SpeedTestService {
  static const _base = 'https://speed.cloudflare.com';

  // latest result, used by the complaint screen
  static SpeedResult? last;

  static Future<SpeedResult> run() async {
    // PING + PACKET LOSS (5 tiny requests)
    int lost = 0;
    int totalMs = 0;
    for (int i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      try {
        await http
            .get(Uri.parse('$_base/__down?bytes=0'))
            .timeout(const Duration(seconds: 3));
        totalMs += sw.elapsedMilliseconds;
      } catch (_) {
        lost++;
      }
    }
    if (lost == 5) throw Exception('No connection');
    final ping = totalMs / (5 - lost);
    final loss = lost / 5 * 100;

    // DOWNLOAD (5 MB)
    var sw = Stopwatch()..start();
    final res = await http
        .get(Uri.parse('$_base/__down?bytes=5000000'))
        .timeout(const Duration(seconds: 20));
    final download =
        res.bodyBytes.length * 8 / (sw.elapsedMilliseconds / 1000) / 1e6;

    // UPLOAD (1 MB)
    sw = Stopwatch()..start();
    await http
        .post(Uri.parse('$_base/__up'), body: List.filled(1000000, 0))
        .timeout(const Duration(seconds: 20));
    final upload = 1000000 * 8 / (sw.elapsedMilliseconds / 1000) / 1e6;

    final score = _score(download, upload, ping, loss);
    return SpeedResult(
        download, upload, ping, loss, score, _status(score));
  }

  // HEALTH SCORE (out of 100)
  // download 40 + upload 20 + ping 30 + packet loss 10
  static int _score(double dl, double ul, double ping, double loss) {
    final d = (dl / 50).clamp(0, 1) * 40;
    final u = (ul / 20).clamp(0, 1) * 20;
    final p = ((200 - ping) / 180).clamp(0, 1) * 30;
    final l = (1 - loss / 10).clamp(0, 1) * 10;
    return (d + u + p + l).round();
  }

  // Status names use the thresholds configured by the admin.
  static String _status(int s) => NetworkHealth.status(s.toDouble());
}