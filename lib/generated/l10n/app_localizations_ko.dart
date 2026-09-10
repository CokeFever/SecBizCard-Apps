// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'SecBizCard';

  @override
  String get loginSlogan => '안전하게. 프로페셔널하게. 즉시.';

  @override
  String get signInWithGoogle => 'Google로 로그인';

  @override
  String get signInWithApple => 'Apple로 로그인';

  @override
  String orSignInWith(String provider) {
    return '또는 $provider(으)로 로그인';
  }

  @override
  String get profileTitle => '프로필';

  @override
  String get editProfile => '프로필 편집';

  @override
  String get onboardingWelcome => 'SecBizCard에 오신 것을 환영합니다';

  @override
  String get ocrRecognizingCloudVision => 'Cloud Vision으로 인식 중…';

  @override
  String get ocrRecognizingOnDevice => '기기에서 인식 중…';

  @override
  String get ocrSourceCloudVisionOwn => 'Cloud Vision · 내 키';

  @override
  String ocrSourceCloudVisionShared(int used, int cap) {
    return 'Cloud Vision · 이번 달 $used/$cap';
  }

  @override
  String get ocrSourceOnDevice => '기기 내 인식';

  @override
  String get aiRecognitionTitle => 'AI 인식';

  @override
  String get ocrUsingOwnKey => '내 Cloud Vision 키 사용';

  @override
  String get ocrUsingOwnKeyDesc => '최고 품질. 본인의 Google Cloud 계정으로 청구됩니다.';

  @override
  String get ocrUsingSharedQuota => '공유 할당량 사용';

  @override
  String ocrUsingSharedQuotaDesc(int perUser) {
    return '무료 AI 스캔은 월 $perUser회까지 제공되며, 이후에는 빠른 기기 내 인식으로 전환됩니다. 무제한 최고 품질 스캔을 원하시면 아래에 본인의 키를 추가하세요.';
  }

  @override
  String ocrUsageThisMonth(int used, int cap) {
    return '이번 달: $used / $cap';
  }

  @override
  String get ocrOwnKeyNearLimitWarn =>
      '월 무료 사용량의 80% 이상을 사용했습니다. 이번 달에 추가로 스캔하면 Google Cloud 계정에 요금이 부과될 수 있습니다.';

  @override
  String get ocrUseOwnKeyHeading => '내 API 키 사용';

  @override
  String get ocrUpdateOwnKeyHeading => 'API 키 업데이트';

  @override
  String get ocrKeyHint => 'Cloud Vision API 키를 붙여넣기';

  @override
  String get ocrKeySaved => 'Cloud Vision 키를 이 기기에 안전하게 저장했습니다.';

  @override
  String get ocrKeyRemoved => 'Cloud Vision 키를 이 기기에서 삭제했습니다.';

  @override
  String get ocrKeyMasked => '이 기기에 키가 저장되어 있습니다.';

  @override
  String get save => '저장';

  @override
  String get update => '업데이트';

  @override
  String get remove => '삭제';

  @override
  String get cancel => '취소';

  @override
  String get ocrReplaceKeyTitle => '저장된 키를 교체할까요?';

  @override
  String get ocrReplaceKeyBody => '이 기기에 현재 저장된 API 키를 덮어씁니다.';

  @override
  String get ocrRemoveKeyTitle => '저장된 키를 삭제할까요?';

  @override
  String get ocrRemoveKeyBody =>
      '이 기기는 공유 월 할당량 사용으로 돌아갑니다. 키는 언제든지 다시 추가할 수 있습니다.';

  @override
  String get ocrHowToTitle => 'Cloud Vision API 키 발급 방법';

  @override
  String get ocrHowTo1 => '1. Google Cloud Console에서 프로젝트를 만들거나 선택합니다.';

  @override
  String get ocrHowTo2 => '2. 해당 프로젝트에서 \'Cloud Vision API\'를 사용 설정합니다.';

  @override
  String get ocrHowTo3 => '3. \'API 및 서비스\' → \'사용자 인증 정보\'에서 API 키를 만듭니다.';

  @override
  String get ocrHowTo4 => '4. 키를 복사하여 위에 붙여넣습니다.';

  @override
  String get ocrOpenConsole => 'Google Cloud Console 열기';

  @override
  String get ocrSafetyTitle => '키는 기기에만 저장됩니다';

  @override
  String get ocrSafety1 =>
      '• 키는 이 기기의 보안 키체인에만 저장됩니다. 당사 서버에 업로드되거나 동기화되지 않으며 기기를 벗어나지 않습니다.';

  @override
  String get ocrSafety2 =>
      '• 앱은 사용자의 키로 명함 이미지를 Google Cloud Vision에 직접 전송하므로, 인식 요금은 본인 계정에 청구됩니다.';

  @override
  String get ocrSafety3 =>
      '• Google Cloud에서 키를 Cloud Vision API로만 제한하고 예산/할당량 한도를 설정하여 지출을 관리하세요.';

  @override
  String get ocrSafety4 => '• 키가 유출된 경우 Cloud Console에서 삭제하고 새 키를 여기에 붙여넣으세요.';

  @override
  String ocrSharedKeyUsage(int used, int cap) {
    return 'Cloud Vision · 공유 키 이번 달 $used/$cap';
  }

  @override
  String get scanCardHint => '명함을 프레임 안에 맞추세요';

  @override
  String get scanCardBackgroundTip => '무늬 없는 단색 배경을 사용하세요';

  @override
  String get ocrFeedbackPromptTitle => '인식 결과가 좋지 않았나요?';

  @override
  String get ocrFeedbackPromptBody =>
      '이 명함이 잘 인식되지 않았다면 개선에 도움을 주실 수 있습니다. 이번 달 스캔 횟수 1회를 돌려드립니다.';

  @override
  String get ocrFeedbackReport => '개선 돕기';

  @override
  String get ocrFeedbackDismiss => '괜찮아요';

  @override
  String get ocrFeedbackDontAsk24h => '24시간 동안 다시 묻지 않기';

  @override
  String get ocrFeedbackConsentTitle => '인식 개선에 도움을 주세요';

  @override
  String get ocrFeedbackConsentSummary =>
      '이 명함의 인식 데이터를 보내 개선에 도움을 주세요. 인식 개선에만 사용하며 검토 후 삭제합니다(사용하지 않아도 최대 90일 이내 삭제).';

  @override
  String get ocrFeedbackConsentIncludePhoto => '명함 사진도 포함(선택)';

  @override
  String get ocrFeedbackViewTerms => '전체 약관 보기';

  @override
  String get ocrFeedbackTermsBody =>
      '자리표시자 — 법무 검토 대기 중. 명함의 인식 텍스트와 레이아웃 데이터, 인식 결과, 그리고 (선택한 경우에만) 명함 사진을 수집합니다. 목적: 인식 정확도를 재현하고 개선하기 위함. 그 외의 목적으로 사용하지 않으며 제3자와 공유하지 않습니다. 데이터는 분석 직후 삭제되며, 사용되지 않은 데이터는 최대 90일 이내에 자동 삭제됩니다. 제출은 항상 선택 사항이며 매번 확인합니다. 명함에는 타인의 개인정보가 포함될 수 있으며, 제출함으로써 이 목적을 위한 공유에 동의하는 것으로 간주됩니다.';

  @override
  String get ocrFeedbackSubmit => '동의하고 보내기';

  @override
  String get ocrFeedbackCancel => '취소';

  @override
  String get ocrFeedbackThanks => '감사합니다! 여러분의 피드백은 인식 개선에 도움이 됩니다.';

  @override
  String get ocrFeedbackThanksRefunded => '감사합니다! 스캔 1회를 돌려드렸습니다.';

  @override
  String get ocrFeedbackLimitReached => '이번 달 피드백 한도에 도달했습니다. 도와주셔서 감사합니다!';

  @override
  String get ocrFeedbackFailed => '피드백을 보내지 못했습니다. 나중에 다시 시도해 주세요.';
}
