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
  String get ocrManageSubscription => 'サブスクリプションを管理';

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

  @override
  String get editProfileTitle => 'プロフィールを編集';

  @override
  String get editProfilePhoneResetWarn =>
      '⚠️ 認証済みの電話番号が変更されました。保存すると認証がリセットされます。';

  @override
  String get editProfileReverifyHint => '⚠️ これを変更すると再認証が必要になります';

  @override
  String get editProfileEditPhoto => '写真を編集';

  @override
  String get editProfileChooseImageSource => '画像の取得元を選択';

  @override
  String get editProfileGallery => 'ギャラリー';

  @override
  String get editProfileCamera => 'カメラ';

  @override
  String get editProfileVerificationResetTitle => '認証がリセットされます';

  @override
  String get editProfileVerificationResetBody =>
      '認証済みの電話番号を変更しようとしています。認証状態がリセットされ、新しい番号を再認証する必要があります。';

  @override
  String get editProfileContinue => '続行';

  @override
  String get editProfileFullName => '氏名';

  @override
  String get editProfileNameRequired => '氏名は必須です';

  @override
  String get editProfileJobTitle => '役職';

  @override
  String get editProfileCompany => '会社';

  @override
  String get editProfilePhone => '電話';

  @override
  String get editProfileAdditionalInfo => 'その他の情報';

  @override
  String get editProfileAddField => '項目を追加';

  @override
  String get editProfileTapToChangePhoto => 'タップして写真を変更';

  @override
  String get editProfileBusinessCards => '名刺';

  @override
  String get editProfileFrontSide => '表面';

  @override
  String get editProfileBackSide => '裏面';

  @override
  String editProfileUpload(String label) {
    return '$labelをアップロード';
  }

  @override
  String get editProfileFieldTypeLabel => '種類';

  @override
  String get editProfileFieldLabelLabel => 'ラベル';

  @override
  String get editProfileAdd => '追加';

  @override
  String get handshakeTitle => '情報を交換';

  @override
  String handshakeSaveFailed(String error) {
    return '保存に失敗しました：$error';
  }

  @override
  String get handshakeShareBackTitle => '情報を返信しますか？';

  @override
  String get handshakeShareBackBody => 'あなたの連絡先情報を相手に返信しますか？';

  @override
  String get handshakeNo => 'いいえ';

  @override
  String get handshakeYes => 'はい';

  @override
  String handshakeShareFailed(String error) {
    return '共有に失敗しました：$error';
  }

  @override
  String get handshakeInvalidLink => '無効または期限切れのリンクです';

  @override
  String handshakeParseError(String error) {
    return 'データの解析中にエラーが発生しました：$error';
  }

  @override
  String get handshakeFoundLink => '安全なリンクが見つかりました';

  @override
  String get handshakeRequestPrompt => '情報交換をリクエストしますか？';

  @override
  String get handshakeAbort => '中止';

  @override
  String get handshakeSendRequest => 'リクエストを送信';

  @override
  String get handshakeRequestSent => 'リクエストを送信しました！';

  @override
  String get handshakeWaitingApproval => '承認を待っています…';

  @override
  String get handshakeRequestDeclined => 'リクエストが拒否されました';

  @override
  String get handshakeSessionExpired => 'セッションの有効期限が切れました';

  @override
  String get handshakeInfoReceived => '情報を受け取りました！';

  @override
  String get handshakeSelectContext => '共有するコンテキストを選択';

  @override
  String get handshakeContextBusiness => 'ビジネス';

  @override
  String get handshakeContextSocial => 'ソーシャル';

  @override
  String get handshakeContextLite => 'ライト';

  @override
  String get handshakeShare => '共有';

  @override
  String get incomingExpired => '期限切れ';

  @override
  String get incomingUnknownUser => '不明なユーザー';

  @override
  String get incomingTitle => '受信したリクエスト';

  @override
  String incomingWantsToExchange(String name) {
    return '$name さんが連絡先情報の交換を希望しています。';
  }

  @override
  String get incomingAddToContacts => '連絡先に追加';

  @override
  String get incomingChooseInfo => '共有する情報を選択：';

  @override
  String get incomingDecline => '拒否';

  @override
  String get incomingApprove => '承認';

  @override
  String get scannerInvalidQr => '無効な QR コード';

  @override
  String get scannerInvalidQrFormat =>
      'QR コードの形式が無効です。想定形式：https://ixo.app/<id>';

  @override
  String get scannerTitle => 'QR コードをスキャン';

  @override
  String get scannerPlaceInFrame => 'QR コードを枠内に合わせてください';

  @override
  String get scannerPermissionTitle => 'カメラの許可が必要です';

  @override
  String get scannerPermissionBody =>
      'この機能では、安全な交換のために QR コードをスキャンするカメラへのアクセスが必要です。';

  @override
  String get scannerOpenSettings => '設定を開く';

  @override
  String get scannerGrantPermission => '許可する';

  @override
  String get editContactTitle => '連絡先を編集';

  @override
  String get editContactUpdated => '連絡先を更新しました';

  @override
  String get editContactBasicInfo => '基本情報';

  @override
  String get editContactDisplayName => '表示名';

  @override
  String get editContactNickname => 'ニックネーム（自分のみ表示）';

  @override
  String get editContactJobInfo => '職務情報';

  @override
  String get editContactContact => '連絡先';

  @override
  String get editContactEmail => 'メール';

  @override
  String get editContactOriginalScan => '元のスキャン';

  @override
  String editContactFieldRequired(String label) {
    return '$label は必須です';
  }

  @override
  String get contactDetailTitle => '連絡先の詳細';

  @override
  String contactDetailCopied(String label) {
    return '$labelをクリップボードにコピーしました';
  }

  @override
  String get contactDetailChooseGallery => 'ギャラリーから選択';

  @override
  String get contactDetailTakePhoto => '写真を撮る';

  @override
  String get contactDetailRemovePhoto => '写真を削除';

  @override
  String get contactDetailPhotoUpdated => '写真を更新しました';

  @override
  String get contactDetailCurrentAccount => '現在のアカウント';

  @override
  String get contactDetailExportTitle => 'Google 連絡先にエクスポート';

  @override
  String get contactDetailUseThisAccount => 'このアカウントを使用';

  @override
  String get contactDetailUseAnotherAccount => '別のアカウントを使用';

  @override
  String contactDetailExportFailed(String error) {
    return 'エクスポートに失敗しました：$error';
  }

  @override
  String get contactDetailExportSuccess => 'エクスポートに成功しました！';

  @override
  String contactDetailShareVcardFailed(String error) {
    return 'vCard の共有に失敗しました：$error';
  }

  @override
  String contactDetailShareZipFailed(String error) {
    return '.zip の共有に失敗しました：$error';
  }

  @override
  String get contactDetailMoreActions => 'その他の操作';

  @override
  String get contactDetailShareVcard => 'テキストのみ（vCard .vcf）';

  @override
  String get contactDetailShareZip => 'テキスト＋画像（.zip）';

  @override
  String get contactDetailSaveToGoogle => 'Google 連絡先に保存';

  @override
  String get contactDetailLabelEmail => 'メール';

  @override
  String get contactDetailLabelPhone => '電話';

  @override
  String get contactDetailLabelJobTitle => '役職';

  @override
  String get contactDetailLabelCompany => '会社';

  @override
  String get contactDetailLabelDepartment => '部署';

  @override
  String get contactDetailLabelAddress => '住所';

  @override
  String get contactDetailOcrResult => 'OCR 結果';

  @override
  String get scanCapturing => '撮影中…';

  @override
  String get scanDetectingEdges => '名刺の端を検出中…';

  @override
  String get scanRecognizeFailed => '名刺の文字を認識できませんでした';

  @override
  String get scanNoteOwnKeyNearLimit => 'Cloud Vision キーが月間無料上限（80%）に近づいています。';

  @override
  String get scanNoteSharedNearLimit => '今月の共有認識クォータが残りわずかです。';

  @override
  String get scanNoteUsedOnDevice =>
      'デバイス上の認識を使用しました。設定で Cloud Vision キーを追加すると最良の結果が得られます。';

  @override
  String get scanToggleHorizontal => '横向き';

  @override
  String get scanToggleVertical => '縦向き';

  @override
  String get scanCameraUnavailableTitle => 'カメラを使用できません';

  @override
  String get scanCameraUnavailableBody =>
      'カメラにアクセスできませんでした。他のアプリで使用されていないか確認してください。';

  @override
  String get scanRetry => '再試行';

  @override
  String get scanPermissionBody => 'この機能では、名刺をスキャンして認識するためにカメラへのアクセスが必要です。';

  @override
  String get backupCreating => 'バックアップを作成中…';

  @override
  String get backupCloudNewerStatus => 'クラウドのバックアップがこの端末より新しいです';

  @override
  String backupFailed(String error) {
    return 'バックアップに失敗しました：$error';
  }

  @override
  String get backupSuccessStatus => 'バックアップに成功しました！';

  @override
  String get backupSavedToDrive => 'バックアップを Google ドライブに保存しました';

  @override
  String get backupCloudNewerTitle => 'クラウドのバックアップが新しい';

  @override
  String get backupNeverChangedOnDevice => 'この端末では変更されていません';

  @override
  String backupLastChanged(String time) {
    return '$time に最終変更';
  }

  @override
  String backupCloudNewerBody(String cloudTime, String localState) {
    return 'Google ドライブのバックアップは $cloudTime に更新されており、この端末のデータ（$localState）より新しいです。\n\n今バックアップすると、その新しいバックアップ（おそらく別の端末で作成されたもの）を上書きします。この端末に新しいデータが欲しい場合は、キャンセルして「復元」を使用してください。\n\nそれでも新しいバックアップを上書きしますか？';
  }

  @override
  String get backupOverwrite => '上書き';

  @override
  String get backupRestoreConfirmTitle => 'バックアップを復元しますか？';

  @override
  String get backupRestoreConfirmBody =>
      '現在の連絡先と設定を上書きします。最近のバックアップがあることを確認してください。続行しますか？';

  @override
  String get backupRestoreAction => '復元';

  @override
  String get backupRestoringStatus => 'ドライブから復元中…';

  @override
  String backupRestoreFailed(String error) {
    return '復元に失敗しました：$error';
  }

  @override
  String get backupRestoreCompletedStatus => '復元が完了しました！';

  @override
  String get backupRestoreSuccessBody => 'データを復元しました。必要に応じてアプリを再起動してください。';

  @override
  String get backupDriveTitle => 'Google ドライブ バックアップ';

  @override
  String get backupDriveDesc => '連絡先と設定を暗号化ファイルとして Google ドライブに安全にバックアップします。';

  @override
  String get backupProcessing => '処理中…';

  @override
  String get backupLastBackupLabel => '前回のバックアップ';

  @override
  String get backupNever => 'なし';

  @override
  String get backupNowButton => '今すぐバックアップ';

  @override
  String get backupChecking => '確認中…';

  @override
  String get backupRestoreFromBackup => 'バックアップから復元';

  @override
  String get backupNoBackupFound => 'バックアップが見つかりません';

  @override
  String vcardErrorReadingFile(String error) {
    return 'ファイルの読み込み中にエラーが発生しました：$error';
  }

  @override
  String vcardInvalidPackage(String error) {
    return '無効なパッケージ：$error';
  }

  @override
  String get vcardNoContactsInPackage => 'パッケージ内に連絡先が見つかりません';

  @override
  String get vcardPasteFirst => '先に vCard の内容を貼り付けてください';

  @override
  String get vcardNoContactsInContent => 'vCard の内容に連絡先が見つかりません';

  @override
  String vcardImportedCount(int count, String skippedNote) {
    return '$count 件の連絡先をインポートしました$skippedNote';
  }

  @override
  String vcardSkippedNote(int count) {
    return '（$count 件スキップ）';
  }

  @override
  String get vcardViewAction => '表示';

  @override
  String vcardImportFailed(String error) {
    return 'インポートに失敗しました：$error';
  }

  @override
  String vcardPreviewTitle(int count) {
    return '$count 件の連絡先をインポートしますか？';
  }

  @override
  String get vcardNoContactInfo => '連絡先情報なし';

  @override
  String get vcardImportAction => 'インポート';

  @override
  String get vcardHowItWorks => '使い方';

  @override
  String get vcardHowItWorksDesc =>
      'お好みの AI アプリ（ChatGPT、Gemini、Grok など）で名刺の写真をスキャンし、結果を vCard 2.1 形式にするよう依頼してください。';

  @override
  String get vcardCopyPrompt => 'AI プロンプトをコピー';

  @override
  String get vcardPromptCopied => 'AI プロンプトをクリップボードにコピーしました！';

  @override
  String get vcardThen => '次に：';

  @override
  String get vcardStep1 => 'エクスポートした .vcf ファイルをアップロード、または';

  @override
  String get vcardStep2 => '下に vCard テキストを直接貼り付け';

  @override
  String get vcardOption1 => 'オプション 1：ファイルをアップロード';

  @override
  String get vcardChooseFile => 'ファイルを選択（.vcf）';

  @override
  String get vcardOr => 'または';

  @override
  String get vcardOption2 => 'オプション 2：vCard テキストを貼り付け';

  @override
  String get vcardImporting => 'インポート中…';

  @override
  String get vcardImportFromText => 'テキストからインポート';

  @override
  String get historyClearTitle => '履歴を消去しますか？';

  @override
  String get historyClearBody => 'すべての交換記録が削除されます。';

  @override
  String get historyClearAction => '消去';

  @override
  String get historyClearTooltip => '履歴を消去';

  @override
  String get historyNoActivity => 'アクティビティはまだありません';

  @override
  String get historyApproved => '承認しました！';

  @override
  String get historyStatusApproved => '承認済み';

  @override
  String get historyStatusRejected => '拒否済み';

  @override
  String get historyStatusPending => '保留中';

  @override
  String get historyStatusMissed => '見逃し';

  @override
  String get historyStatusExpired => '期限切れ';

  @override
  String get verifyEmailTitle => 'メールを確認';

  @override
  String emailVerifyCustomSent(String email) {
    return '$email に確認メールを送信しました！リンクをクリックしてログイン用メールを更新してください。';
  }

  @override
  String get emailVerifySent => '確認メールを送信しました！受信トレイをご確認ください。';

  @override
  String get emailNotVerifiedYet =>
      'メールはまだ確認されていません。受信トレイを確認し、確認リンクをクリックしてください。';

  @override
  String get emailCheckYourEmail => 'メールを確認してください';

  @override
  String get emailVerifyYourEmail => 'メールを確認';

  @override
  String get emailSentBody => '確認リンクをメールに送信しました。リンクをクリックしてメールアドレスを確認してください。';

  @override
  String get emailWillSendBody => 'メールアドレスを確認するための確認リンクを送信します。';

  @override
  String get emailSendButton => '確認メールを送信';

  @override
  String get emailIveVerified => '確認しました';

  @override
  String get emailResend => 'メールを再送信';

  @override
  String get emailTips => 'ヒント';

  @override
  String get emailTipsBody =>
      '• メールが見当たらない場合は迷惑メールフォルダをご確認ください\n• 確認リンクは 1 時間後に失効します\n• 必要に応じてメールを再送信できます';

  @override
  String get verifyPhoneTitle => '電話番号を確認';

  @override
  String get phoneSmsTimeout =>
      'SMS リクエストがタイムアウトしました。番号がすでに使用済み、無効、またはサーバーによってブロックされている可能性があります。';

  @override
  String get phoneEnter6Digit => '6 桁のコードを入力してください';

  @override
  String get phoneVerifiedAuto => '電話番号が自動的に確認されました！';

  @override
  String get phoneEnterNumber => '電話番号を入力';

  @override
  String get phoneWillSendSms => 'SMS で確認コードを送信します';

  @override
  String get phoneNumberLabel => '電話番号';

  @override
  String get phoneSendCode => 'コードを送信';

  @override
  String get phoneEnterCode => '確認コードを入力';

  @override
  String phoneSentCodeTo(String phone) {
    return '$phone に 6 桁のコードを送信しました';
  }

  @override
  String get phoneVerify => '確認';

  @override
  String get phoneDidntReceive => 'コードが届きませんか？ ';

  @override
  String phoneResendIn(int seconds) {
    return '$seconds 秒後に再送信';
  }

  @override
  String get phoneResendCode => 'コードを再送信';

  @override
  String get phoneChangeNumber => '電話番号を変更';

  @override
  String get contextSettingsTitle => 'カードコンテキスト';

  @override
  String contextSettingsErrorSaving(String error) {
    return '保存中にエラーが発生しました：$error';
  }

  @override
  String get contextSettingsSaved => 'コンテキストを保存しました';

  @override
  String get contextSettingsIntro => 'コンテキストごとに共有する情報をカスタマイズ';

  @override
  String get contextSettingsBusinessDesc => 'すべての業務情報';

  @override
  String get contextSettingsSocialDesc => '仕事の詳細を含まない個人連絡先';

  @override
  String get contextSettingsLiteDesc => '最小限の情報のみ';

  @override
  String get contextSettingsToggleName => '氏名';

  @override
  String get contextSettingsToggleEmail => 'メール';

  @override
  String get contextSettingsTogglePhone => '電話';

  @override
  String get contextSettingsToggleJobTitle => '役職';

  @override
  String get contextSettingsToggleCompany => '会社';

  @override
  String get contextSettingsToggleAvatar => 'アバター';

  @override
  String get contextSettingsToggleCardFront => '名刺の表面';

  @override
  String get contextSettingsToggleCardBack => '名刺の裏面';

  @override
  String get homeYourBusinessCard => 'あなたの名刺';

  @override
  String get homeScanToExchange => 'Scan to exchange';

  @override
  String get homeShareMyInfo => '情報を共有';

  @override
  String get manualCropTitle => '範囲を調整';

  @override
  String get manualCropReset => 'デフォルトに戻す';

  @override
  String get manualCropFailed => '切り抜きに失敗しました';

  @override
  String get reviewTitle => '連絡先を確認';

  @override
  String get reviewSaved => '連絡先を保存しました！';

  @override
  String get reviewFieldName => '氏名';

  @override
  String get reviewFieldEmail => 'メール';

  @override
  String get reviewFieldCompany => '会社';

  @override
  String get reviewFieldTitle => '役職';

  @override
  String get reviewFieldPhone => '電話';

  @override
  String get reviewFieldMobile => '携帯';

  @override
  String get reviewFieldFax => 'FAX';

  @override
  String get reviewFieldWebsite => 'ウェブサイト';

  @override
  String get reviewFieldAddress => '住所';

  @override
  String get reviewFieldTaxId => '登録番号／税番号';

  @override
  String get landingStoreLinkFailed => 'ストアのリンクを開けませんでした';

  @override
  String get landingInvitationTitle => 'SecBizCard の招待';

  @override
  String get landingInvitationBody =>
      'SecBizCard での接続に招待されました。この安全なプロフィールを表示して情報を交換するには、モバイルアプリをご利用ください。';

  @override
  String get landingDownloadApp => 'アプリをダウンロード';

  @override
  String get landingContinueToApp => 'アプリへ進む';

  @override
  String get landingHeroTitle => 'プロフェッショナルな\nアイデンティティの新基準。';

  @override
  String get landingHeroSubtitle => '安全で即時、そして検証済みの連絡先交換。\nクラウドによって実現。';

  @override
  String get landingMockName => 'あなたの名前';

  @override
  String get landingMockTitle => '最高技術責任者';

  @override
  String get landingFeatureQrTitle => 'QR 交換';

  @override
  String get landingFeatureQrDesc => '動的な QR コードを見せるだけで、名刺を即座に共有できます。';

  @override
  String get landingFeaturePrivacyTitle => 'プライバシー優先';

  @override
  String get landingFeaturePrivacyDesc =>
      'データはあなた自身の Google ドライブに保存されます。中央集約的なデータ収集はありません。';

  @override
  String get landingFeatureOfflineTitle => 'オフラインでも動作';

  @override
  String get landingFeatureOfflineDesc => 'インターネット接続がなくても、名刺にアクセスして共有できます。';

  @override
  String get landingFeatureVerifiedTitle => '検証済みの身元';

  @override
  String get landingFeatureVerifiedDesc => 'メールと電話の検証シグナルで、プロフィールに信頼を築きます。';

  @override
  String get landingDownloadHeadline => '安全で高速な\n名刺交換を体験';

  @override
  String landingCopyright(int year) {
    return '© $year SecBizCard. All rights reserved.';
  }

  @override
  String get landingPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get landingEula => 'EULA';

  @override
  String get mainCancelSelection => '選択をキャンセル';

  @override
  String mainSelectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get mainExportTooltip => 'エクスポート';

  @override
  String get mainBackupReminderTitle => '連絡先をバックアップしますか？';

  @override
  String get mainBackupReminderBody =>
      '連絡先と名刺画像はこの端末にのみ保存されています。紛失しないよう、ご自身の Google ドライブへのバックアップをおすすめします。';

  @override
  String get mainBackupDontRemind => '今月は通知しない';

  @override
  String get mainBackupLater => '後で';

  @override
  String get mainBackupNow => '今すぐバックアップ';

  @override
  String mainExportCount(int count) {
    return '$count 件の連絡先をエクスポート';
  }

  @override
  String get mainExportVcardSubtitle => '連絡先項目のみ、名刺画像なし';

  @override
  String get mainExportZipSubtitle => '項目と名刺写真、再インポート可能';

  @override
  String mainShareFailed(String error) {
    return '共有に失敗しました：$error';
  }

  @override
  String mainExporting(int count) {
    return '$count 件の連絡先をエクスポート中…';
  }

  @override
  String mainExportedToGoogle(int count) {
    return '$count 件の連絡先を Google 連絡先にエクスポートしました';
  }

  @override
  String mainExportFailed(String error) {
    return 'エクスポートに失敗しました：$error';
  }

  @override
  String mainExportedPartial(int succeeded, int total, int failed) {
    return '$total 件中 $succeeded 件をエクスポート、$failed 件失敗';
  }
}
