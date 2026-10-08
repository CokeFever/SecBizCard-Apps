// Dev tool: generates a dummy SecBizCard backup (`secbizcard-dummy.zip`) in the
// real SBCB v2 magic-word format so the web editor (ixo.app/editor) and the app
// can both open and decrypt it with the magic word "abc123".
//
// It reuses the SHIPPING codec path (BackupCodec.encryptNew with
// encMode=magicword) so the bytes are bit-compatible with what the app writes —
// no hand-rolled container. The inner ZIP holds a single `data.json` matching
// the schema backup_service.dart writes: {contacts, userProfile, settings}
// (plus timestamp/appVersion). Contacts and the self profile are serialized as
// UserProfile.toJson(), the same type the app persists for both.
//
// Dummy data is deliberately messy/varied to exercise editor features: search,
// filter, column multi-select, phone normalization, and find-duplicates/merge.
// Images are omitted (no `zip://` refs) to keep it simple.
//
// Run:  fvm dart run tool/make_dummy_backup.dart
//
// Not part of the app. Safe to commit (it writes only test data; the output
// .zip is gitignored).

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'package:secbizcard/core/services/backup_codec.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

/// Magic word for the dummy file. NOTE: shorter than the app's 8-char UI
/// minimum (MagicWordService), but the codec itself enforces no length — this
/// is a dev fixture, and the editor/app decrypt path only re-derives the key.
const String kMagicWord = 'abc123';

/// Mirrors MagicWordService.normalize (trim + Unicode NFC) so the key we derive
/// matches what the app/editor derive from the user-typed word.
String _normalizeMagicWord(String v) => unorm.nfc(v.trim());

/// Fixed timestamp so the file is reproducible run-to-run (salt/nonce are still
/// random, which is correct — the format carries them in the header).
const String _fixedTimestamp = '2026-01-15T09:30:00.000Z';

UserProfile _contact({
  required String uid,
  required String displayName,
  String? email,
  String? title,
  String? company,
  String? department,
  String? phone,
  String? mobile,
  String? address,
  String? website,
  Map<String, String> customFields = const {},
}) {
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    title: title,
    company: company,
    department: department,
    phone: phone,
    mobile: mobile,
    address: address,
    website: website,
    customFields: customFields,
    source: 'ocr',
    createdAt: DateTime.parse(_fixedTimestamp),
  );
}

