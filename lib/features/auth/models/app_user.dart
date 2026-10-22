import 'package:characters/characters.dart';

/// Pengguna yang sudah masuk lewat Google. [uid] adalah Google user id
/// (stable) dan menjadi shard untuk seluruh data progres di Turso.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.photoUrl = '',
    this.idToken = '',
  });

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String idToken;

  String get initial {
    if (displayName.isNotEmpty) {
      return displayName.characters.first.toUpperCase();
    }
    if (email.isNotEmpty) {
      return email.characters.first.toUpperCase();
    }
    return '?';
  }

  bool get hasPhoto => photoUrl.isNotEmpty;

  @override
  bool operator ==(Object other) => other is AppUser && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}
