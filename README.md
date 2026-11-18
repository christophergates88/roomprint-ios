# Roomprint for iPhone

A home inventory app. People film a slow walkthrough of a room, approve the list of belongings the AI scan finds (with estimated values), and export a claim-ready PDF. Snap and Add cover one-offs, and a label scanner reads model and serial stickers. Records stay on the phone. Only room scans send anything off it, and only after the person allows it on a permission screen: still frames, label text and the room name go to our scan service, which uses Anthropic's Claude. The service keeps no frames.

**Shipping a new build:** double-click `Ship Roomprint.command` on the Mac (or see `appstore/RESUBMIT.md`). It pulls the latest code, updates the scan service, archives and uploads to App Store Connect. **CI:** every push to `main` builds the app with Xcode 26, makes an unsigned App Store archive and takes 6.9-inch screenshots from demo mode; results land on the `ci-results` branch.

**Business model:** free for 1 home and up to 30 items. **Roomprint Pro** is a one-time purchase that unlocks unlimited homes and items, password-protected PDFs, and spreadsheet export. Room scans are paid for with consumable scan credits (the first scan on a device is free).

---

## What you need

- A Mac with **Xcode 16 or newer** (free from the Mac App Store).
- An **Apple Developer Program** membership: $99 per year, at developer.apple.com/programs. You need it to put the app on the App Store and to test the purchase on a real phone.
- Your iPhone and its cable.

## 1. Open and run the app (about 15 minutes)

1. Unzip the folder and double-click **Roomprint.xcodeproj**.
2. In the left sidebar, click the blue **Roomprint** project icon, then the **Roomprint** target, then **Signing & Capabilities**.
3. Under **Team**, pick your Apple Developer account. If Xcode says the bundle ID is taken, change `com.christophergates.roomprint` to something unique, and change the same text in `Roomprint/App/AppConfig.swift` (the Pro product ID).
4. Plug in your iPhone, pick it at the top of Xcode, and press **Run** (the ▶ button).
5. The first time, your iPhone may ask you to trust the developer: **Settings → General → VPN & Device Management**.

If Xcode shows a red build error, copy the error text and send it to Claude. It's usually a one-line fix.

## 2. Set up the Pro purchase (about 20 minutes)

1. Go to **appstoreconnect.apple.com → Apps → +** and create a new iOS app named **Roomprint** with your bundle ID.
2. In the app, open **Monetization → In-App Purchases → +**.
   - Type: **Non-Consumable**
   - Product ID: `com.christophergates.roomprint.pro` (must match `AppConfig.swift`)
   - Reference name: Roomprint Pro
   - Price: suggest **$9.99**
   - Add a display name ("Roomprint Pro"), a description ("Unlimited homes and items, locked PDFs, spreadsheet export") and a review screenshot of the paywall.
3. To test buying without paying, in Xcode choose **File → New → File → StoreKit Configuration File**, check **Sync this file with an app in App Store Connect**, then **Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration** and select it.

## 3. Put up the website pages

Apple requires a privacy policy link and a support link.

The pages live in the `docs` folder and are published with GitHub Pages:

- Privacy policy: https://christophergates88.github.io/roomprint-ios/privacy.html
- Support: https://christophergates88.github.io/roomprint-ios/support.html

`privacyURL` in `Roomprint/App/AppConfig.swift` already points at the privacy page. When you have your own domain, move the two pages there and change `privacyURL` and `serviceURL` to match. The contact email on both pages is in the HTML; change it there when you have a Roomprint address.

## 4. Submit to the App Store

1. In Xcode, set the device to **Any iOS Device**, then **Product → Archive**.
2. When the Organizer opens, click **Distribute App → App Store Connect → Upload**.
3. In App Store Connect, fill in:
   - **Screenshots:** 6.9-inch iPhone screenshots (take them on your phone or the iPhone 16 Pro Max simulator). Good ones: a room full of items, the camera, the home total, the PDF.
   - **Description, keywords** (home inventory, insurance, belongings, claim, moving), **support URL**, **privacy policy URL**.
   - **App Privacy:** **Yes, data is collected**: Photos or Videos, Other User Content and Device ID, each for App Functionality, not linked to the user, not used for tracking (room scans only). See `appstore/RESUBMIT.md`.
   - **Category:** Productivity (or Lifestyle).
   - **Age rating:** 4+.
