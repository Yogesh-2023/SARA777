import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_sara/l10n/app_localizations.dart';

class KingJackpotBiddingClosedDialog extends StatelessWidget {
  final String time;
  final String resultTime;
  final String bidLastTime;

  const KingJackpotBiddingClosedDialog({
    super.key,
    required this.time,
    required this.resultTime,
    required this.bidLastTime,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFF8EE), // Very light orange tint
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.white, width: 3),
      ),
      elevation: 10,
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// ❌ Close Icon (White background, orange border like Image 3)
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFB366), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB366).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 36,
                color: Color(0xFFFFB366),
              ),
            ),

            const SizedBox(height: 18),

            /// ⏰ Time Title
            Text(
              time,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E2F97),
                letterSpacing: 0.8,
              ),
            ),

            const SizedBox(height: 4),

            /// 🔴 Closed Text
            Text(
              AppLocalizations.of(context)?.closedForToday ?? "Closed for Today",
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: const Color(0xFFB71C1C),
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 22),

            /// 🕒 Bid Last Time
            _infoRow(
              context,
              AppLocalizations.of(context)?.bidTime ?? "Bid Time :",
              bidLastTime,
            ),

            const SizedBox(height: 12),

            /// 🕒 Result Time
            _infoRow(
              context,
              AppLocalizations.of(context)?.bidResultTime ?? "Bid Result Time :",
              resultTime,
            ),

            const SizedBox(height: 28),

            /// ✅ OK Button
            SizedBox(
              width: 150,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB366),
                  elevation: 4,
                  shadowColor: const Color(0xFFFFB366).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context)?.ok ?? "OK",
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2F97),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔶 Styled Info Row
  Widget _infoRow(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3E8), // Subtle orange-tinted row
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: const Color(0xFF1E2F97).withOpacity(0.7),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: const Color(0xFF1E2F97),
            ),
          ),
        ],
      ),
    );
  }

}

