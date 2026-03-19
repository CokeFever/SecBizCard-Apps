# Deep Linking Architecture Decision Record

**Date**: 2026-02-01  
**Status**: Approved  
**Author**: Google Antigravity Team

## Context

SecBizCard 需要處理以下情境的 Deep Linking：

1. **已安裝 App**：用戶掃描 QR Code 或點擊連結 → App 直接開啟
2. **未安裝 App**：用戶掃描 QR Code → 導向 App Store → 安裝後繼續交換流程（Deferred Deep Linking）

## Decision

### Platform-Specific Approach

| 平台 | Deep Link | Deferred Deep Link | Fallback |
|------|-----------|-------------------|----------|
| **Android** | Intent URL + Custom Scheme | Play Install Referrer API | Play Store |
| **iOS** | Universal Links | Server-side Fingerprinting (Firestore) | App Store |

### Android Implementation

#### 1. Intent URL (Landing Page → App)
```
intent://handshake/ABC123#Intent;
  scheme=secbizcard;
  package=app.ixo.secbizcard;
  S.browser_fallback_url=https://play.google.com/store/apps/details?id=app.ixo.secbizcard&referrer=...;
end
```

**優點**：
- Chrome 原生支援
- 自動 fallback 到 Play Store
- 無需 2 秒延遲判斷

#### 2. Play Install Referrer API
- 使用 `play_install_referrer` package (v1.0.3+)
- 從 referrer 參數解析 session ID：`session=ABC123`
- 首次啟動時讀取並儲存到 SharedPreferences

### iOS Implementation

#### 1. Universal Links
- 設定 `apple-app-site-association` 於 Firebase Hosting
- 自動開啟 App（如已安裝）

#### 2. Server-side Fingerprinting
- **Device Fingerprint**：IP + User Agent + Screen Size
- **Storage**：Firestore `pending_sessions` collection
- **TTL**：10 分鐘（與 handshake session 相同）

**流程**：
```
Landing Page → 收集設備指紋 → 儲存 (fingerprint, sessionId) 到 Firestore
                                    ↓
App 首次啟動 → 發送設備指紋 → 查詢 Firestore → 取得 pending sessionId
```

## Alternatives Considered

### 1. Firebase Dynamic Links
- **狀態**：2025 年 8 月已棄用 ❌
- **原因**：Google 不再維護

### 2. Branch.io / AppsFlyer
- **狀態**：不採用
- **原因**：付費服務，增加外部依賴

### 3. Clipboard (剪貼簿)
- **狀態**：不採用
- **原因**：iOS 15+ 會顯示權限提示，用戶體驗差

## Technical Components

### Files to Create/Modify

| 檔案 | 用途 |
|------|------|
| `website/public/.well-known/apple-app-site-association` | iOS Universal Links 設定 |
| `website/public/flutter/index.html` | Landing Page（平台判斷 + Intent URL） |
| `functions/src/index.ts` | 新增 `savePendingSession`, `getPendingSession` |
| `lib/core/services/deep_link_service.dart` | 整合 Play Install Referrer + Fingerprint 查詢 |
| `pubspec.yaml` | 加入 `play_install_referrer` package |

### Firestore Schema

```
pending_sessions/{fingerprint_hash}
├── sessionId: string
├── createdAt: timestamp
├── expiresAt: timestamp (10 minutes)
└── platform: "ios" | "android"
```

## Security Considerations

1. **Fingerprint 碰撞**：使用高熵指紋（IP + UA + 時間戳記）降低風險
2. **TTL**：10 分鐘後自動過期
3. **One-time use**：查詢後立即刪除

## Implementation Priority

1. ✅ Android Intent URL（Landing Page）
2. ✅ iOS Universal Links 設定
3. ✅ Android Play Install Referrer
4. ⏳ iOS Server-side Fingerprinting（待 iOS 版發布）

## References

- [Android Intent URL](https://developer.chrome.com/docs/android/intents)
- [Play Install Referrer API](https://developer.android.com/google/play/installreferrer)
- [Apple Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
