// Tombol Google untuk web; hanya dirender di platform JS.
// Non-web memakai tombol custom di LoginPage (guard `kIsWeb`), jadi
// implementasi stub di sini tidak pernah dipakai — tapi tetap dibutuhkan
// supaya build VM/Android tidak mengimpor `dart:ui_web`.
export 'google_web_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_web_sign_in_button_web.dart';
