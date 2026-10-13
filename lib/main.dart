===== FILE: settings.gradle.kts =====
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "LymonChat"
include(":app")

===== FILE: build.gradle.kts =====
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

===== FILE: gradle.properties =====
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official

===== FILE: app/build.gradle.kts =====
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.lymon.chat"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.lymon.chat"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
    buildTypes { release { isMinifyEnabled = false } }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.1")

    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-storage-ktx")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")

    implementation("androidx.credentials:credentials:1.2.2")
    implementation("androidx.credentials:credentials-play-services-auth:1.2.2")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    implementation("io.coil-kt:coil-compose:2.6.0")
    implementation("io.coil-kt:coil-gif:2.6.0")
}

===== FILE: app/google-services.json =====
(نزّله من Firebase Console وحطه هنا — ما أقدر أكتبه لك لأنه خاص بمشروعك)

===== FILE: app/src/main/AndroidManifest.xml =====
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />

    <application
        android:allowBackup="true"
        android:icon="@drawable/lymon_icon"
        android:roundIcon="@drawable/lymon_icon"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.Lymon">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>

===== FILE: app/src/main/res/values/strings.xml =====
<resources>
    <string name="app_name">Lymon chat</string>
</resources>

===== FILE: app/src/main/res/values/themes.xml =====
<resources>
    <style name="Theme.Lymon" parent="android:Theme.Material.Light.NoActionBar">
        <item name="android:windowBackground">#F1F1F1</item>
        <item name="android:statusBarColor">#F1F1F1</item>
        <item name="android:navigationBarColor">#F1F1F1</item>
    </style>
</resources>

===== FILE: app/src/main/res/drawable/lymon_icon.xml =====
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#F1F1F1" android:pathData="M0,0h108v108h-108z" />
    <path android:fillColor="#1E6B34" android:pathData="M54,54m-36,0a36,36 0,1 1,72 0a36,36 0,1 1,-72 0" />
    <path android:fillColor="#F4D31B" android:pathData="M54,54m-30,0a30,30 0,1 1,60 0a30,30 0,1 1,-60 0" />
    <path android:strokeColor="#FFFFFF" android:strokeWidth="2.5" android:pathData="M54,26L54,82M26,54L82,54M34,34L74,74M74,34L34,74" />
</vector>

===== FILE: app/src/main/java/com/lymon/chat/MainActivity.kt =====
@file:OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)

package com.lymon.chat

import android.Manifest
import android.content.Intent
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import coil.ImageLoader
import coil.compose.AsyncImage
import coil.decode.GifDecoder
import coil.decode.ImageDecoderDecoder
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.storage.FirebaseStorage
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.io.File
import java.util.UUID
import kotlin.math.cos
import kotlin.math.sin

// =====================================================================
//  الألوان والثيم واللوجو (مرسوم بالكود)
// =====================================================================
val LymonGreen = Color(0xFF1E6B34)
val LymonLemon = Color(0xFFF4D31B)
val LeafGreen = Color(0xFF8BC34A)
val LogoBg = Color(0xFFF1F1F1)
val BlueBadge = Color(0xFF1DA1F2)
val GoldBadge = Color(0xFFFFB800)

@Composable
fun LymonTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = LymonGreen, onPrimary = Color.White,
            secondary = LymonLemon, onSecondary = Color.Black,
            primaryContainer = Color(0xFFDDEFD9),
            background = Color.White, surface = Color.White
        ),
        content = content
    )
}

