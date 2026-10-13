===== FILE: pubspec.yaml =====
name: lymon_chat
description: Lymon chat
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.4.0
  firebase_auth: ^5.2.0
  cloud_firestore: ^5.3.0
  firebase_storage: ^12.2.0
  google_sign_in: ^6.2.1
  image_picker: ^1.1.2
  file_picker: ^8.1.2
  record: ^5.1.2
  audioplayers: ^6.1.0
  path_provider: ^2.1.4
  url_launcher: ^6.3.0

flutter:
  uses-material-design: true

===== FILE: lib/main.dart =====
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

// =====================================================================
//  الألوان
// =====================================================================
const kGreen = Color(0xFF1E6B34);
const kLemon = Color(0xFFF4D31B);
const kLeaf = Color(0xFF8BC34A);
const kLogoBg = Color(0xFFF1F1F1);
const kBlue = Color(0xFF1DA1F2);
const kGold = Color(0xFFFFB800);

// =====================================================================
//  نماذج البيانات
// =====================================================================
class UserProfile {
  final String uid, name, email, role, badge; // role: user|admin  badge: none|blue|gold
  final bool banned;
  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.badge,
    required this.banned,
  });

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return UserProfile(
      uid: d.id,
      name: (m['name'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      role: (m['role'] ?? 'user') as String,
      badge: (m['badge'] ?? 'none') as String,
      banned: m['banned'] == true,
    );
  }

  bool get isAdmin => role == 'admin';
}

class Chat {
  final String id, name, lastMessage;
  final bool group;
  final List<String> members;
  final Map<String, String> names;
  final int updatedAt;
  Chat({
    required this.id,
    required this.name,
    required this.group,
    required this.members,
    required this.names,
    required this.lastMessage,
    required this.updatedAt,
  });

  factory Chat.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Chat(
      id: d.id,
      name: (m['name'] ?? '') as String,
      group: m['group'] == true,
      members: List<String>.from(m['members'] ?? const []),
      names: Map<String, String>.from(m['names'] ?? const {}),
      lastMessage: (m['lastMessage'] ?? '') as String,
      updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  String title(String myUid) {
    if (group) return name;
    final others = names.entries.where((e) => e.key != myUid);
    return others.isEmpty ? 'محادثة' : others.first.value;
  }

  String? otherUid(String myUid) {
    for (final m in members) {
      if (m != myUid) return m;
    }
    return null;
  }
}

class Msg {
  final String id, senderId, senderName, type, text, url; // type: text|image|gif|sticker|video|voice
  final int createdAt;
  Msg({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.text,
    required this.url,
    required this.createdAt,
  });

  factory Msg.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Msg(
      id: d.id,
      senderId: (m['senderId'] ?? '') as String,
      senderName: (m['senderName'] ?? '') as String,
      type: (m['type'] ?? 'text') as String,
      text: (m['text'] ?? '') as String,
      url: (m['url'] ?? '') as String,
      createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

// =====================================================================
//  Firebase
// =====================================================================
class Repo {
  static final auth = FirebaseAuth.instance;
  static final db = FirebaseFirestore.instance;
  static final storage = FirebaseStorage.instance;

  static Future<void> _ensureProfile(User u, String name) async {
    final ref = db.collection('users').doc(u.uid);
    final s = await ref.get();
    if (!s.exists) {
      await ref.set({
        'name': name,
        'email': u.email ?? '',
        'photo': u.photoURL ?? '',
        'role': 'user',
        'badge': 'none',
        'banned': false,
      });
    }
  }

  static Future<void> register(String name, String email, String pass) async {
    final c = await auth.createUserWithEmailAndPassword(email: email, password: pass);
    await _ensureProfile(c.user!, name);
  }

  static Future<void> login(String email, String pass) async {
    await auth.signInWithEmailAndPassword(email: email, password: pass);
  }

  static Future<void> google() async {
    final acc = await GoogleSignIn().signIn();
    if (acc == null) return;
    final a = await acc.authentication;
    final cred = GoogleAuthProvider.credential(accessToken: a.accessToken, idToken: a.idToken);
    final r = await auth.signInWithCredential(cred);
    await _ensureProfile(r.user!, r.user!.displayName ?? 'مستخدم');
  }

  static Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await auth.signOut();
  }

  static Stream<UserProfile?> profile(String uid) =>
      db.collection('users').doc(uid).snapshots().map((s) => s.exists ? UserProfile.fromDoc(s) : null);

  static Stream<List<UserProfile>> users() =>
      db.collection('users').snapshots().map((s) => s.docs.map(UserProfile.fromDoc).toList());

  static Stream<List<Chat>> chats(String uid) =>
      db.collection('chats').where('members', arrayContains: uid).snapshots().map((s) {
        final l = s.docs.map(Chat.fromDoc).toList();
        l.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return l;
      });

  static Stream<List<Msg>> messages(String chatId) => db
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Msg.fromDoc).toList());

