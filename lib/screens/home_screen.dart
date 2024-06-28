import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String _prediction = '';
  String _filePath = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    final statuses = await [
      Permission.microphone,
      Permission.storage,
      if (androidInfo.version.sdkInt >= 30) Permission.manageExternalStorage,
    ].request();

    // Detailed logging for each permission
    statuses.forEach((permission, status) {
      print('Permission: $permission, Status: $status');
    });

    if (statuses[Permission.microphone] != PermissionStatus.granted ||
        statuses[Permission.storage] != PermissionStatus.granted ||
        (androidInfo.version.sdkInt >= 30 &&
            statuses[Permission.manageExternalStorage] !=
                PermissionStatus.granted)) {
      // Handle permission not granted case
      print('Permissions not granted');
      _showPermissionDeniedDialog();
    } else {
      print('All permissions granted');
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Denied'),
        content: const Text(
            'Microphone and storage permissions are required to use this app. Please enable them in the app settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _record() async {
    await _requestPermissions();
    if (_isRecording) {
      // Stop recording
      final path = await _recorder.stopRecorder();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _filePath = path;
        });

        // Debugging statement
        print('Recording stopped, file path: $_filePath');

        // Send the recorded file to the API
        if (_filePath.isNotEmpty) {
          final file = File(_filePath);
          if (await file.exists()) {
            final response = await _sendFileToApi(file);
            if (response != null) {
              setState(() {
                _prediction = response;
              });
            }
          } else {
            print('File does not exist at path: $_filePath');
          }
        } else {
          print('Recording path is empty');
        }
      } else {
        print('StopRecorder returned null path');
      }
    } else {
      // Start recording
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/audio.wav'; // Change to .wav format
      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.pcm16WAV, // Ensure recording in WAV format
      );
      setState(() {
        _isRecording = true;
        _filePath = path;
      });

      // Debugging statement
      print('Recording started, file path: $_filePath');
    }
  }

  Future<String?> _sendFileToApi(File file) async {
    final uri = Uri.parse('https://ffb5-149-108-58-149.ngrok-free.app/predict');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('audio', file.path));
    setState(() {
      _isLoading = true;
    });
    final response = await request.send();

    if (response.statusCode == 200) {
      final responseBody = await http.Response.fromStream(response);
      setState(() {
        _isLoading = false;
      });
      return responseBody
          .body; // Assuming the API returns the prediction as plain text
    } else {
      // Handle error
      setState(() {
        _isLoading = false;
      });
      print('Failed to send file to API, status code: ${response.statusCode}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Emergesense',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Press the button to start recording',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 80),
            IconButton(
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              iconSize: 100,
              color: _isRecording ? Colors.red : Colors.blue,
              onPressed: _record,
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : Text(
                    _prediction.isEmpty
                        ? 'No prediction yet'
                        : 'Prediction: $_prediction',
                    style: const TextStyle(fontSize: 16),
                  ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Clear record action
                  },
                  child: const Text(
                    'Clear Record',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // History action
                  },
                  child: const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
