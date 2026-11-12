# Data safety answers

For Google Play's Data safety form and Apple's App Privacy labels. Valid for
the current build: the app has no analytics or network calls of its own; the
only outside service is the Google Mobile Ads SDK (AdMob banner and Google's
consent form). Mapping follows Google's own AdMob disclosure:
https://developers.google.com/admob/android/privacy/play-data-disclosure

## Google Play
- **Does your app collect or share any of the required user data types?** Yes, through the Google Mobile Ads SDK.
- **Is all user data encrypted in transit?** Yes (the SDK uses HTTPS).
- **Do you provide a way for users to request that their data be deleted?** The app's own data lives only on the device; uninstalling or deleting entries removes it. Advertising data: the person can reset or delete their advertising ID in Android settings.
- **Data types, each collected and shared, processed ephemerally: no, optional: no:**
  - **Location > Approximate location** (from IP address): Advertising or marketing, Analytics, Fraud prevention, security and compliance.
  - **App activity > App interactions** (ad taps and views): Advertising or marketing, Analytics, Fraud prevention, security and compliance.
  - **App info and performance > Diagnostics:** Advertising or marketing, Analytics, Fraud prevention, security and compliance.
  - **Device or other IDs** (advertising ID, app set ID): Advertising or marketing, Analytics, Fraud prevention, security and compliance.
- **Contains ads:** Yes. **Advertising ID:** Yes, used for advertising, analytics and fraud prevention (the manifest declares `com.google.android.gms.permission.AD_ID`).
- **Exports:** CSV/PDF files are created on the device and handed to the system share sheet at the person's request. Play treats user-initiated sharing like this as not "shared" by the developer.
- **Photos:** the app reads the camera or photo library only when the person adds a picture; the picture is copied into app storage on the device and never uploaded. Processed only on device, so Play does not count it as collected. Android: no broad storage permission needed (system photo picker). iOS: camera and photo library permission texts are set in Info.plist.

## Apple App Privacy
Google's mapping for the Mobile Ads SDK: Device ID, Product interaction,
Advertising data, Coarse location, Crash and Performance data, used for
Third-party advertising and Analytics. Ads are not personalised unless the
person allows tracking (App Tracking Transparency, not requested by this
build), so "Used to track you" is No.

## Re-check when RevenueCat is added
RevenueCat receives store receipts and an anonymous app user id. At that
point Play's form will likely need **Purchase history** (and possibly an app
user id under Device or other IDs) marked as collected, for app
functionality, not shared, not used for tracking; Apple's label likewise
moves to "Purchases, not linked to identity" depending on configuration.
Use RevenueCat's own published guidance for these forms at that time.
