import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class BridgeWsClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<Map<String, dynamic>> _messagesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Object> _errorsController =
      StreamController<Object>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messagesController.stream;
  Stream<Object> get errors => _errorsController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect(String wsUrl) async {
    await disconnect();
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel = channel;

    _subscription = channel.stream.listen(
      (dynamic message) {
        if (message is! String) {
          return;
        }
        try {
          final decoded = jsonDecode(message);
          if (decoded is Map<String, dynamic>) {
            _messagesController.add(decoded);
          } else if (decoded is Map) {
            _messagesController.add(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
        } catch (error) {
          _errorsController.add(error);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _errorsController.add(error);
      },
      onDone: () {
        _channel = null;
      },
      cancelOnError: false,
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messagesController.close();
    await _errorsController.close();
  }
}
