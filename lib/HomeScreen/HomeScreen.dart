// File: lib/HomeScreen.dart
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:new_sara/components/AppNameBold.dart';
import 'package:new_sara/l10n/app_localizations.dart';
import 'package:new_sara/ulits/wallet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Bids/MyBidsPage.dart';
import '../ChartScreen/ChartScreen.dart';
import '../Helper/Toast.dart';
import '../Helper/UserController.dart';
import '../login/LoginWithMpinScreen.dart';
import '../Navigation/FundsFragmentContainer.dart';
import '../Fund/AddFundScreen.dart';
import '../Notice/WithdrawInfoScreen.dart';
import '../Notification/NotificationScreen.dart';
import '../Passbook/PassbookPage.dart';
import '../SetMPIN/SetNewPinScreen.dart';
import '../SettingsScreen/SettingsScreen.dart';
import '../Support/ChatSupport/ChatSupport.dart';
import '../Support/ChatSupport/ChatScreenNew.dart';
import '../Support/SupportPage.dart';
import '../Video/LanguageSelectionScreen.dart';
import '../components/AppName.dart';
import '../game/gameRates/GameRateScreen.dart';
import '../ulits/ColorsR.dart';
import '../ulits/Constents.dart';
import 'HomePage.dart';

// for ui changes  //
double sw(BuildContext c) => MediaQuery.of(c).size.width;
double sh(BuildContext c) => MediaQuery.of(c).size.height;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final UserController userController = Get.isRegistered<UserController>()
      ? Get.find<UserController>()
      : Get.put(UserController(), permanent: true);

  final GetStorage storage = GetStorage();
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    log('HomeScreen sees UserController hash: ${userController.hashCode}');
    _bootstrapLoad();
    storage.write('isLoggedIn', true);
    userController.startLivePolling(interval: const Duration(seconds: 6));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    userController.stopLivePolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      userController.fetchAndUpdateUserDetails();
    }
  }

  Future<void> _bootstrapLoad() async {
    try {
      await userController.fetchAndUpdateUserDetails();
      await Future.wait([
        userController.fetchAndUpdateFeeSettings(),
        userController.fetchAndUpdateContactDetails(),
        userController.fetchPaymentDetails(),
      ]);
    } catch (e, st) {
      log('Warm-up error: $e', stackTrace: st);
    }
  }

  String _normalizePhone(String raw, {String defaultCountryCode = '91'}) {
    var p = raw.replaceAll(RegExp(r'[^0-9]'), '');
    p = p.replaceFirst(RegExp(r'^0+'), '');
    if (p.length == 10) p = '$defaultCountryCode$p';
    return p;
  }

  String? _getSupportNumber() {
    final w = userController.contactWhatsappNo.value.trim();
    if (w.isNotEmpty) return w;
    final c = userController.contactMobileNo.value.trim();
    if (c.isNotEmpty) return c;
    final s = (storage.read('whatsappNo') ?? '').toString().trim();
    if (s.isNotEmpty) return s;
    final u = userController.mobileNo.value.trim();
    if (u.isNotEmpty) return u;
    return null;
  }

  Future<void> launchWhatsAppChat({String? message}) async {
    try {
      final raw = _getSupportNumber();
      if (raw == null) {
        final l10n = AppLocalizations.of(context);
        popToast(
          l10n?.whatsappNumberNotAvailable ?? "WhatsApp number not available",
          4,
          Colors.white,
          ColorsR.appColorRed,
        );
        log("❌ WhatsApp number missing (all sources empty)");
        return;
      }

      final phone = _normalizePhone(raw);
      final encoded = (message ?? '').trim().isEmpty
          ? ''
          : Uri.encodeComponent(message!.trim());

      final nativeUri = Uri.parse(
        'whatsapp://send?phone=$phone${encoded.isNotEmpty ? '&text=$encoded' : ''}',
      );
      if (await canLaunchUrl(nativeUri)) {
        final ok = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );
        log(
          ok ? '✅ Launched WhatsApp (native): $nativeUri' : '❌ Failed (native)',
        );
        if (ok) return;
      }

      final webUri = Uri.parse(
        'https://wa.me/$phone${encoded.isNotEmpty ? '?text=$encoded' : ''}',
      );
      if (await canLaunchUrl(webUri)) {
        final ok = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        log(ok ? '✅ Launched WhatsApp (web): $webUri' : '❌ Failed (web)');
        if (ok) return;
      }

      final l10n1 = AppLocalizations.of(context);
      popToast(
        l10n1?.couldNotOpenWhatsapp ?? "Could not launch WhatsApp",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    } catch (e, st) {
      log('❌ WhatsApp launch error: $e', stackTrace: st);
      final l10n2 = AppLocalizations.of(context);
      popToast(
        l10n2?.errorLaunchingWhatsapp ?? "Error launching WhatsApp",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    }
  }

  final List<Widget> _screens = [
    BidScreen(),
    PassbookPage(),
    HomePage(),
    const AddFundScreen(),
    SupportPage(),
    WithdrawInfoScreen(),
    SettingsScreen(),
    GameRateScreen(),
    ChatScreenNew(),
  ];

  void _onItemTapped(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _selectedIndex = index);
    } else {
      log("Error: Attempted to select invalid index: $index");
    }
  }

  void _navigateToNewScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _navigateToDrawerScreenAndPush(Widget screen) {
    Navigator.pop(context);
    _navigateToNewScreen(screen);
  }

  Widget _buildBodyHeader() {
    // Hide header when on Funds screen (index 3) or Bid screen (index 0)
    if (_selectedIndex == 3 || _selectedIndex == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Premium peach gradient background requested by the user, slightly darker now
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFB74D), // Darker Peach/Orange
            Color(0xFFFFCD91), // Peach
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // APP NAME SECTION (Menu + Launcher Logo)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.menu_rounded, 
                      color: Colors.black87, // High contrast against peach
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Using dpboss image as requested
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Image.asset(
                  "assets/images/dpboss.png",
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // WALLET (Styled for Pink Background)
              WalletBalancePill(
                accountStatus: userController.accountStatus,
                walletBalance: userController.walletBalance,
                horizontalPadding: 16,
                verticalPadding: 8,
              ),
              const SizedBox(width: 10),
              // NOTIFICATION (White style)
              Obx(
                () => userController.accountStatus.value
                    ? GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NoticeHistoryScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade200, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications_active_outlined,
                            color: Color(0xFF1E2F97), // Dark Navy
                            size: 22,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Drawer(
      backgroundColor: const Color(0xFFFCF7F3), // Off-white cream
      child: SafeArea(
        child: Column(
          children: [
            // PROFILE SECTION (3D Card Style)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EE), // Light Orange Tint
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 3), // 3D White Bevel
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8D4A16).withOpacity(0.12), // 3D Shadow
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECCC), // Lighter orange
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFB366), width: 1.5),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: Color(0xFFFFB366),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(
                          () => Text(
                            userController.fullName.value,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E2F97),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Obx(
                          () => Text(
                            userController.mobileNoEnc.value,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B6358),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFB366), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF1E2F97),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Obx(
                () => ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    _buildDrawerItem(
                      "assets/images/home_nav.png",
                      l10n?.home ?? "Home",
                      () {
                        Navigator.pop(context);
                        _onItemTapped(2);
                      },
                      true,
                    ),
                    _buildDrawerItem(
                      "assets/images/bid_nav.png",
                      l10n?.myBids ?? "My Bids",
                      () {
                        Navigator.pop(context);
                        _onItemTapped(0);
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/mpin_nav.png",
                      l10n?.mpin ?? "M-PIN",
                      () {
                        Navigator.pop(context);
                        _handleMpin();
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/passbook.png",
                      l10n?.passbook ?? "Passbook",
                      () =>
                          _navigateToDrawerScreenAndPush(const PassbookPage()),
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/funds_nav.png",
                      l10n?.funds ?? "Funds",
                      () {
                        Navigator.pop(context);
                        _onItemTapped(3);
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/videos.png",
                      l10n?.videos ?? "Videos",
                      () => _navigateToDrawerScreenAndPush(
                        const LanguageSelectionScreen(),
                      ),
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/rate_stars.png",
                      l10n?.gameRates ?? "Game Rates",
                      () {
                        Navigator.pop(context);
                        _onItemTapped(7);
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/charts.png",
                      l10n?.charts ?? "Charts",
                      () => _navigateToDrawerScreenAndPush(const ChartScreen()),
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/setting_nav.png",
                      l10n?.settings ?? "Settings",
                      () {
                        Navigator.pop(context);
                        _onItemTapped(6);
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/share.png",
                      l10n?.shareApplication ?? "Share Application",
                      () {
                        Navigator.pop(context);
                        Share.share(
                          "I'm loving Db Boss App\n\nDownload now:\nhttps://dpbossatta.com/",
                          subject: "Check out the Db Boss App!",
                        );
                      },
                      userController.accountStatus.value,
                    ),
                    _buildDrawerItem(
                      "assets/images/power.png",
                      l10n?.logout ?? "Logout",
                      () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginWithMpinScreen(),
                          ),
                        );
                      },
                      true,
                    ),
                    const SizedBox(height: 20), // Padding at bottom
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    String imagePath,
    String title,
    VoidCallback onTap,
    bool visible,
  ) {
    if (!visible) return const SizedBox.shrink();

    final isHome = title.toLowerCase().contains("home");
    final iconBgColor = isHome ? const Color(0xFFE8EEFC) : const Color(0xFFFFECCC);
    final iconBorderColor = isHome ? const Color(0xFF1E2F97) : const Color(0xFFFFB366);
    final iconColor = isHome ? const Color(0xFF1E2F97) : const Color(0xFFFFB366);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EE), // Light orange/cream
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 3), // 3D White Bevel
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8D4A16).withOpacity(0.08), // Softer shadow for list items
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
                border: Border.all(color: iconBorderColor, width: 1.5),
              ),
              child: Center(
                child: Image.asset(
                  imagePath,
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: const Color(0xFF6B6358),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMpin() async {
    final String mobile = userController.mobileNo.value;
    if (mobile.isEmpty) {
      log("Mobile number is not available.");
      final l10n = AppLocalizations.of(context);
      popToast(
        l10n?.mobileNumberNotAvailable ?? "Mobile number is not available",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SetNewPinScreen(mobile: mobile)),
    );
  }

  Widget _buildBottomAppBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Obx(() {
      final accountStatus = userController.accountStatus.value;
      return SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 70,

              decoration: const BoxDecoration(
                color: Color(0xFFFDB564), // Orange background as per user request
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          "assets/images/bid_nav.png",
                          l10n?.myBids ?? "My Bids",
                          0,
                          visible: accountStatus,
                        ),
                        _buildNavItem(
                          "assets/images/passbook.png",
                          l10n?.passbook ?? "Passbook",
                          1,
                          visible: accountStatus,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.20),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(
                          "assets/images/funds.png",
                          l10n?.funds ?? "Funds",
                          3,
                          visible: accountStatus,
                        ),
                        _buildNavItem(
                          "assets/images/chat_icon.png",
                          l10n?.chat ?? "Chat",
                          8,
                          visible: accountStatus,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              child: GestureDetector(
                onTap: () => _onItemTapped(2),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E2F97), // Dark Navy
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      "assets/images/home1.png",
                      width: 32, // 🔽 icon size control
                      height: 32, // 🔽 icon size control
                      fit: BoxFit.contain,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNavItem(
    String iconPath,
    String label,
    int index, {
    bool visible = true,
  }) {
    if (!visible) return const SizedBox.shrink();
    final isSelected = _selectedIndex == index;
    final color = isSelected ? const Color(0xFF1E2F97) : const Color(0xFF1E2F97).withOpacity(0.6);

    return GestureDetector(
      onTap: () {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PassbookPage()),
          );
        } else if (index == 8) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreenNew()),
          );
        } else {
          _onItemTapped(index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(iconPath, width: 26, height: 26, color: color),
          const SizedBox(height: 4),
          SizedBox(
            width: 50, // 👈 width control (important)
            child: Text(
              label,
              maxLines: 1, // 👈 ek hi line
              overflow: TextOverflow.ellipsis, // 👈 dot dot
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchTelegram() async {
    print('🚀 [Telegram] Button Clicked on HomeScreen - Starting API call...');
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

  void _showSupportBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Support Options",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E2F97),
                ),
              ),
              const SizedBox(height: 24),
              
              // Chat with Admin Option
              _buildSupportTile(
                icon: Icons.chat_bubble_rounded,
                title: "Chat with Admin",
                subtitle: "Direct messaging with our team",
                iconColor: const Color(0xFFFDB564),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreenNew()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Telegram Support Option
              _buildSupportTile(
                icon: Icons.send_rounded,
                title: "Telegram Support",
                subtitle: "Join our official telegram channel",
                iconColor: const Color(0xFF0088CC),
                onTap: () {
                  Navigator.pop(context);
                  _launchTelegram();
                },
              ),
              
              const SizedBox(height: 16),
              
              // WhatsApp Support Option (Existing)
              _buildSupportTile(
                icon: Icons.chat_rounded,
                title: "WhatsApp Support",
                subtitle: "Chat with us on WhatsApp",
                iconColor: const Color(0xFF25D366),
                onTap: () {
                  Navigator.pop(context);
                  launchWhatsAppChat();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: iconColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuitDialog() async {
    final l10n = AppLocalizations.of(context);
    final shouldQuit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Orange Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDB564),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    dialogL10n?.quit ?? 'Quit',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Large orange icon (person running/exiting)
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDB564).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.exit_to_app,
                          size: 50,
                          color: Color(0xFFFDB564),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Question text
                      Text(
                        dialogL10n?.areYouSureYouWantToQuitTheApp ??
                            'Are you sure you want to quit the app?',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // No button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDB564),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                dialogL10n?.no ?? 'No',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Yes button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDB564),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                dialogL10n?.yes ?? 'Yes',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldQuit == true) {
      // Exit the app using SystemNavigator
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 2) {
          _onItemTapped(2);
          return false;
        }
        // Show quit dialog when on HomePage
        _showQuitDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white, // Changed to white as per user request
        resizeToAvoidBottomInset: false,
        drawer: _buildDrawer(context),
        // appBar: _buildAppBar(context),
        body: Container(
          decoration: const BoxDecoration(color: Colors.white),

          child: SafeArea(
            top: false,

            child: Column(
              children: [
                _buildBodyHeader(),

                Expanded(
                  child:
                      (_selectedIndex >= 0 && _selectedIndex < _screens.length)
                      ? _screens[_selectedIndex]
                      : Center(
                          child: Text(
                            l10n?.screenNotFound ?? "Error: Screen not found",
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(child: _buildBottomAppBar(context)),
      ),
    );
  }
}
