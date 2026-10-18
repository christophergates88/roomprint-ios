# Roomprint — App Store listing (draft, ready to paste)

Everything App Store Connect asks for, in the order it asks. Edit freely; nothing here is final until it is submitted.

## App record

| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | Roomprint |
| Primary language | English (U.S.) |
| Bundle ID | com.christophergates.roomprint |
| SKU | roomprint-ios |
| User access | Full access |

## Version information

| Field | Value |
| --- | --- |
| Subtitle (30 chars max) | Home inventory in minutes |
| Category | Primary: Productivity · Secondary: Finance |
| Age rating | 4+ (no objectionable content) |
| Copyright | 2026 Christopher Gates |
| Privacy policy URL | https://christophergates88.github.io/roomprint-ios/privacy.html |
| Support URL | https://christophergates88.github.io/roomprint-ios/support.html |
| Marketing URL | (leave blank until the site is live) |
| Price | Free, with in-app purchases |

**Promotional text** (170 chars, can change without a new build)

> Film a room once. Roomprint lists what's in it, with values, and you approve the list. Your claim-ready home record, done in an afternoon.

**Description**

> If your home burned, flooded or was burglarized tomorrow, could you list everything you owned, with values and proof? Most people can't — and the insurer pays on what you can show.
>
> Roomprint fixes that in an afternoon.
>
> SCAN A ROOM
> Film a slow walkthrough of any room. Roomprint pulls the sharp frames, reads model and serial labels right on your phone, and comes back with a list of what it found — each item named, counted and given an estimated replacement value. You review it, swipe off anything wrong, fix a value, and approve. Nothing is saved until you say so.
>
> ADD THE REST
> Snap one-off items with the camera, or type them in. Point the label scanner at a sticker and the model and serial numbers drop into the right fields.
>
> KEEP PROOF
> Attach receipts and close-ups. Items with proof are marked so you can see at a glance what's documented.
>
> EXPORT A CLAIM-READY RECORD
> One tap makes a clean PDF of your whole home — every room, every item, photos, values and totals — the way an adjuster wants to see it. Keep a copy somewhere safe and share it with your agent.
>
> PRIVATE BY DESIGN
> Your records stay on your iPhone, in your own backup. Lock the app with Face ID. Room scans send only the video frames to our scan service for identification, and the frames are not stored.
>
> FREE AND PRO
> Free covers one home and up to 30 items, with one free room scan. Roomprint Pro is a one-time purchase: unlimited homes and items, password-protected PDFs and spreadsheet export. Room scans beyond the first are sold as small packs of credits.
>
> Roomprint is made in Georgia by someone who sells homeowners insurance and has watched claims fall short for want of a list. Make yours before you need it.

**Keywords** (100 chars max, comma-separated, no spaces)

> home inventory,insurance,claim,contents,belongings,valuables,receipts,renters,homeowners,inventory

**What's New in This Version**

> First release. Film a room, approve the list, export a claim-ready PDF.

## In-app purchases

Create these under **Monetization → In-App Purchases** before uploading the build, so the first TestFlight build can test them. Product IDs must match `AppConfig.swift` exactly.

| Reference name | Product ID | Type | Suggested price | Display name | Description |
| --- | --- | --- | --- | --- | --- |
| Roomprint Pro | com.christophergates.roomprint.pro | Non-consumable | $19.99 | Roomprint Pro | Unlimited homes and items, password-protected PDFs, spreadsheet export. One purchase, yours for good. |
| 3 room scans | com.christophergates.roomprint.scans3 | Consumable | $2.99 | 3 room scans | Three AI room scans: film a room, approve the list. |
| 10 room scans | com.christophergates.roomprint.scans10 | Consumable | $7.99 | 10 room scans | Ten AI room scans: film a room, approve the list. |

Each purchase also needs a review screenshot (any screenshot of the paywall or credits screen) and the **Paid Apps** agreement signed under Business, with banking and tax forms, before it can go live.

## App privacy (the nutrition label)

Answer **Yes, we collect data from this app**, then:

| Data type | Collected? | Linked to the user? | Used for tracking? | Purpose |
| --- | --- | --- | --- | --- |
| Photos or Videos | Yes (video frames during a room scan) | No | No | App Functionality |
| Other User Content | Yes (the room's name, sent with the frames) | No | No | App Functionality |
| User ID | Yes (a random per-install id for daily scan limits) | No | No | App Functionality |

Everything else (items, photos, receipts, PDFs, purchases) stays on the phone and is **not collected**. This matches `Roomprint/PrivacyInfo.xcprivacy`.

## Screenshots

Required: one set for the 6.9-inch iPhone (1320 × 2868) **or** the 6.5-inch size (1284 × 2778 — an iPhone 13 Pro Max screenshot is exactly this). Up to 10; the first three matter most. Take them on the phone with a real, filled-in home:

1. A room's item list with values and the total (the money shot).
2. The scan review screen with the list it found.
3. The scan start screen ("Film the room once. We list what's in it.").
4. The homes screen.
5. The exported PDF, opened.

## Export compliance

`ITSAppUsesNonExemptEncryption` is already `NO` in the project (HTTPS only), so App Store Connect won't ask the encryption question on each upload.

## Review notes (paste into "Notes" for the reviewer)

> Roomprint keeps all records on the device. The only network feature is "Scan room": the app sends frames from a walkthrough video to our service at roomprint-scan.christophergates-cg.workers.dev, which identifies items and returns a list for the user to approve. Frames are not stored. To test: add a home and a room, tap Scan room, film a few seconds of any room, and approve the list. The first scan is free; TestFlight and review builds are not charged credits.

## After enrollment: the order of operations

1. Accept the Developer Program License Agreement at developer.apple.com (it blocks everything until accepted).
2. App Store Connect → Business → sign the **Paid Apps** agreement, add bank account and tax forms (needed for any purchase, including TestFlight sandbox testing of real products).
3. Xcode → Settings → Accounts: confirm the Apple ID shows the new (paid) team; set that team on the Roomprint target under Signing & Capabilities.
4. Certificates, Identifiers & Profiles: register the App ID `com.christophergates.roomprint` with **In-App Purchase** enabled (Xcode's automatic signing can do this).
5. App Store Connect → My Apps → **+** New App with the values above.
6. Create the three in-app purchases.
7. Xcode: Product → Archive → Distribute App → App Store Connect → Upload. Processing takes 10–30 minutes.
8. TestFlight tab → the build appears → Internal Testing → add Christopher as a tester → install the TestFlight app on the iPhone → accept the invite.
9. Fill in the version information, upload screenshots, answer App Privacy, attach the build and the IAPs, Submit for Review.
