import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_sara/l10n/app_localizations.dart';

void closeBidDialogue({
  required BuildContext context,
  required String gameName,
  required String openResultTime,
  required String openBidLastTime,
  required String closeResultTime,
  required String closeBidLastTime,
}) {
  final l10n = AppLocalizations.of(context);
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) {
      return Dialog(
        backgroundColor: const Color(0xFFFFF8EE), // Light orange mode
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white, width: 3),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ❌ Close Icon (White background, orange border like Image 3)
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
                child: const Icon(Icons.close_rounded, size: 36, color: Color(0xFFFFB366)),
              ),
              const SizedBox(height: 18),

              // Game name
              Text(
                gameName.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: const Color(0xFF1E2F97),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),

              // Closed for Today text
              Text(
                l10n?.closedForToday ?? "Closed for Today",
                style: GoogleFonts.poppins(
                  color: const Color(0xFFB71C1C),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),

              // Timings Table
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3E8), // Subtle orange row Tint
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildTimeRow(l10n?.openBidLastTime ?? "Open Bid Last Time", openBidLastTime),
                    _buildTimeRow(l10n?.openResultTime ?? "Open Result Time", openResultTime),

                    // Divider between Open and Close
                    Divider(
                      height: 1,
                      thickness: 1.5,
                      color: Colors.white.withOpacity(0.8),
                    ),

                    _buildTimeRow(l10n?.closeBidLastTime ?? "Close Bid Last Time", closeBidLastTime),
                    _buildTimeRow(l10n?.closeResultTime ?? "Close Result Time", closeResultTime),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // OK Button (Orange with Navy Text)
              SizedBox(
                width: 150,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB366),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFFFFB366).withOpacity(0.6),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    l10n?.ok ?? "OK",
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1E2F97),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
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

Widget _buildTimeRow(String label, String time) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            "$label :",
            style: GoogleFonts.poppins(
              color: const Color(0xFF1E2F97).withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          time.isNotEmpty ? time : "--:--",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E2F97),
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}
