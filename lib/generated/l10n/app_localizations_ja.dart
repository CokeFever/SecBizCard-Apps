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
      'この名刺の認識データを送信して改善にご協力ください。認識の改善のみに使用し、確認後に削除します（未使用でも最長 90 日で削除）。';

  @override
  String get ocrFeedbackConsentIncludePhoto => '名刺の写真も含める（任意）';

  @override
  String get ocrFeedbackViewTerms => '全文を表示';

  @override
  String get ocrFeedbackTermsBody =>
      'プレースホルダー — 法務レビュー待ち。名刺の認識テキストとレイアウトデータ、認識結果、および（チェックした場合のみ）名刺の写真を収集します。目的：認識精度の再現と改善のため。それ以外の目的には使用せず、第三者と共有しません。データは分析後ただちに削除し、未使用のデータは最長 90 日以内に自動削除されます。送信は常に任意で、毎回確認します。名刺には第三者の個人情報が含まれる場合があります。送信することで、この目的での共有に同意したものとみなされます。';

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