  static Future<Chat> openDirect(UserProfile me, UserProfile other) async {
    final ids = [me.uid, other.uid]..sort();
    final id = ids.join('_');
    final names = {me.uid: me.name, other.uid: other.name};
    await db.collection('chats').doc(id).set({
      'group': false,
      'members': [me.uid, other.uid],
      'names': names,
    }, SetOptions(merge: true));
    return Chat(
      id: id, name: '', group: false, members: [me.uid, other.uid],
      names: names, lastMessage: '', updatedAt: 0,
    );
  }

  static Future<Chat> createGroup(String name, UserProfile me, List<UserProfile> others) async {
    final all = [me, ...others];
    final members = all.map((u) => u.uid).toList();
    final names = {for (final u in all) u.uid: u.name};
    final now = DateTime.now().millisecondsSinceEpoch;
    final ref = db.collection('chats').doc();
    await ref.set({
      'name': name,
      'group': true,
      'members': members,
      'names': names,
      'lastMessage': '',
      'updatedAt': now,
      'createdBy': me.uid,
    });
    return Chat(
      id: ref.id, name: name, group: true, members: members,
      names: names, lastMessage: '', updatedAt: now,
    );
  }

  static Future<void> send(String chatId, UserProfile me, String type,
      {String text = '', String url = ''}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final chatRef = db.collection('chats').doc(chatId);
    await chatRef.collection('messages').add({
      'senderId': me.uid,
      'senderName': me.name,
      'type': type,
      'text': text,
      'url': url,
      'createdAt': now,
    });
    const previews = {
      'image': '📷 صورة',
      'gif': 'GIF',
      'video': '🎬 فيديو',
      'voice': '🎤 رسالة صوتية',
    };
    final preview = (type == 'text' || type == 'sticker') ? text : (previews[type] ?? '');
    await chatRef.update({'lastMessage': preview, 'updatedAt': now});
  }

  static Future<String> upload(String chatId, File file) async {
    final ref = storage.ref('chats/$chatId/${DateTime.now().microsecondsSinceEpoch}');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  // ---- صلاحيات الإدارة ----
  static Future<void> setBadge(String uid, String badge) =>
      db.collection('users').doc(uid).update({'badge': badge});

  static Future<void> setBanned(String uid, bool banned) =>
      db.collection('users').doc(uid).update({'banned': banned});

  /// ترقية لمدير = role admin + علامة ذهبية. والإزالة ترجعه مستخدم عادي
  static Future<void> setAdmin(String uid, bool on) => db
      .collection('users')
      .doc(uid)
      .update({'role': on ? 'admin' : 'user', 'badge': on ? 'gold' : 'none'});
}

// =====================================================================
//  بداية التطبيق
// =====================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const LymonApp());
}

class LymonApp extends StatelessWidget {
  const LymonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lymon chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kGreen, primary: kGreen, secondary: kLemon),
        scaffoldBackgroundColor: Colors.white,
      ),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const Root(),
    );
  }
}

