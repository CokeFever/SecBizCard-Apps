# ixo.app 官網 Vue/Nuxt SSR 規劃

## 技術架構

| 項目 | 選擇 |
|------|------|
| Framework | Nuxt 3 |
| Styling | Tailwind CSS |
| Icons | Heroicons / Lucide |
| i18n | @nuxtjs/i18n (繁中/英文) |
| Hosting | Firebase Hosting |
| Analytics | Google Analytics 4 |

---

## 頁面規劃

| 路由 | 檔案 | 用途 |
|------|------|------|
| `/` | `pages/index.vue` | 首頁 - SecBizCard 功能介紹 |
| `/about` | `pages/about.vue` | About Us - 團隊、其他專案 |
| `/privacy` | `pages/privacy.vue` | 隱私權政策 |
| `/eula` | `pages/eula.vue` | 使用者條款 |

> **注意**: `/:sessionId` 深度連結仍由 Flutter Web 處理，使用 Firebase Hosting rewrites 分流。

---

## Firebase Hosting Rewrites

```json
{
  "hosting": {
    "public": "dist",
    "rewrites": [
      {
        "source": "/privacy",
        "destination": "/privacy.html"
      },
      {
        "source": "/eula", 
        "destination": "/eula.html"
      },
      {
        "regex": "/[a-zA-Z0-9]{6,}",
        "destination": "/flutter/index.html"
      },
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

---

## 下一步執行計畫

### Step 1: 初始化專案
```bash
npx nuxi@latest init ixo-website
cd ixo-website
npm install -D tailwindcss @nuxtjs/tailwindcss
```

### Step 2: 建立頁面結構
- 首頁 Hero section
- Feature showcase
- CTA (App Store / Play Store 下載連結)

### Step 3: 遷移現有內容
- 從 Flutter web/privacy.html → pages/privacy.vue
- 從 Flutter web/eula.html → pages/eula.vue

### Step 4: 配置 Firebase Hosting
- 設定 multi-site hosting (官網 + Flutter Deep Link)
- 配置 rewrites 規則

### Step 5: 部署測試
```bash
npm run generate
firebase deploy --only hosting
```

---

## 預估時程

| 階段 | 時間 |
|------|------|
| 專案初始化 + 基礎配置 | 2 小時 |
| 首頁設計與開發 | 4-6 小時 |
| About Us 頁面 | 2-3 小時 |
| 隱私/EULA 遷移 | 1 小時 |
| Firebase 配置 + 部署 | 1 小時 |
| **總計** | **約 10-13 小時** |
