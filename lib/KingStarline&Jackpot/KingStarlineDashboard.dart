import 'dart:convert';
import 'dart:developer';
import 'package:marquee/marquee.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:new_sara/Bids/KingStarlineResultHis/KingStarlineResultHis.dart';
import 'package:new_sara/KingStarline&Jackpot/KingStarlineOptionScreen.dart';
import 'package:new_sara/l10n/app_localizations.dart';

import '../components/KingJackpotBiddingClosedDialog.dart';
import '../ulits/Constents.dart';
import '../Helper/UserController.dart';

//// MAIN STARLINE DASHBOARD ANIMATION
Widget runningTitle(String text) {
  return SizedBox(
    height: 22,
    width: 180,
    child: Marquee(
      text: text,
      scrollAxis: Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.center,
      blankSpace: 40,
      velocity: 30,
      pauseAfterRound: Duration.zero,
      startPadding: 10,
      accelerationDuration: const Duration(seconds: 1),
      decelerationDuration: const Duration(milliseconds: 500),
      style: GoogleFonts.poppins(
        color: Color(0xFF1E2F97),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

///
///
///
/// ---- Data Model ----
class StarlineGame {
  final int id; // from gameId
  final String time; // from gameName (e.g., "09:30 PM")
  final String status; // from statusText
  final String result; // from result
  final bool isClosed; // !playStatus
  final String openTime; // from openTime
  final String closeTime; // from closeTime
  final String additionalInfo; // "Bid closed at <closeTime>" when closed

  StarlineGame({
    required this.id,
    required this.time,
    required this.status,
    required this.result,
    required this.isClosed,
    required this.openTime,
    required this.closeTime,
    this.additionalInfo = '',
  });

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' ||
          s == '1' ||
          s == 'open' ||
          s == 'active' ||
          s == 'running';
    }
    return false;
  }

  factory StarlineGame.fromJson(Map<String, dynamic> json) {
    final int gameId = () {
      final v = json['gameId'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }();

    final String gameName = (json['gameName'] ?? 'N/A').toString();
    final String result = (json['result'] ?? '****-*').toString();
    final String statusText = (json['statusText'] ?? 'Unknown').toString();
    final bool playStatus = _toBool(json['playStatus']); // true => open
    final String closeTime = (json['closeTime'] ?? '--:--').toString();
    final String openTime = (json['openTime'] ?? '--:--').toString();

    final bool closed = !playStatus;
    final String displayStatus = statusText.isEmpty
        ? (closed ? 'Closed' : 'Open')
        : statusText;
    // Note: Localization will be handled in the widget where context is available
    final String displayAdditionalInfo = closed
        ? 'Bid closed at $closeTime'
        : '';

    return StarlineGame(
      id: gameId,
      time: gameName,
      status: displayStatus,
      result: result,
      isClosed: closed,
      openTime: openTime,
      closeTime: closeTime,
      additionalInfo: displayAdditionalInfo,
    );
  }
}

/// ---- Screen ----
class KingStarlineDashboardScreen extends StatefulWidget {
  const KingStarlineDashboardScreen({super.key});

  @override
  State<KingStarlineDashboardScreen> createState() =>
      _KingStarlineDashboardScreenState();
}

class _KingStarlineDashboardScreenState
    extends State<KingStarlineDashboardScreen> {
  bool _notificationsEnabled = true;
  List<StarlineGame> _gameTimes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final GetStorage _storage = GetStorage();
  final UserController userController = Get.put(UserController());

  // Non-nullable registeredId (loaded from local storage)
  String _registeredId = '';

  @override
  void initState() {
    super.initState();
    _loadAuthData();
    _fetchGameList();
  }

  void _loadAuthData() {
    // Signup/Login par jo save kiya tha, wahi se seedha utha rahe hain
    final rid = _storage.read('registerId')?.toString() ?? '';
    _registeredId = rid;
    log(
      'RegisteredId loaded: ${_registeredId.isEmpty ? "(empty)" : _registeredId}',
    );
  }

  Map<String, String> _buildHeaders(
    String accessToken, {
    String? deviceId,
    String? deviceName,
    bool accountStatus = true,
  }) {
    final now = DateTime.now();
    return {
      'deviceId':
          deviceId ??
          (_storage.read('deviceId')?.toString() ?? 'unknown_device'),
      'deviceName':
          deviceName ??
          (_storage.read('deviceName')?.toString() ?? 'unknown_model'),
      'accessStatus': accountStatus ? '1' : '0',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
      // helpful for backend time reconciliation
      'x-client-time': now.toIso8601String(),
      'x-tz-offset-mins': now.timeZoneOffset.inMinutes.toString(),
      'x-tz-name': now.timeZoneName,
    };
  }

  Future<void> _fetchGameList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final String? accessToken = _storage.read('accessToken');
    final String? registerId = _storage.read('registerId');
    final bool accountStatus = (_storage.read('accountStatus') ?? true) == true;

      if (accessToken == null || accessToken.isEmpty) {
      log('Error: Access token not found. Cannot fetch Starline game list.');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = l10n?.accessTokenNotFound ?? 'Access token not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    if (registerId == null || registerId.isEmpty) {
      log('Error: Register ID not found. Cannot fetch Starline game list.');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = l10n?.registerIdNotFound ?? 'Register ID not found. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    final url = Uri.parse('${Constant.apiEndpoint}starline-game-list');
    final headers = _buildHeaders(accessToken, accountStatus: accountStatus);
    final body = jsonEncode({'registerId': registerId});

    try {
      final response = await http.post(url, headers: headers, body: body);

      log('Starline Game List API Status: ${response.statusCode}');
      log('Starline Game List API Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData =
            json.decode(response.body) as Map<String, dynamic>;

        if (responseData['status'] == true && responseData['info'] is List) {
          final List rawList = responseData['info'] as List;
          final games = rawList
              .map(
                (e) =>
                    StarlineGame.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList();

          // Sort by time if parseable (hh:mm a)
          final fmt = DateFormat('hh:mm a');
          games.sort((a, b) {
            DateTime? ta, tb;
            try {
              final pa = fmt.parse(a.time);
              ta = DateTime(1970, 1, 1, pa.hour, pa.minute);
            } catch (_) {}
            try {
              final pb = fmt.parse(b.time);
              tb = DateTime(1970, 1, 1, pb.hour, pb.minute);
            } catch (_) {}
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return ta.compareTo(tb);
          });

          if (!mounted) return;
          setState(() {
            _gameTimes = games;
            _isLoading = false;
          });
        } else {
          final l10n = AppLocalizations.of(context);
          final msg = (responseData['msg'] ?? (l10n?.failedToLoadGameData ?? 'Failed to load game data.'))
              .toString();
          log('Starline Game List API Error: $msg');
          if (!mounted) return;
          setState(() {
            _errorMessage = msg;
            _isLoading = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}\n${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      log('Exception during Starline Game List API call: $e');
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = l10n?.anErrorOccurred(e.toString()) ?? 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  void _onPlayTap(StarlineGame game) {
    log(
      'Play Game tapped => id=${game.id}, time=${game.time}, status=${game.status}, isClosed=${game.isClosed}',
    );

    if (game.isClosed) {
      showDialog(
        context: context,
        builder: (_) => KingJackpotBiddingClosedDialog(
          time: game.time,
          resultTime: game.openTime,
          bidLastTime: game.closeTime,
        ),
      );
      return;
    }

    // BEST PRACTICE: registeredId must be non-empty, warna navigate mat karo
    if (_registeredId.isEmpty) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.registerIdMissing ?? 'Register ID missing. Please log in again.'),
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KingStarlineOptionScreen(
          title: l10n?.kingStarline ?? 'King Starline',
          gameTime: game.time,
          starlineGameId: game.id, // session/game id
          paanaStatus: !game.isClosed, // open/close info
          registeredId: _registeredId, // non-null String
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: Colors.white),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 30),
              // Main Content Container
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Custom Header
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF5F5F5,
                                ), // second image jaisa look
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  // 🔹 BACK BUTTON (NO CHANGE)
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Colors.grey,
                                          width: 1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back,
                                        color: Colors.black,
                                        size: 20,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // 🔹 RUNNING TITLE (FIXED OVERFLOW)
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final l10n = AppLocalizations.of(context);
                                        return SizedBox(
                                          height: 22,
                                          child: Text(
                                            l10n?.mainStarlineDashboard ?? 'MAIN STARLINE DASHBOARD',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              color: Color(0xFF1E2F97),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );

                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // 🔹 WALLET CAPSULE (NO CHANGE)
                                  // Obx(
                                  //   () => userController.accountStatus.value
                                  //       ? Container(
                                  //           padding: const EdgeInsets.symmetric(
                                  //             horizontal: 16,
                                  //             vertical: 8,
                                  //           ),
                                  //           decoration: BoxDecoration(
                                  //             color: const Color(0xFF0B1223),
                                  //             borderRadius:
                                  //                 BorderRadius.circular(40),
                                  //           ),
                                  //           child: Row(
                                  //             children: [
                                  //               Image.asset(
                                  //                 "assets/images/ic_wallet.png",
                                  //                 width: 20,
                                  //                 height: 20,
                                  //                 color: Colors.white,
                                  //               ),
                                  //               const SizedBox(width: 8),
                                  //               Text(
                                  //                 "₹${userController.walletBalance.value}",
                                  //                 style: const TextStyle(
                                  //                   color: Colors.white,
                                  //                   fontWeight: FontWeight.w600,
                                  //                   fontSize: 14,
                                  //                 ),
                                  //               ),
                                  //             ],
                                  //           ),
                                  //         )
                                  //       : const SizedBox.shrink(),
                                  // ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 4),
                            // HISTORY AND NOTIFICATIONS CONTROLS BELOW TITLE
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  l10n?.kingStarline ?? 'Starline Dashboard',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E2F97),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => KingStarlineResultScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    "View History",
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
SizedBox(height: 4,),
                      Expanded(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5.0,
                              ),
                              child: Column(
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final l10n = AppLocalizations.of(context);
                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              _buildInfoCard(
                                                l10n?.singleDigit ?? 'Single Digit',
                                                '10-100',
                                              ),
                                              const SizedBox(width: 8),
                                              _buildInfoCard(
                                                l10n?.doublePana ?? 'Double Pana',
                                                '10-3200',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _buildInfoCard(
                                                l10n?.singlePana ?? 'Single Pana',
                                                '10-1600',
                                              ),
                                              const SizedBox(width: 8),
                                              _buildInfoCard(
                                                l10n?.triplePana ?? 'Triple Pana',
                                                '10-10000',
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (_isLoading)
                              const Expanded(
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFDB564),
                                  ),
                                ),
                              )
                            else if (_errorMessage.isNotEmpty)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    _errorMessage,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFFDB564),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: Container(
                                  color: Colors.white,
                                  child: GridView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 1.15,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemCount: _gameTimes.length,
                                    itemBuilder: (_, i) {
                                      final g = _gameTimes[i];
                                      return _buildGameTimeGridItem(game: g);
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFCF7F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2F97),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFE08122),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTimeGridItem({required StarlineGame game}) {
    final bool isClosed = game.isClosed;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFCF7F3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          // 1. Status Text
          Builder(builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Text(
              isClosed
                  ? (l10n?.closedForToday ?? "Betting is Closed for Today")
                  : (l10n?.bettingIsRunning ?? "Betting is Running Now"),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            );
          }),
          const SizedBox(height: 4),
          // 2. Middle Row
          Row(
            children: [
              // 🔹 CUSTOM BLACK-FACED WATCH
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1D2232),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(Icons.access_time, color: Colors.white, size: 38),
                ],
              ),
              const SizedBox(width: 8),
              // Time and Result
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.time,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFDB564),
                      ),
                    ),
                    FittedBox(
                      child: Text(
                        game.result.trim().isEmpty ? "***-*" : game.result.trim(),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFDB564),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // 3. Play Button
          GestureDetector(
            onTap: () => _onPlayTap(game),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isClosed ? Colors.grey.shade600 : const Color(0xFFFFB366),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: (isClosed ? Colors.grey : const Color(0xFFFFB366)).withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isClosed) ...[
                    const Icon(Icons.sports_esports, color: Color(0xFF1E2F97), size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    isClosed ? "CLOSED" : "Play Game",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isClosed ? Colors.white : const Color(0xFF1E2F97),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

