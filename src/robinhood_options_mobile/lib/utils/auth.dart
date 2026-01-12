import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/device.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';

class AuthUtil {
  final firebase_auth.FirebaseAuth auth;
  AuthUtil(this.auth);

  UserRole? _userRole;

  Future<UserRole> userRole() async {
    if (_userRole == null) {
      String role = "user";
      if (auth.currentUser != null) {
        var token = await auth.currentUser!.getIdTokenResult(false);
        if (token.claims != null && token.claims!['role'] != null) {
          role = token.claims!['role'];
        }
      }
      _userRole = role.parseEnum(UserRole.values, UserRole.user);
    }
    return _userRole!;
  }

  void openLogin(BuildContext context, FirestoreService firestoreService,
      FirebaseAnalytics analytics, FirebaseAnalyticsObserver observer) async {
    final BrokerageUser? result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => LoginWidget(
                  analytics: analytics,
                  observer: observer,
                )));

    if (result != null) {
      if (!context.mounted) return;
      // TODO: see if setState is actually needed, Provider pattern is already listening.
      // setState(() {
      //   futureUser = null;
      // });

      if (auth.currentUser != null) {
        var userStore = Provider.of<BrokerageUserStore>(context, listen: false);
        final authUtil = AuthUtil(auth);
        await authUtil.setUser(firestoreService, brokerageUserStore: userStore);
      }

      // After the Selection Screen returns a result, hide any previous snackbars
      // and show the new result.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text("Logged in ${result.userName}"),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  static final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

  Future<User> setUser(FirestoreService store,
      {required BrokerageUserStore? brokerageUserStore,
      DateTime? lastVisited}) async {
    var value = await userRole();
    debugPrint(value.enumValue());

    var deviceData = <String, dynamic>{};
    if (kIsWeb) {
      deviceData = _readWebBrowserInfo(await deviceInfoPlugin.webBrowserInfo);
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          deviceData =
              _readAndroidBuildData(await deviceInfoPlugin.androidInfo);
          break;
        case TargetPlatform.iOS:
          deviceData = _readIosDeviceInfo(await deviceInfoPlugin.iosInfo);
          break;
        case TargetPlatform.linux:
          deviceData = _readLinuxDeviceInfo(await deviceInfoPlugin.linuxInfo);
          break;
        case TargetPlatform.windows:
          deviceData =
              _readWindowsDeviceInfo(await deviceInfoPlugin.windowsInfo);
          break;
        case TargetPlatform.macOS:
          deviceData = _readMacOsDeviceInfo(await deviceInfoPlugin.macOsInfo);
          break;
        case TargetPlatform.fuchsia:
          deviceData = <String, dynamic>{
            'Error:': 'Fuchsia platform isn\'t supported'
          };
          break;
      }
    }

    final info = await PackageInfo.fromPlatform();
    debugPrint(info.toString());

    String? apnsToken;
    String? fcmToken;

    //TODO: Disable Web Push Notifications for now until blank screen issue is resolved...
    if (!kIsWeb) {
      // You may set the permission requests to "provisional" which allows the user to choose what type
      // of notifications they would like to receive once the user receives a notification.
      final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true, carPlay: true
          // provisional: true
          );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true, // Required to display a heads up notification
          badge: true,
          sound: true,
        );

        // For apple platforms, ensure the APNS token is available before making any FCM plugin API calls
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('apnsToken: $apnsToken');
          // APNS token is available, make FCM plugin API requests...
        }
        try {
          fcmToken = await FirebaseMessaging.instance.getToken();
          debugPrint('fcmToken: $fcmToken');
        } catch (e) {
          debugPrint('fcmToken: $e');
        }
      } else {
        debugPrint(
            'The notification permission was not granted and blocked instead.');
      }
    }
    final firebaseUser = auth.currentUser;
    if (firebaseUser == null) {
      throw Exception("Firebase user is not authenticated.");
    }
    final documentReference = store.userCollection.doc(firebaseUser.uid);
    final document = await documentReference.get();
    User? user;
    if (document.exists) {
      user = document.data()!;
    } else {
      user = User(
          devices: [],
          dateCreated: DateTime.now(), //.toUtc(),
          // dateUpdated: DateTime.now(), //.toUtc(),
          brokerageUsers: []);
    }
    user.name = firebaseUser.displayName;
    user.nameLower = firebaseUser.displayName?.toLowerCase();
    user.email = firebaseUser.email;
    user.phoneNumber = firebaseUser.phoneNumber;
    user.photoUrl = firebaseUser.photoURL;
    user.providerId = firebaseUser.providerData.isNotEmpty
        ? firebaseUser.providerData[0].providerId
        : null;
    user.role = value;
    if (lastVisited != null) {
      user.lastVisited = lastVisited; // DateTime.now(); //.toUtc();
    }

    String deviceId = "";
    if (deviceData.keys.contains("identifierForVendor")) {
      deviceId = deviceData["identifierForVendor"];
    } else if (deviceData.keys.contains("host")) {
      deviceId = deviceData["host"];
    }
    var device =
        user.devices.firstWhereOrNull((element) => element.id == deviceId);
    if (device == null) {
      device = Device(id: deviceId, dateCreated: DateTime.now()); //.toUtc()
      user.devices.add(device);
    } else {
      device.dateUpdated = DateTime.now(); //.toUtc();
    }
    device.model = deviceData["model"];
    device.appVersion = '${info.version} (${info.buildNumber})';
    device.apnsToken = apnsToken;
    device.fcmToken = fcmToken;
    device.deviceInfo = deviceData;

    if (brokerageUserStore != null) {
      user.brokerageUsers = brokerageUserStore.items.toList();
    }

    if (!document.exists) {
      await store.addUser(documentReference, user);
    } else {
      await store.updateUser(documentReference, user);
    }
    return user;
  }

  Map<String, dynamic> _readAndroidBuildData(AndroidDeviceInfo build) {
    return <String, dynamic>{
      'version.securityPatch': build.version.securityPatch,
      'version.sdkInt': build.version.sdkInt,
      'version.release': build.version.release,
      'version.previewSdkInt': build.version.previewSdkInt,
      'version.incremental': build.version.incremental,
      'version.codename': build.version.codename,
      'version.baseOS': build.version.baseOS,
      'board': build.board,
      'bootloader': build.bootloader,
      'brand': build.brand,
      'device': build.device,
      'display': build.display,
      'fingerprint': build.fingerprint,
      'hardware': build.hardware,
      'host': build.host,
      'id': build.id,
      'manufacturer': build.manufacturer,
      'model': build.model,
      'product': build.product,
      'supported32BitAbis': build.supported32BitAbis,
      'supported64BitAbis': build.supported64BitAbis,
      'supportedAbis': build.supportedAbis,
      'tags': build.tags,
      'type': build.type,
      'isPhysicalDevice': build.isPhysicalDevice,
      'systemFeatures': build.systemFeatures,
      'serialNumber': build.serialNumber,
      'isLowRamDevice': build.isLowRamDevice,
    };
  }

  Map<String, dynamic> _readIosDeviceInfo(IosDeviceInfo data) {
    return <String, dynamic>{
      'name': data.name,
      'systemName': data.systemName,
      'systemVersion': data.systemVersion,
      'model': data.model,
      'localizedModel': data.localizedModel,
      'identifierForVendor': data.identifierForVendor,
      'isPhysicalDevice': data.isPhysicalDevice,
      'utsname.sysname:': data.utsname.sysname,
      'utsname.nodename:': data.utsname.nodename,
      'utsname.release:': data.utsname.release,
      'utsname.version:': data.utsname.version,
      'utsname.machine:': data.utsname.machine,
    };
  }

  Map<String, dynamic> _readLinuxDeviceInfo(LinuxDeviceInfo data) {
    return <String, dynamic>{
      'name': data.name,
      'version': data.version,
      'id': data.id,
      'idLike': data.idLike,
      'versionCodename': data.versionCodename,
      'versionId': data.versionId,
      'prettyName': data.prettyName,
      'buildId': data.buildId,
      'variant': data.variant,
      'variantId': data.variantId,
      'machineId': data.machineId,
    };
  }

  Map<String, dynamic> _readWebBrowserInfo(WebBrowserInfo data) {
    return <String, dynamic>{
      'browserName': data.browserName.name,
      'appCodeName': data.appCodeName,
      'appName': data.appName,
      'appVersion': data.appVersion,
      'deviceMemory': data.deviceMemory,
      'language': data.language,
      'languages': data.languages,
      'platform': data.platform,
      'product': data.product,
      'productSub': data.productSub,
      'userAgent': data.userAgent,
      'vendor': data.vendor,
      'vendorSub': data.vendorSub,
      'hardwareConcurrency': data.hardwareConcurrency,
      'maxTouchPoints': data.maxTouchPoints,
    };
  }

  Map<String, dynamic> _readMacOsDeviceInfo(MacOsDeviceInfo data) {
    return <String, dynamic>{
      'computerName': data.computerName,
      'hostName': data.hostName,
      'arch': data.arch,
      'model': data.model,
      'kernelVersion': data.kernelVersion,
      'majorVersion': data.majorVersion,
      'minorVersion': data.minorVersion,
      'patchVersion': data.patchVersion,
      'osRelease': data.osRelease,
      'activeCPUs': data.activeCPUs,
      'memorySize': data.memorySize,
      'cpuFrequency': data.cpuFrequency,
      'systemGUID': data.systemGUID,
    };
  }

  Map<String, dynamic> _readWindowsDeviceInfo(WindowsDeviceInfo data) {
    return <String, dynamic>{
      'numberOfCores': data.numberOfCores,
      'computerName': data.computerName,
      'systemMemoryInMegabytes': data.systemMemoryInMegabytes,
      'userName': data.userName,
      'majorVersion': data.majorVersion,
      'minorVersion': data.minorVersion,
      'buildNumber': data.buildNumber,
      'platformId': data.platformId,
      'csdVersion': data.csdVersion,
      'servicePackMajor': data.servicePackMajor,
      'servicePackMinor': data.servicePackMinor,
      'suitMask': data.suitMask,
      'productType': data.productType,
      'reserved': data.reserved,
      'buildLab': data.buildLab,
      'buildLabEx': data.buildLabEx,
      'digitalProductId': data.digitalProductId,
      'displayVersion': data.displayVersion,
      'editionId': data.editionId,
      'installDate': data.installDate,
      'productId': data.productId,
      'productName': data.productName,
      'registeredOwner': data.registeredOwner,
      'releaseId': data.releaseId,
      'deviceId': data.deviceId,
    };
  }

  static String basicAuthHeader(String identifier, String secret) {
    var userPass = '${Uri.encodeFull(identifier)}:${Uri.encodeFull(secret)}';
    return 'Basic ${base64Encode(ascii.encode(userPass))}';
  }
}
