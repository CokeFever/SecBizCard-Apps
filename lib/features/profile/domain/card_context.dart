import 'package:freezed_annotation/freezed_annotation.dart';

part 'card_context.freezed.dart';
part 'card_context.g.dart';

enum ContextType { business, social, lite }

@freezed
class CardContext with _$CardContext {
  const factory CardContext({
    required ContextType type,
    @Default(true) bool showName,
    @Default(true) bool showEmail,
    @Default(true) bool showPhone,
    @Default(true) bool showTitle,
    @Default(true) bool showCompany,
    @Default(true) bool showAvatar,
    @Default(true) bool showCardFront,
    @Default(true) bool showCardBack,
    @Default({}) Map<String, bool> showCustomFields,
  }) = _CardContext;

  factory CardContext.fromJson(Map<String, dynamic> json) =>
      _$CardContextFromJson(json);

  /// Creates default contexts for a new user
  static Map<ContextType, CardContext> createDefaults() {
    return {
      ContextType.business: const CardContext(
        type: ContextType.business,
        showName: true,
        showEmail: true,
        showPhone: true,
        showTitle: true,
        showCompany: true,
        showAvatar: true,
        showCardFront: true,
        showCardBack: true,
      ),
      ContextType.social: const CardContext(
        type: ContextType.social,
        showName: true,
        showEmail: true,
        showPhone: true,
        showTitle: false,
        showCompany: false,
        showAvatar: true,
        showCardFront: false,
        showCardBack: false,
      ),
      ContextType.lite: const CardContext(
        type: ContextType.lite,
        showName: true,
        showEmail: true,
        showPhone: false,
        showTitle: false,
        showCompany: false,
        showAvatar: false,
        showCardFront: false,
        showCardBack: false,
      ),
    };
  }
}