/// ~30 contacts, intentionally messy and varied.
List<UserProfile> _buildContacts() {
  return [
    // --- Chinese names, inconsistent TW phone formats ---
    _contact(
      uid: 'c001',
      displayName: '王大明',
      email: 'daming.wang@example.com.tw',
      title: '業務經理',
      company: '台灣電子股份有限公司',
      department: '業務部',
      phone: '0912-345-678',
      mobile: '0912-345-678',
      address: '台北市信義區信義路五段7號',
      customFields: {
        'phone_work': '(02)2793-0303',
        'email_personal': 'daming.personal@gmail.com',
        'taxId': '12345678',
      },
    ),
    // Near-duplicate of c001 — same person, different company + extra field.
    _contact(
      uid: 'c002',
      displayName: '王大明',
      email: 'daming@newco.com.tw',
      title: '資深顧問',
      company: '新創顧問有限公司',
      phone: '0912 345 678',
      mobile: '0912 345 678',
      customFields: {'postalCode': '110'},
    ),
    _contact(
      uid: 'c003',
      displayName: '陳美玲',
      email: 'meiling.chen@example.com',
      title: '行銷總監',
      company: '美麗廣告',
      department: '行銷部',
      phone: '(02)2793-0303',
      mobile: '+886 912 000 111',
      address: '新北市板橋區文化路一段100號12樓',
      customFields: {
        'phone_work': '02 2793 0303 ext 235',
        'phone_work_2': '02-2793-0304',
      },
    ),
    _contact(
      uid: 'c004',
      displayName: '林志豪',
      email: 'zhihao.lin@factory.com.tw',
      title: '廠長',
      company: '永豐機械',
      phone: '886-2-2658-8866',
      address: '桃園市龜山區工業一路15號',
    ),
    _contact(
      uid: 'c005',
      displayName: '黃淑芬',
      title: '會計',
      company: '誠信會計師事務所',
      phone: '02 2658 8866',
      mobile: '0988-123-456',
      customFields: {'taxId': '87654321', 'postalCode': '114'},
    ),
    // --- Japanese names, +81 formats ---
    _contact(
      uid: 'c006',
      displayName: '田中太郎',
      email: 'taro.tanaka@example.co.jp',
      title: '営業部長',
      company: '東京商事株式会社',
      department: '営業部',
      phone: '+81 3 1234 5678',
      mobile: '+81 90-1234-5678',
      address: '東京都千代田区丸の内1-1-1',
    ),
    _contact(
      uid: 'c007',
      displayName: '佐藤花子',
      email: 'hanako.sato@example.co.jp',
      title: 'マネージャー',
      company: '大阪物流',
      phone: '06-6345-1234',
      mobile: '090 8765 4321',
    ),
    // Near-duplicate of c006 — different mobile only.
    _contact(
      uid: 'c008',
      displayName: '田中太郎',
      email: 'taro.tanaka@example.co.jp',
      company: '東京商事株式会社',
      mobile: '+81-90-1234-5679',
    ),
    _contact(
      uid: 'c009',
      displayName: '鈴木一郎',
      company: '名古屋製作所',
      phone: '052-123-4567',
    ),
    // --- Korean names, +82 formats ---
    _contact(
      uid: 'c010',
      displayName: '김민준',
      email: 'minjun.kim@example.co.kr',
      title: '대리',
      company: '서울테크',
      department: '개발팀',
      phone: '+82 2 1234 5678',
      mobile: '+82 10-1234-5678',
      address: '서울특별시 강남구 테헤란로 123',
    ),
    _contact(
      uid: 'c011',
      displayName: '이서연',
      email: 'seoyeon.lee@example.co.kr',
      title: '과장',
      company: '부산무역',
      phone: '051-987-6543',
      mobile: '010 9876 5432',
    ),
    // --- English names ---
    _contact(
      uid: 'c012',
      displayName: 'John Smith',
      email: 'john.smith@acme.com',
      title: 'Sales Director',
      company: 'Acme Corporation',
      department: 'Sales',
      phone: '+1 (415) 555-0132',
      mobile: '+1 415 555 0199',
      address: '1600 Amphitheatre Pkwy, Mountain View, CA',
      website: 'https://acme.example.com',
      customFields: {'email_personal': 'johnny.smith@gmail.com'},
    ),
    // Near-duplicate of c012 — same email, extra title.
    _contact(
      uid: 'c013',
      displayName: 'John Smith',
      email: 'john.smith@acme.com',
      title: 'VP of Sales',
      company: 'Acme Corporation',
      mobile: '+1 415 555 0199',
    ),
    _contact(
      uid: 'c014',
      displayName: 'Emily Johnson',
      email: 'emily.johnson@globex.com',
      title: 'Product Manager',
      company: 'Globex Inc',
      phone: '+1 212 555 0145',
      website: 'www.globex.example.com',
    ),
    _contact(
      uid: 'c015',
      displayName: 'Michael Brown',
      email: 'm.brown@initech.io',
      title: 'CTO',
      company: 'Initech',
      mobile: '+1-650-555-0177',
      customFields: {'email_personal': 'mike.brown@outlook.com'},
    ),
    _contact(
      uid: 'c016',
      displayName: 'Sarah Davis',
      company: 'Umbrella LLC',
      phone: '+44 20 7946 0958',
      address: '221B Baker Street, London',
    ),
    // --- Sparse: name only ---
    _contact(uid: 'c017', displayName: '張三'),
    _contact(uid: 'c018', displayName: 'David Lee'),
    _contact(uid: 'c019', displayName: '李四'),
    // --- Varied, some empty company/title/dept to test hide-empty-columns ---
    _contact(
      uid: 'c020',
      displayName: '吳建宏',
      email: 'jianhong.wu@example.com',
      phone: '0922 333 444',
      mobile: '0922-333-444',
    ),
    _contact(
      uid: 'c021',
      displayName: '周雅婷',
      title: '設計師',
      phone: '0933-555-666',
      website: 'behance.net/yating',
    ),
    _contact(
      uid: 'c022',
      displayName: '鄭文傑',
      company: '文傑設計工作室',
      email: 'wenjie@studio.tw',
      phone: '04-2301-2345',
      address: '台中市西區台灣大道二段2號',
    ),
    _contact(
      uid: 'c023',
      displayName: 'Lisa Wang',
      email: 'lisa.wang@startup.co',
      title: 'Founder & CEO',
      company: 'Nimbus Startup',
      mobile: '+1 (628) 555-0110',
      phone: '628-555-0110',
      department: 'Executive',
      address: '500 Market St, San Francisco, CA 94105',
      website: 'https://nimbus.example.co',
      customFields: {
        'email_personal': 'lisa.personal@proton.me',
        'phone_work': '+1 628 555 0111',
        'taxId': '99-7654321',
        'postalCode': '94105',
      },
    ),
    _contact(
      uid: 'c024',
      displayName: '許志明',
      company: '明志科技',
      phone: '03 5712 121',
      mobile: '0955 777 888',
    ),
    _contact(
      uid: 'c025',
      displayName: '蔡依琳',
      email: 'yilin.tsai@music.tw',
      title: '製作人',
      company: '依琳音樂',
      mobile: '+886-955-123-456',
    ),
    _contact(
      uid: 'c026',
      displayName: 'Robert Garcia',
      email: 'robert.garcia@consulting.es',
      title: 'Consultant',
      company: 'Garcia & Partners',
      phone: '+34 91 123 45 67',
      address: 'Calle Gran Vía 1, Madrid',
    ),
    _contact(
      uid: 'c027',
      displayName: '高橋健',
      email: 'ken.takahashi@example.co.jp',
      company: '福岡システム',
      phone: '092-111-2222',
      mobile: '080-1111-2222',
    ),
    _contact(
      uid: 'c028',
      displayName: '정우성',
      title: '부장',
      company: '인천전자',
      phone: '032-555-7777',
    ),
    _contact(
      uid: 'c029',
      displayName: 'Anna Müller',
      email: 'anna.mueller@example.de',
      title: 'Geschäftsführerin',
      company: 'Müller GmbH',
      phone: '+49 30 1234567',
      mobile: '+49 170 1234567',
      address: 'Alexanderplatz 1, Berlin',
    ),
    // Very complete contact (all common fields) to test rendering extremes.
    _contact(
      uid: 'c030',
      displayName: '劉德華',
      email: 'andy.lau@example.com.hk',
      title: '總經理',
      company: '華仔企業有限公司',
      department: '管理部',
      phone: '(02)2345-6789',
      mobile: '+886 910 888 999',
      address: '台北市中山區南京東路三段1號20樓',
      website: 'https://andylau.example.hk',
      customFields: {
        'email_personal': 'andy.personal@icloud.com',
        'phone_work': '02-2345-6789',
        'phone_work_2': '02-2345-6780',
        'taxId': '53912345',
        'postalCode': '104',
        'LinkedIn': 'linkedin.com/in/andylau',
      },
    ),
  ];
}

