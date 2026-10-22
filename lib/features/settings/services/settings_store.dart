import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/day.dart';
import '../../vocab/services/srs_scheduler.dart';

/// Rendahnya pengaturan flashcard (nilai default SRS).
const int kMinNewPerSession = 5;
const int kMaxNewPerSession = 30;
const int kMinSessionCap = 10;
const int kMaxSessionCap = 50;
const int kMinDailyNewBudget = 5;
const int kMaxDailyNewBudget = 100;

/// Rentang pengaturan pola ulangan (SRS).
const int kMinFirstReview = 1;
const int kMaxFirstReview = 7;
const double kMinIntervalFactor = 1.5;
const double kMaxIntervalFactor = 3.0;
const int kMinMaxInterval = 14;
const int kMaxMaxInterval = 365;
const int kMinMatureDays = 7;
const int kMaxMatureDays = 90;

/// Snapshot pengaturan user.
class SettingsData {
  const SettingsData({
    this.newPerSession = kDefaultNewPerSession,
    this.sessionCap = kDefaultSessionCap,
    this.dailyNewBudget = kDefaultDailyNewBudget,
    this.autoSpeak = false,
    this.firstReviewDays = kDefaultFirstReviewDays,
    this.intervalFactor = kDefaultIntervalFactor,
    this.maxIntervalDays = kDefaultMaxIntervalDays,
    this.matureDays = kDefaultMatureDays,
  });

  static const int kDefaultNewPerSession = 10;
  static const int kDefaultSessionCap = 20;

  /// Jatah kata baru per hari; `0` berarti tidak dibatasi.
  static const int kDefaultDailyNewBudget = 0;

  /// Hari sebelum kartu baru dijadwalkan ulang setelah sukses pertama.
  static const int kDefaultFirstReviewDays = 1;

  /// Ease awal (pengali interval) untuk kartu baru.
  static const double kDefaultIntervalFactor = kDefaultEase;

  /// Cap interval review (hari).
  static const int kDefaultMaxIntervalDays = kMaxInterval;

  /// Ambang interval agar kartu dihitung "hafal" (hari).
  static const int kDefaultMatureDays = kMatureInterval;

  /// Batas maks kata baru per sesi.
  final int newPerSession;

  /// Batas maks kartu (review + baru) per sesi.
  final int sessionCap;

  /// Jatah kata baru per hari; `0` = tanpa batas.
  final int dailyNewBudget;

  /// Putar pengucapan otomatis saat kartu dibalik (bila TTS tersedia).
  final bool autoSpeak;

  /// Hari review pertama untuk kartu baru.
  final int firstReviewDays;

  /// Faktor naik interval (ease awal) untuk kartu baru.
  final double intervalFactor;

  /// Cap interval review (hari).
  final int maxIntervalDays;

  /// Ambang interval agar dihitung "hafal".
  final int matureDays;

  SettingsData copyWith({
    int? newPerSession,
    int? sessionCap,
    int? dailyNewBudget,
    bool? autoSpeak,
    int? firstReviewDays,
    double? intervalFactor,
    int? maxIntervalDays,
    int? matureDays,
  }) {
    return SettingsData(
      newPerSession: newPerSession ?? this.newPerSession,
      sessionCap: sessionCap ?? this.sessionCap,
      dailyNewBudget: dailyNewBudget ?? this.dailyNewBudget,
      autoSpeak: autoSpeak ?? this.autoSpeak,
      firstReviewDays: firstReviewDays ?? this.firstReviewDays,
      intervalFactor: intervalFactor ?? this.intervalFactor,
      maxIntervalDays: maxIntervalDays ?? this.maxIntervalDays,
      matureDays: matureDays ?? this.matureDays,
    );
  }
}

/// Penyimpanan pengaturan per-uid di SharedPreferences,
/// bersifat live (ValueNotifier) dan netral offline.
class SettingsStore extends ValueNotifier<SettingsData> {
  SettingsStore(this._prefs, this.uid) : super(const SettingsData());

  final SharedPreferences _prefs;
  final String uid;

  static String _key(String uid, String field) => 'settings.$uid.$field';
  static String _dailyKey(String uid, int day) =>
      'settings.$uid.daily_new.$day';

