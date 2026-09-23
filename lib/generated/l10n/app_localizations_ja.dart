// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'SecBizCard';

  @override
  String get loginSlogan => '安全。プロフェッショナル。すぐに。';

  @override
  String get signInWithGoogle => 'Google でログイン';

  @override
  String get signInWithApple => 'Apple でログイン';

  @override
  String orSignInWith(String provider) {
    return 'または $provider でログイン';
  }

  @override
  String get profileTitle => 'プロフィール';

  @override
  String get editProfile => 'プロフィールを編集';

  @override
  String get onboardingWelcome => 'SecBizCard へようこそ';

  @override
  String get ocrRecognizingCloudVision => 'Cloud Vision で認識中…';

  @override
  String get ocrRecognizingOnDevice => '端末上で認識中…';

  @override
  String get ocrSourceCloudVisionOwn => 'Cloud Vision · あなたのキー';

  @override
  String ocrSourceCloudVisionShared(int used, int cap) {
    return 'Cloud Vision · 今月 $used/$cap';
  }

  @override
  String get ocrSourceOnDevice => '端末上での認識';

  @override
  String get aiRecognitionTitle => 'AI 認識';

  @override
  String get ocrUsingOwnKey => 'あなたの Cloud Vision キーを使用';

  @override
  String get ocrUsingOwnKeyDesc => '最高品質。ご自身の Google Cloud アカウントに課金されます。';

  @override
  String get ocrUsingSharedQuota => '共有クォータを使用';

  @override
  String ocrUsingSharedQuotaDesc(int perUser) {
    return '無料の AI スキャンは月 $perUser 回まで。以降は高速な端末上認識に切り替わります。無制限で最高品質のスキャンには、下にご自身のキーを追加してください。';
  }

  @override
  String ocrUsageThisMonth(int used, int cap) {
    return '今月：$used / $cap';
  }

  @override
  String get ocrOwnKeyNearLimitWarn =>
      '月間無料枠の 80% 以上を使用しました。今月これ以上スキャンすると、Google Cloud アカウントに料金が発生する場合があります。';

  @override
  String get ocrUseOwnKeyHeading => '自分の API キーを使う';

  @override
  String get ocrUpdateOwnKeyHeading => 'API キーを更新';

  @override
  String get ocrKeyHint => 'Cloud Vision API キーを貼り付け';

  @override
  String get ocrKeySaved => 'Cloud Vision キーをこの端末に安全に保存しました。';

  @override
  String get ocrKeyRemoved => 'Cloud Vision キーをこの端末から削除しました。';

  @override
  String get ocrKeyMasked => 'キーがこの端末に保存されています。';

  @override
  String get save => '保存';

  @override
  String get update => '更新';

  @override
  String get remove => '削除';

  @override
  String get cancel => 'キャンセル';

  @override
  String get ocrReplaceKeyTitle => '保存済みのキーを置き換えますか？';

  @override
  String get ocrReplaceKeyBody => 'この端末に現在保存されている API キーを上書きします。';

  @override
  String get ocrRemoveKeyTitle => '保存済みのキーを削除しますか？';

  @override
  String get ocrRemoveKeyBody => 'この端末は共有の月間クォータの使用に戻ります。キーはいつでも再度追加できます。';

  @override
  String get ocrHowToTitle => 'Cloud Vision API キーの取得方法';

  @override
  String get ocrHowTo1 => '1. Google Cloud Console でプロジェクトを作成（または選択）します。';

  @override
  String get ocrHowTo2 => '2. そのプロジェクトで「Cloud Vision API」を有効にします。';

  @override
  String get ocrHowTo3 => '3.「API とサービス」→「認証情報」で API キーを作成します。';

  @override
  String get ocrHowTo4 => '4. キーをコピーして上に貼り付けます。';

  @override
  String get ocrOpenConsole => 'Google Cloud Console を開く';

  @override
  String get ocrSafetyTitle => 'キーは端末内にとどまります';

  @override
  String get ocrSafety1 =>
      '• キーはこの端末の安全なキーチェーンにのみ保存されます。当社のサーバーにアップロードされることも、同期されることも、端末から外に出ることもありません。';

  @override
  String get ocrSafety2 =>
      '• アプリはあなたのキーを使って名刺画像を直接 Google Cloud Vision に送信するため、認識はご自身のアカウントに課金されます。';

  @override
  String get ocrSafety3 =>
      '• Google Cloud で、キーを Cloud Vision API のみに制限し、予算／クォータの上限を設定して支出を抑えてください。';

  @override
  String get ocrSafety4 =>
      '• キーが漏洩した場合は、Cloud Console で削除し、新しいキーをここに貼り付けてください。';

  @override
  String ocrSharedKeyUsage(int used, int cap) {
    return 'Cloud Vision · 共有キー 今月 $used/$cap';
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
    return '今月 $used/$cap';
  }

  @override
  String get ocrUsageByok => 'BYOK';

  @override
  String ocrTierBadge(String tier, String usage) {
    return '$tier · $usage';
  }

  @override
  String get ocrUsageUnknown => '使用状況を取得できません';

  @override
  String get ocrYourPlan => '現在のプラン';

  @override
  String get ocrSubscribe => '登録する';

  @override
  String get ocrUpgradeToPro => 'Pro にアップグレード';

  @override
  String get ocrSubscribeComingSoon => 'サブスクリプションは近日提供予定です。';

  @override
  String get ocrAdminObservability => '管理者 · 共有キーの使用状況';

  @override
  String get ocrAdminShared800 => '無料枠（Basic）';

  @override
  String get ocrAdminTotal => 'CV 呼び出し総数';

  @override
  String get ocrKeyFormatHint => 'Google Cloud API キーは「AIza」で始まり、39 文字です。';

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
  String get unsavedChangesTitle => '未保存の変更';

  @override
  String get unsavedChangesBody => '保存されていない変更があります。破棄して移動してもよろしいですか?';

  @override
  String get unsavedChangesStay => 'とどまる';

  @override
  String get unsavedChangesDiscard => '破棄';

  @override
  String get drawerNotLoggedIn => '未ログイン';

  @override
  String get drawerDefaultUser => 'ユーザー';

  @override
  String get drawerMyProfile => 'マイプロフィール';

  @override
  String get drawerManageContexts => 'コンテキスト管理';

  @override
  String get drawerErrorLoadingProfile => 'プロフィールの読み込み中にエラーが発生しました';

  @override
  String get drawerBackupRestore => 'バックアップと復元';

  @override
  String get drawerAiRecognition => 'AI 認識';

  @override
  String get drawerImportVcard => 'vCard をインポート';

  @override
  String get drawerAppearance => '外観';

  @override
  String get drawerThemeAuto => '自動';

  @override
  String get drawerThemeLight => 'ライト';

  @override
  String get drawerThemeDark => 'ダーク';

  @override
  String get drawerLogout => 'ログアウト';

  @override
  String get drawerConfirmLogoutTitle => 'ログアウトの確認';

  @override
  String get drawerConfirmLogoutBody => 'ログアウトしてもよろしいですか?';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get drawerLinkPrivacy => 'プライバシー';

  @override
  String get drawerLinkTerms => '規約';

  @override
  String get drawerLinkGuide => 'ガイド';

  @override
  String loginSignInError(String error) {
    return 'サインインエラー:$error';
  }

  @override
  String contactsNoneFoundFor(String query) {
    return '「$query」に一致する連絡先が見つかりません';
  }

  @override
  String get contactsNoneYet => '連絡先がまだありません';

  @override
  String get contactsEmptyHint => '交換またはスキャンした名刺がここに表示されます';

  @override
  String contactsDeleteFailed(String error) {
    return '削除に失敗しました:$error';
  }

  @override
  String get contactsDeleted => '連絡先を削除しました';

  @override
  String get contactsDelete => '削除';

  @override
  String get contactsSearchHint => '連絡先を検索…';

  @override
  String commonErrorWithDetail(String error) {
    return 'エラー:$error';
  }

  @override
  String get onboardingSetupProfile => 'プロフィール設定';

  @override
  String get onboardingGetStarted => 'すぐに始める';

  @override
  String get onboardingImportDesc => 'Google 連絡先の名刺からプロフィールをインポートして、手入力を省けます。';

  @override
  String get onboardingImportFromGoogle => 'Google からインポート';

  @override
  String get onboardingEnterManually => '手動で入力';

  @override
  String get onboardingReviewInfo => '情報を確認';

  @override
  String get onboardingMasterProfileDesc =>
      'この情報があなたの「マスタープロフィール」になります。共有する内容は後で選べます。';

  @override
  String get onboardingRecoveryTip =>
      'ヒント:アカウント復旧と信頼性確認のため、個人の電話番号と Gmail の使用をおすすめします。';

  @override
  String get onboardingFieldName => '氏名(必須)';

  @override
  String get onboardingFieldPhone => '電話(任意)';

  @override
  String get onboardingFieldEmail => 'メール(任意)';

  @override
  String get onboardingFieldTitle => '役職';

  @override
  String get onboardingFieldCompany => '会社';

  @override
  String get onboardingNameRequired => '氏名は必須です';

  @override
  String get onboardingContinue => '続ける';

  @override
  String get onboardingSmartContexts => 'スマートコンテキスト';

  @override
  String get onboardingContextsDesc =>
      '3 つのデフォルトコンテキストを設定しました。設定でいつでもカスタマイズできます。';

  @override
  String get onboardingContextWorkShares => '共有:氏名、役職、会社、電話、メール';

  @override
  String get onboardingContextPersonalShares => '共有:氏名、個人メール、アバター';

  @override
  String get onboardingContextQuickShares => '共有:氏名のみ';

  @override
  String get onboardingLooksGood => '良さそう';

  @override
  String get onboardingAllSet => '準備完了!';

  @override
  String get onboardingReadyDesc => 'デジタル名刺の共有準備ができました。';

  @override
  String get onboardingStartUsing => 'SecBizCard を使い始める';

  @override
  String get profileNotFound => 'プロフィールが見つかりません';

  @override
  String get profileEdit => 'プロフィールを編集';

  @override
  String get profileDeleteAccount => 'アカウントを削除';

  @override
  String get profileContinueToDelete => '削除に進む';

  @override
  String get profileAreYouSure => '本当によろしいですか?';

  @override
  String get profileDeleteLastChance =>
      'これが最後の確認です。アカウント、プロフィール、すべての連絡先が完全に削除されます。';

  @override
  String get profileDeleteForever => '完全に削除';

  @override
  String commonFailedWithDetail(String error) {
    return '失敗:$error';
  }

  @override
  String get qrGenerating => '安全な QRCode を生成中…';

  @override
  String get qrBatchApproval => '一括承認';

  @override
  String get qrBatchApprovalOn => 'すべてのリクエストを自動承認';

  @override
  String get qrBatchApprovalOff => 'リクエストを個別に手動承認';

  @override
  String qrResetsIn(String time) {
    return '$time 後にリセット';
  }

  @override
  String qrRefreshAvailableIn(int seconds) {
    return '$seconds 秒後に利用可能';
  }

  @override
  String get qrRefreshTooltip => 'QRCode を再生成';

  @override
  String get qrUrlCopied => 'URL をクリップボードにコピーしました';

  @override
  String get qrCopyUrl => 'URL をコピー';

  @override
  String get qrRetry => '再試行';

  @override
  String get qrErrorSignInRequired => '情報を共有するにはサインインが必要です。';

  @override
  String qrErrorPrefix(String message) {
    return 'エラー:$message';
  }

  @override
  String get qrErrorNotAuthenticated => '認証されていません';

  @override
  String get qrErrorCompleteProfile => '先にプロフィールを完成させてください';

  @override
  String get qrCannotShare => '共有できません';

  @override
  String get commonOk => 'OK';

  @override
  String get qrInfoSharedBack => '相手も情報を共有しました!';

  @override
  String qrAlsoSharedInfo(String name) {
    return '$name も情報を共有しました。';
  }

  @override
  String get qrSaveToContacts => '連絡先に保存';

  @override
  String get commonClose => '閉じる';

  @override
  String get qrContactSaved => '連絡先を保存しました!';

  @override
  String qrSavedToContacts(String name) {
    return '$name を連絡先に保存しました';
  }

  @override
  String get qrInfoSharedSuccess => '情報を共有しました!';

  @override
  String get ocrKeyLockedNote => '自分のキーが有効です。変更するには、先に削除してから新しいキーを追加してください。';

  @override
  String get ocrRemoveKeyAction => 'キーを削除';

  @override
  String get ocrPaywallTitle => 'クラウド認識をアップグレード';

  @override
  String get ocrPaywallSubtitle => 'キー設定不要で、より速く正確な名刺認識。';

  @override
  String get ocrPlanPlusPrice => 'US\$0.99/月';

  @override
  String get ocrPlanPlusDesc => '毎月 20 回のクラウドスキャン';

  @override
  String get ocrPlanProPrice => 'US\$4.99/月';

  @override
  String get ocrPlanProDesc => '毎月 100 回のクラウドスキャン';

  @override
  String get ocrRestorePurchases => '購入を復元';

  @override
  String get ocrSubscribeThanks => 'ご登録ありがとうございます！';

  @override
  String get ocrRestoreDone => '購入を復元しました。';

  @override
  String get ocrSubscribeFailed => 'エラーが発生しました。もう一度お試しください。';

  @override
  String get scanCardHint => '名刺を枠内に収めてください';

  @override
  String get scanCardBackgroundTip => '無地で模様のない背景をご使用ください';

  @override
  String get ocrFeedbackPromptTitle => '認識結果はうまくいきませんでしたか？';

  @override
  String get ocrFeedbackPromptBody =>
      'この名刺がうまく認識されなかった場合、改善にご協力いただけます。今月のスキャン回数を 1 回分お返しします。';

  @override
  String get ocrFeedbackReport => '改善に協力';

  @override
  String get ocrFeedbackDismiss => 'いいえ';

  @override
  String get ocrFeedbackDontAsk24h => '24 時間は再度表示しない';

  @override
  String get ocrFeedbackConsentTitle => '認識精度の改善にご協力ください';

  @override
  String get ocrFeedbackConsentSummary =>
      'この名刺の認識データを送信して改善にご協力ください。認識の改善のみに使用し、分析後に削除します。いかなる場合も 30 日以内に削除します。';

  @override
  String get ocrFeedbackConsentIncludePhoto =>
      '名刺の写真を含める（認識の修正に役立ちます。チェックを外すと送信しません）';

  @override
  String get ocrFeedbackViewTerms => '全文を表示';

  @override
  String get ocrFeedbackTermsBody =>
      'データ管理者：SecBizCard は、お客様が送信するフィードバックのデータ管理者です。お問い合わせ：privacy@ixo.app。\n\n収集する情報：名刺の認識テキストとレイアウトデータ、認識結果、および名刺の写真。認識エラーを再現・修正するために写真は不可欠です。送信は常に任意で、毎回確認します。\n\n目的：認識精度の再現と改善のみに使用します。それ以外の目的には使用せず、販売や広告目的での共有も行いません。\n\n情報の取扱先：フィードバックを処理するため、当社に代わって処理を行うサービス提供者（認識と保存のための Google Cloud Vision および Firebase（Google））を利用します。これらはお客様の国以外で処理される場合があり、EU のユーザーについては必要に応じて標準契約条項（SCC）に基づき対応します。それ以外の第三者とは共有しません。\n\n法的根拠：認識品質の改善という当社の正当な利益、および本送信に対するお客様の同意。名刺には第三者の個人情報が含まれるため、この目的で共有する合理的な根拠があることをお客様は確認するものとします。\n\n保存期間：分析が完了した時点で送信データを削除し、いかなる場合も 30 日以内に削除します。データは転送中および保存時に暗号化されます。\n\nお客様の権利：privacy@ixo.app にて、送信したフィードバックへのアクセスや削除の請求、懸念の申し立てができます。詳細はプライバシーポリシーをご覧ください。';

  @override
  String get ocrFeedbackSubmit => '同意して送信';

  @override
  String get ocrFeedbackCancel => 'キャンセル';

  @override
  String get ocrFeedbackThanks => 'ありがとうございます！フィードバックは認識精度の改善に役立ちます。';

  @override
  String get ocrFeedbackThanksRefunded => 'ありがとうございます！スキャン 1 回分をお返ししました。';

  @override
  String get ocrFeedbackLimitReached => '今月のフィードバック上限に達しました。ご協力ありがとうございます！';

  @override
  String get ocrFeedbackFailed => 'フィードバックを送信できませんでした。後でもう一度お試しください。';
}