UserProfile _buildSelfProfile() {
  return UserProfile(
    uid: 'self-jack-wang',
    displayName: 'Jack Wang',
    email: 'jack.wang@secbizcard.example',
    title: 'Founder',
    company: 'SecBizCard',
    department: 'Product',
    phone: '0911-222-333',
    mobile: '+886 911 222 333',
    address: '台北市大安區',
    website: 'https://ixo.app',
    source: 'handshake',
    isOnboardingComplete: true,
    createdAt: DateTime.parse(_fixedTimestamp),
    customFields: {'LinkedIn': 'linkedin.com/in/jackwang'},
  );
}

Future<void> main() async {
  final contacts = _buildContacts();
  final self = _buildSelfProfile();

  // data.json — exact shape backup_service.dart writes.
  final data = <String, dynamic>{
    'timestamp': _fixedTimestamp,
    'appVersion': 'dummy',
    'contacts': contacts.map((c) => c.toJson()).toList(),
    'settings': <String, dynamic>{},
    'userProfile': self.toJson(),
  };

  final jsonBytes = utf8.encode(jsonEncode(data));

  // Inner ZIP with a single data.json (no images → no zip:// refs).
  final archive = Archive()
    ..addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
  final zipBytes = ZipEncoder().encode(archive);

  // Encrypt via the shipping codec, magic-word mode, normalized word.
  final codec = BackupCodec();
  final keySource = _normalizeMagicWord(kMagicWord);
  final sbcbBytes = await codec.encryptNew(
    zipBytes,
    encMode: BackupCodec.encModeMagicWord,
    keySource: keySource,
  );

  // Output paths.
  const outPrimary =
      '/Users/jack/_Projects/SecBizCard-Apps/.agents/tmp/secbizcard-dummy.zip';
  const outDownloads = '/Users/jack/Downloads/secbizcard-dummy.zip';

  for (final path in [outPrimary, outDownloads]) {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(sbcbBytes, flush: true);
  }

  // --- Verify: header + round-trip decrypt ---
  final headerOk = sbcbBytes.length >= 4 &&
      sbcbBytes[0] == 0x53 && // S
      sbcbBytes[1] == 0x42 && // B
      sbcbBytes[2] == 0x43 && // C
      sbcbBytes[3] == 0x42; // B
  final header = codec.readHeaderOrNull(sbcbBytes);

  final decrypted = await codec.decrypt(
    sbcbBytes,
    uid: 'unused-for-magicword',
    magicWord: keySource,
  );
  final roundTrip = ZipDecoder().decodeBytes(decrypted);
  final dataFile = roundTrip.findFile('data.json');
  final parsed =
      jsonDecode(utf8.decode(dataFile!.content)) as Map<String, dynamic>;
  final contactCount = (parsed['contacts'] as List).length;

  stdout.writeln('=== make_dummy_backup ===');
  stdout.writeln('magic word       : $kMagicWord');
  stdout.writeln('encMode          : ${header?.encMode}');
  stdout.writeln('version          : ${header?.version}');
  stdout.writeln('kdf iterations   : ${header?.iterations}');
  stdout.writeln("starts with 'SBCB': $headerOk");
  stdout.writeln('byte size        : ${sbcbBytes.length} bytes');
  stdout.writeln('contacts         : $contactCount');
  stdout.writeln('userProfile      : ${parsed['userProfile'] != null ? 'present' : 'null'}');
  stdout.writeln('wrote            : $outPrimary');
  stdout.writeln('wrote            : $outDownloads');

  if (!headerOk ||
      header?.encMode != BackupCodec.encModeMagicWord ||
      contactCount != contacts.length) {
    stderr.writeln('VERIFICATION FAILED');
    exitCode = 1;
    return;
  }
  stdout.writeln('VERIFICATION OK');
}
