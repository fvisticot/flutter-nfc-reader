import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum NFCStatus {
  none,
  reading,
  read,
  stopped,
  error,
}

class NfcData {
  final String id;
  final String content;
  final String error;
  final int errorCode;
  final String statusMapper;

  NFCStatus status;

  NfcData({
    this.id,
    this.content,
    this.error,
    this.errorCode,
    this.statusMapper,
  });

  factory NfcData.fromMap(Map data) {
    NfcData result = NfcData(
      id: data['nfcId'],
      content: data['nfcContent'],
      error: data['nfcError'],
      errorCode: data['nfcErrorCode'],
      statusMapper: data['nfcStatus'],
    );
    switch (result.statusMapper) {
      case 'none':
        result.status = NFCStatus.none;
        break;
      case 'reading':
        result.status = NFCStatus.reading;
        break;
      case 'stopped':
        result.status = NFCStatus.stopped;
        break;
      case 'error':
        result.status = NFCStatus.error;
        break;
      default:
        result.status = NFCStatus.none;
    }
    return result;
  }

  @override
  String toString() {
    return 'NfcData{id: $id, content: $content, error: $error, errorCode: $errorCode, statusMapper: $statusMapper, status: $status}';
  }
}

class FlutterNfcReader {
  static const MethodChannel _methodChannel =
      const MethodChannel('flutter_nfc_reader/read');
  static const EventChannel _stream =
      const EventChannel('flutter_nfc_reader/stream');
  static Stream<NfcData> _onNfcTagRead;

  static Future<NfcData> read({String instruction}) async {
    final Map data = await _methodChannel
        .invokeMethod('NfcRead', <String, String>{'instruction': instruction});
    if (Platform.isAndroid) {
      await stop();
    }
    return _parseEvent(data);
  }

  static Stream<NfcData> onNfcTagRead({String instruction}) {
    if (_onNfcTagRead == null) {
      _onNfcTagRead = _stream.receiveBroadcastStream([
        <String, String>{"instruction": instruction}
      ]).map((dynamic event) {
        final nfcData = _parseEvent(event);
        if (nfcData.error.length > 0) {
          _onNfcTagRead = null;
        }
        return nfcData;
      });
    }
    return _onNfcTagRead;
  }

  static NfcData _parseEvent(dynamic event) {
    return NfcData.fromMap(event);
  }

  static Future<NfcData> stop() async {
    _onNfcTagRead = null;
    final Map data = await _methodChannel.invokeMethod('NfcStop');

    final NfcData result = NfcData.fromMap(data);

    return result;
  }
}
