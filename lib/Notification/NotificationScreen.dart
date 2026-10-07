import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:new_sara/l10n/app_localizations.dart';

// Assuming 'ulits/Constents.dart' exists and contains Constant.apiEndpoint
import '../../ulits/Constents.dart';

class NoticeHistoryScreen extends StatefulWidget {
  const NoticeHistoryScreen({Key? key}) : super(key: key);

  @override
  State<NoticeHistoryScreen> createState() => _NoticeHistoryScreenState();
}

class _NoticeHistoryScreenState extends State<NoticeHistoryScreen> {
  List<NoticeEntry> entries = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchNoticeHistory();
  }

  Future<void> _fetchNoticeHistory() async {
    setState(() => loading = true);

    final String mobileNo =
        GetStorage().read("mobileNo") ??
        '7007465202'; // Using provided mobileNo from curl
    final token = GetStorage().read("accessToken") ?? '';

    // Construct the URL with query parameters for a GET request
    final Uri uri = Uri.parse(
      '${Constant.apiEndpoint}notice-history',
    ).replace(queryParameters: {'mobileNo': mobileNo});

    try {
      final res = await http.get(
        uri, 
        headers: {
          'deviceId': 'qwert',
          'deviceName': 'sm2233',
          'accessStatus': '1',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == true && data['info'] is List) {
          final List<dynamic> noticeList = data['info'];
          setState(() {
            entries = noticeList.map((e) => NoticeEntry.fromJson(e)).toList();
          });
        } else {
          setState(() {
            entries = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Exception: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7F3),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF1E2F97),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    AppLocalizations.of(context)?.notifications ?? 'Notifications',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1E2F97),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // List Content
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFB366),
                      ),
                    )
                  : entries.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)?.noNotificationsFound ?? "No notifications found.",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF1E2F97).withOpacity(0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return _buildNoticeCard(entries[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function for rich text
  List<TextSpan> _parseAndFormatText(String text) {
    if (text.isEmpty) return [const TextSpan(text: '')];
    String cleanText = text.replaceAll(r'\n', '\n');
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'\*(.*?)\*');
    int lastMatchEnd = 0;
    final matches = exp.allMatches(cleanText).toList();

    if (matches.isEmpty) {
      return [TextSpan(text: cleanText)];
    }

    for (RegExpMatch match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: cleanText.substring(lastMatchEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1) ?? '',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: const Color(0xFF1E2F97)),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < cleanText.length) {
      spans.add(TextSpan(text: cleanText.substring(lastMatchEnd)));
    }

    return spans;
  }

  Widget _buildNoticeCard(NoticeEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE), // Light Orange Card Tint
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 3), // 3D Beveled Look
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D4A16).withOpacity(0.12), // 3D Shadow
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title.toUpperCase(),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.5,
                color: const Color(0xFFFFB366), // Vibrant Orange from OK button
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: _parseAndFormatText(entry.description),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.6,
                  color: const Color(0xFF1E2F97).withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoticeEntry {
  final String title;
  final String description;

  NoticeEntry({required this.title, required this.description});

  factory NoticeEntry.fromJson(Map<String, dynamic> json) {
    return NoticeEntry(
      title: json['title'] ?? 'No Title',
      description: json['msg'] ?? 'No Description',
    );
  }
}