/** لوجو Lymon chat: ليمونة داخل فقاعة محادثة + إشارة + اسم التطبيق */
@Composable
fun LemonLogo(modifier: Modifier = Modifier, size: Dp = 180.dp, showText: Boolean = true) {
    val k = size.value / 180f
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Canvas(Modifier.size(size)) {
            val w = this.size.width
            val c = Offset(w * 0.40f, w * 0.60f)
            val r = w * 0.34f

            // ذيل الفقاعة
            val tail = Path().apply {
                moveTo(c.x - r * 0.95f, c.y + r * 0.30f)
                lineTo(c.x - r * 1.08f, c.y + r * 1.18f)
                lineTo(c.x - r * 0.30f, c.y + r * 0.92f)
                close()
            }
            drawPath(tail, LymonGreen)
            drawPath(
                Path().apply {
                    moveTo(c.x - r * 0.85f, c.y + r * 0.45f)
                    lineTo(c.x - r * 0.90f, c.y + r * 1.00f)
                    lineTo(c.x - r * 0.40f, c.y + r * 0.85f)
                    close()
                }, LymonLemon
            )

            // الليمونة
            drawCircle(LymonGreen, r, c)
            drawCircle(LymonLemon, r * 0.88f, c)
            drawCircle(Color(0xFFEAF3C6), r * 0.78f, c)
            drawCircle(LymonLemon, r * 0.72f, c)
            for (i in 0 until 8) {
                val a = Math.toRadians(i * 45.0 + 22.5)
                drawLine(
                    Color(0xFFFFF8D0), c,
                    Offset(c.x + (cos(a) * r * 0.74f).toFloat(), c.y + (sin(a) * r * 0.74f).toFloat()),
                    strokeWidth = 5f * k
                )
            }
            drawCircle(Color(0xFFF7FBE0), r * 0.10f, c)
            for (i in 0 until 8) {
                val a = Math.toRadians(i * 45.0)
                drawCircle(
                    if (i % 2 == 0) LeafGreen else Color(0xFFFFF8D0), r * 0.055f,
                    Offset(c.x + (cos(a) * r * 0.45f).toFloat(), c.y + (sin(a) * r * 0.45f).toFloat())
                )
            }

            // إشارة الواي فاي
            val o = Offset(c.x + r * 0.78f, c.y - r * 0.78f)
            listOf(0.30f, 0.52f, 0.74f).forEach { f ->
                val rr = r * f
                drawArc(
                    LeafGreen, startAngle = -88f, sweepAngle = 76f, useCenter = false,
                    topLeft = Offset(o.x - rr, o.y - rr), size = Size(rr * 2, rr * 2),
                    style = Stroke(width = 9f * k, cap = StrokeCap.Round)
                )
            }
        }
        if (showText) {
            Text("Lymon", color = LymonGreen, fontSize = (44 * k).sp, fontWeight = FontWeight.ExtraBold)
            Text("chat", color = LymonGreen, fontSize = (30 * k).sp, fontWeight = FontWeight.Light)
        }
    }
}

/** علامة التوثيق: ذهبية للإدارة، زرقاء للموثقين */
@Composable
fun BadgeIcon(profile: UserProfile?, size: Dp = 16.dp) {
    val color = when (profile?.badge) {
        "gold" -> GoldBadge
        "blue" -> BlueBadge
        else -> return
    }
    Icon(Icons.Filled.Verified, contentDescription = "موثّق", tint = color, modifier = Modifier.size(size))
}

@Composable
fun Avatar(text: String, size: Int = 44) {
    Box(
        Modifier.size(size.dp).clip(CircleShape).background(LymonLemon),
        contentAlignment = Alignment.Center
    ) { Text(text.trim().take(1).uppercase(), color = LymonGreen, style = MaterialTheme.typography.titleMedium) }
}

// =====================================================================
//  نماذج البيانات + Firebase
// =====================================================================
data class UserProfile(
    val uid: String = "",
    val name: String = "",
    val email: String = "",
    val photo: String = "",
    val role: String = "user",      // user | admin
    val badge: String = "none",     // none | blue | gold
    val banned: Boolean = false
)

data class Chat(
    val id: String = "",
    val name: String = "",
    val group: Boolean = false,
    val members: List<String> = emptyList(),
    val names: Map<String, String> = emptyMap(),
    val lastMessage: String = "",
    val updatedAt: Long = 0
) {
    fun title(myUid: String): String =
        if (group) name else names.filterKeys { it != myUid }.values.firstOrNull() ?: "محادثة"
}

data class Message(
    val id: String = "",
    val senderId: String = "",
    val senderName: String = "",
    val type: String = "text",      // text | image | gif | sticker | video | voice
    val text: String = "",
    val url: String = "",
    val createdAt: Long = 0
)

object Repo {
    val auth = FirebaseAuth.getInstance()
    private val db = FirebaseFirestore.getInstance()
    private val storage = FirebaseStorage.getInstance()

    fun authFlow(): Flow<String?> = callbackFlow {
        val l = FirebaseAuth.AuthStateListener { trySend(it.currentUser?.uid) }
        auth.addAuthStateListener(l)
        awaitClose { auth.removeAuthStateListener(l) }
    }

