import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_vless/flutter_vless.dart';

/// کانفیگ‌ها: برای افزودن کانفیگ جدید یک لینک vless:// به این لیست اضافه کنید.
const List<String> kConfigs = [
  'vless://fb759958-b17f-4da2-84ac-03796206eb12@trx.koomeh.net:443?type=tcp&security=reality&sni=play.google.com&sid=3ccf670d31a26902&pbk=lN1dFBctfyxI_hivur2gHxdbWb4n_c5Rf047iCCPUkI&fp=chrome&flow=xtls-rprx-vision&headerType=none&encryption=none#%F0%9F%87%B9%F0%9F%87%B7%20%F0%9D%97%A7%F0%9D%97%A5%20%F0%9F%A7%BF%20%E1%B4%B5%CB%A2%E1%B5%97%E1%B5%83%E2%81%BF%E1%B5%87%E1%B5%98%CB%A1',
];

void main() => runApp(const VpnApp());

class VpnApp extends StatelessWidget {
  const VpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VLESS VPN',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final FlutterVless _vless;
  VlessStatus? _status;
  String _state = 'DISCONNECTED';
  bool _busy = false;
  bool _ready = false;
  int _selected = 0;

  bool get _connected => _state == 'CONNECTED';
  bool get _connecting => _busy || _state == 'CONNECTING';

  @override
  void initState() {
    super.initState();
    _vless = FlutterVless(onStatusChanged: (status) {
      if (!mounted) return;
      setState(() {
        _status = status;
        _state = status.state;
        if (_state == 'CONNECTED' || _state == 'DISCONNECTED') _busy = false;
      });
    });
    _init();
  }

  Future<void> _init() async {
    try {
      await _vless.initializeVless(
        notificationIconResourceType: 'mipmap',
        notificationIconResourceName: 'ic_launcher',
      );
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      _toast('خطا در راه‌اندازی: $e');
    }
  }

  VlessURL? _parse(String link) {
    try {
      return FlutterVless.parseFromURL(link);
    } catch (_) {
      return null;
    }
  }

  String _nameOf(int i) {
    final p = _parse(kConfigs[i]);
    final r = p?.remark ?? '';
    return r.isEmpty ? 'سرور ${i + 1}' : r;
  }

  Future<void> _toggle() async {
    if (!_ready || _connecting) return;
    if (_connected) {
      setState(() => _busy = true);
      try {
        _vless.stopVless();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final granted = await _vless.requestPermission();
      if (!granted) {
        _toast('دسترسی VPN داده نشد');
        setState(() => _busy = false);
        return;
      }
      final parsed = _parse(kConfigs[_selected]);
      if (parsed == null) {
        _toast('لینک کانفیگ نامعتبر است');
        setState(() => _busy = false);
        return;
      }
      _vless.startVless(
        remark: parsed.remark,
        config: parsed.getFullConfiguration(),
        proxyOnly: false,
        notificationDisconnectButtonName: 'قطع اتصال',
      );
    } catch (e) {
      _toast('خطا در اتصال: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _speed(num? bytesPerSec) {
    final b = (bytesPerSec ?? 0).toDouble();
    if (b < 1024) return '${b.toStringAsFixed(0)} B/s';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB/s';
    return '${(b / 1024 / 1024).toStringAsFixed(2)} MB/s';
  }

  String _bytes(num? v) {
    final b = (v ?? 0).toDouble();
    if (b < 1024) return '${b.toStringAsFixed(0)} B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _connected
        ? Colors.greenAccent.shade700
        : (_connecting ? Colors.orange : cs.outline);
    final label = _connected
        ? 'متصل'
        : (_connecting ? 'در حال اتصال...' : 'قطع');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('VLESS VPN'), centerTitle: true),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (kConfigs.length > 1)
                  DropdownButtonFormField<int>(
                    value: _selected,
                    decoration: const InputDecoration(
                      labelText: 'سرور',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (int i = 0; i < kConfigs.length; i++)
                        DropdownMenuItem(value: i, child: Text(_nameOf(i))),
                    ],
                    onChanged: _connected || _connecting
                        ? null
                        : (v) => setState(() => _selected = v ?? 0),
                  )
                else
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.dns_outlined),
                      title: Text(_nameOf(0)),
                      subtitle: const Text('VLESS • Reality'),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _toggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.15),
                      border: Border.all(color: color, width: 4),
                      boxShadow: [
                        if (_connected)
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                      ],
                    ),
                    child: Center(
                      child: _connecting
                          ? CircularProgressIndicator(color: color)
                          : Icon(Icons.power_settings_new,
                              size: 80, color: color),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: color)),
                const SizedBox(height: 6),
                Text(
                  _connected ? (_status?.duration ?? '00:00:00') : '--:--:--',
                  style: Theme.of(context).textTheme.titleMedium,
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _ready ? _toggle : null,
                  child: Text(_connected ? 'قطع اتصال' : 'اتصال'),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.arrow_downward,
                        title: 'دانلود',
                        speed: _speed(_connected ? _status?.downloadSpeed : 0),
                        total: _bytes(_connected ? _status?.download : 0),
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.arrow_upward,
                        title: 'آپلود',
                        speed: _speed(_connected ? _status?.uploadSpeed : 0),
                        total: _bytes(_connected ? _status?.upload : 0),
                        color: Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String speed;
  final String total;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.speed,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(title),
              ],
            ),
            const SizedBox(height: 10),
            Text(speed,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textDirection: TextDirection.ltr),
            const SizedBox(height: 4),
            Text('مجموع: $total',
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }
}
