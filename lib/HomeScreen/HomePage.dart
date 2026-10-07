// File: lib/HomePage.dart
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:marquee/marquee.dart';
import 'package:new_sara/Fund/AddFundScreen.dart';
import 'package:new_sara/Fund/WithdrawScreen.dart';
import 'package:new_sara/Navigation/FundsFragmentContainer.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Helper/UserController.dart';
import '../KingStarline&Jackpot/KingJackpotDashboard.dart';
import '../KingStarline&Jackpot/KingStarlineDashboard.dart';
import '../Support/ChatSupport/ChatScreenNew.dart';
import '../components/closeBidDialogue.dart';
import '../game/GameScreen.dart';
import '../ulits/Constents.dart';
import 'package:new_sara/l10n/app_localizations.dart';
import 'package:new_sara/Helper/LocaleHelper.dart';
import '../Helper/Toast.dart';
import 'CricketQuizWidget.dart';

/// HomePage — merged final UI (gradient, marquee, pills, big card list)

class HomeData {
  final bool status;
  final String msg;
  final List<Info>? result;

  HomeData({required this.status, required this.msg, this.result});

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
    status: _b(json["status"]),
    msg: json["msg"]?.toString() ?? '',
    result: json["info"] == null
        ? []
        : List<Info>.from(
            (json["info"] as List).map(
              (x) => Info.fromJson(x as Map<String, dynamic>),
            ),
          ),
  );
}

class Info {
  final int gameId;
  final String gameName;
  final String gameNameHindi;
  final String openTime;
  final String closeTime;
  final String result;
  final String statusText;
  final bool openSessionStatus;
  final bool closeSessionStatus;

  Info({
    required this.gameId,
    required this.gameName,
    this.gameNameHindi = '',
    required this.openTime,
    required this.closeTime,
    required this.result,
    required this.statusText,
    required this.openSessionStatus,
    required this.closeSessionStatus,
  });

  factory Info.fromJson(Map<String, dynamic> json) => Info(
    gameId: int.tryParse(json["gameId"].toString()) ?? 0,
    gameName: json["gameName"]?.toString() ?? '',
    gameNameHindi:
        json["gameNameHindi"]?.toString() ??
        json["game_name_hindi"]?.toString() ??
        '',
    openTime: json["openTime"]?.toString() ?? '',
    closeTime: json["closeTime"]?.toString() ?? '',
    result: json["result"]?.toString() ?? '',
    statusText: json["statusText"]?.toString() ?? '',
    openSessionStatus: _b(json["openSessionStatus"]),
    closeSessionStatus: _b(json["closeSessionStatus"]),
  );
}

bool _b(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes' || s == 'y';
  }
  return false;
}

class ContactDetails {
  final String? mobileNo;
  final String? whatsappNo;
  final String? homepageContent;

  ContactDetails({this.mobileNo, this.whatsappNo, this.homepageContent});
}

HomeData homeDataFromJson(String str) =>
    HomeData.fromJson(json.decode(str) as Map<String, dynamic>);