    private suspend fun createProfileIfMissing(uid: String, name: String, email: String, photo: String) {
        val ref = db.collection("users").document(uid)
        if (!ref.get().await().exists()) {
            ref.set(
                mapOf(
                    "name" to name, "email" to email, "photo" to photo,
                    "role" to "user", "badge" to "none", "banned" to false
                )
            ).await()
        }
    }

    suspend fun register(name: String, email: String, pass: String) {
        val u = auth.createUserWithEmailAndPassword(email, pass).await().user!!
        createProfileIfMissing(u.uid, name, email, "")
    }

    suspend fun login(email: String, pass: String) {
        auth.signInWithEmailAndPassword(email, pass).await()
    }

    suspend fun googleLogin(idToken: String) {
        val u = auth.signInWithCredential(GoogleAuthProvider.getCredential(idToken, null)).await().user!!
        createProfileIfMissing(u.uid, u.displayName ?: "مستخدم", u.email ?: "", u.photoUrl?.toString() ?: "")
    }

    fun logout() = auth.signOut()

    fun profileFlow(uid: String): Flow<UserProfile?> = callbackFlow {
        val l = db.collection("users").document(uid).addSnapshotListener { s, _ ->
            trySend(if (s != null && s.exists()) s.toObject(UserProfile::class.java)?.copy(uid = s.id) else null)
        }
        awaitClose { l.remove() }
    }

    fun usersFlow(): Flow<List<UserProfile>> = callbackFlow {
        val l = db.collection("users").addSnapshotListener { s, _ ->
            trySend(s?.documents?.mapNotNull { d -> d.toObject(UserProfile::class.java)?.copy(uid = d.id) } ?: emptyList())
        }
        awaitClose { l.remove() }
    }

    fun chatsFlow(uid: String): Flow<List<Chat>> = callbackFlow {
        val l = db.collection("chats").whereArrayContains("members", uid).addSnapshotListener { s, _ ->
            val list = s?.documents?.mapNotNull { d -> d.toObject(Chat::class.java)?.copy(id = d.id) } ?: emptyList()
            trySend(list.sortedByDescending { it.updatedAt })
        }
        awaitClose { l.remove() }
    }

    fun messagesFlow(chatId: String): Flow<List<Message>> = callbackFlow {
        val l = db.collection("chats").document(chatId).collection("messages")
            .orderBy("createdAt").addSnapshotListener { s, _ ->
                trySend(s?.documents?.mapNotNull { d -> d.toObject(Message::class.java)?.copy(id = d.id) } ?: emptyList())
            }
        awaitClose { l.remove() }
    }

    suspend fun openDirect(me: UserProfile, other: UserProfile): Chat {
        val id = listOf(me.uid, other.uid).sorted().joinToString("_")
        val members = listOf(me.uid, other.uid)
        val names = mapOf(me.uid to me.name, other.uid to other.name)
        db.collection("chats").document(id)
            .set(mapOf("group" to false, "members" to members, "names" to names), SetOptions.merge()).await()
        return Chat(id = id, group = false, members = members, names = names)
    }

    suspend fun createGroup(name: String, me: UserProfile, others: List<UserProfile>): Chat {
        val all = listOf(me) + others
        val members = all.map { it.uid }
        val names = all.associate { it.uid to it.name }
        val now = System.currentTimeMillis()
        val ref = db.collection("chats").document()
        ref.set(
            mapOf(
                "name" to name, "group" to true, "members" to members, "names" to names,
                "lastMessage" to "", "updatedAt" to now, "createdBy" to me.uid
            )
        ).await()
        return Chat(id = ref.id, name = name, group = true, members = members, names = names)
    }

    suspend fun send(chatId: String, me: UserProfile, type: String, text: String = "", url: String = "") {
        val now = System.currentTimeMillis()
        val chatRef = db.collection("chats").document(chatId)
        chatRef.collection("messages").add(
            mapOf(
                "senderId" to me.uid, "senderName" to me.name, "type" to type,
                "text" to text, "url" to url, "createdAt" to now
            )
        ).await()
        val preview = when (type) {
            "text", "sticker" -> text
            "image" -> "📷 صورة"
            "gif" -> "GIF"
            "video" -> "🎬 فيديو"
            "voice" -> "🎤 رسالة صوتية"
            else -> ""
        }
        chatRef.update(mapOf("lastMessage" to preview, "updatedAt" to now)).await()
    }

    suspend fun upload(chatId: String, uri: Uri): String {
        val ref = storage.reference.child("chats/$chatId/${UUID.randomUUID()}")
        ref.putFile(uri).await()
        return ref.downloadUrl.await().toString()
    }

