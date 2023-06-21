import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc_app/src/lang/translation_service.dart';
import 'package:flutter_webrtc_app/src/routes/app_pages.dart';
import 'package:flutter_webrtc_app/src/shared/logger/logger_utils.dart';
import 'package:flutter_webrtc_app/src/theme/theme_service.dart';
import 'package:flutter_webrtc_app/src/theme/themes.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get_storage/get_storage.dart';
import 'screens/join_screen.dart';
import 'services/signalling.service.dart';

void main() async {
  await GetStorage.init();
  runApp(GetMaterialApp(
    debugShowCheckedModeBanner: false,
    enableLog: true,
    logWriterCallback: Logger.write,
    initialRoute: AppPages.INITIAL,
    getPages: AppPages.routes,
    locale: TranslationService.locale,
    fallbackLocale: TranslationService.fallbackLocale,
    translations: TranslationService(),
    theme: Themes().lightTheme,
    darkTheme: Themes().darkTheme,
    themeMode: ThemeService().getThemeMode(),
  ));
}


/*
void main() {
  // start videoCall app
  runApp(VideoCallApp());
}

class VideoCallApp extends StatelessWidget {
  VideoCallApp({super.key});

  // signalling server url
  final String websocketUrl = "http://192.168.0.22:5000";

  // generate callerID of local user
  final String selfCallerID =
      Random().nextInt(999999).toString().padLeft(6, '0');

  @override
  Widget build(BuildContext context) {
    // init signalling service
    SignallingService.instance.init(
      websocketUrl: websocketUrl,
      selfCallerID: selfCallerID,
    );

    // return material app
    return MaterialApp(
      darkTheme: ThemeData.dark().copyWith(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(),
      ),
      themeMode: ThemeMode.dark,
      home: JoinScreen(selfCallerId: selfCallerID),
    );
  }
}

 */