  /// Membaca nilai dari prefs (default = [SettingsData]).
  Future<void> load() async {
    value = SettingsData(
      newPerSession:
          _prefs.getInt(_key(uid, 'new_per_session')) ??
          SettingsData.kDefaultNewPerSession,
      sessionCap:
          _prefs.getInt(_key(uid, 'session_cap')) ??
          SettingsData.kDefaultSessionCap,
      dailyNewBudget:
          _prefs.getInt(_key(uid, 'daily_new_budget')) ??
          SettingsData.kDefaultDailyNewBudget,
      autoSpeak: _prefs.getBool(_key(uid, 'auto_speak')) ?? false,
      firstReviewDays:
          _prefs.getInt(_key(uid, 'first_review_days')) ??
          SettingsData.kDefaultFirstReviewDays,
      intervalFactor:
          _prefs.getDouble(_key(uid, 'interval_factor')) ??
          SettingsData.kDefaultIntervalFactor,
      maxIntervalDays:
          _prefs.getInt(_key(uid, 'max_interval_days')) ??
          SettingsData.kDefaultMaxIntervalDays,
      matureDays:
          _prefs.getInt(_key(uid, 'mature_days')) ??
          SettingsData.kDefaultMatureDays,
    );
  }

  Future<void> setNewPerSession(int v) async {
    final clamped = v.clamp(kMinNewPerSession, kMaxNewPerSession);
    await _prefs.setInt(_key(uid, 'new_per_session'), clamped);
    value = value.copyWith(newPerSession: clamped);
  }

  Future<void> setSessionCap(int v) async {
    final clamped = v.clamp(kMinSessionCap, kMaxSessionCap);
    await _prefs.setInt(_key(uid, 'session_cap'), clamped);
    value = value.copyWith(sessionCap: clamped);
  }

  Future<void> setDailyNewBudget(int v) async {
    final clamped = v.clamp(0, kMaxDailyNewBudget);
    await _prefs.setInt(_key(uid, 'daily_new_budget'), clamped);
    value = value.copyWith(dailyNewBudget: clamped);
  }

  Future<void> setAutoSpeak(bool v) async {
    await _prefs.setBool(_key(uid, 'auto_speak'), v);
    value = value.copyWith(autoSpeak: v);
  }

  Future<void> setFirstReviewDays(int v) async {
    final clamped = v.clamp(kMinFirstReview, kMaxFirstReview);
    await _prefs.setInt(_key(uid, 'first_review_days'), clamped);
    value = value.copyWith(firstReviewDays: clamped);
  }

  Future<void> setIntervalFactor(double v) async {
    final clamped = v.clamp(kMinIntervalFactor, kMaxIntervalFactor).toDouble();
    await _prefs.setDouble(_key(uid, 'interval_factor'), clamped);
    value = value.copyWith(intervalFactor: clamped);
  }

  Future<void> setMaxIntervalDays(int v) async {
    final clamped = v.clamp(kMinMaxInterval, kMaxMaxInterval);
    await _prefs.setInt(_key(uid, 'max_interval_days'), clamped);
    value = value.copyWith(maxIntervalDays: clamped);
  }

  Future<void> setMatureDays(int v) async {
    final clamped = v.clamp(kMinMatureDays, kMaxMatureDays);
    await _prefs.setInt(_key(uid, 'mature_days'), clamped);
    value = value.copyWith(matureDays: clamped);
  }

  /// Kata baru yang sudah diperkenalkan hari ini (lintas kategori).
  Future<int> introducedToday() async =>
      _prefs.getInt(_dailyKey(uid, epochDay(DateTime.now()))) ?? 0;

  /// Mencatat [count] kata baru yang diperkenalkan hari ini.
  Future<void> recordIntroduced(int count) async {
    final today = epochDay(DateTime.now());
    final prev = _prefs.getInt(_dailyKey(uid, today)) ?? 0;
    await _prefs.setInt(_dailyKey(uid, today), prev + count);
  }

  /// Batas kartu baru yang boleh masuk antrean sesi kali ini,
  /// sudah memperhitungkan sisa jatah harian (bila dinyalakan).
  Future<int> freshCapToday() async {
    final d = value;
    if (d.dailyNewBudget <= 0) return d.newPerSession;
    final remaining = d.dailyNewBudget - await introducedToday();
    return math.max(0, math.min(d.newPerSession, remaining));
  }
}
