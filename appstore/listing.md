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
| Subtitle (30 chars max) | Film rooms. Get a claim list. |
| Category | Primary: Productivity · Secondary: Finance |
| Age rating | 4+ (no objectionable content) |
| Copyright | 2026 Christopher Gates |
| Privacy policy URL | https://getroomprint.com/privacy.html |
| Support URL | https://getroomprint.com/support.html |
| Marketing URL | https://getroomprint.com |
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
> ARE YOU COVERED?
> Enter the contents coverage from your policy and Roomprint shows how it compares with what you actually own. It also points out things policies often cap, like jewelry, firearms and collectibles, and writes a note you can send your agent.
>
> IF THE WORST HAPPENS
> After a fire, theft or storm, mark what was lost or damaged, by room or all at once, and get a claim list PDF and spreadsheet with the date of loss and your claim number, ready for the adjuster.
>
> PRIVATE BY DESIGN
> Your records stay on your iPhone, in your own backup. Lock the app with Face ID. A room scan asks first, then sends still frames from your video to our scan service, which uses Anthropic's Claude AI to list the items. Roomprint keeps no frames, and Anthropic doesn't train on them.
>
> FREE AND PRO
> Free covers one home and up to 30 items, with one free room scan. Roomprint Pro is a one-time purchase: unlimited homes and items, password-protected PDFs and spreadsheet export. Room scans beyond the first are sold as small packs of credits.
>
> Roomprint is made in Georgia by someone who has watched claims fall short for want of a list. Make yours before you need it.

**Keywords** (100 chars max, comma-separated, no spaces)

> insurance,claim,contents,belongings,valuables,receipts,renters,homeowners,fire,flood,theft,serial

(97 characters. "Home" and "Inventory" are already in the app name, so repeating them here wastes space.)

**What's New in This Version**

> First release. Film a room, approve the list, check your coverage, export a claim-ready PDF.

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
| Device ID | Yes (a random per-install id for daily scan limits) | No | No | App Functionality |

Everything else (items, photos, receipts, PDFs, purchases) stays on the phone and is **not collected**. This matches `Roomprint/PrivacyInfo.xcprivacy`.

## Screenshots

Ready-made 6.9-inch set (1320 × 2868): `appstore/screenshots/6.9/`, in upload order. They come from the app's
demo mode on the simulator (CI takes fresh raw shots on every push; `tools/frame_shots.py` adds the captions).
Real screenshots from your own house are even better for sales later; keep the same order:

1. Film a room. Get the list. (the scan review screen)
2. Know what your home holds. (the home total and rooms)
3. A claim-ready record. (the PDF)
4. Proof for every item. (a room's items)
5. One slow walkthrough. (the scan screen)
6. Private by design. (the homes screen)

## Export compliance

`ITSAppUsesNonExemptEncryption` is already `NO` in the project (HTTPS only), so App Store Connect won't ask the encryption question on each upload.

## Review notes

The current review notes, the reply to App Review and the resubmission steps are in `appstore/RESUBMIT.md`.

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
