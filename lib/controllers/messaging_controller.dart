import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wvems_protocols/models/temp_messages.dart';

class MessagingController extends GetxController {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  late NotificationSettings settings;
  final AndroidNotificationChannel channel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    'This channel is used for important notifications.', // description
    importance: Importance.max,
  );
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GetStorage store = GetStorage();

  final messages = <Map<String, dynamic>>{}.obs;

  final tempMessages = tempMessageSet.obs;

  /// *************** Temporary, need to modify to set ****************///
  Set<Map<String, dynamic>> get unread => sortByDate(
          messages.where((message) => message['beenRead'] == false).toList())
      .toSet();

  Set<Map<String, dynamic>> get read => sortByDate(
          messages.where((message) => message['beenRead'] == true).toList())
      .toSet();

  List<Map<String, dynamic>> sortByDate(
      List<Map<String, dynamic>> messageList) {
    messageList.sort((a, b) =>
        DateTime.parse(a['dateTime']).compareTo(DateTime.parse(b['dateTime'])));
    return messageList;
  }

  void setAsRead(String dateTimeSent) {
    messages.firstWhere(
        (message) => message['dateTime'] == dateTimeSent)['beenRead'] = true;
  }

  /// *************** Initialize Class and necessary values ****************///
  @override
  Future<void> onInit() async {
    settings = await _requestPermissions();
    await _createNotificationChannel();
    await loadMessagesFromStore();
    super.onInit();
    listen();
  }

  Future<void> loadMessagesFromStore() async {
    final storeMessages = store.read('messages');
    if (storeMessages != null) {
      messages.addAll(List<Map<String, dynamic>>.from(storeMessages));
    }
    await saveMessagesToStore();
  }

  Future<void> saveMessagesToStore() async =>
      await store.write('messages', messages.toList());

  Future<void> listen() async {
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        final RemoteNotification? notification = message.notification;
        final AndroidNotification? android = message.notification?.android;

        // If `onMessage` is triggered with a notification, construct our own
        // local notification to show to users using the created channel.
        // todo: this is currently setup for android only
        // todo: add iOS configuration
        if (notification != null && android != null) {
          print('${notification.title ?? ''} ${notification.body ?? ''}');
          messages.add({
            'title': notification.title,
            'body': notification.body,
            'dateTime': '${DateTime.now()}',
            'beenRead': false,
          });
          await saveMessagesToStore();

          flutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channel.description,
                  icon: 'ic_launcher',
                ),
              ));
        }
      },
    );
  }

  /// ************* Initialize Class and necessary values ***************///
  Future<NotificationSettings> _requestPermissions() async =>
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

  Future<void> _createNotificationChannel() async =>
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
}
