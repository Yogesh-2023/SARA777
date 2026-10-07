import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:new_sara/Bids/BidHistory/BidHistoryScreen.dart';
import 'package:new_sara/Bids/KingJackpotBidHis/KingJackpotHistoryScreen.dart';
import 'package:new_sara/Bids/KingJackpotResultHis/KingJackpotResultScreen.dart';
import 'package:new_sara/Bids/KingStartlineBidHis/KingStarlineBidHistoryScreen.dart';
import 'package:new_sara/game/GameResults/GameResultScreen.dart';
import 'package:new_sara/l10n/app_localizations.dart';
import '../Helper/UserController.dart';
import 'KingStarlineResultHis/KingStarlineResultHis.dart';
import '../HomeScreen/HomeScreen.dart';

class BidScreen extends StatefulWidget {
  @override
  State<BidScreen> createState() => _BidScreenState();
}

class _BidScreenState extends State<BidScreen> {
  final UserController userController = Get.put(UserController());

  List<_BidOption> _getBidOptions(AppLocalizations? l10n) {
    return [
      _BidOption(
        l10n?.historyPage ?? "BID HISTORY",
        l10n?.youCanViewYourMarketBidHistory ?? "You can view your market bid history",
        Icons.trending_up,
        "BID_HISTORY",
      ),
      _BidOption(
        "${l10n?.kingStarline ?? "KING STARLINE"} ${l10n?.historyPage ?? "Bid History"}",
        l10n?.youCanViewYourStarlineBidHistory ?? "You can view your starline bid history",
        Icons.account_balance,
        "KING_STARLINE_BID_HISTORY",
      ),
      _BidOption(
        "${l10n?.kingJackpot ?? "KING JACKPOT"} ${l10n?.historyPage ?? "Bid History"}",
        l10n?.youCanViewYourJackpotBidHistory ?? "You can view your jackpot bid history",
        Icons.attach_money,
        "KING_JACKPOT_BID_HISTORY",
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7F3),
      body: SafeArea(
        child: Column(
          children: [
            // -------------------- TOP HEADER --------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomeScreen(),
                        ),
                        (route) => false,
                      );
                    },
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
                    l10n?.historyPage ?? 'History Page',
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

            // -------------------- MAIN LIST --------------------
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _getBidOptions(l10n).length,
                itemBuilder: (context, index) {
                  final item = _getBidOptions(l10n)[index];
                  return _buildBidListItem(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBidListItem(_BidOption item) {
    return GestureDetector(
      onTap: () {
        if (item.key == "BID_HISTORY") {
          Navigator.push(context, MaterialPageRoute(builder: (_) => BidHistoryPage()));
        } else if (item.key == "KING_STARLINE_BID_HISTORY") {
          Navigator.push(context, MaterialPageRoute(builder: (_) => KingStarlineBidHistoryScreen()));
        } else if (item.key == "KING_JACKPOT_BID_HISTORY") {
          Navigator.push(context, MaterialPageRoute(builder: (_) => KingJackpotHistoryScreen()));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EE), // Light orange/cream
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 3), // 3D White Bevel
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8D4A16).withOpacity(0.12),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🔘 Icon Circle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECCC), // Lighter orange background like image 3
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFB366), width: 1.5),
              ),
              child: Icon(
                item.icon,
                size: 26,
                color: const Color(0xFFFFB366), // Match image 3 icon style (orange)
              ),
            ),
            const SizedBox(width: 18),
            // 📑 Label
            Expanded(
              child: Text(
                item.title.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6B6358), // Greyish-brown text like Image 3
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Image 3 has no chevron! Removed.
          ],
        ),
      ),
    );
  }
}

class _BidOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final String key;

  _BidOption(this.title, this.subtitle, this.icon, this.key);
}