// ---------------- HomePage ----------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomeData> _futureHomeData;
  late Future<ContactDetails?> _futureContactDetails;
  final GetStorage _storage = GetStorage();

  late final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController(), permanent: true);

  late String _preferredLanguage;

  // Helper function to translate game names based on locale
  String _translateGameName(
    String gameName,
    String gameNameHindi,
    BuildContext context,
  ) {
    final langCode = LocaleHelper.getLanguageCode();

    // Use Hindi name if available and language is Hindi
    if (langCode == 'hi' && gameNameHindi.isNotEmpty) {
      return gameNameHindi;
    }

    // For other Indian languages, you can add more mappings here
    // For now, return original English name
    return gameName;
  }

  @override
  void initState() {
    super.initState();
    _preferredLanguage = _storage.read('selectedLanguage') ?? 'en';
    _futureHomeData = _fetchDashboardData();
    _futureContactDetails = fetchContactDetail();

    // react to auth/token changes
    everAll([userController.accessToken, userController.registerId], (_) {
      setState(() {
        _futureHomeData = _fetchDashboardData();
        _futureContactDetails = fetchContactDetail();
      });
    });
    userController.fetchSocialLinks();
  }

  // Removed _preTranslateUI and _t as we'll use AppLocalizations directly

  Future<HomeData> _fetchDashboardData() async {
    final token = _storage.read('accessToken') ?? '';
    final regId = _storage.read('registerId') ?? '';

    if (token.isEmpty || regId.isEmpty) {
      log("Missing token/regId — returning empty HomeData");
      return HomeData(status: false, msg: "Not logged", result: []);
    }

    final response = await http.post(
      Uri.parse("${Constant.apiEndpoint}game-list"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: json.encode({"registerId": regId}),
    );

    if (response.statusCode == 200) {
      try {
        return homeDataFromJson(response.body);
      } catch (e, st) {
        log("Parse error: $e", stackTrace: st);
        return HomeData(status: false, msg: "Parse error", result: []);
      }
    } else {
      log("game-list failed: ${response.statusCode} ${response.body}");
      return HomeData(status: false, msg: "Failed", result: []);
    }
  }

  Future<ContactDetails?> fetchContactDetail() async {
    try {
      final response = await http.get(
        Uri.parse("${Constant.apiEndpoint}contact-detail"),
        headers: {
          "Authorization": "Bearer ${_storage.read('accessToken') ?? ''}",
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final contactInfo =
            (data['info'] as Map?)?['contactInfo'] as Map<String, dynamic>?;
        return ContactDetails(
          mobileNo: contactInfo?['mobileNo']?.toString(),
          whatsappNo: contactInfo?['whatsappNo']?.toString(),
          homepageContent: contactInfo?['homepageContent']?.toString(),
        );
      }
    } catch (e) {
      log("contact-detail error: $e");
    }
    return null;
  }

  Future<void> _handleRefresh() async {
    try {
      await userController.refreshEverything();
      setState(() {
        _futureHomeData = _fetchDashboardData();
        _futureContactDetails = fetchContactDetail();
      });
    } catch (e) {
      log("refresh error: $e");
    }
  }

  // Open/Call helpers (used by contact pills)
  Future<void> _openWhatsApp(String raw) async {
    var p = raw.replaceAll(RegExp(r'[^0-9]'), '');
    p = p.replaceFirst(RegExp(r'^0+'), '');
    if (p.length == 10) p = '91$p';
    final uri = Uri.parse('https://wa.me/$p');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // FULL PAGE TOP -> BOTTOM GRADIENT
        decoration: const BoxDecoration(color: Colors.white), // Main background now white
        child: RefreshIndicator(
            color: const Color(0xFFFDB564),
            onRefresh: _handleRefresh,
            child: FutureBuilder<HomeData>(
              future: _futureHomeData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFDB564)),
                  );
                }
                if (snapshot.hasError) {
                  log("Future error: ${snapshot.error}");
                  final l10n = AppLocalizations.of(context);
                  return Center(
                    child: Text(
                      l10n?.errorLoadingData ?? "Error loading data.",
                      style: const TextStyle(color: Color(0xFFFDB564)),
                    ),
                  );
                }
                final results = snapshot.data?.result ?? [];
                if (results.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    children: [

                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context);
                          return Center(
                            child: Text(
                              l10n?.noGameDataAvailable ??
                                  "No game data available.",
                              style: const TextStyle(color: Colors.black54),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(top: 0, bottom: 2),
                  children: [


                    // ———————— UNIFIED ACTION CARD (Games + Funds) ————————
                    Obx(
                      () => userController.accountStatus.value
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED), // Light peach accent
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Brand and Telegram section
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(30),
                                                border: Border.all(color: Colors.grey.shade200, width: 1.0),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.03),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.report_gmailerrorred_rounded, color: Colors.red, size: 16),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      "DpBoss name is a brand",
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF1E2F97),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => _showSupportDialog(context),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(30),
                                                  border: Border.all(color: Colors.grey.shade200, width: 1.0),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.03),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Image.asset(
                                                      "assets/images/whatsapp.png",
                                                      width: 16,
                                                      height: 16,
                                                      color: const Color(0xFF25D366),
                                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.send, color: Colors.green, size: 16),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        "Telegram",
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: const Color(0xFF1E2F97),
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Promotional Card
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB366),
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 5,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            const Icon(Icons.redeem, size: 36, color: Color(0xFF1E2F97)),
                                            const SizedBox(height: 8),
                                            Text(
                                              "Let's Start Playing Now",
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF1E2F97),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Choose your favourite game",
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF1E2F97),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Active Row (DpBoss Starline & Add Funds)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: ZoomingWidget(
                                              child: Builder(builder: (context) {
                                                return _categoryButtonUnified(
                                                  title: "DpBoss Starline",
                                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KingStarlineDashboardScreen())),
                                                );
                                              }),
                                            ),
                                          ),
                                          Expanded(
                                            child: ZoomingWidget(
                                              child: Builder(builder: (context) {
                                                return _categoryButtonUnified(
                                                  title: "₹ Add Funds",
                                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddFundScreen())),
                                                );
                                              }),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    /* --- Commented as per request ---
                                    // 1. Unified Category Row (Starline & Jackpot) - Stuck to top
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(30),
                                          topRight: Radius.circular(30),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: ZoomingWidget(
                                              child: Builder(builder: (context) {
                                                final l10n = AppLocalizations.of(context);
                                                return _categoryButtonUnified(
                                                  title: l10n?.kingStarline ?? "KING STARLINE",
                                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KingStarlineDashboardScreen())),
                                                );
                                              }),
                                            ),
                                          ),
                                          Expanded(
                                            child: ZoomingWidget(
                                              child: Builder(builder: (context) {
                                                final l10n = AppLocalizations.of(context);
                                                return _categoryButtonUnified(
                                                  title: l10n?.kingJackpot ?? "KING JACKPOT",
                                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KingJackpotDashboard())),
                                                );
                                              }),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 2. Main Padding for content below
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Column(
                                        children: [
                                          // Fund Action Row (Magenta Bar)
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Builder(builder: (context) {
                                                  final l10n = AppLocalizations.of(context);
                                                  return _fundActionButtonUnified(
                                                    icon: Icons.currency_rupee,
                                                    title: l10n?.addMoney ?? "ADD MONEY",
                                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundsFragmentContainer())),
                                                  );
                                                }),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Builder(builder: (context) {
                                                  final l10n = AppLocalizations.of(context);
                                                  return _fundActionButtonUnified(
                                                    icon: Icons.account_balance,
                                                    title: l10n?.withdrawFunds ?? "WITHDRAW",
                                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WithdrawScreen())),
                                                  );
                                                }),
                                              ),
                                            ],
                                          ),

                                        ],
                                      ),
                                    ),
                                    ---------------------------------- */
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // ------- BIG CARD vs QUIZ -------
                    Obx(
                      () => userController.accountStatus.value
                          ? Container(
                              margin: const EdgeInsets.only(top: 15),
                              padding: const EdgeInsets.only(top: 10, bottom: 8),
                              decoration: const BoxDecoration(
                                color: Colors.white, // Section background white
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(35),
                                  topRight: Radius.circular(35),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Section Header for Games
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(width: 4, height: 20, color: const Color(0xFF1E2F97)),
                                        const SizedBox(width: 10),
                                        const Text(
                                          "ALL MARKET GAMES",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1E2F97),
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                    _buildBigGameCard(results),
                                  ],
                                ),
                              ).animateIn(delay: 200) // Animation for section
                          : const CricketQuizWidget(),
                    ),

                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
      ),
    );
  }

  // ---------------- Widgets ----------------

  Widget _categoryButtonUnified({
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB366),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Support Dialog ----------------
  Future<void> _launchTelegram() async {
    print('🚀 [Telegram] Button Clicked on HomePage - Starting API call...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0088CC)),
          ),
        );
      },
    );

    try {
      final String apiUrl = '${Constant.apiEndpoint}social-links';
      log('=== Telegram API URL ===: $apiUrl');
      print('=== Telegram API URL ===: $apiUrl');

      final response = await http.get(Uri.parse(apiUrl));

      print('✅ [Telegram] Request URL: $apiUrl');
      print('📦 [Telegram] Response Status: ${response.statusCode}');
      print('📦 [Telegram] Response Body: ${response.body}');

      if (mounted) {
        Navigator.pop(context); // Dismiss the loading dialog
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['info'] != null) {
          String? telUrl;
          final List infoList = data['info'];

          for (var item in infoList) {
            final String title = item['title']?.toString().toLowerCase() ?? '';
            if (title.contains('telegram')) {
              telUrl = item['url'];
              break;
            }
          }

          if (telUrl == null && infoList.isNotEmpty) {
            telUrl = infoList.first['url'];
          }

          if (telUrl != null && telUrl.toString().trim().isNotEmpty) {
            final String finalUrl = telUrl.toString().trim();
            log('=== Final Telegram Launch URL ===: $finalUrl');
            print('=== Final Telegram Launch URL ===: $finalUrl');
            final uri = Uri.parse(finalUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return;
            }
          }
          popToast("Telegram link not available", 3, Colors.white, Colors.red);
        } else {
          popToast(data['msg'] ?? "Failed to fetch link", 3, Colors.white, Colors.red);
        }
      } else {
        popToast("Server error: ${response.statusCode}", 3, Colors.white, Colors.red);
      }
    } catch (e, st) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog on error
      }
      log("Telegram API error: $e", stackTrace: st);
      popToast("Something went wrong", 3, Colors.white, Colors.red);
    }
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<ContactDetails?>(
          future: _futureContactDetails,
          builder: (context, snapshot) {
            final details = snapshot.data;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCF7F3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFB366),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Spacer(),
                          Text(
                            "Select One",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E2F97),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Options List
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          _buildDialogOption(
                            icon: Icons.phone_forwarded_rounded,
                            iconColor: const Color(0xFF25D366),
                            title: "Call",
                            onTap: () async {
                              final phone = details?.mobileNo ?? "";
                              final uri = Uri.parse("tel:$phone");
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildDialogOption(
                            icon: Icons.chat_bubble_rounded,
                            iconColor: const Color(0xFF25D366),
                            title: "Whatsapp",
                            onTap: () {
                              if (details?.whatsappNo != null) {
                                _openWhatsApp(details!.whatsappNo!);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Obx(() => _buildDialogOption(
                            icon: Icons.send_rounded,
                            iconColor: const Color(0xFF0088CC),
                            title: "Telegram",
                            iconUrl: userController.telegramIcon.value,
                            onTap: () async {
                              Navigator.pop(context);
                              _launchTelegram();
                            },
                          )),
                          const SizedBox(height: 12),
                          _buildDialogOption(
                            icon: Icons.headset_mic_rounded,
                            iconColor: const Color(0xFF1E2F97),
                            title: "Chat Support",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreenNew()));
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    String? iconUrl,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8D4A16).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: iconUrl != null && iconUrl.isNotEmpty
                  ? (iconUrl.endsWith('.svg') 
                      ? SvgPicture.network(iconUrl, width: 22, height: 22, color: iconColor)
                      : Image.network(iconUrl, width: 22, height: 22, errorBuilder: (_,__,___) => Icon(icon, color: iconColor, size: 22)))
                  : Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E2F97),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fundActionButtonUnified({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB366),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.black),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getStatusIcon(String status) {
    status = status.toLowerCase();

    if (status.contains("open for today")) {
      return "assets/images/open_icon.png";
    }
    if (status.contains("closed for today")) {
      return "assets/images/closed_icon.png";
    }
    if (status.contains("holiday for today")) {
      return "assets/images/holiday_icon.png";
    }

    return "assets/images/closed_icon.png"; // default
  }

  Widget _whatsappContactPillSeparate(String number) {
    return GestureDetector(
      onTap: () => _openWhatsApp(number),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/whatsapp.png",
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                number,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF25D366),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactPill({
    required String icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Image.asset(
              icon,
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.phone, color: Colors.green),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getPlayIcon(String status) {
    status = status.toLowerCase();

    if (status.contains("open for today")) {
      return "assets/images/play3.png"; // आपकी open image
    } else if (status.contains("closed for today")) {
      return "assets/images/play6.png"; // आपकी open image
    } else if (status.contains("holiday for today")) {
      return "assets/images/play4.png"; // आपकी closed image
    }
    return "assets/images/play4.png"; // आपकी closed image
  }

  Widget _buildBigGameCard(List<Info> results) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.0 : 0.85, // Adjust this as needed for smaller/larger screens
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final game = results[index];
        final bool isClosed = game.statusText.toLowerCase().contains("closed") || 
                             game.statusText.toLowerCase().contains("holiday");

        return FadeInUp(
          delay: (index % 6) * 100,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EE), // Final Light Orange Card Background
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8D4A16).withOpacity(0.12),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                /// 1. GAME NAME & CLOCK ICON
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        _translateGameName(
                          game.gameName,
                          game.gameNameHindi,
                          context,
                        ).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFFFFB366), // Vibrant Orange from Image 2
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1E2F97), width: 1.5),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.access_time, // Clock outline icon
                        color: Color(0xFF1E2F97), // Dark blue from image2
                        size: 14,
                      ),
                    ),
                  ],
                ),

                /// 2. RESULT
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    game.result.isEmpty ? "***-**-***" : game.result,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4C66C3), // Blue from result in image2
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                /// 3. BID TIMES
                Text(
                  "Bet -${game.openTime} - ${game.closeTime}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),

                /// 4. STATUS
                Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    String statusText = game.statusText;
                    if (statusText.toLowerCase().contains("closed")) {
                      statusText = l10n?.closedForToday ?? "Bet Closed for Today";
                    } else if (statusText.toLowerCase().contains("open")) {
                      statusText = l10n?.bettingIsRunning ?? "Betting is Running";
                    } else if (statusText.toLowerCase().contains("holiday")) {
                      statusText = "Holiday for Today";
                    }

                    return Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !isClosed ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F), // Red if closed
                      ),
                    );
                  },
                ),

                /// 5. PLAY GAME BUTTON
                GestureDetector(
                  onTap: () {
                    if (isClosed) {
                      closeBidDialogue(
                        context: context,
                        gameName: game.gameName,
                        openResultTime: game.openTime,
                        openBidLastTime: game.openTime,
                        closeResultTime: game.closeTime,
                        closeBidLastTime: game.closeTime,
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GameMenuScreen(
                            title: game.gameName,
                            gameId: game.gameId,
                            openSessionStatus: game.openSessionStatus,
                            closeSessionStatus: game.closeSessionStatus,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB366), // Vibrant Orange matching image 2
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB366).withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.sports_esports, // Gamepad icon
                          color: Color(0xFF1E2F97), // Dark blue icon
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Play Game",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E2F97), // Dark blue text
                          ),
                        ),
                      ],
                    ),

                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension WidgetAnimation on Widget {
  Widget animateIn({int delay = 0}) => FadeInUp(delay: delay, child: this);
}

// ———————— HELPER ANIMATION WIDGETS ————————
class FadeInUp extends StatefulWidget {
  final Widget child;
  final int delay;
  const FadeInUp({super.key, required this.child, this.delay = 0});

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _offset = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
} // End of HomePage class extension or helper section

// ———————— HELPER ANIMATION WIDGET ————————
class ZoomingWidget extends StatefulWidget {
  final Widget child;
  const ZoomingWidget({super.key, required this.child});

  @override
  State<ZoomingWidget> createState() => _ZoomingWidgetState();
}

class _ZoomingWidgetState extends State<ZoomingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
