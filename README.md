# Shorty

Rent your shared room from your roommate for a bit — 15 minutes or a whole night — without the awkward ask. Send an offer, they accept, decline, or negotiate the time/price, and a shared countdown keeps you both on the same page about when time's up.

Phase one is built for exactly two people (you and one roommate). No accounts, no server to run — it syncs over your personal iCloud accounts using Apple CloudKit sharing.

## What's here

A native iOS app (SwiftUI, iOS 17+):

- **Room** tab — live available/occupied status with a countdown timer, plus today's schedule at a glance.
- **Offers** tab — send an offer (purpose: study / call / intimacy / alone time / other, a time window, and an optional price), and accept, decline, or counter-propose different terms on offers you receive.
- **Schedule** tab — post recurring "away" or "in the room" blocks (like a class schedule) so your roommate can see when the room is naturally free, before they even need to ask. Includes a graphical calendar to jump to any day, plus a **photo import**: snap or pick a photo of a printed/on-screen class schedule and Shorty (via Apple's Vision text recognition) tries to pull out day/time blocks automatically. Detected entries always land in an editable review list before saving — OCR on free-form schedule layouts is inherently best-effort, so nothing saves without a look first. Saved blocks sync to both roommates like any other schedule block.
- Duke Blue (`#001A57`) color theme throughout, with bold centered headers on each tab.

## How the sync works

Two roommates share one CloudKit record zone via `CKShare`:

1. Whoever sets up the room taps **Create Room & Invite** — this creates the room in their private iCloud database and opens the standard iOS share sheet (Messages, Mail, AirDrop, etc.) with an invite link.
2. Their roommate taps the link. iOS shows the native "accept this share" prompt, opens Shorty, and the app automatically connects to the same shared zone (handled in `AppDelegate.application(_:userDidAcceptCloudKitShareWith:)` in `ShortyApp.swift`).
3. From then on, both devices read and write the same `Room`, `Offer`, and `ScheduleBlock` records. There's no backend to host — it's just each person's iCloud account.

Both people enter their own name locally on first launch; that's only used to label who's who on offers and schedule blocks.

This intentionally skips push notifications for phase one — the app polls every ~12 seconds while open (`OfferStore.startPolling()`) and refreshes on pull-to-refresh. Real-time push via `CKQuerySubscription` is a natural phase-1.5 addition once the core flow is validated between the two of you.

## Trying it out for free, before any Apple Developer Program membership

CloudKit — the thing that syncs offers between two people — is gated behind Apple's **paid** Developer Program ($99/year); a free "Personal Team" account can't provision it, regardless of whether you're testing via cable or TestFlight. That's a real wall, but it only blocks the cross-device sync, not the app itself.

To click through every screen for free first: open the app, on the welcome screen enter your name (roommate name is optional here) and tap **Just Explore (No iCloud Needed)**. This calls `CloudKitManager.enableLocalPreview()`, which quietly serves every read/write from an in-memory store instead of the network — so offers, the countdown timer, and the schedule editor all work solo, on one device, with a free Apple ID. Nothing syncs to anyone, and the data resets each time you relaunch (by design — it's meant to be thrown away once you're ready for the real thing).

When you're ready to test the actual two-person flow, enroll in the paid Developer Program and follow the steps below — the same $99 carries you through TestFlight and eventual App Store publishing too.

## Opening the project for real (two-device) testing

1. Open `Shorty.xcodeproj` in Xcode (15.4+, targeting iOS 17+).
2. Select the **Shorty** target → **Signing & Capabilities**:
   - Pick your Apple Developer team (the project ships with `DEVELOPMENT_TEAM` blank).
   - Confirm the **iCloud** capability is present with **CloudKit** checked and a container assigned (the entitlements file already requests `iCloud.$(CFBundleIdentifier)`; Xcode will offer to create that container automatically the first time you build).
   - Change the bundle identifier (`com.fdonoghue.shorty` placeholder in the project build settings) to one under your own team if needed.
3. Build to a real device (CloudKit sharing between two people needs two real iCloud accounts — the simulator alone can't fully exercise the invite/accept flow).
4. Before submitting to TestFlight, swap the placeholder `AppIcon-1024.png` (a plain Duke Blue door glyph) for real branding.

## Testing with your roommate

1. You create the room and send the invite link to your roommate directly (text it to them outside the app, however you'd normally send a link).
2. They tap it, accept, and enter their name.
3. From there, send each other offers and see them sync.

## After pulling an update to this project

Because `Shorty.xcodeproj`'s project file is regenerated (not hand-edited) whenever files are added, **your Signing & Capabilities Team selection gets reset to blank each time you pull a change that adds new files.** After `git pull`, always re-check Shorty target → Signing & Capabilities → Team before building.

The photo-import feature also needs a camera permission string, which is already wired into the project's Info.plist settings (`NSCameraUsageDescription`) — no extra setup needed, but the first time you tap "Take Photo" on a real device, iOS will show the permission prompt using that text.

## Honesty about what's been verified

This was built in an environment without Xcode or a Swift toolchain, so the code has been carefully reviewed line-by-line (including validating the CloudKit async APIs and the `.xcodeproj` file structure via the `xcodeproj` Ruby gem) but **has not been compiled or run**. Expect to fix a handful of small build errors on first open — most likely candidates are exact CloudKit API signatures shifting slightly between SDK versions, or Signing & Capabilities steps Xcode wants to do interactively (creating the actual CloudKit container). Please test the golden path (create room → invite → accept → send offer → accept/counter → countdown → session ends) end-to-end on two devices before relying on it.

## Roadmap beyond phase one

- Push notifications via `CKQuerySubscription` instead of polling.
- Support for more than two roommates per room.
- Public rooms / accounts so any two students (or any two people sharing a room) can pair up without you manually distributing invite links — this is the path to the App Store release across universities.
