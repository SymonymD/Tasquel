# Tasquel Submission Review — 2026-10-25

This review covers the code at `77bcf8a` (the working tree is clean), the build settings, the privacy manifest, the live support and privacy pages, and the survey endpoint. It was done by reading the code; nothing was built or run.

## Verdict
The app is ready for TestFlight. Before you submit for review, there are two small website fixes, one privacy-label check, and a short on-device pass of things that only show up in an archived build. I found nothing that should get the app rejected.

---

## Fix before submitting

1. **The privacy policy mentions a feature that's gone.** It says your data includes "the optional name you enter during setup", but the name was removed. Delete that phrase. While you're there, add a line saying Smart Add runs on your device with Apple Intelligence and sends nothing, which matches the in-app Help.
2. **The support page says "Requires iOS 26.2 or later".** The app's deployment target is 26.0, and the App Store will list 26.0. Change it to 26.0.
3. **Check the App Store Connect privacy label against the manifest.** The manifest declares *Other Data Types*, not linked, not tracking, purpose Analytics, and the commit says App Store Connect matches. One thing to consider: the optional comment is free text the user writes, which Apple's definitions treat as **Other User Content**. Declaring both (feature picks as Other Data, the comment as Other User Content, neither linked) is the most accurate description. This is unlikely to cause a rejection; it's about the label being right.

## Check in a TestFlight build (only a real archive shows these)
- **The Retro icon switch.** `AppIconRetro` is an Icon Composer file listed in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`. Make sure choosing Retro changes the home-screen icon and any other theme changes it back. If the archive left the alternate icon out, `setAlternateIconName` fails silently.
- **The survey sends from a phone.** The endpoint is live: it rejects a malformed request with 400. Tap Send once in the TestFlight build and confirm the response arrives. A reviewer may tap it too, and "Couldn't send" would look unfinished.
- **Smart Add on an Apple Intelligence device**, including the "Added … · Undo" message.
- **A run on the iOS 26.0 simulator**, your minimum, especially Smart Add (Foundation Models) and the Liquid Glass bottom bar.
- **The iPad grid** (three columns) in a full-screen window and in Split View or Stage Manager.

---

## App Store Connect checklist
- **Screenshots:** iPhone 6.9" *and* iPad 13", since the app runs on iPad. The other sizes are scaled down from these.
- **Age rating:** answer the questionnaire in the current format. The survey's comment isn't shown to other users, so it isn't user-generated content. Everything else is "No", which gives the youngest rating.
- **Category:** Productivity. Also fill in the subtitle, keywords and copyright (with your legal name, which is also the seller name).
- **Privacy policy and support URLs:** both live (checked today).
- **Export compliance:** `ITSAppUsesNonExemptEncryption = NO` is set, so there's no question at upload.
- **Version / build:** 1.0 (1). Every new upload needs a higher build number.
- **App Review notes:** worth filling in, because a reviewer may not see everything:
  - Smart Add (✨ in a card's Add task row) only appears on devices with Apple Intelligence turned on; without it, Return adds tasks normally.
  - Calendar access is optional and is only requested from onboarding or Settings.
  - Settings ▸ Coming Soon is an optional, anonymous feature survey sent to the developer's site.
  - There's no login and no account.

---

## App Review Guidelines: possible risks (all low)
- **4.6 Alternate app icons:** compliant. The icon only changes when the user picks a theme (`onChange`, never at launch), and picking another theme reverts it. As a UX point, iOS's "You have changed the icon" alert pops up the moment someone picks Retro, which can surprise people. An explicit "Match app icon to theme" toggle under Appearance would make it something people expect.
- **2.1 Completeness / 2.3 Accurate metadata:** a section titled **Coming Soon** listing features the app doesn't have could read as promised features. It's a survey, so it should pass, but a title like "Help Choose What's Next" removes the question and describes it better. Don't mention these features in the App Store description.
- **5.1.1 Data collection:** fine. The survey is opt-in, anonymous, sent over an ephemeral session, and disclosed in both the policy and the manifest.
- **5.1.1(iv) Permissions:** fine. Calendar access is requested only on a user action, with a clear purpose string.

---

## UX status since round 2
**Fixed:** iPad grid (three columns), iPhone portrait-only, empty-card "No tasks yet · Tap to add", localized week header, Undo for deletes, task reordering, Smart Add's "Added … · Undo" message, "daily" as a goal of 7.

**Left (polish, not blockers):**
- Rings are red at 0%.
- Adding a category still asks "Every Week / This Week Only" each time.

---

## Submit order
1. Fix the two web pages (items 1–2) and decide on the label (item 3).
2. Archive, then upload to TestFlight.
3. Do the on-device checks above.
4. Take the screenshots (iPhone 6.9", iPad 13").
5. Fill in the metadata, age rating and review notes.
6. Submit.
