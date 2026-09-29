# Real-ticket fixtures (STEP 21)

Each `*.json` file here is one real boarding pass, replayed through the
parsers by `test/features/boarding_pass/real_ticket_fixtures_test.dart`, which
also prints per-field accuracy across all fixtures.

## Adding a ticket

1. Run a **debug** build on a phone (`flutter run`).
2. Add a boarding pass: live scan, photo, screenshot, or pasted text.
3. **Correct every field in the form** so it matches the ticket exactly. The
   form values become the fixture's `expected` (ground truth).
4. Tap **Copy test fixture (debug)** (only in debug builds). The JSON is also
   printed to the console.
5. Save it as `test/fixtures/tickets/<airline>_<layout>_<n>.json`, e.g.
   `pr_printed_1.json`, `5j_app_screenshot_2.json`.
6. Edit `expected`: set a field to `null` if it isn't printed on the ticket
   (null = "don't check"). Add a short `notes` (airline, paper/screenshot,
   lighting, rotation).
7. Run `flutter test test/features/boarding_pass/real_ticket_fixtures_test.dart`.

If the parser gets it wrong and you're not fixing that now, set
`"knownFailure": true`. The test is then skipped (CI stays green) but still
counted in the accuracy report, so failures stay visible until they're fixed.

## ⚠️ Personal data

Real passes contain names, booking references, ticket and frequent-flyer
numbers. The capture tool redacts what it can recognise (labelled values,
`SURNAME/GIVEN` names, 13-digit ticket numbers, and the BCBP name/booking
fields; it also drops the barcode's conditional section). OCR layouts vary, so
**read every `input` before committing** and replace anything personal with
`[REDACTED]`. Never commit ticket images.

## Fields

| Field | Meaning |
|---|---|
| `source` | `liveBarcode`, `photoBarcode`, `photoText`, `pastedText`; picks the parser |
| `capturedOn` | Capture date; used as "today" so year inference replays the same |
| `input` | Redacted barcode payload or OCR text |
| `expected` | Ground truth: `flightNumber`, `origin`, `destination`, `departureDate` (YYYY-MM-DD), `departureTime` (HH:mm), `seat`, `gate`; `null` = don't check |
| `parsedAtCapture` | What the parser produced when captured (for reference only) |
| `knownFailure` | Skip in CI, still counted in accuracy |
