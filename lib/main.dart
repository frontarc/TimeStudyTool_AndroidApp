import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert'; // For utf8 encoding
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart'; // For XFile
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // For SystemNavigator
import 'package:permission_handler/permission_handler.dart'; // For requesting storage permissions
import 'package:url_launcher/url_launcher.dart'; // For email sending

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Study Tool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TimeStudyPage(title: 'Time Study Tool'),
    );
  }
}

class TaskRecord {
  final String taskName;
  final DateTime startTime;
  final DateTime? endTime;

  TaskRecord({
    required this.taskName,
    required this.startTime,
    this.endTime,
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  Map<String, dynamic> toMap() {
    final formatter = DateFormat('HH:mm:ss');
    return {
      '作業名': taskName,
      'START': formatter.format(startTime),
      'STOP': endTime != null ? formatter.format(endTime!) : '',
    };
  }
}

class TimeStudyPage extends StatefulWidget {
  const TimeStudyPage({super.key, required this.title});

  final String title;

  @override
  State<TimeStudyPage> createState() => _TimeStudyPageState();
}

class _TimeStudyPageState extends State<TimeStudyPage> {
  String? _currentTask;
  DateTime? _startTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  final List<TaskRecord> _taskRecords = [];
  String _csvFilePath = '';
  
  // Save location preference
  String _saveLocation = 'internal'; // 'internal' or 'drive'

  final List<String> _taskTypes = [
    '申し送り',
    '掃除・環境整備',
    '徒手で介助',
    '機具を使用',
    '体位変換',
    '離床臥床移乗含む',
    '車椅子から移乗',
    'トイレへ移動',
    '洗面・手洗い',
    '口腔ケア',
    '清拭・洗髪・足浴',
    '整容・衣服着脱',
    'トイレで排泄介',
    'おむつ交換',
    '入浴準備片付け',
    '入浴介助@浴室',
    '配茶',
    '水分摂取',
    '食事準備片付け',
    '座位で食事介助',
    '歩行介助',
    '車いす移動',
    '個別の対応',
    'その他介助',
    '事務・記録等',
    '休憩',
    'TIME-JUST',
    '各作業の終了',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTask(String taskName) {
    // 同じタスクを連続で押せないようにする
    if (_currentTask == taskName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同じ作業は連続で選択できません')),
      );
      return;
    }
    
    // 現在のタスクがある場合は終了する
    if (_currentTask != null) {
      _stopCurrentTask();
    }

    setState(() {
      _currentTask = taskName;
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
    });

    // タイマーを開始
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
      });
    });
  }

  void _stopCurrentTask() {
    if (_currentTask != null && _startTime != null) {
      final endTime = DateTime.now();
      
      // タスク記録を保存
      _taskRecords.add(TaskRecord(
        taskName: _currentTask!,
        startTime: _startTime!,
        endTime: endTime,
      ));

      // CSVに保存
      _saveToCSV();
      
      // タイマーをリセット
      _timer?.cancel();
      _timer = null;
    }
  }

  void _cancelLastTask() {
    if (_currentTask != null && _startTime != null) {
      // 現在進行中のタスクのみをリセット
      setState(() {
        _currentTask = null;
        _startTime = null;
        _elapsed = Duration.zero;
        
        // タイマーをリセット
        _timer?.cancel();
        _timer = null;
      });
      
      // CSVファイルから現在のタスク記録を削除
      _removeCurrentTaskFromCSV();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('現在の作業記録をリセットしました')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リセットする作業記録がありません')),
      );
    }
  }
  
  // CSVファイルから現在のタスク記録を削除
  Future<void> _removeCurrentTaskFromCSV() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/time_study_data.csv';
      final file = File(path);
      
      if (file.existsSync()) {
        // 既存ファイルを読み込み
        List<int> existingBytes = await file.readAsBytes();
        
        // BOMがあれば除去 (最初の3バイトがBOMかチェック)
        int startIndex = 0;
        if (existingBytes.length >= 3 && 
            existingBytes[0] == 0xEF && 
            existingBytes[1] == 0xBB && 
            existingBytes[2] == 0xBF) {
          startIndex = 3;
        }
        
        // 既存の内容をデコード
        String existingContent = utf8.decode(existingBytes.sublist(startIndex));
        List<String> lines = existingContent.split('\n');
        
        if (lines.length > 2) {
          // 最後の行（現在のタスク）を削除
          lines.removeLast();
          String newContent = lines.join('\n');
          
          // UTF-8 BOMを追加して文字化けを防止
          List<int> bytes = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
          bytes.addAll(utf8.encode(newContent));
          
          await file.writeAsBytes(bytes);
        }
      }
    } catch (e) {
      print('CSVファイルからの記録削除中にエラーが発生しました: $e');
    }
  }
  
  // アプリを終了する
  Future<void> _onExitButtonPressed() async {
    // 現在のタスクがある場合は停止
    if (_currentTask != null) {
      _stopCurrentTask();
    }
    
    // タイマーをキャンセル
    _timer?.cancel();
    
    // データをクリア
    setState(() {
      _currentTask = null;
      _startTime = null;
      _elapsed = Duration.zero;
      _taskRecords.clear();
      _csvFilePath = '';
    });
    
    // 一時ファイルを削除
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/time_study_data.csv';
      final file = File(path);
      
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      print('一時ファイルの削除中にエラーが発生しました: $e');
    }
    
    // アプリを終了してホーム画面に戻る
    SystemNavigator.pop();
  }

  // 保存先選択ダイアログを表示
  Future<void> _showSaveLocationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('保存先を選択'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('CSVファイルの保存先を選択してください:'),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('内部にダウンロード'),
                  leading: const Icon(Icons.download),
                  onTap: () {
                    Navigator.of(context).pop();
                    _saveToInternalStorage();
                  },
                ),
                ListTile(
                  title: const Text('Google Drive'),
                  leading: const Icon(Icons.cloud_upload),
                  onTap: () {
                    Navigator.of(context).pop();
                    _saveToGoogleDrive();
                  },
                ),
                ListTile(
                  title: const Text('メール送信'),
                  leading: const Icon(Icons.email),
                  onTap: () {
                    Navigator.of(context).pop();
                    _sendEmailWithCSV();
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 内部ストレージのDownloadsフォルダに保存
  Future<void> _saveToInternalStorage() async {
    if (_taskRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録がありません')),
      );
      return;
    }
    
    try {
      // CSVデータを作成
      List<List<dynamic>> rows = _createCSVData();
      
      // CSVに変換 (UTF-8 BOMありで文字化け対策)
      String csv = const ListToCsvConverter().convert(rows);
      
      // UTF-8 BOMを追加して文字化けを防止
      List<int> bytes = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
      bytes.addAll(utf8.encode(csv));
      
      // モバイルプラットフォームでの保存方法
      if (Platform.isAndroid) {
        // ストレージ権限をリクエスト
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ストレージへのアクセス権限が必要です')),
            );
            return;
          }
        }
        
        // Downloadsディレクトリのパスを取得
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ダウンロードフォルダが見つかりません')),
          );
          return;
        }
        
        // Downloadsディレクトリのパスを構築
        // Android 10以降はscoped storageのため、特定のパスを使用
        String downloadsPath = directory.path;
        if (downloadsPath.contains('Android/data')) {
          // 公開ディレクトリのパスを構築
          downloadsPath = downloadsPath.split('Android/data')[0] + 'Download';
        }
        
        final fileName = 'time_study_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
        final path = '$downloadsPath/$fileName';
        final file = File(path);
        await file.writeAsBytes(bytes);
        
        _csvFilePath = path;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSVファイルをダウンロードフォルダに保存しました: $fileName')),
        );
      } else if (Platform.isIOS) {
        // iOSの場合はShare機能を使用
        final directory = await getTemporaryDirectory();
        final fileName = 'time_study_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsBytes(bytes);
        
        // Share Plusを使用してファイルを共有/保存
        final result = await Share.shareXFiles(
          [XFile(path)],
          text: 'Time Study Tool - CSVデータ',
        );
        
        _csvFilePath = path;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSVファイルを共有しました')),
        );
      } else {
        // デスクトッププラットフォームでの保存方法
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'CSVファイルを保存',
          fileName: 'time_study_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
        
        if (outputFile != null) {
          // ファイルに書き込み
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          
          _csvFilePath = outputFile;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('CSVファイルを保存しました: ${file.path}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSVファイルの保存中にエラーが発生しました: $e')),
      );
    }
  }
  
  // Google Driveに保存
  Future<void> _saveToGoogleDrive() async {
    if (_taskRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録がありません')),
      );
      return;
    }
    
    try {
      // CSVデータを作成
      List<List<dynamic>> rows = _createCSVData();
      
      // CSVに変換 (UTF-8 BOMありで文字化け対策)
      String csv = const ListToCsvConverter().convert(rows);
      
      // UTF-8 BOMを追加して文字化けを防止
      List<int> bytes = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
      bytes.addAll(utf8.encode(csv));
      
      // 一時ファイルを作成
      final directory = await getTemporaryDirectory();
      final fileName = 'time_study_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(bytes);
      
      // Google Driveへのアップロードが複雑なため、代わりにShare機能を使用
      final result = await Share.shareXFiles(
        [XFile(path)],
        text: 'Time Study Tool - CSVデータ (Google Driveに保存できます)',
        subject: 'Time Study Tool - CSVデータ',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSVファイルを共有しました。Google Driveに保存するには共有メニューからGoogle Driveを選択してください。')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSVファイルの共有中にエラーが発生しました: $e')),
      );
    }
  }
  
  // メールでCSVを送信（プラットフォーム固有の実装を使用）
  Future<void> _sendEmailWithCSV() async {
    if (_taskRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録がありません')),
      );
      return;
    }
    
    try {
      // CSVデータを作成
      List<List<dynamic>> rows = _createCSVData();
      
      // CSVに変換 (UTF-8 BOMありで文字化け対策)
      String csv = const ListToCsvConverter().convert(rows);
      
      // UTF-8 BOMを追加して文字化けを防止
      List<int> bytes = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
      bytes.addAll(utf8.encode(csv));
      
      // 一時ファイルを作成
      final directory = await getTemporaryDirectory();
      final fileName = 'time_study_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final path = '${directory.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(bytes);
      
      // プラットフォーム固有の実装を使用
      if (Platform.isAndroid) {
        // Androidの場合はMethodChannelを使用してGmailを直接起動
        const platform = MethodChannel('com.example.caregiver_timer/email');
        final bool success = await platform.invokeMethod('sendEmailWithAttachment', {
          'filePath': path,
          'recipient': 'keisuke.nishida@frontarc.co.jp',
          'subject': 'Time Study Tool - CSVデータ',
          'body': 'Time Study Toolからのデータ送信です。',
        });
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gmailが起動しました。送信ボタンを押してください。')),
          );
        } else {
          // 失敗した場合は通常の共有機能を使用
          _fallbackToShareFiles(path);
        }
      } else {
        // Android以外のプラットフォームでは通常の共有機能を使用
        _fallbackToShareFiles(path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('メール送信中にエラーが発生しました: $e')),
      );
      print('メール送信エラー: $e');
    }
  }
  
  // 通常の共有機能を使用するフォールバックメソッド
  Future<void> _fallbackToShareFiles(String path) async {
    final result = await Share.shareXFiles(
      [XFile(path)],
      text: '宛先: keisuke.nishida@frontarc.co.jp\n\nTime Study Tool - CSVデータ',
      subject: 'Time Study Tool - CSVデータ',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSVファイルをメール送信用に共有しました。メールアプリを選択して送信してください。')),
    );
  }
  
  // CSVデータを作成するヘルパーメソッド
  List<List<dynamic>> _createCSVData() {
    List<List<dynamic>> rows = [];
    
    // 日付を追加 (A1)
    rows.add([DateFormat('yyyy年MM月dd日').format(DateTime.now())]);
    
    // ヘッダー行を追加 (A2, B2, C2)
    rows.add(['作業名', 'START', 'STOP']);
    
    // タスク記録を追加
    for (var record in _taskRecords) {
      rows.add([
        record.taskName,
        DateFormat('HH:mm:ss').format(record.startTime),
        record.endTime != null ? DateFormat('HH:mm:ss').format(record.endTime!) : '',
      ]);
    }
    
    return rows;
  }

  // CSVエクスポート - 保存先選択ダイアログを表示
  Future<void> _exportCSV() async {
    if (_taskRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('記録がありません')),
      );
      return;
    }
    
    await _showSaveLocationDialog();
  }

  // 読込機能は削除しました

  // 自動保存用のCSVファイル
  Future<void> _saveToCSV() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/time_study_data.csv';
      final file = File(path);
      
      // CSVデータを作成
      List<List<dynamic>> rows = [];
      
      // ファイルが存在しない場合は日付とヘッダー行を追加
      if (!file.existsSync()) {
        // A1: 日付
        rows.add([DateFormat('yyyy年MM月dd日').format(DateTime.now())]);
        // A2, B2, C2: ヘッダー行
        rows.add(['作業名', 'START', 'STOP']);
      }
      
      // 最新のタスク記録を追加
      final latestRecord = _taskRecords.last;
      rows.add([
        latestRecord.taskName,
        DateFormat('HH:mm:ss').format(latestRecord.startTime),
        latestRecord.endTime != null ? DateFormat('HH:mm:ss').format(latestRecord.endTime!) : '',
      ]);
      
      // CSVに変換
      String csv = const ListToCsvConverter().convert(rows);
      
      // ファイルに追記
      if (file.existsSync()) {
        // 既存ファイルを読み込み
        List<int> existingBytes = await file.readAsBytes();
        
        // BOMがあれば除去 (最初の3バイトがBOMかチェック)
        int startIndex = 0;
        if (existingBytes.length >= 3 && 
            existingBytes[0] == 0xEF && 
            existingBytes[1] == 0xBB && 
            existingBytes[2] == 0xBF) {
          startIndex = 3;
        }
        
        // 既存の内容をデコード
        String existingContent = utf8.decode(existingBytes.sublist(startIndex));
        List<String> lines = existingContent.split('\n');
        
        if (lines.length >= 2) {
          // ヘッダー行の後に追記
          lines.insert(2, csv.split('\n').last);
          String newContent = lines.join('\n');
          
          // UTF-8 BOMを追加して文字化けを防止
          List<int> bytes = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
          bytes.addAll(utf8.encode(newContent));
          
          await file.writeAsBytes(bytes);
        } else {
          // UTF-8 BOMを追加して文字化けを防止
          List<int> bytes = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
          bytes.addAll(utf8.encode(csv));
          
          await file.writeAsBytes(bytes);
        }
      } else {
        // UTF-8 BOMを追加して文字化けを防止
        List<int> bytes = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
        bytes.addAll(utf8.encode(csv));
        
        await file.writeAsBytes(bytes);
      }
      
      _csvFilePath = path;
    } catch (e) {
      print('CSVファイルの保存中にエラーが発生しました: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // 現在のタスクと経過時間を表示
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blue.shade100,
            child: Column(
              children: [
                Text(
                  _currentTask ?? '作業を選択してください',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(_elapsed),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // コントロールボタン
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _cancelLastTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: _onExitButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('終了'),
                ),
                ElevatedButton(
                  onPressed: _exportCSV,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('CSV'),
                ),
              ],
            ),
          ),
          
          // タスクボタンのグリッド
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _taskTypes.length,
              itemBuilder: (context, index) {
                final taskName = _taskTypes[index];
                final isActive = _currentTask == taskName;
                
                return ElevatedButton(
                  onPressed: () => _startTask(taskName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? Colors.blue : null,
                    foregroundColor: isActive ? Colors.white : null,
                    padding: const EdgeInsets.all(4),
                  ),
                  child: Text(
                    taskName,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