// =====================================================================
//  اللوجو (مرسوم بالكود) + عناصر مشتركة
// =====================================================================
class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final c = Offset(w * 0.40, w * 0.60);
    final r = w * 0.34;
    Paint fill(Color col) => Paint()..color = col;

    // ذيل الفقاعة
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.95, c.dy + r * 0.30)
        ..lineTo(c.dx - r * 1.08, c.dy + r * 1.18)
        ..lineTo(c.dx - r * 0.30, c.dy + r * 0.92)
        ..close(),
      fill(kGreen),
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.85, c.dy + r * 0.45)
        ..lineTo(c.dx - r * 0.90, c.dy + r * 1.00)
        ..lineTo(c.dx - r * 0.40, c.dy + r * 0.85)
        ..close(),
      fill(kLemon),
    );

    // الليمونة
    canvas.drawCircle(c, r, fill(kGreen));
    canvas.drawCircle(c, r * 0.88, fill(kLemon));
    canvas.drawCircle(c, r * 0.78, fill(const Color(0xFFEAF3C6)));
    canvas.drawCircle(c, r * 0.72, fill(kLemon));

    final line = Paint()
      ..color = const Color(0xFFFFF8D0)
      ..strokeWidth = w * 0.028;
    for (var i = 0; i < 8; i++) {
      final a = (i * 45 + 22.5) * math.pi / 180;
      canvas.drawLine(c, Offset(c.dx + math.cos(a) * r * 0.74, c.dy + math.sin(a) * r * 0.74), line);
    }
    canvas.drawCircle(c, r * 0.10, fill(const Color(0xFFF7FBE0)));
    for (var i = 0; i < 8; i++) {
      final a = i * 45 * math.pi / 180;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * r * 0.45, c.dy + math.sin(a) * r * 0.45),
        r * 0.055,
        fill(i.isEven ? kLeaf : const Color(0xFFFFF8D0)),
      );
    }

    // إشارة الواي فاي
    final o = Offset(c.dx + r * 0.78, c.dy - r * 0.78);
    for (final f in [0.30, 0.52, 0.74]) {
      canvas.drawArc(
        Rect.fromCircle(center: o, radius: r * f),
        -88 * math.pi / 180,
        76 * math.pi / 180,
        false,
        Paint()
          ..color = kLeaf
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.05
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LemonLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const LemonLogo({super.key, this.size = 180, this.showText = true});

  @override
  Widget build(BuildContext context) {
    final k = size / 180;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: Size(size, size), painter: _LogoPainter()),
        if (showText) ...[
          Text('Lymon',
              style: TextStyle(color: kGreen, fontSize: 44 * k, fontWeight: FontWeight.w800, height: 1.1)),
          Text('chat',
              style: TextStyle(color: kGreen, fontSize: 30 * k, fontWeight: FontWeight.w300, height: 1.1)),
        ],
      ],
    );
  }
}

/// علامة التوثيق: ذهبية للإدارة، زرقاء للموثقين
class VerifiedBadge extends StatelessWidget {
  final UserProfile? profile;
  final double size;
  const VerifiedBadge(this.profile, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final b = profile?.badge;
    if (b == 'gold') return Icon(Icons.verified, color: kGold, size: size);
    if (b == 'blue') return Icon(Icons.verified, color: kBlue, size: size);
    return const SizedBox.shrink();
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final double radius;
  const Avatar(this.name, {super.key, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final t = name.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: kLemon,
      child: Text(t.isEmpty ? '؟' : t.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
    );
  }
}

// =====================================================================
//  الجذر: انترو ثم دخول ثم التطبيق
// =====================================================================
class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool _splash = true;

  @override
  Widget build(BuildContext context) {
    if (_splash) return SplashScreen(onDone: () => setState(() => _splash = false));
    return StreamBuilder<User?>(
      stream: Repo.auth.authStateChanges(),
      initialData: Repo.auth.currentUser,
      builder: (context, snap) {
        final u = snap.data;
        if (u == null) return const AuthScreen();
        return SignedIn(key: ValueKey(u.uid), uid: u.uid);
      },
    );
  }
}

// =====================================================================
//  الانترو
// =====================================================================
class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 2300), widget.onDone);
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLogoBg,
      body: Center(
        child: FadeTransition(
          opacity: _c,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1.0)
                .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
            child: const LemonLogo(size: 260),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
//  تسجيل الدخول / إنشاء حساب
// =====================================================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false;
  bool _loading = false;
  String? _error;

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await job();
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? e.code;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const LemonLogo(size: 140),
                const SizedBox(height: 16),
                Text(_register ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_register) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'الرمز السري', border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading
                        ? null
                        : () {
                            final email = _email.text.trim();
                            final pass = _pass.text;
                            final name = _name.text.trim();
                            if (email.isEmpty || pass.length < 6 || (_register && name.isEmpty)) {
                              setState(() => _error = 'عبّي كل الحقول (الرمز 6 أحرف على الأقل)');
                              return;
                            }
                            _run(() => _register ? Repo.register(name, email, pass) : Repo.login(email, pass));
                          },
                    child: Text(_register ? 'إنشاء الحساب' : 'دخول'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _run(Repo.google),
                    child: const Text('المتابعة بحساب Google'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _register = !_register;
                    _error = null;
                  }),
                  child: Text(_register ? 'عندي حساب؟ سجّل دخول' : 'ما عندك حساب؟ أنشئ حساب'),
                ),
                if (_loading) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
