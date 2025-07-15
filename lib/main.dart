import 'package:flutter/material.dart';
import 'dart:async'; // ←★これがTimer用
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart'; // ←★これがCsvToListConverter/ListToCsvConverter用
import 'package:share_plus/share_plus.dart';  // 追加
import 'package:fl_chart/fl_chart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

//sqlite構成
class DBHelper {
  static Future<Database> open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'time_study.mobile');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS task_table (
            task_id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_name TEXT,
            task_type_no INTEGER,
            task_category_no INTEGER
          );
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS time_study (
            timestudy_id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER,
            start TEXT,
            stop TEXT,
            helpno INTEGER,
            FOREIGN KEY(task_id) REFERENCES task_table(task_id)
          );
        ''');
      },
    );
  }
}


void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Study Tool',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
      home: const MenuPage(),
    );
  }
}

//画面：メインメニュー
class MenuPage extends StatelessWidget {
  const MenuPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Time study tool'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //作業時間計測ボタン
            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TimerPage()));
                },
                child: const Text('作業時間計測', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
            //計測データ出力ボタン
            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  // 今はダミー画面
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DataExportPage()));
                },
                child: const Text('計測データ出力', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
            //作業時間表示ボタン
            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TimeDisplayPage()));
                },
                child: const Text('作業時間表示', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
            //設定ボタン
            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                },
                child: const Text('設定', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 1-1.機能：計測開始/終了
class TimerPage extends StatefulWidget {
  const TimerPage({super.key});
  @override
  State<TimerPage> createState() => _TimerPageState();
}
class _TimerPageState extends State<TimerPage> {
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  bool _isMeasuring = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _startTime = DateTime.now();
      _isMeasuring = true;
      _elapsed = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
      });
    });
  }

  void _end() async {
    _timer?.cancel();
    //終了確認モーダル
    bool? ok = await showOkCancelModal(
        context,
        message: "計測を終了します。よろしいですか。",
        okLabel: "OK",
        cancelLabel: "キャンセル"
    );
    if (ok == true) {
      if (_startTime != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TaskSelectPage(startTime: _startTime!, endTime: DateTime.now()),
          ),
        );
      }
    } else {
      // キャンセルなら計測再開
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      });
    }
  }

  //1-1.画面：計測開始・終了
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Time study tool'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MenuPage()),
                  (route) => false,
            );
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.grey.shade300,
            padding: const EdgeInsets.all(12),
            child: Text(
              '[経過時間：${_format(_elapsed)}]',
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const Spacer(),
          Center(
            child: !_isMeasuring
                ? ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: _start,
              child: const Text('計測開始', style: TextStyle(fontSize: 22, color: Colors.white)),
            )
                : ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _end,
              child: const Text('計測終了', style: TextStyle(fontSize: 22, color: Colors.white)),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  String _format(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes % 60)}:${twoDigits(d.inSeconds % 60)}";
  }
}

//1-2.機能：作業選択
class TaskSelectPage extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;
  const TaskSelectPage({super.key, required this.startTime, required this.endTime});

  @override
  State<TaskSelectPage> createState() => _TaskSelectPageState();
}

class _TaskSelectPageState extends State<TaskSelectPage> {
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final loaded = await fetchTaskSettings(); // ←SQLiteのデータ取得関数に修正！
    setState(() {
      _tasks = loaded;
      _loading = false;
    });
  }


  //1-2.画面：作業選択
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.blue, title: const Text('Time study tool')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, idx) {
          final task = _tasks[idx];
          final taskName = task['name'] ?? '';
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300),
              onPressed: () async {
                bool? ok = await showOkCancelModal(
                  context,
                  message: '$taskName\n作業内容を記録します。よろしいですか。',
                  okLabel: "OK",
                  cancelLabel: "キャンセル",
                );
                if (ok == true) {
                  final taskId = task['id'] ?? task['task_id'];
                  final start = widget.startTime.toIso8601String();
                  final stop  = widget.endTime.toIso8601String();
                  await insertTimeStudy(taskId, start, stop, 0); // helpno=0

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('登録完了しました。'),
                      duration: const Duration(milliseconds: 1500),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.only(top: 20, left: 16, right: 16),
                    ),
                  );
                  await Future.delayed(const Duration(milliseconds: 1500));
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const TimerPage()),
                        (route) => false,
                  );
                }
              },
              child: Text(taskName, style: const TextStyle(fontSize: 16, color: Colors.black)),
            ),
          );
        },
      ),
    );
  }
}

//2-1.画面：計測データ出力
class DataExportPage extends StatelessWidget {
  const DataExportPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Time study tool'),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // web登録ボタン（ダミー）
            SizedBox(
              width: 150,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  // まだ何も処理しない
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("未実装です（今後Web登録機能を追加）")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('web登録'),
              ),
            ),
            const SizedBox(width: 30),
            // メール送信ボタン
            SizedBox(
              width: 150,
              height: 60,
              child: ElevatedButton(
                onPressed: () async {
                  await sendLatestCsvByMail(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('メール送信'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//2-1.機能：メール送信
Future<void> sendLatestCsvByMail(BuildContext context) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/time_study_data.csv';
    final file = File(path);

    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("CSVデータがありません")),
      );
      return;
    }

    // メール共有(ファイル添付)
    await Share.shareXFiles(
      [XFile(path)],
      text: 'TimeStudyToolの計測データを添付します。',
      subject: 'TimeStudyTool 計測データ',
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("エラー: $e")),
    );
  }
}

//3-1.機能：作業時間表示
class TimeDisplayPage extends StatelessWidget {
  const TimeDisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text('Time study tool'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final data = await _loadCsvData();
            if (data.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('計測データがありません')),
              );
              return;
            }
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 400,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: BarChartSample(data: data),
                  ),
                ),
              ),
            );
          },
          child: const Text('グラフ表示', style: TextStyle(fontSize: 20)),
        ),
      ),
    );
  }

  // 3-2.機能：DBを読み込んでデータを抽出
  Future<List<_TaskBarData>> _loadCsvData() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/time_study_data.csv';
    final file = File(path);

    if (!file.existsSync()) return [];

    final csvStr = await file.readAsString(encoding: utf8);
    final rows = const CsvToListConverter().convert(csvStr, eol: '\n');

    // ヘッダー確認
    final header = rows.isNotEmpty ? rows.first : [];
    final isValid = header.length >= 4 && header[0] == "task_id";
    if (!isValid) return [];

    // データ抽出
    final List<_TaskBarData> list = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 4) continue;
      final taskName = row[1].toString();
      final startStr = row[2].toString();
      final stopStr = row[3].toString();

      try {
        final start = DateFormat('HH:mm:ss').parse(startStr);
        final stop = DateFormat('HH:mm:ss').parse(stopStr);
        final duration = stop.difference(start).inSeconds;
        final label = "$startStr\n$taskName";
        list.add(_TaskBarData(label, duration));
      } catch (_) {}
    }
    return list;
  }
}

// グラフ用データクラス
class _TaskBarData {
  final String label; // x軸（開始時刻＋作業名）
  final int duration; // y軸（秒）
  _TaskBarData(this.label, this.duration);
}

// グラフウィジェット
class BarChartSample extends StatelessWidget {
  final List<_TaskBarData> data;
  const BarChartSample({super.key, required this.data});

  // 3-1.画面：作業時間表示
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("データがありません"));
    }
    // グラフデータを最大10件表示
    final maxBars = 10;
    final showData = data.length > maxBars ? data.sublist(data.length - maxBars) : data;
    final maxY = showData.map((d) => d.duration).fold<int>(0, (p, c) => c > p ? c : p) + 10;

    return Column(
      children: [
        const Text('作業時間グラフ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY.toDouble(),
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (maxY ~/ 6 > 0 ? maxY ~/ 6 : 1).toDouble(),
                    reservedSize: 32,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= showData.length) return const SizedBox();
                      final label = showData[i].label;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                    reservedSize: 60,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (int i = 0; i < showData.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: showData[i].duration.toDouble(),
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text("横軸: 開始時刻＋作業名\n縦軸: 作業時間（秒）"),
      ],
    );
  }
}

//4-1.：設定 ※不要
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.blue, title: const Text('Time study tool')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskSettingListPage()));
          },
          child: const Text('作業設定一覧へ', style: TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}


// 4-1.機能：作業設定一覧 ※無料版のみ
class TaskSettingListPage extends StatefulWidget {
  const TaskSettingListPage({super.key});

  @override
  State<TaskSettingListPage> createState() => _TaskSettingListPageState();
}

class _TaskSettingListPageState extends State<TaskSettingListPage> {
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await fetchTaskSettings();
    setState(() => _tasks = loaded);
  }

  // 保存は個別にやる
  Future<void> _save(int idx, Map<String, dynamic> updated) async {
    await updateTaskSetting(updated); // DBを更新
    setState(() {
      _tasks[idx] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.blue, title: const Text('作業設定一覧')),
      body: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, idx) {
          final task = _tasks[idx];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300),
              onPressed: () async {
                final updated = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TaskEditPage(task: Map<String, dynamic>.from(task)),
                  ),
                );
                if (updated != null) {
                  await _save(idx, updated); // SQLiteにも保存
                }
              },
              child: Text(task['name'], style: const TextStyle(fontSize: 16, color: Colors.black)),
            ),
          );
        },
      ),
    );
  }
}


//4-2.機能：作業設定編集 ※無料版のみ
class TaskEditPage extends StatefulWidget {
  final Map<String, dynamic> task;
  const TaskEditPage({super.key, required this.task});

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  late TextEditingController _nameController;
  late int _selectedType;
  late int _selectedCategory;

  final _typeOptions = const ['直接介護', '間接介護', 'その他'];
  final _categoryOptions = const ['肉体的負担', '精神的負担', 'その他'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task['name'] ?? widget.task['task_name'] ?? '');
    _selectedType = (widget.task['type'] ?? widget.task['task_type'] ?? 0) as int;
    _selectedCategory = (widget.task['category'] ?? widget.task['task_category'] ?? 0) as int;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  //4-2.画面：作業設定編集 ※無料版のみ
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.blue, title: const Text('作業編集')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '作業名'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('カテゴリ:'),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _selectedType,
                  items: List.generate(
                    _typeOptions.length,
                        (i) => DropdownMenuItem(value: i, child: Text(_typeOptions[i])),
                  ),
                  onChanged: (v) => setState(() => _selectedType = v ?? 0),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('介護種別:'),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _selectedCategory,
                  items: List.generate(
                    _categoryOptions.length,
                        (i) => DropdownMenuItem(value: i, child: Text(_categoryOptions[i])),
                  ),
                  onChanged: (v) => setState(() => _selectedCategory = v ?? 0),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () {
                    Navigator.pop(context, {
                      'id': widget.task['id'],
                      'name': _nameController.text,
                      'type': _selectedType,
                      'category': _selectedCategory,
                    });
                  },
                  child: const Text('確定', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  onPressed: () {
                    Navigator.pop(context, null);
                  },
                  child: const Text('キャンセル', style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}


//機能：sqlite登録
Future<int> insertTimeStudy(int taskId, String start, String stop, int helpno) async {
  final db = await DBHelper.open();
  return await db.insert('time_study', {
    'task_id': taskId,
    'start': start,
    'stop': stop,
    'helpno': helpno,
  });
}

// OK/Cancelモーダル共通化
Future<bool?> showOkCancelModal(BuildContext context,
    {required String message, String okLabel = "OK", String cancelLabel = "キャンセル"}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.indigo.shade900),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(okLabel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.indigo.shade900),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
      ],
    ),
  );
}

//機能：sqlite データ取得(一覧表示)
Future<List<Map<String, dynamic>>> fetchTaskSettings() async {
  final db = await DBHelper.open();
  final result = await db.query('task_table', orderBy: 'task_id ASC');
  // データが無ければ初期投入
  if (result.isEmpty) {
    await db.insert('task_table', {
      'task_name': '申し送り',
      'task_type_no': 0,
      'task_category_no': 0,
    });
    // もう一度取得
    return await fetchTaskSettings();
  }
  return result.map((row) => {
    'id': row['task_id'],
    'name': row['task_name'],
    'type': row['task_type_no'],
    'category': row['task_category_no'],
  }).toList();
}

//機能：sqlite データ保存（更新）
Future<void> updateTask(Map<String, dynamic> task) async {
  final db = await DBHelper.open();
  await db.update(
    'task_table',
    {
      'task_name': task['name'],
      'task_type_no': task['type'],
      'task_category_no': task['category'],
    },
    where: 'task_id = ?',
    whereArgs: [task['id']],
  );
}
//機能：sqlite タスク保存（更新）
Future<void> updateTaskSetting(Map<String, dynamic> task) async {
  final db = await DBHelper.open();
  await db.update(
    'task_table',
    {
      'task_name': task['name'],
      'task_type_no': task['type'],
      'task_category_no': task['category'],
    },
    where: 'task_id = ?',
    whereArgs: [task['id']],
  );
}


