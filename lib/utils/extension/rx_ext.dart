import 'package:get/get_rx/src/rx_types/rx_types.dart' show RxList;

extension RxListExt<E> on RxList<E> {
  void fillRangeOnly(int start, int end, [E? fill]) {
    E fillValue = fill as E;
    // This helper intentionally mutates without notifying listeners on every
    // item; the caller advances its visible trim index separately.
    // ignore: invalid_use_of_protected_member
    final values = value;
    for (int i = start; i < end; i++) {
      values[i] = fillValue;
    }
  }
}
