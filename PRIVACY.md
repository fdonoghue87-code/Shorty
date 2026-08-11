---
title: Shorty Privacy Policy
---

# Shorty Privacy Policy

_Last updated: July 2026_

Shorty is a small, two-person app for coordinating shared room time between roommates (or, during testing, family members). This page explains what data the app touches and how.

## What Shorty collects

- **Your name and your roommate's name.** Entered once during setup, used only to label who's who on requests and schedule entries.
- **Room requests, negotiations, standing arrangements, and schedule entries.** Whatever you and your roommate create while using the app.
- **Photos you choose to scan for the schedule-import feature.** For everyone, these are processed entirely on your device using Apple's on-device Vision framework by default — the photo itself is never uploaded anywhere. **Shorty Plus subscribers** get an additional, more accurate option: the photo is sent to Shorty's own small backend, which forwards it to Anthropic's Claude API to read it, and is not stored anywhere by either Shorty or Anthropic once a response is returned. If that step fails for any reason, Shorty automatically falls back to the on-device method instead.
- **Calendar events, if you use the "Import from Calendar" feature.** Read directly from your device's Calendar app (whatever account it's synced to — Google, Outlook, iCloud) using Apple's EventKit framework, entirely on-device. Nothing is uploaded until you review and confirm which events to save as schedule entries.
- **A Venmo username, Cash App $Cashtag, and/or Zelle phone/email, if you choose to add them in Settings.** Optional, and only used to help your roommate's payment buttons find you faster — see below.

## Where it's stored

All of the above (aside from the Shorty Plus photo-reading feature described above) is stored in **Apple's iCloud (CloudKit)**, under your own personal iCloud account, in a private zone shared only between you and the one roommate you've paired with. Shorty has no database of its own — there is no persistent copy of your data anywhere except in Apple's infrastructure, accessible only to your and your roommate's own devices signed into your own iCloud accounts. The one exception is the small backend used only for Shorty Plus's AI-powered photo reading: it exists solely to relay a photo to Claude's API and back, holds no user accounts or database, and doesn't retain anything after each request.

## What Shorty does not do

- No analytics, tracking, or advertising of any kind.
- No data is sold, shared, or shown to anyone outside the two people paired in a given room.
- No payment information ever touches Shorty. The optional "price" on a request is just a number you agree on with your roommate — actually sending that money happens entirely inside Venmo, Cash App, Zelle, or Apple Cash (via Messages), apps Shorty simply opens or hands a username/phone/email off to; Shorty never sees your account balances, card numbers, or bank details, and never processes a single payment itself.
- No card or billing information touches Shorty for the optional "Shorty Plus" subscription either — that's handled entirely by Apple's App Store billing (StoreKit), the same system used by every other app's in-app purchases.

## Notifications

Shorty can send you local reminders (e.g., "5 minutes left") about your own room sessions. These are generated and delivered entirely on your device — they are not sent through any external service.

## Leaving a room / deleting your data

Using **Settings → Leave This Room** disconnects your device from the shared data going forward. Because the underlying data lives in your and your roommate's iCloud accounts rather than on a server Shorty controls, removing it entirely means deleting it from iCloud directly (or simply letting it sit unused, private to the two of you, like any other iCloud data).

## Contact

Questions about this policy or your data: **fdonoghue87@gmail.com**
