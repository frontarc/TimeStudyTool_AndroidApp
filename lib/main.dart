import 'package:flutter/material.dart';
import 'dart:async'; // ←★これがTimer用
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart'; // ←★これがCsvToListConverter/ListToCsvConverter用

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
            // 1つ目：作業時間計測
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
            // 2つ目：計測データ出力
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
            // 3つ目：作業時間表示
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
            // 4つ目：設定
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
// 以下はダミー画面。あとで機能追加OK
class DataExportPage extends StatelessWidget {
  const DataExportPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('計測データ出力')),
      body: const Center(child: Text('ここにデータ出力機能を実装')),
    );
  }
}
class TimeDisplayPage extends StatelessWidget {
  const TimeDisplayPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('作業時間表示')),
      body: const Center(child: Text('ここに作業時間表示を実装')),
    );
  }
}
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: const Center(child: Text('ここに設定画面を実装')),
    );
  }
}
/// 1. 計測開始・終了画面
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
    // 3. 終了確認モーダル
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.blue, title: const Text('Time study tool')),
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

/// 4. 業務選択画面
class TaskSelectPage extends StatelessWidget {
  final DateTime startTime;
  final DateTime endTime;
  const TaskSelectPage({super.key, required this.startTime, required this.endTime});

  static const List<String> _taskTypes = [
    '申し送り','掃除・環境整備','徒手で介助','機具を使用','体位変換','離床臥床移乗含む','車椅子から移乗','トイレへ移動','洗面・手洗い','口腔ケア',
    '清拭・洗髪・足浴','整容・衣服着脱','トイレで排泄介','おむつ交換','入浴準備片付け','入浴介助@浴室','配茶','水分摂取','食事準備片付け',
    '座位で食事介助','歩行介助','車いす移動','個別の対応','その他介助','事務・記録等','休憩','TIME-JUST','各作業の終了'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.blue, title: const Text('Time study tool')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _taskTypes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, idx) {
          final taskName = _taskTypes[idx];
          return SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300),
              onPressed: () async {
                // 5. 業務記録モーダル
                bool? ok = await showOkCancelModal(
                  context,
                  message: '$taskName\n作業内容を記録します。よろしいですか。',
                  okLabel: "OK",
                  cancelLabel: "キャンセル",
                );
                if (ok == true) {
                  await saveTaskToCsv(taskName, startTime, endTime);

                  // バナー上部1.5秒表示
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
                } else {
                  // キャンセルなら何もせず業務選択に戻る
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

/// CSV保存
Future<void> saveTaskToCsv(String taskName, DateTime start, DateTime stop) async {
  const List<String> taskTypes = TaskSelectPage._taskTypes;
  int taskId = taskTypes.indexOf(taskName) + 1;

  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/time_study_data.csv';
  final file = File(path);

  final newRow = [taskId, taskName, DateFormat('HH:mm:ss').format(start), DateFormat('HH:mm:ss').format(stop)];
  List<List<dynamic>> rows = [];
  if (file.existsSync()) {
    String content = await file.readAsString(encoding: utf8);
    List<List<dynamic>> existingRows = const CsvToListConverter().convert(content, eol: '\n');
    rows.addAll(existingRows);
  } else {
    rows.add(['task_id', 'task_name', 'start', 'stop']);
  }
  rows.add(newRow);

  String csv = const ListToCsvConverter().convert(rows);
  List<int> bytes = [0xEF, 0xBB, 0xBF];
  bytes.addAll(utf8.encode(csv));
  await file.writeAsBytes(bytes);
}