4. Attach the Pro in-app purchase to the version, then **Submit for Review**. Review usually takes 1–3 days.

## Room scans (AI)

The main way to record a room: film a slow walkthrough, the phone pulls sharp frames and reads label
text on-device, the frames go to the scan service (`worker/`, a Cloudflare Worker), which asks Claude to
name and value every item, and you approve the list before anything is saved. Snap and Add remain for
one-offs. Frames are processed and not stored.

- First scan on a device is free; then consumable credits (`…roomprint.scans3` for 3, `…scans10` for 10),
  created in App Store Connect as **Consumable** products. A scan is charged when a list comes back. Credits
  live in the Keychain, so a reinstall keeps them. Only Debug builds from Xcode run free; TestFlight and
  review builds are charged like the store build (TestFlight purchases cost nothing).
- `AppConfig.scanServiceURL` is the Worker's address. The app sends `ScanKey.value`, which must equal the
  Worker's `APP_KEY` secret. The ship script keeps the real key on the Mac (`~/.roomprint/scan-key`) and only
  puts it into the App Store build, so the key in this public repo stops working after the first ship.
- The Worker needs secrets `ANTHROPIC_API_KEY` and `APP_KEY`, and a KV binding `ROOMPRINT_KV` for the
  daily caps (20 scans per device per day, 150 per day in total, adjustable in its variables).
- Deployed at `https://roomprint-scan.christophergates-cg.workers.dev` (`/health` reports whether the key is
  set). To redeploy after changing `worker/src/worker.js`: `cd worker && npx wrangler deploy`; to rotate a
  secret: `npx wrangler secret put ANTHROPIC_API_KEY` (never commit keys). The model runs on prepaid API
  credits at console.anthropic.com. On Sonnet 5.5 ($2 per million input tokens) a 1024px frame is about
  1,000 tokens, so a 40-frame scan costs roughly 10¢ and a maximum 80-frame scan about 20¢; Haiku 5.5
  (`MODEL` variable) would be about 20× cheaper. `GET /stats` with the app key reports scans, tokens and
  estimated cost for today, the last 7 days and the month.

## What's in the app

| Screen | What it does |
| --- | --- |
| Welcome | Three short intro pages |
| Homes | Your homes with their total value |
| Home | Big total, "need proof" count, grid of rooms |
| Room | Items with photos and values; **Scan room** films a walkthrough and lists everything; Snap/Add for one-offs |
| Item | Photos, name, value, quantity; More details holds brand, model, serial, price paid, purchase date, receipt, notes |
| Label scanner | Reads text from a model or serial sticker on the phone and drops it into the right field |
| Export | Branded PDF (optional password with Pro) and CSV spreadsheet (Pro) |
| AI consent | Before the first scan: what is sent, to whom, what happens to it; Allow or Not now (Guideline 5.1.2(i)) |
| Settings | Pro status, scan balance, Allow AI room scans, Face ID lock, Help, Email support, Privacy, Terms, restore purchase |

## Files

- `Roomprint/App` – app entry, data model, colors and logo, Pro purchase, settings you may change (`AppConfig.swift`)
- `Roomprint/Screens` – the main screens
- `Roomprint/Capture` – camera and label scanner
- `Roomprint/Export` – PDF and spreadsheet
- `Roomprint/Assets.xcassets` – app icon and accent color
- `Roomprint/PrivacyInfo.xcprivacy` – Apple's required privacy manifest
- `docs` – getroomprint.com: home page, privacy policy, support page, sample record (served by GitHub Pages)
- `appstore` – the App Store listing text, the resubmission steps, and marketing screenshots
- `tools` – CI scripts and the screenshot framer
- `Roomprint/App/Demo.swift` – demo mode for screenshots: launch with `-RPDemo -RPScreen home|room|scan|review|pdf|export|homes|onboarding` (in-memory, never touches real records)

Requires iOS 17 or later. iPhone only, portrait.
