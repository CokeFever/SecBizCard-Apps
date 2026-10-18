# Web Editor (ixo.app) — Strict CSP & Build Ground Truth (cross-session)

適用於 `SecBizCard` repo 的 Nuxt 4 網站(`website/`,部署到 ixo.app,含 /editor 與 /guide)。
重開 session 處理 web editor 的 CSP / 部署 / 白屏問題時以本檔為準。細節脈絡見 backend repo 的
`SecBizCard/docs/handoff_2026-10-08.md`(H1 嚴格 CSP 緣起;handoff 與 web editor/portal 設計文件已於
2026-10-18 全數移至 private backend repo)與 fix-editor-importmap-csp 任務。web editor 的設計 source
of truth 現在也在 backend repo:`SecBizCard/docs/web_editor_design.md`、`web_editor_ux_backlog.md`、
`web_portal_and_e2e_encryption_plan.md`。

## 嚴格 CSP 是刻意的,不要弱化
- root `firebase.json` 的 hosting `headers` 有一條 `**` CSP,`script-src` 是 **`'self'` + 指定
  Google/Cloudflare 來源,NO `'unsafe-inline'`**(security audit H1)。
- Nuxt SSG 預設會注入**可執行 inline script**(runtime-config bootstrap),嚴格 CSP 會擋 → 白屏。
  已用 `prerender:generate` hook 把它**外部化**到 `/_nuxt_config/<hash>.js`。這機制要保留。
- **禁止**用 `'unsafe-inline'` 當逃生門;**禁止**把 hash CSP 寫死在 firebase.json(綁 buildId 會脆)。

## 🚨 已踩過的雷:Nuxt 4.6 的 inline importmap(2026-10-11 白屏事件)
- `npm audit fix` 把 **Nuxt 4.3 → 4.6**,4.6 新增 inline `<script type="importmap">` → 被嚴格 CSP
  擋 → `#entry` 解析失敗 → **全站白屏**(/editor、/、/guide)。
- 修法(**正解,已上線 commit aa5210f**):`website/nuxt.config.ts` 加
  **`experimental: { entryImportMap: false }`** → entry 回到 `<script type="module" src=...>`,
  嚴格 CSP 照舊能用。Nuxt 維持 4.6、CSP 零改動。
- importmap **不能**用 `src` 外部化(HTML 規範禁止外部 importmap),所以 H1 那套 externalize 對它無效 →
  只能關掉 feature。

## 🚨 鐵律:凡動到 Nuxt 版本或 build 產物,必須做「嚴格 CSP 下的 runtime hydration 實測」
- **build 綠燈 ≠ 頁面能動。** build 不管 CSP;`curl` HTML/資源看起來健康也不代表能 hydrate
  (CSP 是瀏覽器執行期才擋 inline script)。白屏兩次都是這樣漏掉的。
- 驗證必須:用 `website/scripts/serve-with-csp.mjs`(純 Node,無新依賴,套用 firebase.json 的確切 CSP)
  起 server,用 **headless Chrome(puppeteer/playwright)** 載 /editor、/、/guide,確認
  (a) console **零** `Refused to ... Content-Security-Policy`,(b) 真的 hydrate(DOM 有 editor
  stepper / "Open your encrypted backup",不是空 `<div id="__nuxt">`)。拿到此證據才算修好。

## 🚨 lockfile / npm 版本陷阱(2026-10-10 L2 事件)
- CI(`firebase_deploy.yml`)用 **npm 10.8.2 on Node 20** 跑 `npm ci`(嚴格比對 lockfile)。
- 本機新版 npm/Node 的 `npm ci` 太寬鬆,**會漏掉 CI 才會爆的 lockfile out-of-sync**。
- 動到 lockfile 後,本機驗證**必須用 CI 相同版本**:`npx -y npm@10.8.2 ci`(重現 CI 檢查);
  要 re-sync 用 `npx -y npm@10.8.2 install`。
- 另:部署結果一律用 `gh run view <id> --json conclusion` 明確讀,**不要靠 `tail` 猜**(曾誤判
  failure 為 success)。

## 部署慣例
- web/Firebase = **手動** `gh workflow run firebase_deploy.yml --ref main -f deploy_target=hosting`
  (hosting-only,不碰 functions)。push main 不自動部署。
- 部署後**務必 curl 線上驗證**:`script-src` 無 unsafe-inline、inline importmap/script 數為 0、
  entry module 存在、HTTP 200。能的話再請 user 肉眼確認 hydration。
