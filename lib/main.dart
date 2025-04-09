import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Handler for background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set the background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

// Store notification information
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

  // Initialize flutter_local_notifications
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
          // Handle notification tap here
        }
      },
    );
  }

  // Show local notification and add it to history list
  Future<void> _showNotification(RemoteMessage message) async {
    final String notificationTitle = message.notification?.title ?? 'No Title';
    final String notificationBody = message.notification?.body ?? 'No Body';

    // Add notification to history
    setState(() {
      _notificationHistory.add(NotificationItem(
        title: notificationTitle,
        body: notificationBody,
        timestamp: DateTime.now(),
      ));
    });

    // Android-specific notification details.
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'activity_14_channel', 
      'Activity 14 Notifications', 
      channelDescription: 'Channel for practicing Firebase',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Display the notification.
    await flutterLocalNotificationsPlugin.show(
      0,
      notificationTitle,
      notificationBody,
      platformChannelSpecifics,
      payload: 'action_payload', 
    );
  }

  // Set up Firebase Messaging to request permission, retrieve token, and listen for messages
  Future<void> _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');

    // Retrieve the FCM token for this device
    String? token = await messaging.getToken();
    setState(() {
      _fcmToken = token ?? 'No token received';
    });
    print("FCM Token: $_fcmToken");

    // Listen for messages when the app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Message received while in the foreground:");
      print("Data: ${message.data}");
      if (message.notification != null) {
        print("Notification: ${message.notification!.title} - ${message.notification!.body}");
      }
      _showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification caused app to open: ${message.messageId}');
    });
  }

  // Navigate to the Notification History screen
  void _navigateToHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationHistoryScreen(history: _notificationHistory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Cloud Messaging Demo',
      home: Scaffold(
        appBar: AppBar(
          title: Text("FCM Demo"),
          actions: [
            Builder(
              builder: (context) {
                return IconButton(
                  icon: Icon(Icons.history),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            NotificationHistoryScreen(history: _notificationHistory),
                      ),
                    );
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
                Text(
                  "Copy this token and use it to test notifications.",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Screen to display notification history.
class NotificationHistoryScreen extends StatelessWidget {
  final List<NotificationItem> history;
  const NotificationHistoryScreen({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification History'),
      ),
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
