import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../Helper/UserController.dart';
import '../ulits/Constents.dart';
import 'GameItem.dart';

// Screens
import 'SingleDigitBetScreen/SingleDigitBetScreen.dart';
import 'SingleDigitBetScreen/SingleDigitsBulkScreen.dart';
import 'SPDPTPScreen/SPMotors.dart';
import 'SPDPTPScreen/DPMotors.dart';
import 'SPDPTPScreen/TPMotorScreen.dart';
import 'Panna/DoublePana/DoublePana.dart';
import 'Panna/SinglePanna/SinglePannaBulk.dart';
import 'Panna/SinglePanna/SinglePanna.dart';
import 'Jodi/JodiBidScreen.dart';
import 'Jodi/JodiBulkScreen.dart';
import 'Jodi/group_jodi_screen.dart';
import 'TwoDigitPanel/TwoDigitPanel.dart';
import 'DigitBasedBoard/DigitBasedBoardScreen.dart';
import 'OddEvenBoard/OddEvenBoardScreen.dart';
import 'PannelGroup/PannelGroup.dart';
import 'SPDPTPScreen/ChoiceSpDpTpBoardScreen.dart';
import 'SPDPTPScreen/SpDpTpBoardScreen.dart';
import 'RedBracket/RedBracketScreen.dart';
import 'Sangam/HalfSangamABoardScreen.dart';
import 'Sangam/HalfSangamBBoardScreen.dart';
import 'Sangam/FullSangamBoardScreen.dart';

class GameMenuScreen extends StatefulWidget {
  final String title;
  final int gameId;
  final bool openSessionStatus;
  final bool closeSessionStatus;

  const GameMenuScreen({
    super.key,
    required this.title,
    required this.gameId,
    required this.openSessionStatus,
    required this.closeSessionStatus,
  });

  @override
  State<GameMenuScreen> createState() => _GameMenuScreenState();
}

class _GameMenuScreenState extends State<GameMenuScreen> {
  Future<List<GameItem>>? _futureGames;
  final storage = GetStorage();
  final UserController userController = Get.put(UserController());

  @override
  void initState() {
    super.initState();
    _futureGames = fetchGameList();
  }

  Future<List<GameItem>> fetchGameList() async {
    final token = storage.read("accessToken");
    try {
      final res = await http.get(
        Uri.parse("${Constant.apiEndpoint}game-bid-type"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["status"] == true) {
          return (data["info"] as List).map((e) => GameItem.fromJson(e)).toList();
        }
      }
    } catch (e) {
      debugPrint("Error fetching games: $e");
    }
    throw Exception("Failed to load games");
  }

