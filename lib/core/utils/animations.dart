/// Sakelar global animasi ambient. Dimatikan oleh pengujian widget karena
/// partikel melayang berulang tanpa henti akan membuat `pumpAndSettle`
/// tidak pernah tuntas (animasi lainnya tetap satu-kali / finite).
bool ambientEnabled = true;
