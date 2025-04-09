import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Handler for background messages.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set the background messaging handler.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

// Model class to store notification information.
class NotificationItem {
  final String? title;
  final String? body;
  final DateTime timestamp;
  NotificationItem({
    required this.title,
    required this.body,
    required this.timestamp,
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _fcmToken = '';
  final List<NotificationItem> _notificationHistory = [];
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    _initLocalNotifications();
    _setupFCM();
  }

  // Initialize the flutter_local_notifications plugin.
  void _initLocalNotifications() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        final String? payload = notificationResponse.payload;
        if (payload != null) {
          debugPrint('Notification payload: $payload');
          // Handle notification tap here (e.g., navigate to a specific screen).
        }
      },
    );
  }

  /// Shows a local notification.
  /// 
  /// [isImportant] indicates which type of notification to display.
  Future<void> _showNotification(RemoteMessage message, {bool isImportant = false}) async {
    final String notificationTitle = message.notification?.title ??
        (isImportant ? 'Important' : 'Regular');
    final String notificationBody = message.notification?.body ??
        'Notification Body';

    // Save the notification info in history.
    setState(() {
      _notificationHistory.add(NotificationItem(
        title: notificationTitle,
        body: notificationBody,
        timestamp: DateTime.now(),
      ));
    });

    // Choose channel settings based on type.
    AndroidNotificationDetails androidDetails;
    if (isImportant) {
      androidDetails = const AndroidNotificationDetails(
        'important_channel', // Channel ID for important notifications.
        'Important Notifications', // Channel name.
        channelDescription: 'Channel for important alerts.',
        importance: Importance.max,
        priority: Priority.high,
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        'regular_channel', // Channel ID for regular notifications.
        'Regular Notifications', // Channel name.
        channelDescription: 'Channel for regular notifications.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
    }

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      notificationTitle,
      notificationBody,
      platformDetails,
      payload: isImportant ? 'important_payload' : 'regular_payload',
    );
  }

  // Set up Firebase Messaging to request permissions, retrieve the token, and listen for messages.
  Future<void> _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');

    // Retrieve FCM token for this device.
    String? token = await messaging.getToken();
    setState(() {
      _fcmToken = token ?? 'No token received';
    });
    print("FCM Token: $_fcmToken");

    // Listen for foreground messages.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      bool isImportant = message.data['importance'] == 'important';
      print("Message received (isImportant=$isImportant): ${message.data}");
      _showNotification(message, isImportant: isImportant);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification caused app to open: ${message.messageId}');
    });
  }

  // Navigate to the Notification History screen.
  void _navigateToHistory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => NotificationHistoryScreen(history: _notificationHistory),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Notifications Demo',
      home: Scaffold(
        appBar: AppBar(
          title: Text("FCM Demo"),
          actions: [
            // Wrap in Builder to get correct context for Navigator.
            Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(Icons.history),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => NotificationHistoryScreen(history: _notificationHistory),
                    ));
                  },
                );
              },
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "FCM Token:",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SelectableText(_fcmToken),
                ),
                Text("Copy this token and use it to test notifications."),
                const SizedBox(height: 20),
                // Button to simulate a regular notification.
                ElevatedButton(
                  onPressed: () {
                    RemoteMessage dummyMessage = RemoteMessage(
                      notification: RemoteNotification(
                        title: "Test Regular",
                        body: "This is a regular notification",
                      ),
                      data: {},
                    );
                    _showNotification(dummyMessage, isImportant: false);
                  },
                  child: Text("Send Regular Notification"),
                ),
                const SizedBox(height: 20),
                // Button to simulate an important notification.
                ElevatedButton(
                  onPressed: () {
                    RemoteMessage dummyMessage = RemoteMessage(
                      notification: RemoteNotification(
                        title: "Test Important",
                        body: "This is an important notification",
                      ),
                      data: {"importance": "important"},
                    );
                    _showNotification(dummyMessage, isImportant: true);
                  },
                  child: Text("Send Important Notification"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A screen to display the history of received notifications.
class NotificationHistoryScreen extends StatelessWidget {
  final List<NotificationItem> history;
  const NotificationHistoryScreen({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notification History')),
      body: ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          final NotificationItem item = history[index];
          return ListTile(
            title: Text(item.title ?? 'No Title'),
            subtitle: Text('${item.body ?? 'No Body'}\nReceived: ${item.timestamp.toLocal()}'),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}
