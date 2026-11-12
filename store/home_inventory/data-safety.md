# Data safety answers (draft)

For Google Play's Data safety form and Apple's App Privacy labels. Valid for
the current build, which has no analytics, ads or network calls of its own.

## Google Play
- **Does your app collect or share any of the required user data types?** No (this build).
- **Is all user data encrypted in transit?** Not applicable: the app sends no user data.
- **Do you provide a way for users to request that their data be deleted?** Data lives only on the device; uninstalling or deleting entries removes it.
- **Exports:** CSV/PDF files are created on the device and handed to the system share sheet at the person's request. Play treats user-initiated sharing like this as not "shared" by the developer.
- **Photos:** the app reads the camera or photo library only when the person adds a picture; the picture is copied into app storage on the device and never uploaded. Processed only on device, so Play does not count it as collected. Android: no broad storage permission needed (system photo picker). iOS: camera and photo library permission texts are set in Info.plist.

## Apple App Privacy
- **Data Not Collected** (this build).

## Re-check when RevenueCat is added
RevenueCat receives store receipts and an anonymous app user id. At that
point Play's form will likely need **Purchase history** (and possibly an app
user id under Device or other IDs) marked as collected, for app
functionality, not shared, not used for tracking; Apple's label likewise
moves to "Purchases, not linked to identity" depending on configuration.
Use RevenueCat's own published guidance for these forms at that time.
