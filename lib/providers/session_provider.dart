import 'package:flutter/foundation.dart';

class SessionProvider extends ChangeNotifier {
  String? _activeSessionId;
  bool _isHost = false;

  String? get activeSessionId => _activeSessionId;
  bool get isHost => _isHost;

  void setActiveSession({required String sessionId, required bool isHost}) {
    _activeSessionId = sessionId;
    _isHost = isHost;
    notifyListeners();
  }

  void clearActiveSession() {
    _activeSessionId = null;
    _isHost = false;
    notifyListeners();
  }
}