//  بعد تسجيل الدخول: التنقل بين الشاشات
// =====================================================================
enum _Page { home, newChat, admin, room }

class SignedIn extends StatefulWidget {
  final String uid;
  const SignedIn({super.key, required this.uid});
  @override
  State<SignedIn> createState() => _SignedInState();
}

class _SignedInState extends State<SignedIn> {
  _Page _page = _Page.home;
  Chat? _room;

  void _go(_Page p, {Chat? room}) => setState(() {
        _page = p;
        _room = room;
      });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: Repo.profile(widget.uid),
      builder: (context, ps) {
        final me = ps.data;
        if (me == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (me.banned) {
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('تم حظر حسابك', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('تواصل مع إدارة Lymon chat إذا تعتقد أن هذا خطأ.'),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: Repo.logout, child: const Text('تسجيل الخروج')),
                ],
              ),
            ),
          );
        }
        return StreamBuilder<List<UserProfile>>(
          stream: Repo.users(),
          builder: (context, us) {
            final users = us.data ?? const <UserProfile>[];
            Widget body;
            switch (_page) {
              case _Page.home:
                body = HomeScreen(
                  me: me,
                  users: users,
                  onOpen: (c) => _go(_Page.room, room: c),
                  onNew: () => _go(_Page.newChat),
                  onAdmin: () => _go(_Page.admin),
                );
                break;
              case _Page.newChat:
                body = NewChatScreen(
                  me: me,
                  users: users,
                  onBack: () => _go(_Page.home),
                  onCreated: (c) => _go(_Page.room, room: c),
                );
                break;
              case _Page.admin:
                body = AdminScreen(me: me, users: users, onBack: () => _go(_Page.home));
                break;
              case _Page.room:
                body = ChatScreen(chat: _room!, me: me, users: users, onBack: () => _go(_Page.home));
                break;
            }
            return WillPopScope(
              onWillPop: () async {
                if (_page != _Page.home) {
                  _go(_Page.home);
                  return false;
                }
                return true;
              },
              child: body,
            );
          },
        );
      },
    );
  }
}

// =====================================================================
//  قائمة المحادثات
// =====================================================================
class HomeScreen extends StatelessWidget {
  final UserProfile me;
  final List<UserProfile> users;
  final void Function(Chat) onOpen;
  final VoidCallback onNew, onAdmin;
  const HomeScreen({
    super.key,
    required this.me,
    required this.users,
    required this.onOpen,
    required this.onNew,
    required this.onAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final u in users) u.uid: u};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lymon chat', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
        actions: [
          if (me.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: kGold),
              tooltip: 'لوحة الإدارة',
              onPressed: onAdmin,
            ),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'خروج', onPressed: Repo.logout),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        onPressed: onNew,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Chat>>(
        stream: Repo.chats(me.uid),
        builder: (context, snap) {
          final chats = snap.data ?? const <Chat>[];
          if (chats.isEmpty) {
            return const Center(child: Text('ما عندك محادثات بعد. اضغط + للبدء'));
          }
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = chats[i];
              final title = c.title(me.uid);
              return ListTile(
                leading: Avatar(title),
                title: Row(children: [
                  Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (!c.group) ...[
                    const SizedBox(width: 4),
                    VerifiedBadge(byId[c.otherUid(me.uid)]),
                  ],
                ]),
                subtitle: Text(c.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => onOpen(c),
              );
            },
          );
        },
      ),
    );
  }
}

// =====================================================================
//  محادثة جديدة: شخص واحد = خاصة، أكثر + اسم = قروب
// =====================================================================
class NewChatScreen extends StatefulWidget {
  final UserProfile me;
  final List<UserProfile> users;
  final VoidCallback onBack;
  final void Function(Chat) onCreated;
  const NewChatScreen({
    super.key,
    required this.me,
    required this.users,
    required this.onBack,
    required this.onCreated,
  });
  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _group = TextEditingController();
  final _query = TextEditingController();
  final Set<String> _sel = {};
  bool _busy = false;

