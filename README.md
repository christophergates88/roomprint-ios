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

1. In the `website` folder, replace **[your support email]** in both files.
2. Upload `privacy.html` and `support.html` to your website (or to GitHub Pages, the same way you host Lookout).
3. Update `serviceURL` and `privacyURL` in `Roomprint/App/AppConfig.swift` to the real addresses. Until your domain is live, `serviceURL` points at the public Roomprint site draft so the "Book a Roomprint visit" link works; `privacyURL` must be a working page before you submit.

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

## What's in the app

| Screen | What it does |
| --- | --- |
| Welcome | Three short intro pages |
| Homes | Your homes with their total value |
| Home | Big total, "need proof" count, grid of rooms |
| Room | Items with photos and values; **Snap items** opens a camera that saves one item per photo |
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
- `website` – privacy policy and support pages

Requires iOS 17 or later. iPhone only, portrait.
