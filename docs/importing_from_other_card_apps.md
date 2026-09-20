# Migrating Contacts + Card Images out of Another Business-Card App

A practical guide for anyone who wants to move a large set of business cards
(structured text **and** the card images) out of a third-party card app and into
SecBizCard.

This is a **methodology write-up**, not a ready-to-run scraper. Every service is
different and their terms change; treat the steps below as a decision framework
and adapt them to your own source. Only extract data from an account **you own**,
and respect the source service's Terms of Service.

> The end goal is to land two things locally: (1) the **structured fields** for
> each card, and (2) a **clear image** of each card. SecBizCard can then ingest
> both together via the `.zip` import format (see
> [`zip_import_format.md`](./zip_import_format.md)).

---

## 1. The two halves of the problem

Most card apps let you export **text** relatively easily but lock the **images**
behind a paid tier or the mobile app only. So the work splits in two:

| Half | Typical difficulty | Approach |
|------|--------------------|----------|
| Structured text | Easy–medium | Use the app's built-in export (CSV / Excel / vCard). |
| Card images | Hard | Often needs a browser-session approach against the web app. |

Do the easy half first and confirm you have complete text before spending effort
on images.

---

## 2. Getting the structured text

1. Look for a first-party **export** feature (Settings → Export, or a web
   dashboard). Prefer the richest format offered — usually Excel/CSV with one
   column per field, sometimes vCard.
2. If only vCard is offered and it exports one card at a time, check whether the
   web version can select-all and export the whole set in one file.
3. Open the export and **map its columns to the fields you care about**: name,
   company, department, title, phone(s), mobile, fax, email(s), address, website,
   note. Card apps often split a single logical field across several columns
   (e.g. `Company1 / Company2 / Company(Others)`), so plan to coalesce them.

Keep this file — it becomes the source of truth for the text half.

### Tip: parsing an `.xlsx` without extra tooling

An `.xlsx` is just a zip of XML. If you don't want to install a spreadsheet
library, you can unzip it and read two files:

- `xl/sharedStrings.xml` — the string table (cell text lives here, referenced by
  index).
- `xl/worksheets/sheetN.xml` — the cells; a cell with `t="s"` holds an index into
  the shared-strings table.

Walk the cells, resolve shared-string indices, and you have a row/column grid.

---

## 3. Getting the card images (the hard half)

### Why the obvious things fail

Card images are usually served from a CDN that expects a **logged-in browser
session**. Common dead ends:

- **Plain `curl` with no auth** → rejected (the CDN checks session cookies and/or
  the request fingerprint).
- **`fetch()` from the browser console** → blocked by CORS.
- **Drawing the image to a `<canvas>` then `toDataURL()`** → the canvas is
  "tainted" by the cross-origin image and export throws.

### What actually works: a real browser session

The reliable path is to **drive a real, logged-in browser** and either read the
image bytes through the browser's own network layer, or replay a request with the
**full session cookie** copied from a genuine request.

Tooling options:

- **Chrome DevTools MCP / Chrome DevTools Protocol (CDP)** — attach to a Chrome
  instance started with remote debugging, navigate the list, read the DOM to
  collect each card's id + image URL, and pull image bytes via the browser's
  network layer.
- **A browser-automation framework** (Playwright/Puppeteer) — same idea with a
  scripted context.
- **Manual cookie + `curl`** — capture one real image request in DevTools,
  copy its complete `Cookie` header and `User-Agent`, then replay with `curl`.
  This works because you're presenting the exact session the server expects.

### General recipe

1. **Start a browser you control.** For CDP/MCP, launch Chrome with a
   remote-debugging port and an **isolated user-data-dir** (a throwaway profile),
   then log into the source service once in that window. Using a separate profile
   avoids fighting your daily browser's locks/permissions.
2. **Set the list to show as many items per page as possible** to minimise
   pagination.
3. **Read the list DOM** to build an index: for each row capture a stable id, the
   person's name, and the thumbnail image URL.
4. **Derive the full-resolution URL.** Thumbnails often encode a size in the
   filename (e.g. a `...t80u.jpg` thumbnail vs a `...r80u.jpg` larger variant).
   Inspect a couple of variants to find the largest that still returns the
   original scan.