  bool get _isGroup => _sel.length > 1 || _group.text.trim().isNotEmpty;
  bool get _canStart => _sel.isNotEmpty && (!_isGroup || _group.text.trim().isNotEmpty) && !_busy;

  Future<void> _start() async {
    setState(() => _busy = true);
    final chosen = widget.users.where((u) => _sel.contains(u.uid)).toList();
    final chat = _isGroup
        ? await Repo.createGroup(_group.text.trim(), widget.me, chosen)
        : await Repo.openDirect(widget.me, chosen.first);
    if (mounted) setState(() => _busy = false);
    widget.onCreated(chat);
  }

  @override
  void dispose() {
    _group.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final list = widget.users
        .where((u) => u.uid != widget.me.uid && !u.banned && u.name.toLowerCase().contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثة جديدة'),
        leading: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: widget.onBack),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _canStart ? _start : null,
          child: Text(_isGroup ? 'إنشاء القروب' : 'ابدأ المحادثة'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          TextField(
            controller: _group,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'اسم القروب (اتركه فاضي لمحادثة خاصة)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'ابحث بالاسم', border: OutlineInputBorder()),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final u in list)
                  CheckboxListTile(
                    value: _sel.contains(u.uid),
                    onChanged: (v) => setState(() => v == true ? _sel.add(u.uid) : _sel.remove(u.uid)),
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: Avatar(u.name, radius: 18),
                    title: Row(children: [
                      Flexible(child: Text(u.name)),
                      const SizedBox(width: 4),
                      VerifiedBadge(u),
                    ]),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// =====================================================================
//  لوحة الإدارة
// =====================================================================
class AdminScreen extends StatefulWidget {
  final UserProfile me;
  final List<UserProfile> users;
  final VoidCallback onBack;
  const AdminScreen({super.key, required this.me, required this.users, required this.onBack});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _act(String v, UserProfile u) async {
    switch (v) {
      case 'blue':
        await Repo.setBadge(u.uid, 'blue');
        break;
      case 'unblue':
        await Repo.setBadge(u.uid, 'none');
        break;
      case 'admin':
        await Repo.setAdmin(u.uid, true);
        break;
      case 'unadmin':
        await Repo.setAdmin(u.uid, false);
        break;
      case 'ban':
        await Repo.setBanned(u.uid, true);
        break;
      case 'unban':
        await Repo.setBanned(u.uid, false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final list = widget.users
        .where((u) => u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الإدارة'),
        leading: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: widget.onBack),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'ابحث بالاسم أو البريد', border: OutlineInputBorder()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('عدد المستخدمين: ${widget.users.length}'),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = list[i];
                final sub = u.email + (u.isAdmin ? ' • مدير' : '') + (u.banned ? ' • محظور' : '');
                return ListTile(
                  leading: Avatar(u.name, radius: 20),
                  title: Row(children: [
                    Flexible(child: Text(u.name)),
                    const SizedBox(width: 4),
                    VerifiedBadge(u),
                  ]),
                  subtitle: Text(sub),
                  trailing: u.uid == widget.me.uid
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (v) => _act(v, u),
                          itemBuilder: (_) => [
                            if (u.badge == 'blue')
                              const PopupMenuItem(value: 'unblue', child: Text('إزالة العلامة الزرقاء'))
                            else if (!u.isAdmin)
                              const PopupMenuItem(value: 'blue', child: Text('توثيق بعلامة زرقاء')),
                            if (u.isAdmin)
                              const PopupMenuItem(value: 'unadmin', child: Text('إزالة الإدارة'))
                            else
                              const PopupMenuItem(value: 'admin', child: Text('ترقية لمدير (علامة ذهبية)')),
                            PopupMenuItem(
                              value: u.banned ? 'unban' : 'ban',
                              child: Text(u.banned ? 'فك الحظر' : 'حظر المستخدم'),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// =====================================================================
//  شاشة المحادثة (نص، صور، GIF، فيديو، فويس، ملصقات)
// =====================================================================
const _stickers = [
  '😀', '😂', '🥰', '😎', '🤩', '😭', '😡', '😴', '🤔', '🙈',
  '👍', '👏', '🙏', '💪', '🤝', '🔥', '❤️', '🎉', '💯', '🍋',
];

class ChatScreen extends StatefulWidget {
  final Chat chat;
  final UserProfile me;
  final List<UserProfile> users;
  final VoidCallback onBack;
  const ChatScreen({
    super.key,
    required this.chat,
    required this.me,
    required this.users,
    required this.onBack,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _rec = AudioRecorder();
  bool _sending = false, _showStickers = false, _recording = false;
  String? _error;
  int _lastCount = 0;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() job) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await job();
    } catch (e) {
      _error = 'تعذر الإرسال: $e';
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _sendFile(File f, String type) => _guard(() async {
        final url = await Repo.upload(widget.chat.id, f);
        await Repo.send(widget.chat.id, widget.me, type, url: url);
      });

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) _sendFile(File(x.path), 'image');
  }

  Future<void> _pickVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (x != null) _sendFile(File(x.path), 'video');
  }

  Future<void> _pickGif() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['gif']);
    final p = r?.files.single.path;
    if (p != null) _sendFile(File(p), 'gif');
  }

  Future<void> _startRec() async {
    try {
      if (!await _rec.hasPermission()) {
        setState(() => _error = 'نحتاج إذن المايكروفون');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => _recording = true);
    } catch (e) {
      setState(() => _error = 'تعذر بدء التسجيل');
    }
  }

  Future<void> _stopRec() async {
    final path = await _rec.stop();
    setState(() => _recording = false);
    if (path != null) _sendFile(File(path), 'voice');
  }

  void _sendText() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    setState(() {});
    _guard(() => Repo.send(widget.chat.id, widget.me, 'text', text: t));
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat, me = widget.me;
    final byId = {for (final u in widget.users) u.uid: u};
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: widget.onBack),
        title: Row(children: [
          Avatar(chat.title(me.uid), radius: 18),
          const SizedBox(width: 10),
          Flexible(child: Text(chat.title(me.uid), overflow: TextOverflow.ellipsis)),
          if (!chat.group) ...[
            const SizedBox(width: 4),
            VerifiedBadge(byId[chat.otherUid(me.uid)]),
          ],
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<Msg>>(
            stream: Repo.messages(chat.id),
            builder: (context, snap) {
              final msgs = snap.data ?? const <Msg>[];
              if (msgs.length != _lastCount) {
                _lastCount = msgs.length;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
                });
              }
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(8),
                itemCount: msgs.length,
                itemBuilder: (context, i) {
                  final m = msgs[i];
                  final mine = m.senderId == me.uid;
                  return Align(
                    alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                    child: _Bubble(msg: m, mine: mine, group: chat.group, sender: byId[m.senderId]),
                  );
                },
              );
            },
          ),
        ),
        if (_sending) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_showStickers)
          Container(
            width: double.infinity,
            color: const Color(0xFFF6F6F6),
            padding: const EdgeInsets.all(8),
            child: Wrap(children: [
              for (final s in _stickers)
                InkWell(
                  onTap: () {
                    setState(() => _showStickers = false);
                    _guard(() => Repo.send(chat.id, me, 'sticker', text: s));
                  },
                  child: Padding(padding: const EdgeInsets.all(8), child: Text(s, style: const TextStyle(fontSize: 32))),
                ),
            ]),
          ),
        SafeArea(
          top: false,
          child: _recording
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.red),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('جاري التسجيل... اضغط ■ للإرسال')),
                    IconButton(icon: const Icon(Icons.stop, color: kGreen), onPressed: _stopRec),
                  ]),
                )
              : Row(children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.attach_file),
                    onSelected: (v) {
                      if (v == 'image') _pickImage();
                      if (v == 'gif') _pickGif();
                      if (v == 'video') _pickVideo();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'image', child: Text('صورة')),
                      PopupMenuItem(value: 'gif', child: Text('GIF')),
                      PopupMenuItem(value: 'video', child: Text('فيديو')),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    onPressed: () => setState(() => _showStickers = !_showStickers),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                  if (_text.text.trim().isEmpty)
                    IconButton(icon: const Icon(Icons.mic, color: kGreen), onPressed: _startRec)
                  else
                    IconButton(icon: const Icon(Icons.send, color: kGreen), onPressed: _sendText),
                ]),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Msg msg;
  final bool mine, group;
  final UserProfile? sender;
  const _Bubble({required this.msg, required this.mine, required this.group, required this.sender});

  @override
  Widget build(BuildContext context) {
    final senderRow = (group && !mine)
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Text(msg.senderName, style: const TextStyle(color: kGreen, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 3),
            VerifiedBadge(sender, size: 14),
          ])
        : null;

    if (msg.type == 'sticker') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [if (senderRow != null) senderRow, Text(msg.text, style: const TextStyle(fontSize: 56))],
        ),
      );
    }

    Widget content;
    switch (msg.type) {
      case 'image':
      case 'gif':
        content = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            msg.url,
            fit: BoxFit.cover,
            loadingBuilder: (c, child, p) => p == null
                ? child
                : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            errorBuilder: (c, e, s) => const Text('تعذر تحميل الصورة'),
          ),
        );
        break;
      case 'video':
        content = InkWell(
          onTap: () => launchUrl(Uri.parse(msg.url), mode: LaunchMode.externalApplication),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.play_circle_fill, color: kGreen, size: 40),
            SizedBox(width: 8),
            Text('تشغيل الفيديو'),
          ]),
        );
        break;
      case 'voice':
        content = _VoiceBubble(url: msg.url);
        break;
      default:
        content = Text(msg.text);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFFDDEFD9) : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [if (senderRow != null) senderRow, content],
      ),
    );
  }
}

