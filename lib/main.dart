import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(RecoverAngolaApp());

class RecoverAngolaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Recover Angola', debugShowCheckedModeBanner: false, theme: ThemeData(primarySwatch: Colors.green), home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<AssetEntity> photos = [];
  List<AssetEntity> selected = [];
  bool loading = false;
  String status = "Toque em Verificar Fotos";
  
  Future<void> checkPhotos() async {
    setState(() { loading = true; status = "Buscando permissão..."; });
    await Permission.photos.request();
    await Permission.storage.request();
    final ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) { setState(() { loading = false; status = "Permissão negada!"; }); return; }
    setState(() { status = "Buscando fotos..."; });
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(onlyAll: true, type: RequestType.image);
    List<AssetEntity> all = await albums[0].getAssetListRange(start: 0, end: 1000);
    setState(() { photos = all; loading = false; status = "${all.length} fotos encontradas"; });
  }
  
  Future<void> recover() async {
    String base = "/storage/emulated/0/Pictures/RecoverAngola";
    Directory dir = Directory(base);
    if (!await dir.exists()) await dir.create(recursive: true);
    int c = 0;
    for (var a in selected) {
      File? f = await a.file;
      if (f != null) { await f.copy("$base/recuperada_${DateTime.now().millisecondsSinceEpoch}_$c.jpg"); c++; }
    }
    setState(() { status = "$c fotos salvas em Pictures/RecoverAngola"; loading = false; });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Recover Angola"), backgroundColor: Colors.green[700]),
      body: Column(children: [
        Container(width: double.infinity, color: Colors.green[50], padding: EdgeInsets.all(12), child: Text(status, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
        Padding(padding: EdgeInsets.all(10), child: Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: loading ? null : checkPhotos, icon: Icon(Icons.search), label: Text("Verificar"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))),
          SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(onPressed: selected.isEmpty || loading ? null : recover, icon: Icon(Icons.save), label: Text("Recuperar (${selected.length})"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange))),
        ])),
        Expanded(child: loading ? Center(child: CircularProgressIndicator()) : GridView.builder(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2), itemCount: photos.length, itemBuilder: (ctx,i){
          bool sel = selected.contains(photos[i]);
          return GestureDetector(onTap: (){ setState((){ if(sel) selected.remove(photos[i]); else selected.add(photos[i]); }); }, child: Stack(fit: StackFit.expand, children: [
            FutureBuilder<File?>(future: photos[i].file, builder: (_,s){ if(s.hasData && s.data!=null) return Image.file(s.data!, fit: BoxFit.cover); return Container(color: Colors.grey[300], child: Icon(Icons.image)); }),
            if(sel) Container(color: Colors.green.withOpacity(0.5), child: Icon(Icons.check_circle, color: Colors.white, size:30)),
          ]));
        })),
      ]),
    );
  }
}
