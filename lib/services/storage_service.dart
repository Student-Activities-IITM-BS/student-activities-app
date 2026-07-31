import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const String _votesKey = 'comments_votes';
  static const String _reportsKey = 'comments_reports';
  static const String _updateVotesKey = 'update_votes';

  Future<Map<String, String>> getUpdateVotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_updateVotesKey);
    if (jsonString == null) return {};
    try {
      final values = jsonDecode(jsonString) as Map<String, dynamic>;
      return values.map((id, vote) => MapEntry(id, vote.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveUpdateVotes(Map<String, String> votes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_updateVotesKey, jsonEncode(votes));
  }

  Future<Map<String, String>> getCommentVotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_votesKey);
    if (jsonStr == null) return {};
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveCommentVotes(Map<String, String> votes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_votesKey, jsonEncode(votes));
  }

  Future<Set<String>> getReportedComments() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_reportsKey);
    return list?.toSet() ?? {};
  }

  Future<void> saveReportedComment(String commentId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getReportedComments();
    current.add(commentId);
    await prefs.setStringList(_reportsKey, current.toList());
  }
}