class _VoiceBubble extends StatefulWidget {
  final String url;
  const _VoiceBubble({required this.url});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  bool _playing = false;
  StreamSubscription? _s1, _s2;

  @override
  void initState() {
    super.initState();
    _s1 = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    _s2 = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _s1?.cancel();
    _s2?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        icon: Icon(_playing ? Icons.pause : Icons.play_arrow, color: kGreen),
        onPressed: () async {
          if (_playing) {
            await _player.pause();
          } else if (_player.state == PlayerState.paused) {
            await _player.resume();
          } else {
            await _player.play(UrlSource(widget.url));
          }
        },
      ),
      const Text('🎤 رسالة صوتية'),
    ]);
  }
}

===== FILE: android/app/src/main/AndroidManifest.xml (أضف فقط هذي الأسطر) =====
<!-- داخل <manifest> وقبل <application> -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
</queries>
<!-- وغيّر android:label في <application> إلى "Lymon chat" -->

===== FILE: android/settings.gradle.kts (أضف داخل plugins { }) =====
id("com.google.gms.google-services") version "4.4.2" apply false

===== FILE: android/app/build.gradle.kts =====
// 1) داخل plugins { } أضف:
id("com.google.gms.google-services")
// 2) داخل defaultConfig { } غيّر minSdk إلى:
minSdk = 23

