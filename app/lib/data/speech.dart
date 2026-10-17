import 'package:flutter_tts/flutter_tts.dart';

import '../widgets/rich_text.dart';
import 'models.dart';

/// 段落块的朗读文本；图片没有可读内容，返回空串。
String speakableText(Block b) => b.t == 'img' ? '' : plainText(b.text).trim();

/// 把长段落按句切成不超过 [max] 字的片段：安卓 TTS 单次输入有长度上限，
/// 分段也让暂停后能从当前句附近继续。
List<String> splitForSpeech(String text, {int max = 300}) {
  final sentences = RegExp(r'[^。！？；!?;\n]*[。！？；!?;\n]+|[^。！？；!?;\n]+$')
      .allMatches(text)
      .map((m) => m.group(0)!.trim())
      .where((s) => s.isNotEmpty);
  final parts = <String>[];
  var current = '';
  for (var s in sentences) {
    while (s.length > max) {
      if (current.isNotEmpty) parts.add(current);
      current = '';
      parts.add(s.substring(0, max));
      s = s.substring(max);
    }
    if (current.length + s.length > max) {
      if (current.isNotEmpty) parts.add(current);
      current = s;
    } else {
      current += s;
    }
  }
  if (current.isNotEmpty) parts.add(current);
  return parts;
}

/// 朗读速度档位（倍速）。
const speechSpeeds = [0.75, 1.0, 1.25, 1.5, 2.0];

/// 系统 TTS 的薄封装：一次读一段，读完（或被 stop）后 [speak] 才返回。
class Speaker {
  final _tts = FlutterTts();
  Future<bool>? _ready;

  /// 是否有中文语音；没有时返回 false，界面提示用户去系统里安装。
  Future<bool> prepare() => _ready ??= () async {
        await _tts.awaitSpeakCompletion(true);
        final ok = await _tts.isLanguageAvailable('zh-CN');
        if (ok != true) return false;
        await _tts.setLanguage('zh-CN');
        return true;
      }();

  /// flutter_tts 的 0.5 为正常语速。
  Future<void> setSpeed(double speed) => _tts.setSpeechRate(speed * 0.5);

  /// 读完返回 true；被 [stop] 打断或出错返回 false。
  Future<bool> speak(String text) async => await _tts.speak(text) == 1;

  Future<void> stop() => _tts.stop();
}