    // ---- صلاحيات الإدارة ----
    suspend fun setBadge(uid: String, badge: String) {
        db.collection("users").document(uid).update("badge", badge).await()
    }

    suspend fun setBanned(uid: String, banned: Boolean) {
        db.collection("users").document(uid).update("banned", banned).await()
    }

    /** ترقية لمدير = role admin + علامة ذهبية. والإزالة ترجعه مستخدم عادي */
    suspend fun setAdmin(uid: String, on: Boolean) {
        db.collection("users").document(uid)
            .update(mapOf("role" to if (on) "admin" else "user", "badge" to if (on) "gold" else "none")).await()
    }
}

// =====================================================================
//  الشاشة الرئيسية والتنقل
// =====================================================================
sealed class Screen {
    object Home : Screen()
    object NewChat : Screen()
    object Admin : Screen()
    data class Room(val chat: Chat) : Screen()
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { LymonTheme { App() } }
    }
}

@Composable
fun App() {
    var showSplash by remember { mutableStateOf(true) }
    val uid by Repo.authFlow().collectAsState(initial = Repo.auth.currentUser?.uid)
    when {
        showSplash -> SplashScreen { showSplash = false }
        uid == null -> AuthScreen()
        else -> SignedIn(uid!!)
    }
}

@Composable
fun SignedIn(uid: String) {
    val profile by remember(uid) { Repo.profileFlow(uid) }.collectAsState(initial = null)
    val users by remember { Repo.usersFlow() }.collectAsState(initial = emptyList())
    val me = profile

    if (me == null) {
        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
        return
    }
    if (me.banned) {
        Column(
            Modifier.fillMaxSize().padding(32.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("تم حظر حسابك", style = MaterialTheme.typography.headlineSmall)
            Spacer(Modifier.height(8.dp))
            Text("تواصل مع إدارة Lymon chat إذا تعتقد أن هذا خطأ.")
            Spacer(Modifier.height(24.dp))
            Button(onClick = { Repo.logout() }) { Text("تسجيل الخروج") }
        }
        return
    }

    var screen by remember { mutableStateOf<Screen>(Screen.Home) }
    BackHandler(enabled = screen != Screen.Home) { screen = Screen.Home }

    when (val s = screen) {
        Screen.Home -> HomeScreen(
            me = me, users = users,
            onOpen = { screen = Screen.Room(it) },
            onNew = { screen = Screen.NewChat },
            onAdmin = { screen = Screen.Admin }
        )
        Screen.NewChat -> NewChatScreen(
            me = me, users = users,
            onBack = { screen = Screen.Home },
            onCreated = { screen = Screen.Room(it) }
        )
        Screen.Admin -> AdminScreen(me = me, users = users, onBack = { screen = Screen.Home })
        is Screen.Room -> ChatScreen(chat = s.chat, me = me, users = users, onBack = { screen = Screen.Home })
    }
}

// =====================================================================
//  الانترو
// =====================================================================
@Composable
fun SplashScreen(onDone: () -> Unit) {
    val scale = remember { Animatable(0.6f) }
    val alpha = remember { Animatable(0f) }

    LaunchedEffect(Unit) {
        launch { scale.animateTo(1f, tween(900, easing = FastOutSlowInEasing)) }
        launch { alpha.animateTo(1f, tween(900)) }
        delay(2300)
        onDone()
    }

    Box(Modifier.fillMaxSize().background(LogoBg), contentAlignment = Alignment.Center) {
        Box(Modifier.graphicsLayer {
            scaleX = scale.value
            scaleY = scale.value
            this.alpha = alpha.value
        }) { LemonLogo(size = 260.dp) }
    }
}

// =====================================================================
//  تسجيل الدخول / إنشاء حساب
// =====================================================================
@Composable
fun AuthScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var isRegister by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var pass by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }

    fun run(block: suspend () -> Unit) {
        scope.launch {
            loading = true; error = null
            try { block() } catch (e: Exception) { error = e.localizedMessage ?: "حدث خطأ" }
            loading = false
        }
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        LemonLogo(size = 140.dp)
        Spacer(Modifier.height(16.dp))
        Text(if (isRegister) "إنشاء حساب جديد" else "تسجيل الدخول", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(16.dp))

        if (isRegister) {
            OutlinedTextField(name, { name = it }, label = { Text("الاسم") }, singleLine = true, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
        }
        OutlinedTextField(email, { email = it }, label = { Text("البريد الإلكتروني") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            pass, { pass = it }, label = { Text("الرمز السري") }, singleLine = true,
            visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth()
        )
        error?.let { Spacer(Modifier.height(8.dp)); Text(it, color = MaterialTheme.colorScheme.error) }
        Spacer(Modifier.height(16.dp))

        Button(
            enabled = !loading && email.isNotBlank() && pass.length >= 6 && (!isRegister || name.isNotBlank()),
            modifier = Modifier.fillMaxWidth(),
            onClick = {
                run { if (isRegister) Repo.register(name.trim(), email.trim(), pass) else Repo.login(email.trim(), pass) }
            }
        ) { Text(if (isRegister) "إنشاء الحساب" else "دخول") }

        OutlinedButton(
            enabled = !loading, modifier = Modifier.fillMaxWidth(),
            onClick = {
                run {
                    val option = GetGoogleIdOption.Builder()
                        .setFilterByAuthorizedAccounts(false)
                        .setServerClientId(ctx.getString(R.string.default_web_client_id))
                        .build()
                    val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
                    val result = CredentialManager.create(ctx).getCredential(ctx, request)
                    val token = GoogleIdTokenCredential.createFrom(result.credential.data).idToken
                    Repo.googleLogin(token)
                }
            }
        ) { Text("المتابعة بحساب Google") }

        TextButton(onClick = { isRegister = !isRegister; error = null }) {
            Text(if (isRegister) "عندي حساب؟ سجّل دخول" else "ما عندك حساب؟ أنشئ حساب")
        }
        if (loading) LinearProgressIndicator(Modifier.fillMaxWidth())
    }
}

// =====================================================================
//  قائمة المحادثات + محادثة جديدة
// =====================================================================
@Composable
fun HomeScreen(
    me: UserProfile, users: List<UserProfile>,
    onOpen: (Chat) -> Unit, onNew: () -> Unit, onAdmin: () -> Unit
) {
    val chats by remember(me.uid) { Repo.chatsFlow(me.uid) }.collectAsState(initial = emptyList())
    val byId = users.associateBy { it.uid }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Image(painterResource(R.drawable.lymon_icon), null, Modifier.size(32.dp).clip(CircleShape))
                        Spacer(Modifier.width(8.dp))
                        Text("Lymon chat", color = LymonGreen)
                    }
                },
                actions = {
                    if (me.role == "admin") {
                        IconButton(onClick = onAdmin) { Icon(Icons.Filled.AdminPanelSettings, "لوحة الإدارة", tint = GoldBadge) }
                    }
                    IconButton(onClick = { Repo.logout() }) { Icon(Icons.AutoMirrored.Filled.Logout, "خروج") }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onNew, containerColor = LymonGreen, contentColor = Color.White) {
                Icon(Icons.Filled.Add, "محادثة جديدة")
            }
        }
    ) { pad ->
        if (chats.isEmpty()) {
            Box(Modifier.fillMaxSize().padding(pad), Alignment.Center) { Text("ما عندك محادثات بعد. اضغط + للبدء") }
        } else LazyColumn(Modifier.padding(pad)) {
            items(chats, key = { it.id }) { chat ->
                val title = chat.title(me.uid)
                val otherUid = chat.members.firstOrNull { it != me.uid }
                Row(
                    Modifier.fillMaxWidth().clickable { onOpen(chat) }.padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Avatar(title)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(title, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            if (!chat.group) { Spacer(Modifier.width(4.dp)); BadgeIcon(byId[otherUid]) }
                        }
                        Text(
                            chat.lastMessage, maxLines = 1, overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                HorizontalDivider()
            }
        }
    }
}

/** اختر شخص واحد = محادثة خاصة، أكثر من شخص + اسم = قروب */
@Composable
fun NewChatScreen(me: UserProfile, users: List<UserProfile>, onBack: () -> Unit, onCreated: (Chat) -> Unit) {
    val scope = rememberCoroutineScope()
    var groupName by remember { mutableStateOf("") }
    var query by remember { mutableStateOf("") }
    var selected by remember { mutableStateOf(setOf<String>()) }
    var busy by remember { mutableStateOf(false) }
    val list = users.filter { it.uid != me.uid && !it.banned && it.name.contains(query, ignoreCase = true) }
    val isGroup = selected.size > 1 || groupName.isNotBlank()
    val canStart = selected.isNotEmpty() && (!isGroup || groupName.isNotBlank()) && !busy

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("محادثة جديدة") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "رجوع") } }
            )
        },
        bottomBar = {
            Button(
                enabled = canStart,
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                onClick = {
                    scope.launch {
                        busy = true
                        val chosen = users.filter { it.uid in selected }
                        val chat = if (isGroup) Repo.createGroup(groupName.trim(), me, chosen)
                        else Repo.openDirect(me, chosen.first())
                        busy = false
                        onCreated(chat)
                    }
                }
            ) { Text(if (isGroup) "إنشاء القروب" else "ابدأ المحادثة") }
        }
    ) { pad ->
        Column(Modifier.padding(pad).padding(horizontal = 16.dp)) {
            OutlinedTextField(
                groupName, { groupName = it }, label = { Text("اسم القروب (اتركه فاضي لمحادثة خاصة)") },
                singleLine = true, modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                query, { query = it }, label = { Text("ابحث بالاسم") },
                singleLine = true, modifier = Modifier.fillMaxWidth()
            )
            LazyColumn {
                items(list, key = { it.uid }) { u ->
                    Row(
                        Modifier.fillMaxWidth().clickable {
                            selected = if (u.uid in selected) selected - u.uid else selected + u.uid
                        }.padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Checkbox(checked = u.uid in selected, onCheckedChange = null)
                        Spacer(Modifier.width(8.dp))
                        Avatar(u.name, 36)
                        Spacer(Modifier.width(8.dp))
                        Text(u.name); Spacer(Modifier.width(4.dp)); BadgeIcon(u)
                    }
                }
            }
        }
    }
}

