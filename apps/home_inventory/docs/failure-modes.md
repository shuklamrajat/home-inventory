# Home inventory: ways it can be wrong

Written before the code. I = isolated scenario in test/inventory_scenarios_test.dart,
E = end-to-end test through the app.

| # | Failure | Prevention | Check |
|---|---------|------------|-------|
| 1 | Warranty end for a purchase on 31 Jan + 1 month lands on 3 Mar | Month arithmetic clamps to the last day of the month (31 Jan + 13 months = 29 Feb 2024) | I-A, E |
| 2 | "Expiring soon" off by one around midnight or daylight saving | Compare calendar dates, not durations | I-A |
| 3 | An expired warranty is listed among the active ones | Status: none / active / soon (30 days) / expired; list sorted soon, active, expired | I-A, E |
| 4 | Total value double counts or ignores the current value | Item value = current value if set, else purchase price, else 0 | I-B, E |
| 5 | Photos stored with absolute paths break after an iOS update moves the app folder | Store file names only, resolve against the app's folder at read time | E |
| 6 | Deleting an item leaves its photos on disk forever | Item delete removes its attachment files | E |
| 7 | A missing photo file crashes the PDF export | Missing files are skipped and listed as "photo missing" | I-C |
| 8 | 30 full-size phone photos make a 100 MB PDF | Photos are downscaled when picked (max 1600 px, quality 85) | - (device only) |
| 9 | Free tier limit counted wrongly (e.g. allows 26) | Limit checked before opening the new-item form | E |
| 10 | CSV cells with commas or "=" break the sheet | Shared CSV writer quotes and guards cells | E |
