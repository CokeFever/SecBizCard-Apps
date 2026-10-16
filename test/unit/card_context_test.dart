import 'package:flutter_test/flutter_test.dart';
import 'package:secbizcard/features/profile/domain/card_context.dart';

/// FEAT-004: CardContext gains `showDepartment` so department can be gated per
/// context. These lock the serialization-sensitive behaviors: a toJson/fromJson
/// round-trip preserves showDepartment, a legacy map missing the key defaults to
/// true, and createDefaults applies the per-context defaults (business shows,
/// social/lite hide).
void main() {
  test('toJson/fromJson round-trips with showDepartment intact', () {
    const context = CardContext(
      type: ContextType.business,
      showDepartment: false,
    );

    final restored = CardContext.fromJson(context.toJson());

    expect(restored.showDepartment, isFalse);
    expect(restored, equals(context));
  });

  test('fromJson of a map missing showDepartment yields default true', () {
    final context = CardContext.fromJson(const {
      'type': 'business',
      'showName': true,
      'showEmail': true,
    });

    expect(context.showDepartment, isTrue);
  });

  test('createDefaults yields business=true, social=false, lite=false', () {
    final defaults = CardContext.createDefaults();

    expect(defaults[ContextType.business]!.showDepartment, isTrue);
    expect(defaults[ContextType.social]!.showDepartment, isFalse);
    expect(defaults[ContextType.lite]!.showDepartment, isFalse);
  });
}