  void openScreen(GameItem item, String screenTitle) {
    Widget? page;
    switch (item.type) {
      case "singleDigits":
        page = SingleDigitBetScreen(title: screenTitle, gameId: widget.gameId, gameName: item.name, gameCategoryType: item.type, selectionStatus: widget.openSessionStatus);
        break;
      case "singleDigitsBulk":
        page = SingleDigitsBulkScreen(title: screenTitle, gameId: widget.gameId, gameType: item.type, gameName: item.name, selectionStatus: widget.openSessionStatus);
        break;
      case "doublePana":
        page = DoublePanaBetScreen(title: screenTitle, gameId: widget.gameId, gameName: item.name, gameCategoryType: item.type, selectionStatus: widget.openSessionStatus);
        break;
      case "singlePanaBulk":
      case "doublePanaBulk":
        page = SinglePannaBulkBoardScreen(title: screenTitle, gameId: widget.gameId, gameType: item.type, gameName: item.name, selectionStatus: widget.openSessionStatus);
        break;
      case "singlePana":
        page = SinglePannaScreen(title: screenTitle, gameId: widget.gameId, gameType: item.type, gameName: item.name, selectionStatus: widget.openSessionStatus);
        break;
      case "spMotor":
        page = SPMotorsBetScreen(title: screenTitle, gameId: widget.gameId, gameName: item.name, gameCategoryType: item.type, selectionStatus: widget.openSessionStatus);
        break;
      case "dpMotor":
        page = DPMotorsBetScreen(title: screenTitle, gameId: widget.gameId, gameName: item.name, gameCategoryType: item.type, selectionStatus: widget.openSessionStatus);
        break;
      case "triplePana":
        page = TPMotorsBetScreen(title: screenTitle, gameId: widget.gameId, gameName: item.name, gameCategoryType: item.type, selectionStatus: widget.openSessionStatus);
        break;
      case "jodi":
        page = JodiBidScreen(title: screenTitle, gameId: widget.gameId, gameType: item.type, gameName: item.name);
        break;
      case "jodiBulk":
        page = JodiBulkScreen(screenTitle: screenTitle, gameId: widget.gameId, gameType: item.type, gameName: item.name);
        break;
      case "groupJodi":
        page = GroupJodiScreen(title: screenTitle, gameId: widget.gameId, gameType: item.type);
        break;
      case "twoDigitsPanel":
        page = TwoDigitPanelScreen(title: screenTitle, gameId: widget.gameId, gameType: item.type, selectionStatus: widget.openSessionStatus);
        break;
      case "digitBasedJodi":
        page = DigitBasedBoardScreen(title: screenTitle, gameId: widget.gameId.toString(), gameType: item.type, gameName: item.name);
        break;
      case "oddEven":
        page = OddEvenBoardScreen(title: screenTitle, gameId: widget.gameId, gameType: item.type, selectionStatus: widget.openSessionStatus);
        break;
      case "panelGroup":
        page = PanelGroupScreen(title: screenTitle, gameId: widget.gameId, gameName: item.name, gameCategoryType: item.type);
        break;
      case "choicePannaSPDP":
        page = ChoiceSpDpTpBoardScreen(screenTitle: screenTitle, gameId: widget.gameId, gameType: item.type, gameName: item.name, selectionStatus: widget.openSessionStatus);
        break;
      case "SPDPTP":
        page = SpDpTpBoardScreen(screenTitle: screenTitle, gameId: widget.gameId, gameType: item.type, openSessionStatus: widget.openSessionStatus);
        break;
      case "redBracket":
        page = RedBracketBoardScreen(screenTitle: screenTitle, gameId: widget.gameId, gameType: item.type);
        break;
      case "halfSangamA":
        page = HalfSangamABoardScreen(
          screenTitle: screenTitle,
          gameId: widget.gameId,
          gameType: item.type,
          gameName: item.name,
          openSessionStatus: widget.openSessionStatus,
        );
        break;
      case "halfSangamB":
        page = HalfSangamBBoardScreen(
          screenTitle: screenTitle,
          gameId: widget.gameId,
          gameType: item.type,
          gameName: item.name,
          closeSessionStatus: widget.closeSessionStatus,
        );
        break;
      case "fullSangam":
        page = FullSangamBoardScreen(
          screenTitle: screenTitle,
          gameId: widget.gameId,
          gameType: item.type,
          gameName: item.name,
          openSessionStatus: widget.openSessionStatus,
          closeSessionStatus: widget.closeSessionStatus,
        );
        break;
    }
    if (page != null) Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF7F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF7F3),
        elevation: 0,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFDB564).withOpacity(0.1)),
              child: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFFDB564), size: 18),
            ),
          ),
        ),
        title: Text(widget.title, style: GoogleFonts.poppins(color: const Color(0xFF1E2F97), fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          Obx(() => Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF0B1223), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Image.asset("assets/images/ic_wallet.png", width: 16, height: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text("₹${userController.walletBalance.value}", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          )),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Expanded(
              child: FutureBuilder<List<GameItem>>(
                future: _futureGames,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFDB564)));
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(child: ElevatedButton(onPressed: () => setState(() => _futureGames = fetchGameList()), child: const Text("Retry")));
                  }
                  final games = snapshot.data!;
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: games.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, 
                      crossAxisSpacing: 12, 
                      mainAxisSpacing: 14, 
                      childAspectRatio: 0.75, 
                    ),
                    itemBuilder: (_, i) => GameCard(item: games[i], onTap: () => openScreen(games[i], "${widget.title}, ${games[i].name}")),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameCard extends StatelessWidget {
  final GameItem item;
  final VoidCallback onTap;
  const GameCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFCF7F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔹 ORANGE ICON CIRCLE
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFFDB564),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFDB564).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Image.network(
                  item.image,
                  width: 32,
                  height: 32,
                  color: Colors.white,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.casino,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E2F97),
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
