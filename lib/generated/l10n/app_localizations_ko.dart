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
  String get ocrTierBasic => 'Basic';

  @override
  String get ocrTierPlus => 'Plus';

  @override
  String get ocrTierPro => 'Pro';

  @override
  String get ocrTierVip => 'VIP';

  @override
  String get ocrTierFlex => 'Flex';

  @override
  String ocrTierUsageCount(int used, int cap) {
    return '이번 달 $used/$cap';
  }

  @override
  String get ocrUsageByok => 'BYOK';

  @override
  String ocrTierBadge(String tier, String usage) {
    return '$tier · $usage';
  }

  @override
  String get ocrUsageUnknown => '사용량을 불러올 수 없습니다';

  @override
  String get ocrYourPlan => '내 요금제';

  @override
  String get ocrSubscribe => '구독';

  @override
  String get ocrUpgradeToPro => 'Pro로 업그레이드';

  @override
  String get ocrSubscribeComingSoon => '구독 기능은 곧 제공됩니다.';

  @override
  String get ocrAdminObservability => '관리자 · 공유 키 사용량';

  @override
  String get ocrAdminShared800 => '무료 풀(Basic)';

  @override
  String get ocrAdminTotal => 'CV 총 호출 수';

  @override
  String get ocrKeyFormatHint => 'Google Cloud API 키는 \"AIza\"로 시작하며 39자입니다.';

  @override
  String get ocrPaywallPlanPlus => 'SecBizCard Plus';

  @override
  String get ocrPaywallPlanPro => 'SecBizCard Pro';

  @override
  String get qrScanToExchange => 'Scan to Exchange';

  @override
  String get navShare => 'Share';

  @override
  String get navCard => 'Card';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get unsavedChangesTitle => '저장되지 않은 변경사항';

  @override
  String get unsavedChangesBody => '저장되지 않은 변경사항이 있습니다. 취소하고 나가시겠습니까?';

  @override
  String get unsavedChangesStay => '머무르기';

  @override
  String get unsavedChangesDiscard => '취소';

  @override
  String get drawerNotLoggedIn => '로그인되지 않음';

  @override
  String get drawerDefaultUser => '사용자';

  @override
  String get drawerMyProfile => '내 프로필';

  @override
  String get drawerManageContexts => '컨텍스트 관리';

  @override
  String get drawerErrorLoadingProfile => '프로필을 불러오는 중 오류가 발생했습니다';

  @override
  String get drawerBackupRestore => '백업 및 복원';

  @override
  String get drawerAiRecognition => 'AI 인식';

  @override
  String get drawerImportVcard => 'vCard 가져오기';

  @override
  String get drawerAppearance => '테마';

  @override
  String get drawerThemeAuto => '자동';

  @override
  String get drawerThemeLight => '라이트';

  @override
  String get drawerThemeDark => '다크';

  @override
  String get drawerLogout => '로그아웃';

  @override
  String get drawerConfirmLogoutTitle => '로그아웃 확인';

  @override
  String get drawerConfirmLogoutBody => '로그아웃하시겠습니까?';

  @override
  String get commonCancel => '취소';

  @override
  String get drawerLinkPrivacy => '개인정보';

  @override
  String get drawerLinkTerms => '약관';

  @override
  String get drawerLinkGuide => '가이드';

  @override
  String get qrGenerating => '보안 QRCode 생성 중…';

  @override
  String get qrBatchApproval => '일괄 승인';

  @override
  String get qrBatchApprovalOn => '모든 요청 자동 승인';

  @override
  String get qrBatchApprovalOff => '요청을 개별적으로 수동 승인';

  @override
  String qrResetsIn(String time) {
    return '$time 후 재설정';
  }

  @override
  String qrRefreshAvailableIn(int seconds) {
    return '$seconds초 후 사용 가능';
  }

  @override
  String get qrRefreshTooltip => 'QRCode 다시 생성';

  @override
  String get qrUrlCopied => 'URL을 클립보드에 복사했습니다';

  @override
  String get qrCopyUrl => 'URL 복사';

  @override
  String get qrRetry => '다시 시도';

  @override
  String get qrErrorSignInRequired => '정보를 공유하려면 로그인해야 합니다.';

  @override
  String qrErrorPrefix(String message) {
    return '오류: $message';
  }

  @override
  String get qrErrorNotAuthenticated => '인증되지 않았습니다';

  @override
  String get qrErrorCompleteProfile => '먼저 프로필을 완성해 주세요';

  @override
  String get qrCannotShare => '공유할 수 없습니다';

  @override
  String get commonOk => '확인';

  @override
  String get qrInfoSharedBack => '상대방도 정보를 공유했습니다!';

  @override
  String qrAlsoSharedInfo(String name) {
    return '$name님도 정보를 공유했습니다.';
  }

  @override
  String get qrSaveToContacts => '연락처에 저장';

  @override
  String get commonClose => '닫기';

  @override
  String get qrContactSaved => '연락처를 저장했습니다!';

  @override
  String qrSavedToContacts(String name) {
    return '$name님을 연락처에 저장했습니다';
  }

  @override
  String get qrInfoSharedSuccess => '정보를 공유했습니다!';

  @override
  String get ocrKeyLockedNote =>
      '직접 등록한 키가 사용 중입니다. 변경하려면 먼저 삭제한 후 새 키를 추가하세요.';

  @override
  String get ocrRemoveKeyAction => '키 삭제';

  @override
  String get ocrPaywallTitle => '클라우드 인식 업그레이드';

  @override
  String get ocrPaywallSubtitle => '키 설정 없이 더 빠르고 정확한 명함 인식.';

  @override
  String get ocrPlanPlusPrice => 'US\$0.99/월';

  @override
  String get ocrPlanPlusDesc => '매월 20회 클라우드 스캔';

  @override
  String get ocrPlanProPrice => 'US\$4.99/월';

  @override
  String get ocrPlanProDesc => '매월 100회 클라우드 스캔';

  @override
  String get ocrRestorePurchases => '구매 복원';

  @override
  String get ocrSubscribeThanks => '구독해 주셔서 감사합니다!';

  @override
  String get ocrRestoreDone => '구매를 복원했습니다.';

  @override
  String get ocrSubscribeFailed => '오류가 발생했습니다. 다시 시도해 주세요.';

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
      '이 명함의 인식 데이터를 보내 개선에 도움을 주세요. 인식 개선에만 사용하며 분석 후 삭제하고, 어떤 경우에도 30일 이내에 삭제합니다.';

  @override
  String get ocrFeedbackConsentIncludePhoto =>
      '명함 사진 포함(인식 오류 수정에 도움이 됩니다. 체크 해제 시 제외)';

  @override
  String get ocrFeedbackViewTerms => '전체 약관 보기';

  @override
  String get ocrFeedbackTermsBody =>
      '데이터 관리자: SecBizCard는 귀하가 보내는 피드백의 데이터 관리자입니다. 문의: privacy@ixo.app.\n\n수집 항목: 명함의 인식 텍스트와 레이아웃 데이터, 인식 결과, 그리고 명함 사진. 인식 오류를 재현하고 수정하기 위해 사진이 필수적입니다. 제출은 항상 선택 사항이며 매번 확인합니다.\n\n목적: 인식 정확도를 재현하고 개선하는 용도로만 사용합니다. 그 외의 목적으로 사용하지 않으며, 판매하거나 광고 목적으로 공유하지 않습니다.\n\n전달 대상: 피드백을 처리하기 위해 당사를 대신하여 처리하는 서비스 제공자(인식 및 저장을 위한 Google Cloud Vision 및 Firebase(Google))를 이용합니다. 이들은 귀하의 국가 외부에서 처리할 수 있으며, EU 사용자의 경우 필요 시 표준 계약 조항(SCC)에 따릅니다. 그 외 제3자와는 공유하지 않습니다.\n\n법적 근거: 인식 품질 개선에 대한 당사의 정당한 이익, 그리고 본 제출에 대한 귀하의 동의. 명함에는 타인의 개인정보가 포함되므로, 귀하는 이 목적을 위해 해당 정보를 공유할 합리적 근거가 있음을 확인합니다.\n\n보관 기간: 분석을 완료한 즉시 제출 데이터를 삭제하며, 어떤 경우에도 30일 이내에 삭제합니다. 데이터는 전송 중 및 저장 시 암호화됩니다.\n\n귀하의 권리: privacy@ixo.app을 통해 제출한 피드백의 열람 또는 삭제를 요청하거나 우려 사항을 제기할 수 있습니다. 자세한 내용은 개인정보처리방침을 참조하세요.';

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
