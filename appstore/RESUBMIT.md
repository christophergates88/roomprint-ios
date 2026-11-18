# Resubmit Roomprint to App Review

Apple sent back the Oct 30 submission on Nov 3 ("There's an issue with your submission"). Their exact note
is only inside App Store Connect. Build 1.0 (2026…) fixes the two things in the old build that break Apple's
current rules, whatever else the note says:

1. **Third-party AI consent (Guideline 5.1.2(i), in force since Nov 2025).** The old build sent room video
   to Anthropic's Claude without asking. The new build shows a permission screen before the first scan:
   what is sent, who gets it, what happens to it. Nothing leaves the phone until the person taps
   **Allow and continue**, and Settings can withdraw it.
2. **Reviewers couldn't reach the scan-pack purchase.** The old build treated TestFlight and review builds
   as "Test build: scans don't use credits", so the paywall for the consumables never appeared and the
   screen said "Test build". Review builds now work like the store build: first scan free, then packs.
   "Get more room scans" is on the scan screen and in Settings.

Also new in the app: a coverage check (your record against your policy's contents coverage), a claim list for
after a loss, one-tap "often missed" items, a six-month reminder. And: privacy policy rewritten for the AI rule (getroomprint.com/privacy.html), the scan service can't
cut off long lists, credits survive a reinstall, scan-first onboarding, PDF preview, Help/Email/Terms in
Settings, the private scan key.

---

## Step 1. Send the build to Apple (Mac, about 10 minutes)

1. Press **Cmd + Space**, type **Terminal**, press **Return**.
2. Paste this whole line and press **Return**:

   ```
   cd ~/Downloads/Roomprint-iOS-project/Roomprint-iOS && git fetch -q origin && git stash -u -q; git branch -f mac-backup && git reset -q --hard origin/main && "./Ship Roomprint.command"
   ```

   - If the Mac asks whether Terminal may use the Downloads folder, click **OK**.
   - If a browser opens asking to allow **Wrangler** (Cloudflare), click **Allow**, then go back to Terminal.
   - If a box says **codesign wants to access key** in your keychain, type your Mac password and click
     **Always Allow** (it can ask up to three times, once per part of the app).
   - It ends with "Done: Roomprint 1.0 (…) is with Apple". If it stops with "!!", send Claude the file
     `ship.log` from that folder.
   - If the folder isn't there, paste this instead:
     `git clone https://github.com/christophergates88/roomprint-ios ~/Roomprint && cd ~/Roomprint && "./Ship Roomprint.command"`

## Step 2. App Store Connect (about 5 minutes, 15–30 minutes after step 1)

1. Go to **appstoreconnect.apple.com** > **Apps** > **Roomprint: Home Inventory**.
2. If there is a message from App Review (a banner at the top, or **App Review** in the left sidebar), open it.
   Reply with **The reply** below. If their note is about something this page doesn't cover, take a
   screenshot of it and send it to Claude instead of replying.
3. In the left sidebar under **iOS App**, click **1.0**.
4. **Build**: hover the old build, click the red **minus**, then **Add Build** and pick the newest one
   (its number starts with 2026). Click **Done**.
5. **App Review Information > Notes**: replace the text with **The review notes** below.
6. **In-App Purchases and Subscriptions** (on the same page): make sure **Roomprint Pro**, **3 room scans** and
   **10 room scans** are listed. If one is missing, click **+** (or **Edit**) and add it. Their prices should be
   $19.99, $2.99 and $7.99, which is what getroomprint.com shows. If you set different prices, tell Claude and the
   website will be changed to match.
7. **Screenshots** (top of the page, 6.9-inch display): optional but recommended. After step 1 they are on
   the Mac: in Finder open **Downloads > Roomprint-iOS-project > Roomprint-iOS > appstore > screenshots > 6.9**
   and drag the seven files in, 01 first.
8. Left sidebar > **App Privacy**: check it matches **App Privacy answers** below. Click **Publish** if you
   changed anything.
9. Top right: **Add for Review**, then **Submit to App Review** (it may say **Resubmit to App Review**).

Apple usually answers in 1 to 3 days. Approval arrives by email; getroomprint.com switches its buttons to the
App Store link on its own.

---

## The reply (paste into the App Review message)

> Hello, and thank you for the review. We've uploaded a new build of version 1.0 with these changes:
>
> 1. Before the first room scan, the app now shows a permission screen that explains what is sent (still
> frames from the walkthrough video, label text read on the device, and the room's name), who receives it
> (Roomprint's scan service and Anthropic's Claude AI), and how it's handled (Roomprint keeps no frames;
> Anthropic doesn't train on them and deletes them within 30 days). Nothing is sent until the user taps
> "Allow and continue", and the choice can be changed any time in Settings > Allow AI room scans. The privacy
> policy at https://getroomprint.com/privacy.html says the same.
>
> 2. Review and TestFlight builds now work exactly like the App Store build. The first room scan is free; after
> that the consumable in-app purchases "3 room scans" and "10 room scans" are offered. They can be reached at
> any time from the scan screen ("Get more room scans") and from Settings > Room scans. The non-consumable
> "Roomprint Pro" is in Settings > Upgrade to Pro, and on the export screen.
>
> To test: add a home, open any room, tap Scan room, tap Allow and continue, then Record a walkthrough (10 to
> 20 seconds of any room is enough) or Choose a video. The list appears in about a minute; tap Approve. Tapping
> Scan room again opens the scan-pack purchase. There is no account or login.
>
> Thank you,
> Christopher Gates

## The review notes (App Review Information > Notes)

> Roomprint keeps all records on the device. There is no account or login. The only network feature is Scan
> room: after the user agrees on a permission screen, the app sends still frames from a walkthrough video,
> on-device OCR label text and the room's name to our scan service (roomprint-scan.christophergates-cg.workers.dev),
> which uses Anthropic's Claude to identify items and estimate replacement values and returns a list the user
> approves. The service stores no frames.
>
> To test: create a home, open any room, tap Scan room, tap Allow and continue, record 10 to 20 seconds of any
> room (or choose a video), wait about a minute, then approve the list. The first scan is free. More scans are
> the consumables "3 room scans" and "10 room scans" (Settings > Room scans, or "Get more room scans" on the
> scan screen). Roomprint Pro (non-consumable) unlocks unlimited homes and items, password-protected PDFs and CSV
> export: Settings > Upgrade to Pro. Restore purchase is in Settings.

## App Privacy answers (App Store Connect > App Privacy)

"Do you or your third-party partners collect data from this app?" **Yes.** Then exactly these three:

| Data type | Used for | Linked to the user? | Tracking? |
| --- | --- | --- | --- |
| Photos or Videos (scan frames) | App Functionality | No | No |
| Other User Content (room name, label text) | App Functionality | No | No |
| Device ID (random per-install id for daily scan limits) | App Functionality | No | No |

Everything else: not collected. This matches the app's privacy manifest (`Roomprint/PrivacyInfo.xcprivacy`).

## If Apple says something else

| Apple's note mentions | What to do |
| --- | --- |
| 5.1.1 / 5.1.2, privacy, third-party AI, consent | Covered above. Reply with The reply. |
| 2.1, in-app purchases not found, "unable to locate" | Covered above (point 2 of The reply). Make sure all three purchases are attached in step 2.6. |
| 2.1, demo video, "screen recording", "physical device" | On the iPhone: Settings > Control Center > add Screen Recording. Record: open Roomprint, scan one room, approve, export the PDF. Attach the video to the reply. |
| 2.3.3 screenshots | Use the new screenshots in `appstore/screenshots/6.9/` (step 2.7). |
| 3.1.1, payment outside the App Store | There's no outside payment in the app. Ask Claude to check the app and site text it names. |
| Anything else | Screenshot the message and send it to Claude. |
