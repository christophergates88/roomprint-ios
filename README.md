# Roomprint for iPhone

A home inventory app. People photograph their belongings room by room, scan model and serial labels, and export a claim-ready PDF. Everything stays on the phone, so there are no server or AI costs.

**Business model:** free for 1 home and up to 30 items. **Roomprint Pro** is a one-time purchase that unlocks unlimited homes and items, password-protected PDFs, and spreadsheet export.

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
   - **App Privacy:** choose **"Data Not Collected"**. The app collects nothing.
   - **Category:** Productivity (or Lifestyle).
   - **Age rating:** 4+.
4. Attach the Pro in-app purchase to the version, then **Submit for Review**. Review usually takes 1–3 days.

## Room scans (AI)

The main way to record a room: film a slow walkthrough, the phone pulls sharp frames and reads label
text on-device, the frames go to the scan service (`worker/`, a Cloudflare Worker), which asks Claude to
name and value every item, and you approve the list before anything is saved. Snap and Add remain for
one-offs. Frames are processed and not stored.

- First scan on a device is free; then consumable credits (`…roomprint.scans3` for 3, `…scans10` for 10),
  created in App Store Connect as **Consumable** products. Debug builds from Xcode never use credits so the
  flow can be tested.
- `AppConfig.scanServiceURL` is the Worker's address and `scanAppKey` must equal the Worker's `APP_KEY` secret.
- The Worker needs secrets `ANTHROPIC_API_KEY` and `APP_KEY`, and a KV binding `ROOMPRINT_KV` for the
  daily caps (6 scans per device per day, 150 per day in total, adjustable in its variables).

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
| Settings | Pro status, Face ID lock, "Book a Roomprint visit" link, restore purchase |

## Files

- `Roomprint/App` – app entry, data model, colors and logo, Pro purchase, settings you may change (`AppConfig.swift`)
- `Roomprint/Screens` – the main screens
- `Roomprint/Capture` – camera and label scanner
- `Roomprint/Export` – PDF and spreadsheet
- `Roomprint/Assets.xcassets` – app icon and accent color
- `Roomprint/PrivacyInfo.xcprivacy` – Apple's required privacy manifest
- `docs` – privacy policy and support pages (served by GitHub Pages)

Requires iOS 17 or later. iPhone only, portrait.