5. **Handle pagination deliberately.** Simple "next" clicks sometimes don't fire;
   setting a page-number input and dispatching a keyboard Enter event is often
   more reliable. Re-read the DOM after each page.
6. **Download with the session.** Either capture bytes through the browser's
   network inspector, or replay each URL with `curl` carrying the copied
   `Cookie` + `User-Agent` + `Referer`. Verify each file is a real image
   (check the magic bytes / `file` output), and retry failures.
7. **Key every image to the same id** you captured in step 3, so you can later
   join images to the text rows.

### Security & privacy notes

- Session cookies (especially the session id) are **secrets** and **expire**.
  Never commit them anywhere. Re-capture a fresh cookie right before a batch run.
- The isolated browser profile and any remote-debugging switch are **temporary**:
  close the window and delete the throwaway profile when done.
- These images are **other people's PII**. Keep them on a trusted local machine,
  don't upload them anywhere you don't control, and delete intermediates you
  don't need.

---

## 4. Joining text ↔ images

You now have two datasets:

- Text rows (from the export) — often in the same order as the web list.
- Image files — keyed by the id you captured while scraping.

Produce a **mapping** (a small CSV/JSON of `id ↔ name ↔ image filename`). If the
export and the scrape were both taken in the same sort order, row order alone can
be enough to pair them — but a mapping keyed by id is more robust and lets you
re-run either half independently.

