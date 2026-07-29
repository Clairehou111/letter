/// Opens the device dialer for an emergency contact.
///
/// Implementations must never hide the number: the sheet always renders the
/// number as visible text so a dialer failure leaves the manual path open.
library;

abstract class SafetyDialer {
  /// Attempts to open the dialer for [number]. Returns false when the dialer
  /// cannot be opened; callers keep the visible number as the fallback.
  Future<bool> call(String number);
}
