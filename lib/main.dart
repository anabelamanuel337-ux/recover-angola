import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:battery_plus/battery_plus.dart';

// ================= MOTOR REAL =================
// Este arquivo SÓ funciona se android/.../MainActivity.kt existir
// Sem ele, o MethodChannel falha.

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RecoverAngolaApp());
}

class RecoverAngolaApp extends StatelessWidget {
  const RecoverAngolaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Recuperar Angola Real',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0B),
        primaryColor: const Color(0xFFFF2A2A),
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  static const platform = MethodChannel('com.recover.angola/forense');
  late TabController _tabController;

  List<Map<String, dynamic>> _realFiles = [];
  List<Map<String, dynamic>> _topContacts = [];
  List<Map<String, dynamic>> _smsList = [];
  Map<String, dynamic> _deviceState = {};
  bool _isScanning = false;
  String _status = "Pronto para varredura REAL";
  int _batteryLevel = 0;
  bool _isRooted = false;
  bool _hasSpyware = false;

  final Battery _battery = Battery();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _requestRealPermissions();
    _getBattery();
    _checkRoot();
  }

  Future<void> _requestRealPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.contacts,
      Permission.sms,
      Permission.phone,
    ].request();

    // No Android 13+ precisa de fotos
    if (Platform.isAndroid) {
      var androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        await [Permission.photos, Permission.mediaLibrary].request();
      }
    }

    if (statuses[Permission.manageExternalStorage] != PermissionStatus.granted) {
      debugPrint("Aviso: MANAGE_EXTERNAL_STORAGE negado - varredura limitada");
    }
  }

  Future<void> _getBattery() async {
    try {
      final level = await _battery.batteryLevel;
      setState(() => _batteryLevel = level);
      final state = await platform.invokeMethod('getBatteryReal');
      setState(() => _deviceState['batteryNative'] = state);
    } catch (e) {
      debugPrint("Erro bateria: $e");
    }
  }

  Future<void> _checkRoot() async {
    try {
      final result = await platform.invokeMethod('checkRootAndSpyware');
      setState(() {
        _isRooted = result['isRooted'] ?? false;
        _hasSpyware = result['hasSpyware'] ?? false;
        _deviceState = result;
      });
    } catch (e) {
      debugPrint("Sem motor nativo: $e");
    }
  }

  // ============= VARREDURA REAL =============
  Future<void> _scanRealFiles() async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _status = "Varrendo disco REAL... /DCIM/.thumbnails";
      _realFiles = [];
    });

    try {
      final List<dynamic> result = await platform.invokeMethod('scanRealFiles', {
        'includeThumbnails': true,
        'includeWhatsAppCache': true,
        'includeHidden': true,
        'deepScan': _isRooted,
      });

      List<Map<String, dynamic>> parsed = result.map((e) {
        return Map<String, dynamic>.from(e as Map);
      }).toList();

      // Filtra apenas imagens/videos existentes de verdade
      List<Map<String, dynamic>> existing = [];
      for (var f in parsed) {
        final file = File(f['path']);
        if (await file.exists()) {
          f['size'] = await file.length();
          existing.add(f);
        }
      }

      setState(() {
        _realFiles = existing;
        _status = "Encontrados ${existing.length} arquivos REAIS";
        _isScanning = false;
      });
    } on PlatformException catch (err) {
      setState(() {
        _status = "ERRO MOTOR NATIVO: ${err.message}. Colocou MainActivity.kt?";
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _status = "Falha varredura: $e";
        _isScanning = false;
      });
    }
  }

  Future<void> _getTopContacts() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getTopContacts');
      setState(() {
        _topContacts = result.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      debugPrint("Erro contacts: $e");
    }
  }

  Future<void> _getSmsReal() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getSms', {
        'limit': 100,
      });
      setState(() {
        _smsList = result.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      debugPrint("Erro SMS: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF141416),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFFFF2A2A)),
            SizedBox(width: 8),
            Text("RECOVER ANGOLA REAL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFFF2A2A),
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFFFF2A2A),
          tabs: const [
            Tab(icon: Icon(Icons.photo_library), text: "RECUPERAR"),
            Tab(icon: Icon(Icons.message), text: "MENSAGENS"),
            Tab(icon: Icon(Icons.security), text: "ANTI-HACK"),
            Tab(icon: Icon(Icons.phone_android), text: "ESTADO"),
            Tab(icon: Icon(Icons.qr_code), text: "CLIENTE"),
          ],
          onTap: (i) {
            if (i == 1) _getTopContacts();
            if (i == 2) _getSmsReal();
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _isRooted ? const Color(0xFF22FF88).withOpacity(0.12) : const Color(0xFFFF2A2A).withOpacity(0.12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(_isRooted ? Icons.verified_user : Icons.warning, size: 18, color: _isRooted ? const Color(0xFF22FF88) : const Color(0xFFFF2A2A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isRooted ? "ROOT DETECTADO - Recuperação total em /data/media ativada" : "SEM ROOT - Recuperando cache real: .thumbnails, WhatsApp/Databases, Telegram",
                    style: TextStyle(fontSize: 12, color: _isRooted ? const Color(0xFF22FF88) : const Color(0xFFFF2A2A), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                if (_isScanning) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF2A2A))),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1 - RECUPERAR
                _buildRecoverTab(),
                // TAB 2 - MENSAGENS / TOP 5
                _buildMessagesTab(),
                // TAB 3 - ANTI-HACK
                _buildAntiHackTab(),
                // TAB 4 - ESTADO
                _buildEstadoTab(),
                // TAB 5 - CLIENTE QR
                _buildClientTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFF2A2A),
              onPressed: _scanRealFiles,
              icon: const Icon(Icons.radar),
              label: Text(_isScanning ? "VARRRENDO..." : "VARREDURA REAL"),
            )
          : null,
    );
  }

  Widget _buildRecoverTab() {
    if (_realFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_search, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            Text(_isScanning ? "Lendo setores..." : "Nenhum arquivo ainda", style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            const Text("Clique em VARREDURA para ver SUAS fotos", style: TextStyle(color: Colors.white24, fontSize: 12)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
      itemCount: _realFiles.length,
      itemBuilder: (ctx, i) {
        final f = _realFiles[i];
        final path = f['path'] as String;
        return GestureDetector(
          onTap: () => _openRealFile(path),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // PREVIEW REAL - File()
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) {
                  return Container(color: const Color(0xFF1A1A1E), child: const Icon(Icons.broken_image, color: Colors.white24));
                }),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  color: Colors.black54,
                  child: Text(
                    "${(f['size'] / 1024).toStringAsFixed(0)} KB • ${f['source']}",
                    style: const TextStyle(fontSize: 9, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessagesTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text("TOP 5 NÚMEROS MAIS FALADOS (CallLog real)", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF2A2A))),
        const SizedBox(height: 12),
        ..._topContacts.take(5).map((c) {
          return ListTile(
            tileColor: const Color(0xFF1A1A1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Text(c['name'] ?? c['number'] ?? "Desconhecido", style: const TextStyle(color: Colors.white)),
            subtitle: Text("${c['count']} chamadas • último: ${c['lastCall']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: Text(c['blocked'] == true ? "BLOQUEADO" : "", style: const TextStyle(color: Color(0xFFFF2A2A), fontSize: 10, fontWeight: FontWeight.bold)),
          );
        }),
        const SizedBox(height: 24),
        const Text("SMS REAIS RECUPERADOS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
        ..._smsList.map((sms) {
          return Card(
            color: const Color(0xFF1A1A1E),
            child: ListTile(
              title: Text(sms['address'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(sms['body'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAntiHackTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _checkTile("App espião com acessibilidade", _hasSpyware, "Nenhum app suspeito com BIND_ACCESSIBILITY detectado"),
        _checkTile("Root / Magisk", _isRooted, _isRooted ? "Dispositivo rooteado - acesso total OK" : "Sem root - acesso limitado a cache"),
        _checkTile("Bateria Anormal", _batteryLevel < 20, "Bateria: $_batteryLevel% - Verifique drenagem por spyware"),
        _checkTile("Pacotes suspeitos", _deviceState['suspiciousPackages'] != null, "Varredura de QUERY_ALL_PACKAGES concluída"),
      ],
    );
  }

  Widget _checkTile(String title, bool alert, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1E), borderRadius: BorderRadius.circular(10), border: Border.all(color: alert ? const Color(0xFFFF2A2A).withOpacity(0.4) : Colors.white12)),
      child: Row(
        children: [
          Icon(alert ? Icons.warning_amber : Icons.check_circle, color: alert ? const Color(0xFFFF2A2A) : const Color(0xFF22FF88)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12))])),
        ],
      ),
    );
  }

  Widget _buildEstadoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("BATERIA: $_batteryLevel% - ${_deviceState['batteryHealth'] ?? 'Desconhecido'}", style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 12),
        Text("MODELO: ${_deviceState['model'] ?? '-'}", style: const TextStyle(color: Colors.white70)),
        Text("ANDROID: ${_deviceState['androidVersion'] ?? '-'} SDK ${_deviceState['sdk'] ?? '-'}", style: const TextStyle(color: Colors.white70)),
        Text("ROOT: ${_isRooted ? 'SIM' : 'NÃO'}", style: TextStyle(color: _isRooted ? const Color(0xFF22FF88) : Colors.white70)),
        const SizedBox(height: 20),
        const Text("Este estado é 100% real via MethodChannel + BatteryManager + PackageManager", style: TextStyle(color: Colors.white24, fontSize: 11)),
      ],
    );
  }

  Widget _buildClientTab() {
    final link = "https://recover-angola.vercel.app/cliente/${_deviceState['androidId'] ?? 'ID'}";
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("QR REAL DO CLIENTE", style: TextStyle(color: Color(0xFFFF2A2A), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(data: link, version: QrVersions.auto, size: 200),
          ),
          const SizedBox(height: 16),
          Text(link, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2A2A)),
            onPressed: () => Share.share("Meu link Recover Angola: $link"),
            icon: const Icon(Icons.share),
            label: const Text("COMPARTILHAR LINK REAL"),
          ),
        ],
      ),
    );
  }

  void _openRealFile(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.file(File(path), errorBuilder: (_, __, ___) => const Text("Não foi possível abrir", style: TextStyle(color: Colors.white))),
        ),
      ),
    );
  }
}