// =====================================================================
//  لوحة الإدارة
// =====================================================================
@Composable
fun AdminScreen(me: UserProfile, users: List<UserProfile>, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var query by remember { mutableStateOf("") }
    val list = users.filter { it.name.contains(query, true) || it.email.contains(query, true) }

    Scaffold(topBar = {
        TopAppBar(
            title = { Text("لوحة الإدارة") },
            navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "رجوع") } }
        )
    }) { pad ->
        Column(Modifier.padding(pad).padding(horizontal = 16.dp)) {
            OutlinedTextField(
                query, { query = it }, label = { Text("ابحث بالاسم أو البريد") },
                singleLine = true, modifier = Modifier.fillMaxWidth()
            )
            Text("عدد المستخدمين: ${users.size}", modifier = Modifier.padding(vertical = 8.dp))
            LazyColumn {
                items(list, key = { it.uid }) { u ->
                    var menu by remember { mutableStateOf(false) }
                    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Avatar(u.name, 40)
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(u.name, style = MaterialTheme.typography.titleSmall)
                                Spacer(Modifier.width(4.dp)); BadgeIcon(u)
                            }
                            Text(
                                u.email + (if (u.role == "admin") " • مدير" else "") + (if (u.banned) " • محظور" else ""),
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                        if (u.uid != me.uid) {
                            Box {
                                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, "خيارات") }
                                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                                    if (u.badge == "blue") {
                                        DropdownMenuItem(text = { Text("إزالة العلامة الزرقاء") },
                                            onClick = { menu = false; scope.launch { Repo.setBadge(u.uid, "none") } })
                                    } else if (u.role != "admin") {
                                        DropdownMenuItem(text = { Text("توثيق بعلامة زرقاء") },
                                            onClick = { menu = false; scope.launch { Repo.setBadge(u.uid, "blue") } })
                                    }
                                    if (u.role == "admin") {
                                        DropdownMenuItem(text = { Text("إزالة الإدارة") },
                                            onClick = { menu = false; scope.launch { Repo.setAdmin(u.uid, false) } })
                                    } else {
                                        DropdownMenuItem(text = { Text("ترقية لمدير (علامة ذهبية)") },
                                            onClick = { menu = false; scope.launch { Repo.setAdmin(u.uid, true) } })
                                    }
                                    DropdownMenuItem(
                                        text = { Text(if (u.banned) "فك الحظر" else "حظر المستخدم") },
                                        onClick = { menu = false; scope.launch { Repo.setBanned(u.uid, !u.banned) } }
                                    )
                                }
                            }
                        }
                    }
                    HorizontalDivider()
                }
            }
        }
    }
}

