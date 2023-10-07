import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui';
import 'package:background_sms/background_sms.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_sender/backend/firebase/firebase_config.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'home_page_widget.dart' show HomePageWidget;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

ValueNotifier<bool> isServiceRunning = ValueNotifier<bool>(false);

class HomePageModel extends FlutterFlowModel<HomePageWidget> {
  ///  State fields for stateful widgets in this page.

  final unfocusNode = FocusNode();

  int? simSlot;

  /// Initialization and disposal methods.

  void initState(BuildContext context) async {
    await loadServiceStatus();
    int delay = await loadDelay();
    log("init delayTimeM: $delay");

    await initializeService();
  }

  void dispose() {
    unfocusNode.dispose();
  }
}

Future<void> loadServiceStatus() async {
  // Load the status from shared preferences.
  SharedPreferences prefs = await SharedPreferences.getInstance();

  isServiceRunning.value = prefs.getBool('isServiceRunning') ?? false;
}

Future<void> saveServiceStatus(bool status) async {
  // Save the status to shared preferences.
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isServiceRunning', status);
}

Future<int> loadDelay() async {
  // Load the status from shared preferences.
  SharedPreferences prefs = await SharedPreferences.getInstance();

  int delay = prefs.getInt('delayTimeM') ?? 0;
  log("shared: $delay");
  return delay;
}

Future<void> saveDelayMinutes(int minutes) async {
  // Save the status to shared preferences.
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setInt('delayTimeM', minutes);
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  await initFirebase();
  DartPluginRegistrant.ensureInitialized();

  saveServiceStatus(true);
  log("onStart");

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    saveServiceStatus(false);

    service.stopSelf();
  });

  // bring to foreground
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "My App Service",
          content: "Updated at ${DateTime.now()}",
        );
      }
    }
  });

  await otpMonitor();
}

Future<void> initializeService() async {
  log("initializeService");
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStartOnBoot: true,
      autoStart: false,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

Future<void> otpMonitor() async {
  int delay = await loadDelay();
  int delayTimeM = delay;
  log("otpMonitor delayTimeM: $delay");

  log("otpMonitor has been called");

  CollectionReference<Map<String, dynamic>> reference =
      FirebaseFirestore.instance.collection('sms_request');

  reference.snapshots(includeMetadataChanges: true).listen((event) async {
    List<DocumentChange<Map<String, dynamic>>> changedDocs = event.docChanges;
    for (DocumentChange<Map<String, dynamic>> doc in changedDocs) {
      // if the OTP has been set or the user complete the registration
      if (doc.type == DocumentChangeType.removed ||
          doc.type == DocumentChangeType.modified) {
        continue;
      }

      Map<String, dynamic>? docData = doc.doc.data();
      log("the delay is: $delayTimeM");

      if (docData == null || docData.containsKey("otp")) {
        continue;
      }
      await Future.delayed(
        Duration(minutes: delayTimeM),
        () async {
          DocumentSnapshot updatedDocument = await doc.doc.reference.get();
          Object? dataObject = updatedDocument.data();
          if (dataObject == null) return;

          Map<String, dynamic>? updatedDocData =
              dataObject as Map<String, dynamic>;

          if (updatedDocData == null || updatedDocData.containsKey("otp")) {
            return;
          }

          log(docData.toString());
          String otp = generateOTP(4);
          sendMessage(docData.values.toList()[0].toString(),
              "أهلًا بك في واتر،\nرمز التحقق الخاص بك: $otp");
          docData['otp'] = otp;
          await doc.doc.reference.update(docData);
        },
      );
    }
  });
}

String generateOTP(int length) {
  const String validChars = '0123456789';
  math.Random random = math.Random();
  String otp = '';

  for (int i = 0; i < length; i++) {
    int randomIndex = random.nextInt(validChars.length);
    otp += validChars[randomIndex];
  }

  return otp;
}

Future<bool> get supportCustomSim async =>
    await BackgroundSms.isSupportCustomSim ?? false;

void sendMessage(String phoneNumber, String message, {int? simSlot}) async {
  SmsStatus result = await BackgroundSms.sendMessage(
      phoneNumber: phoneNumber,
      message: message,
      simSlot: await supportCustomSim ? simSlot : null);
  if (result == SmsStatus.sent) {
    log("Sent");
  } else {
    log("Failed");
  }
}
