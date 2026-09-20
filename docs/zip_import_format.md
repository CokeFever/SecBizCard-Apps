# SecBizCard `.zip` 匯入格式規格 (v1)

這份文件定義 SecBizCard app「批次匯入」用的 `.zip` 封包格式。它是 `.vcf`
匯入的進階版:除了結構化的聯絡人文字,還能一起帶入**裁切校正後的名片圖**。

用途:讓使用者用任意 AI/LLM app 拍多張名片、辨識、裁圖,依本規格打包成一個
`.zip`,再交給 SecBizCard 在**本機**解開匯入。全程不經過 SecBizCard 後端,
符合「不觸碰個資」原則。

---

## 1. 封包結構

```
import.zip
├── manifest.json         # 必要。UTF-8。聯絡人陣列 + 對應圖檔檔名。
└── images/               # 選用。所有名片圖放這裡。沒有圖的封包可省略整個資料夾。
    ├── 0001_front.jpg
    ├── 0001_back.jpg
    ├── 0002_front.jpg
    └── ...
```

規則:
- `manifest.json` **必須**在 zip 根目錄。
- 所有圖檔**必須**放在 `images/` 資料夾下(可再分子目錄,但檔名以 manifest 內的相對路徑為準)。
- 圖檔格式:接受 `jpg` / `jpeg` / `png` / `webp`;**建議用 `jpg`**(檔案小、名片照相容性最佳)。
- 檔名只用 ASCII 英數、底線、連字號、點;避免空白與非 ASCII,以降低跨平台問題。

### 限制(app 匯入時強制,超過會被拒絕或略過)

為避免異常或惡意的封包拖垮 app,匯入時有以下上限:

| 項目 | 上限 | 超過時的行為 |
|------|------|--------------|
| 聯絡人筆數 | **2000** | 整包拒絕匯入 |
| 單張圖大小 | **10 MB** | 略過該圖(聯絡人仍會匯入,只是沒那張圖) |
| 解壓後圖片總量 | **200 MB** | 達上限後不再解壓後續圖片 |

參考:一批數百張名片的 `jpg` 封包通常只有數十 MB,遠低於上限。請勿放入未壓縮或超高解析度的原圖。

---

## 2. `manifest.json` Schema

頂層是一個物件:

```json
{
  "version": 1,
  "source": "ai-ocr",
  "contacts": [ /* Contact 物件陣列 */ ]
}
```

| 欄位 | 型別 | 必要 | 說明 |
|------|------|------|------|
| `version` | int | 是 | 目前固定為 `1`。未來格式演進用。 |
| `source` | string | 否 | 產包來源標記,自由字串(例:`"ai-ocr"`、`"camcard"`)。僅供記錄。 |
| `contacts` | array | 是 | 聯絡人清單。空陣列合法(視為沒有可匯入的聯絡人)。 |

### Contact 物件

所有欄位除 `name` 外皆為選填。缺的欄位可省略或給 `null`/空字串。

| 欄位 | 型別 | 對應 app 欄位 | 說明 |
|------|------|--------------|------|
| `name` | string | displayName | **建議必填**。聯絡人顯示名稱。缺時退回 email,再退回 `"Unknown"`。 |
| `company` | string | company | 公司 |
| `department` | string | department | 部門 |
| `title` | string | title | 職稱 |
| `email` | string | email | 主要 email(單一;多個放 `emails`) |
| `phone` | string | phone | 市話/公司電話 |
| `mobile` | string | mobile | 行動電話 |
| `fax` | string | customFields["fax"] | 傳真 |
| `website` | string | website | 網站 |
| `address` | string | address | 完整地址(單行文字即可) |
| `note` | string | customFields["note"] | 備註 |
| `emails` | string[] | (第一個→email,其餘→customFields) | 多 email 時使用 |
| `phones` | string[] | (依序補 phone/mobile) | 多電話時使用 |
| `frontImage` | string | cardFrontPath | 名片正面圖,相對 zip 根的路徑,例 `"images/0001_front.jpg"` |
| `backImage` | string | cardBackPath | 名片背面圖(選) |
| `originalImage` | string | originalImagePath | 未裁切的原始拍攝圖(選) |

備註:
- 若同時給了 `email` 與 `emails`,以 `email` 為主,`emails` 內未重複者存進 customFields。
- 圖檔路徑必須指到 zip 內實際存在的檔案;找不到的圖會被忽略(該聯絡人仍會匯入,只是沒圖)。
- app 端會為每筆聯絡人自動產生一個新的內部 `uid`;manifest **不需要**、也不應假設 uid。

---

## 3. 範例

```json
{
  "version": 1,
  "source": "ai-ocr",
  "contacts": [
    {
      "name": "劉心如",
      "company": "Google",
      "title": "Data Analytics Sales Specialist",
      "email": "shinruliu@example.com",
      "phone": "+886920069682",
      "frontImage": "images/0001_front.jpg"
    },
    {
      "name": "Louis Lu",
      "company": "Softmobile Technology",
      "department": "Marketing Tech",
      "title": "Assistant Vice President",
      "mobile": "+886920221660",
      "phone": "+886287525527",
      "fax": "+886287525596",
      "email": "louislu@example.com",
      "address": "No.2, Ln. 258, Ruiguang Rd., Neihu Dist., Taipei 114, Taiwan",
      "website": "www.example.com",
      "frontImage": "images/0002_front.jpg",
      "backImage": "images/0002_back.jpg"
    }
  ]
}
```

對應的 zip:

```
import.zip
├── manifest.json
└── images/
    ├── 0001_front.jpg
    ├── 0002_front.jpg
    └── 0002_back.jpg
```

---

## 4. 給 LLM 的產包指示(可直接貼給 AI)

> 我有數張名片照片。請你:
> 1. 逐張辨識名片上的聯絡資訊(姓名、公司、部門、職稱、電話、手機、傳真、email、地址、網站)。
> 2. 把每張名片裁切、校正邊緣成一張乾淨的正面圖(必要時含背面)。
> 3. 依照「SecBizCard zip 匯入格式 v1」產生一個 `manifest.json`:頂層含 `version: 1`、`contacts` 陣列;每筆聯絡人的欄位用 name/company/department/title/email/phone/mobile/fax/website/address/note,並用 `frontImage`/`backImage` 指向 `images/` 下對應的圖檔相對路徑。
> 4. 把 `manifest.json` 放在 zip 根目錄,所有圖放在 `images/`,打包成一個 `.zip` 給我。

---

## 5. app 端匯入行為(實作契約)

- 使用者在「Import」畫面選檔;`.vcf` 走既有 vCard 解析,`.zip` 走本格式解析(依副檔名分流)。
- app 解 zip → 讀 `manifest.json` → 對每筆 Contact:
  1. 把引用到的圖檔從 zip 解到暫存目錄。
  2. 組出 `UserProfile`(新 uid、`source` 設為 `'ocr'`、圖路徑指向暫存檔)。
  3. 交給既有 `saveContactLocally`;圖片會由既有落地邏輯自動搬到 app 永久目錄
     (`cardFrontPath`/`cardBackPath`→`profile/`,`originalImagePath`→`contacts/`)。
- 一筆聯絡人若完全沒有可用資訊(無 name/email/phone/mobile),略過不匯入。
- 匯入為新增(每筆新 uid),不覆蓋既有聯絡人。
- 全程本機處理,不上傳任何資料到後端。
