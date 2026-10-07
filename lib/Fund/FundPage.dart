import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:new_sara/Fund/BankDetailsFragment.dart';
import 'package:new_sara/l10n/app_localizations.dart';

import '../Helper/TranslationHelper.dart';
import '../Helper/UserController.dart';
import 'AddFundScreen.dart';
import 'DepositHistoryPage.dart';
import 'WithdrawScreen.dart';
import 'WithdrawalHistoryPage.dart';
import '../HomeScreen/HomeScreen.dart';

class FundsScreen extends StatefulWidget {
  final void Function(String title)? onItemTap;

  FundsScreen({super.key, this.onItemTap});

  @override
  State<FundsScreen> createState() => _FundsScreenState();
}

class _FundsScreenState extends State<FundsScreen> {
  final UserController userController = Get.put(UserController());

  List<_FundOption> getFundOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      _FundOption(
        l10n?.addFund ?? "Add Fund", 
        "assets/images/add_fund.png", 
        "Add Fund"
      ),
      _FundOption(
        l10n?.withdrawFunds ?? "Withdraw Funds", 
        "assets/images/withdrawl_fund.png", 
        "Withdraw Funds"
      ),
      // _FundOption(
      //   l10n?.bankDetails ?? "Bank Details",
      //   "assets/images/add_bank_details.png",
      //   "Bank Details"
      // ),
      _FundOption(
        l10n?.depositHistory ?? "Deposit History", 
        "assets/images/fund_deposite_history.png", 
        "Deposit History"
      ),
      _FundOption(
        l10n?.withdrawHistory ?? "Withdraw History", 
        "assets/images/fund_withdraw_history.png", 
        "Withdraw History"
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
                    l10n?.funds ?? 'Funds',
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
                itemCount: getFundOptions(context).length,
                itemBuilder: (context, index) {
                  final item = getFundOptions(context)[index];
                  return _buildFundListItem(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFundListItem(_FundOption item) {
    return GestureDetector(
      onTap: () {
        switch (item.key) {
          case "Add Fund":
            Navigator.push(context, MaterialPageRoute(builder: (_) => AddFundScreen()));
            break;
          case "Withdraw Funds":
            Navigator.push(context, MaterialPageRoute(builder: (_) => WithdrawScreen()));
            break;
          case "Bank Details":
            Navigator.push(context, MaterialPageRoute(builder: (_) => BankDetailsFragment()));
            break;
          case "Deposit History":
            Navigator.push(context, MaterialPageRoute(builder: (_) => DepositHistoryPage()));
            break;
          case "Withdraw History":
            Navigator.push(context, MaterialPageRoute(builder: (_) => WithdrawalHistoryPage()));
            break;
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
            // 🌸 Orange Circle Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECCC), // Lighter orange background like image 3
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFB366), width: 1.5),
              ),
              child: Image.asset(
                item.assetIconPath,
                width: 24,
                height: 24,
                color: const Color(0xFFFFB366), // Match image 3 icon style (orange)
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Color(0xFFFFB366)),
              ),
            ),
            const SizedBox(width: 18),
            // 📑 Option Label
            Expanded(
              child: Text(
                item.title, // Keep normal casing, image 3 looks slightly Title Cased.
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6B6358), // Greyish-brown text like Image 3
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // ⏭ Chevron Icon (removed or changed to match image 3... Image 3 has no chevron!)
          ],
        ),
      ),
    );
  }
}

class _FundOption {
  final String title;
  final String assetIconPath;
  final String key; // For switch statement matching

  _FundOption(this.title, this.assetIconPath, this.key);
}