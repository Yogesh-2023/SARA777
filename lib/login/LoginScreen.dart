import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../../ulits/ColorsR.dart';
import '../../../Components/showAccountRecoveryDialog.dart';
import '../../../Helper/Toast.dart';
import '../../../l10n/app_localizations.dart';
import '../ulits/Constents.dart';
import '../SetMPIN/SetNewPinScreen.dart';
import 'CreateAccountScreen.dart';

class EnterMobileScreen extends StatefulWidget {
  const EnterMobileScreen({super.key});

  @override
  State<EnterMobileScreen> createState() => _EnterMobileScreenState();
}

class _EnterMobileScreenState extends State<EnterMobileScreen> {
  final TextEditingController mobileController = TextEditingController();
  final storage = GetStorage();
  bool isLoading = false;
  String? _supportWhatsAppNumber;

  Future<void> _handleBack() async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // ---------------- DIALER SUPPORT ----------------
  Future<void> _openDialer(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    
    // Try to get from state first
    String? raw = _supportWhatsAppNumber;
    
    // If not in state, try storage
    if (raw == null || raw.isEmpty) {
      raw = _getSupportNumber();
    }
    
    // If still not found, try fetching from API
    if (raw == null || raw.isEmpty) {
      await _fetchContactDetails();
      raw = _supportWhatsAppNumber ?? _getSupportNumber();
    }

    if (raw == null || raw.isEmpty) {
      popToast(
        l10n?.mobileNumberNotAvailable ?? "Mobile number is not available",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }

    try {
      final phone = _normalizePhone(raw);
      await launchUrl(Uri.parse("tel:+$phone"));
    } catch (e) {
      popToast(
        l10n?.somethingWentWrong ?? "Something went wrong",
        3,
        Colors.white,
        ColorsR.appColorRed,
      );
    }
  }

  // ---------------- GET SUPPORT WHATSAPP NUMBER ----------------
  String? _getSupportNumber() {
    // First check storage
    final s = (storage.read('whatsappNo') ?? '').toString().trim();
    if (s.isNotEmpty) return s;
    return null;
  }

  // ---------------- NORMALIZE PHONE NUMBER ----------------
  String _normalizePhone(String raw, {String defaultCountryCode = '91'}) {
    var p = raw.replaceAll(RegExp(r'[^0-9]'), '');
    p = p.replaceFirst(RegExp(r'^0+'), '');
    if (p.length == 10) p = '$defaultCountryCode$p';
    return p;
  }

  // ---------------- FETCH CONTACT DETAILS FROM API ----------------
  Future<void> _fetchContactDetails() async {
    final url = "${Constant.apiEndpoint}contact-detail";
    final headers = {'Content-Type': 'application/json'};
    
    print('--------------------------------------------------');
    print('[EnterMobileScreen] GET CONTACT DETAILS REQUEST:');
    print('  URL: $url');
    print('  HEADERS: $headers');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('[EnterMobileScreen] GET CONTACT DETAILS RESPONSE: ${response.statusCode}');
      print('  BODY: ${response.body}');
      print('--------------------------------------------------');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contactInfo = data['info']?['contactInfo'];
        if (contactInfo != null) {
          final whatsappNo = contactInfo['whatsappNo']?.toString().trim() ?? '';
          if (whatsappNo.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              _supportWhatsAppNumber = whatsappNo;
            });
            storage.write('whatsappNo', whatsappNo);
          }
        }
      }
    } catch (e) {
      // Silent fail - will use storage value
    }
  }

  // ---------------- WHATSAPP SUPPORT ----------------
  Future<void> _openWhatsAppSupport(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    
    // Try to get from state first
    String? raw = _supportWhatsAppNumber;
    
    // If not in state, try storage
    if (raw == null || raw.isEmpty) {
      raw = _getSupportNumber();
    }
    
    // If still not found, try fetching from API
    if (raw == null || raw.isEmpty) {
      await _fetchContactDetails();
      raw = _supportWhatsAppNumber ?? _getSupportNumber();
    }

    if (raw == null || raw.isEmpty) {
      popToast(
        l10n?.whatsappNumberNotAvailable ?? "WhatsApp number not available",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }

    try {
      final phone = _normalizePhone(raw);
      final encoded = '';

      // Try native WhatsApp first
      final nativeUri = Uri.parse(
        'whatsapp://send?phone=$phone${encoded.isNotEmpty ? '&text=$encoded' : ''}',
      );
      if (await canLaunchUrl(nativeUri)) {
        final ok = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );
        if (ok) return;
      }

      // Fallback to web WhatsApp
      final webUri = Uri.parse(
        'https://wa.me/$phone${encoded.isNotEmpty ? '?text=$encoded' : ''}',
      );
      if (await canLaunchUrl(webUri)) {
        final ok = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
        if (ok) return;
      }

      popToast(
        l10n?.couldNotOpenWhatsapp ?? "Could not launch WhatsApp",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    } catch (e) {
      popToast(
        l10n?.errorLaunchingWhatsapp ?? "Error launching WhatsApp",
        4,
        Colors.white,
        ColorsR.appColorRed,
      );
    }
  }

  // ---------------- API ----------------
  Future<void> _handleLogin(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (mobileController.text.length != 10) {
      popToast(
        l10n?.enterValidMobileNumber ?? "Enter valid mobile number",
        3,
        Colors.white,
        ColorsR.appColorRed,
      );
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    final url = "${Constant.apiEndpoint}check-mobile";
    final headers = {"Content-Type": "application/json"};
    final body = {"mobileNo": int.parse(mobileController.text)};

    print('--------------------------------------------------');
    print('[EnterMobileScreen] POST CHECK MOBILE REQUEST:');
    print('  URL: $url');
    print('  HEADERS: $headers');
    print('  BODY: ${jsonEncode(body)}');

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      print('[EnterMobileScreen] POST CHECK MOBILE RESPONSE: ${res.statusCode}');
      print('  BODY: ${res.body}');
      print('--------------------------------------------------');

      final data = jsonDecode(res.body);
      storage.write("mobile", mobileController.text);

      if (data["status"] == true) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SetNewPinScreen(mobile: mobileController.text),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
        );
      }
    } catch (_) {
      final l10n = AppLocalizations.of(context);
      popToast(
        l10n?.somethingWentWrong ?? "Something went wrong",
        3,
        Colors.white,
        ColorsR.appColorRed,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Load WhatsApp number from storage on init
    _supportWhatsAppNumber = _getSupportNumber();
    // Try to fetch latest from API
    _fetchContactDetails();
  }

  @override
  void dispose() {
    mobileController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true, // ✅ IMPORTANT

      backgroundColor: const Color(0xFFFFCD91),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _handleBack,
              icon: const Icon(Icons.arrow_back_ios_new),
              color: const Color(0xFF1E2F97),
            ),
          ),
          const SizedBox(height: 90),

          /// WHITE CONTAINER
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Color(0xFFFFCD91),
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: [
                    const SizedBox(height: 30),

                    // /// IMAGE
                    // Image.asset("assets/icon/only_image.png", height: 160),

                    const SizedBox(height: 10),

                    /// TITLE
                    Text(
                      l10n?.enterYourMobileNumber ?? "ENTER YOUR MOBILE NUMBER",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xFF1E2F97),
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// INPUT CARD
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xffeeeeeee),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDB564),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.phone_android,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: mobileController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                counterText: "",
                                hintText: l10n?.phoneNumber ?? "Mobile Number",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    const SizedBox(height: 25),

                    /// LOGIN BUTTON
                    SizedBox(
                      width: 180,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () => _handleLogin(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDB564),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                l10n?.next ?? "NEXT",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(color: Colors.grey.shade300),
                    //   const Spacer(),
                    const SizedBox(height: 10),

                    /// CALL + WHATSAPP SUPPORT
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _bottomIcon(Icons.call, () => _openDialer(context)),
                        const SizedBox(width: 30),
                        _bottomIcon(
                          null,
                          () => _openWhatsAppSupport(context),
                          asset: "assets/images/whatsapp.png",
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    
                    /// Keyboard space
                    SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomIcon(IconData? icon, VoidCallback onTap, {String? asset}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        color: Colors.white,
        child: SizedBox(
          width: 60,
          height: 38,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 20)
                : Image.asset(asset!, width: 20),
          ),
        ),
      ),

    );
  }
}
