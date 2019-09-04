import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CountdownManager {
  static final timerKey = "Timer";
  var _timer = 0;
  var _remainingTimer = 0;

  Timer _countdownTimer;

  bool get enabled {
    return _timer == 0;
  }

  void toggle() {
    switch (_timer) {
      case 0:
        _timer = 3;
        break;
      case 3:
        _timer = 10;
        break;
      default:
        _timer = 0;
        break;
    }
    saveSettings();
  }

  Icon get icon {
    switch (_timer) {
      case 3:
        return Icon(Icons.timer_3);
      case 10:
        return Icon(Icons.timer_10);
      default:
        return Icon(Icons.timer_off);
    }
  }

  Widget widget() {
    return Text(
      '$_remainingTimer',
      style: TextStyle(fontSize: 64, color: Colors.white30),
      textAlign: TextAlign.center,
    );
  }

  void schedule(Function(bool) handler) {
    _remainingTimer = _timer;
    _countdownTimer = new Timer.periodic(
      Duration(seconds: 1),
      (timer) {
        if (_countdownTimer == null) {
          // canceled
          handler(false);
          return;
        }

        --_remainingTimer;
        if (_remainingTimer <= 0) {
          _countdownTimer.cancel();
          handler(true);
        } else {
          handler(false);
        }
      },
    );
  }

  void cancel() {
    _countdownTimer.cancel();
    _countdownTimer = null;
  }

  Future saveSettings() async {
    var preferences = await SharedPreferences.getInstance();
    preferences.setInt(timerKey, _timer);
  }

  Future loadSettings() async {
    var preferences = await SharedPreferences.getInstance();
    _timer = preferences.getInt(timerKey) ?? _timer;
  }
}
