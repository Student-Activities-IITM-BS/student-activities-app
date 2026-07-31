import 'dart:async';

import 'package:student_activities/core/constants.dart';
import 'package:student_activities/services/auth_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class VoicesChatService {
  io.Socket? _socket;
  Completer<void>? _connection;

  io.Socket? get socket => _socket;

  Future<io.Socket?> connect() async {
    final current = _socket;
    if (current?.connected == true) return current;

    if (current == null || (_connection?.isCompleted ?? true)) {
      _startConnection();
    }
    final connection = _connection;
    if (connection == null) return null;
    try {
      await connection.future.timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
    return _socket?.connected == true ? _socket : null;
  }

  void _startConnection() {
    _socket?.dispose();
    final token = AuthService.instance.token;
    if (token == null || token.isEmpty) {
      _socket = null;
      _connection = null;
      return;
    }

    final connection = Completer<void>();
    _connection = connection;
    final socket = io.io(
      AppConstants.apiBaseUrl,
      io.OptionBuilder()
          .setPath('/ws')
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setReconnectionAttempts(3)
          .setReconnectionDelay(800)
          .setReconnectionDelayMax(3000)
          .setTimeout(8000)
          .enableForceNew()
          .build(),
    );
    _socket = socket;
    socket.onConnect((_) {
      if (!connection.isCompleted) connection.complete();
    });
    socket.onConnectError((_) {
      if (!connection.isCompleted) connection.complete();
    });
    socket.onDisconnect((_) {
      if (identical(_socket, socket)) _connection = null;
    });
  }

  Future<Map<String, dynamic>> join(String groupId) async {
    final socket = await connect();
    if (socket == null) {
      return {'ok': false, 'error': 'Unable to connect to Voices.'};
    }
    return request(socket, 'chat:join', {'groupId': groupId});
  }

  Future<Map<String, dynamic>> history(io.Socket socket, {int limit = 30}) =>
      request(socket, 'chat:history', {'limit': limit});

  Future<Map<String, dynamic>> send(
    io.Socket socket,
    String content, {
    String? parentId,
  }) {
    final data = <String, dynamic>{'content': content};
    if (parentId != null) data['parentId'] = parentId;
    return request(socket, 'chat:send', data);
  }

  Future<Map<String, dynamic>> request(
    io.Socket socket,
    String event,
    Map<String, dynamic> data,
  ) {
    if (!socket.connected) {
      return Future.value({'ok': false, 'error': 'Voices is not connected.'});
    }
    final response = Completer<Map<String, dynamic>>();
    final timer = Timer(const Duration(seconds: 8), () {
      if (!response.isCompleted) {
        response.complete({
          'ok': false,
          'error': 'Request timed out. Check your connection.',
        });
      }
    });
    socket.emitWithAck(
      event,
      data,
      ack: (dynamic raw) {
        timer.cancel();
        if (response.isCompleted) return;
        response.complete(
          raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{
                  'ok': false,
                  'error': 'Invalid response from Voices.',
                },
        );
      },
    );
    return response.future;
  }

  void dispose() {
    _connection = null;
    _socket?.dispose();
    _socket = null;
  }
}