===== FILE: android/app/google-services.json =====
(نزّله من Firebase Console وحطه هنا — خاص بمشروعك)

===== (ليس ملف مشروع) الصقه في Firebase > Firestore > Rules ثم Publish =====
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function signedIn() { return request.auth != null; }
    function me() { return get(/databases/$(db)/documents/users/$(request.auth.uid)).data; }
    function isAdmin() { return signedIn() && me().role == 'admin'; }
    function notBanned() { return signedIn() && me().banned != true; }
    function isMember(chatId) {
      return request.auth.uid in get(/databases/$(db)/documents/chats/$(chatId)).data.members;
    }

    match /users/{uid} {
      allow read: if signedIn();
      allow create: if signedIn() && request.auth.uid == uid
        && request.resource.data.role == 'user'
        && request.resource.data.badge == 'none'
        && request.resource.data.banned == false;
      allow update: if isAdmin()
        || (request.auth.uid == uid
            && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['name', 'photo']));
    }

    match /chats/{chatId} {
      allow read: if notBanned() && (request.auth.uid in resource.data.members || isAdmin());
      allow create: if notBanned() && request.auth.uid in request.resource.data.members;
      allow update: if notBanned() && request.auth.uid in resource.data.members;

      match /messages/{mid} {
        allow read: if notBanned() && isMember(chatId);
        allow create: if notBanned() && isMember(chatId) && request.resource.data.senderId == request.auth.uid;
      }
    }
  }
}

===== (ليس ملف مشروع) الصقه في Firebase > Storage > Rules ثم Publish =====
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /chats/{chatId}/{file} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
        && request.resource.size < 50 * 1024 * 1024
        && firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.banned != true;
    }
  }
}