// =====================================================================
//  شاشة المحادثة (نص، صور، GIF، فيديو، فويس، ملصقات)
// =====================================================================
private val STICKERS = listOf(
    "😀", "😂", "🥰", "😎", "🤩", "😭", "😡", "😴", "🤔", "🙈",
    "👍", "👏", "🙏", "💪", "🤝", "🔥", "❤️", "🎉", "💯", "🍋"
)

@Composable
fun ChatScreen(chat: Chat, me: UserProfile, users: List<UserProfile>, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val messages by remember(chat.id) { Repo.messagesFlow(chat.id) }.collectAsState(initial = emptyList())
    val byId = users.associateBy { it.uid }
    val listState = rememberLazyListState()

    var text by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    var showStickers by remember { mutableStateOf(false) }
    var attachMenu by remember { mutableStateOf(false) }
    var pendingType by remember { mutableStateOf("image") }
    var error by remember { mutableStateOf<String?>(null) }

    val loader = remember {
        ImageLoader.Builder(ctx).components {
            if (Build.VERSION.SDK_INT >= 28) add(ImageDecoderDecoder.Factory()) else add(GifDecoder.Factory())
        }.build()
    }

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) listState.animateScrollToItem(messages.lastIndex)
    }

    fun safe(block: suspend () -> Unit) {
        scope.launch {
            sending = true; error = null
            try { block() } catch (e: Exception) { error = e.localizedMessage ?: "تعذر الإرسال" }
            sending = false
        }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri != null) safe {
            val url = Repo.upload(chat.id, uri)
            Repo.send(chat.id, me, pendingType, url = url)
        }
    }
    fun pick(type: String, mime: String) { pendingType = type; attachMenu = false; picker.launch(mime) }

    // ---- تسجيل الصوت ----
    var recorder by remember { mutableStateOf<MediaRecorder?>(null) }
    var recFile by remember { mutableStateOf<File?>(null) }

    fun startRec() {
        try {
            val f = File(ctx.cacheDir, "voice_${System.currentTimeMillis()}.m4a")
            val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(ctx) else @Suppress("DEPRECATION") MediaRecorder()
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setOutputFile(f.absolutePath)
            r.prepare(); r.start()
            recorder = r; recFile = f
        } catch (e: Exception) { error = "تعذر بدء التسجيل" }
    }

    fun stopRec() {
        val r = recorder; val f = recFile
        recorder = null; recFile = null
        if (r == null || f == null) return
        val ok = try { r.stop(); true } catch (e: Exception) { false }
        r.release()
        if (ok) safe {
            val url = Repo.upload(chat.id, Uri.fromFile(f))
            Repo.send(chat.id, me, "voice", url = url)
            f.delete()
        }
    }

    val micPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) startRec() else error = "نحتاج إذن المايكروفون"
    }
    DisposableEffect(Unit) { onDispose { try { recorder?.release() } catch (_: Exception) {} } }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Avatar(chat.title(me.uid), 36)
                        Spacer(Modifier.width(10.dp))
                        Text(chat.title(me.uid))
                        if (!chat.group) {
                            Spacer(Modifier.width(4.dp))
                            BadgeIcon(byId[chat.members.firstOrNull { it != me.uid }])
                        }
                    }
                },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "رجوع") } }
            )
        },
        bottomBar = {
            Column(Modifier.navigationBarsPadding().imePadding()) {
                if (sending) LinearProgressIndicator(Modifier.fillMaxWidth())
                error?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(horizontal = 16.dp)) }

                if (showStickers) {
                    FlowRow(Modifier.fillMaxWidth().background(Color(0xFFF6F6F6)).padding(8.dp)) {
                        STICKERS.forEach { s ->
                            Text(s, fontSize = 32.sp, modifier = Modifier.clickable {
                                showStickers = false
                                safe { Repo.send(chat.id, me, "sticker", text = s) }
                            }.padding(8.dp))
                        }
                    }
                }

                if (recorder != null) {
                    Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.FiberManualRecord, null, tint = Color.Red)
                        Spacer(Modifier.width(8.dp))
                        Text("جاري التسجيل... اضغط ■ للإرسال", Modifier.weight(1f))
                        IconButton(onClick = { stopRec() }) { Icon(Icons.Filled.Stop, "إرسال", tint = LymonGreen) }
                    }
                } else {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box {
                            IconButton(onClick = { attachMenu = true }) { Icon(Icons.Filled.AttachFile, "إرفاق") }
                            DropdownMenu(expanded = attachMenu, onDismissRequest = { attachMenu = false }) {
                                DropdownMenuItem(text = { Text("صورة" ) }, leadingIcon = { Icon(Icons.Filled.Image, null) },
                                    onClick = { pick("image", "image/*") })
                                DropdownMenuItem(text = { Text("GIF") }, leadingIcon = { Icon(Icons.Filled.Gif, null) },
                                    onClick = { pick("gif", "image/gif") })
                                DropdownMenuItem(text = { Text("فيديو") }, leadingIcon = { Icon(Icons.Filled.Videocam, null) },
                                    onClick = { pick("video", "video/*") })
                            }
                        }
                        IconButton(onClick = { showStickers = !showStickers }) { Icon(Icons.Filled.EmojiEmotions, "ملصقات") }
                        OutlinedTextField(
                            text, { text = it }, modifier = Modifier.weight(1f),
                            placeholder = { Text("اكتب رسالة") }, maxLines = 4,
                            shape = RoundedCornerShape(24.dp)
                        )
                        if (text.isBlank()) {
                            IconButton(onClick = { micPermission.launch(Manifest.permission.RECORD_AUDIO) }) {
                                Icon(Icons.Filled.Mic, "تسجيل صوتي", tint = LymonGreen)
                            }
                        } else {
                            IconButton(onClick = {
                                val t = text.trim(); text = ""
                                safe { Repo.send(chat.id, me, "text", text = t) }
                            }) { Icon(Icons.AutoMirrored.Filled.Send, "إرسال", tint = LymonGreen) }
                        }
                    }
                }
            }
        }
    ) { pad ->
        LazyColumn(Modifier.padding(pad).fillMaxSize().padding(horizontal = 8.dp), state = listState) {
            items(messages, key = { it.id }) { m ->
                val mine = m.senderId == me.uid
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 3.dp),
                    horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start
                ) {
                    if (m.type == "sticker") {
                        Column {
                            if (chat.group && !mine) SenderName(m, byId[m.senderId])
                            Text(m.text, fontSize = 56.sp)
                        }
                    } else {
                        Column(
                            Modifier.widthIn(max = 280.dp).clip(RoundedCornerShape(16.dp))
                                .background(if (mine) Color(0xFFDDEFD9) else Color(0xFFF1F1F1)).padding(10.dp)
                        ) {
                            if (chat.group && !mine) SenderName(m, byId[m.senderId])
                            when (m.type) {
                                "image", "gif" -> AsyncImage(
                                    model = m.url, imageLoader = loader, contentDescription = null,
                                    contentScale = ContentScale.FillWidth,
                                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp))
                                )
                                "video" -> Row(
                                    Modifier.clickable {
                                        try {
                                            ctx.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(Uri.parse(m.url), "video/*"))
                                        } catch (_: Exception) {}
                                    }.padding(4.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(Icons.Filled.PlayCircle, null, tint = LymonGreen, modifier = Modifier.size(40.dp))
                                    Spacer(Modifier.width(8.dp)); Text("تشغيل الفيديو")
                                }
                                "voice" -> VoiceBubble(m.url)
                                else -> Text(m.text)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SenderName(m: Message, profile: UserProfile?) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(m.senderName, style = MaterialTheme.typography.labelMedium, color = LymonGreen)
        Spacer(Modifier.width(3.dp)); BadgeIcon(profile, 14.dp)
    }
}

@Composable
private fun VoiceBubble(url: String) {
    var playing by remember { mutableStateOf(false) }
    var prepared by remember { mutableStateOf(false) }
    val player = remember { MediaPlayer() }
    DisposableEffect(url) { onDispose { try { player.release() } catch (_: Exception) {} } }

    Row(verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = {
            try {
                if (playing) { player.pause(); playing = false }
                else if (prepared) { player.start(); playing = true }
                else {
                    player.setDataSource(url)
                    player.setOnPreparedListener { prepared = true; it.start(); playing = true }
                    player.setOnCompletionListener { playing = false; it.seekTo(0) }
                    player.prepareAsync()
                }
            } catch (_: Exception) { playing = false }
        }) {
            Icon(if (playing) Icons.Filled.Pause else Icons.Filled.PlayArrow, "تشغيل", tint = LymonGreen)
        }
        Text("🎤 رسالة صوتية")
    }
}

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