Sanity-check the join before packaging: counts match, every text row has an image
(or a known reason it doesn't), and a few spot-checked names line up with their
images.

---

## 5. Packaging for SecBizCard

Once you have text + images + a reliable join, assemble the SecBizCard `.zip`
import package described in [`zip_import_format.md`](./zip_import_format.md):

- `manifest.json` — one entry per contact with the mapped fields and a
  `frontImage` path.
- `images/` — the card images, renamed to clean ASCII filenames referenced by the
  manifest.

Then import it in the app (**Import** screen → choose the `.zip`). Everything is
processed on-device; nothing is uploaded to a backend.

---

## 6. Alternative: skip images, re-OCR later

If pulling images turns out to be impractical for your source, a valid fallback
is to import **text only** (via `.vcf` or a manifest with no images) and later
re-scan the physical or saved cards through SecBizCard's own OCR. You lose the
convenience of bulk images but keep a clean, supported path.

---

## Appendix — AI-assisted walkthrough (Chrome DevTools MCP)

This appendix turns the methodology above into concrete, runnable steps for an
AI coding assistant (e.g. Kiro, Claude, Cursor) driving a browser via the
**Chrome DevTools MCP** server. It is written to be adapted to any source; the
placeholders `SOURCE_URL`, `IMAGE_HOST`, and the DOM selectors must be filled in
for your specific card app by inspecting it.

> Scope reminder: do this only for an account **you own**, respect the source's
> Terms of Service, and keep all card data (third-party PII) on your local
> machine. Session cookies are secrets — never commit them.

### Step 0 — Install & connect Chrome DevTools MCP

`chrome-devtools-mcp` lets the assistant read the DOM, run JS, and inspect
network traffic in a real Chrome. Add it to your MCP config:

```jsonc
// ~/.kiro/settings/mcp.json  (or your client's MCP config)
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--browserUrl", "http://127.0.0.1:9222"],
      "disabled": false
    }
  }
}
```

Requirements: Node.js (for `npx`) and Google Chrome installed. The
`--browserUrl` tells the server to attach to a Chrome you start yourself (next
step), which is more reliable than letting it auto-launch.

### Step 1 — Launch Chrome with remote debugging (isolated profile)

Start Chrome on the debugging port with a **throwaway profile** (avoids clashing
with your everyday Chrome's locks/permissions), then log into the source once in
that window:

```sh
# macOS
nohup "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/.chrome-mcp-scrape" \
  "SOURCE_URL" >/tmp/chrome_mcp.log 2>&1 & disown
```

(Linux: `google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-mcp-scrape SOURCE_URL`.)
Log in manually in that window. The assistant then confirms the attach with the
MCP `list_pages` tool and notes the page id.

Troubleshooting we actually hit:
- **`exit 21` / SingletonLock / permission prompts** when reusing your daily
  profile → use the separate `--user-data-dir` above.
- Auto-connect failing to find the tab → prefer the explicit
  `--browserUrl http://127.0.0.1:9222` in the MCP config.

### Step 2 — Set the list to the largest page size

In the source's contact list, set "items per page" to its maximum to minimise
pagination. Note how many pages that leaves (e.g. 200/page → 231 cards = 2 pages).

### Step 3 — Extract the list index (id + name + image URL)

Have the assistant run JS in the page via the MCP `evaluate_script` tool. You
must adapt the selectors to the source's DOM (inspect one row first). Shape:

```js
// evaluate_script — returns one row per card
() => {
  const rows = [...document.querySelectorAll('ROW_SELECTOR')];
  return rows.map(r => {
    const key  = r.getAttribute('ID_ATTR');                 // stable id
    const name = r.querySelector('NAME_SELECTOR')?.textContent?.trim() || '';
    const img  = r.querySelector('img');
    // thumbnails often carry a size token; swap to the largest variant:
    let hi = img?.getAttribute('data-src') || img?.getAttribute('src') || '';
    hi = hi.replace('.tXXu.jpg', '.rXXu.jpg');              // see Step 4
    return { key, name, hi };
  }).filter(x => x.key && x.hi);
}
```

Save the returned rows to a JSON file per page.

### Step 4 — Find the full-resolution URL

Thumbnails usually encode a size in the filename. Load a couple of variants of
one image (via the browser) and compare dimensions to find the largest that
still returns the original scan. Example seen in the wild: list thumbnails were
`....t80u.jpg`; swapping to `....r80u.jpg` returned the full card. Confirm by
checking the loaded image's `naturalWidth/Height`.

### Step 5 — Paginate

A plain "next" click sometimes doesn't fire. Setting the page-number input and
dispatching a keyboard Enter is more reliable:

```js
() => {
  const inp = document.querySelector('PAGE_INPUT_SELECTOR');
  inp.value = '2';
  const ev = (t) => new KeyboardEvent(t, {key:'Enter', keyCode:13, which:13, bubbles:true});
  inp.dispatchEvent(ev('keydown'));
  inp.dispatchEvent(ev('keyup'));
}
```

Wait, then re-run Step 3's extraction. Repeat for each page and concatenate.

### Step 6 — Capture a fresh session cookie

The image CDN needs your logged-in session. Two ways to get the exact header:

- Read `document.cookie` via `evaluate_script` (covers non-HttpOnly cookies; on
  many CDNs the session id is readable here), **or**
- Use the MCP network tools: trigger one image load, `list_network_requests`
  (filter to images), then `get_network_request` on an `IMAGE_HOST` request and
  copy its full `Cookie` + `User-Agent` + `Referer` request headers.

Re-capture right before the batch — cookies expire.

### Step 7 — Batch download with the session

Replay each full-res URL with `curl` carrying the captured headers. A small
script (Python/shell) that: loops the merged list, downloads
`IMAGE_HOST/<id>.rXXu.jpg` to `EXPORT_DIR/images/<id>__<name>.jpg`, verifies
each file is a real image (`file` / magic bytes `FF D8 FF` for JPEG), and
retries failures. Key each file to the `id` from Step 3 so text and images can
be joined later.

Why `curl` with the copied cookie works when naked `curl` doesn't: you're
presenting the exact session (cookie + UA + referer) the CDN expects. Browser
`fetch()` is blocked by CORS and a canvas `toDataURL()` is tainted — hence this
approach.

### Step 8 — Build mapping + package

Produce `mapping.csv` (`id,name,image_filename,status`), then run the packaging
step (§5) to emit `manifest.json` + `images/` and zip it. Import the `.zip` in
SecBizCard.

### Step 9 — Clean up

Quit the isolated Chrome, delete the throwaway profile
(`rm -rf ~/.chrome-mcp-scrape`), remove the MCP entry if you no longer need it,
and delete working data you don't want to keep. Never commit cookies or card
images.

> Reference implementation: the Excel-parsing, vCard and `.zip` packaging
> scripts used for one real migration live in the **private** companion repo
> under `tools/camcard-migration/` (kept private precisely because they encode a
> specific source's layout; the data itself is git-ignored). This public
> appendix is the reusable method; adapt the selectors and URL tokens to your
> own source.
