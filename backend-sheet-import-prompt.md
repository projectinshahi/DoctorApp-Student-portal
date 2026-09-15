# Import questions from the Google Sheet into the database

**For the backend developer. No student-app change is involved.**

## The problem, measured

Timings taken on a real device against the live server:

```
POST  /api/users/me/lessons/44/quiz-attempts    3032ms   1302 bytes   (2 questions)
POST  /api/users/me/quiz-attempts/29/answers    3254ms    790 bytes   (1 answer)
GET   /api/users/me/home                        5459ms   1614 bytes   (cold)
GET   /api/users/me/courses/22/daily-quiz       2450ms   6428 bytes
GET   /api/health                                143ms                (baseline)
```

Three seconds to return two questions, against 143ms for a health check on the
same instance. The payloads are tiny, so this is not bandwidth and it is not
the app. Something in the request path is slow, and a Google Sheets read per
request would explain it exactly: the Sheets API is rate-limited and typically
takes 1–3s per call, and it does not get faster under load — it gets slower.

**Question to confirm first:** does any of these endpoints read the sheet
during the request? If yes, everything below applies. If no, the cause is
something else in the query path and the timings above are still the place to
start.

## What to change

Read the sheet **once, on import**. Serve every request from the database.

```
Google Sheet  ──(import job, manual or scheduled)──>  Database  ──> API ──> app
```

Not on the request path:

```
app ──> API ──> Google Sheet        ← 1–3s on every single request
```

### The import

A route the admin panel can call, or a script run by hand:

```
POST /api/admin/import/questions
{ "sheetId": "...", "tab": "Cardiology", "lessonId": 44 }
```

It should:

1. Read the sheet once.
2. Validate every row before writing any of them — a half-imported bank is
   worse than a failed import.
3. Upsert on a stable key from the sheet (a question id column), so re-running
   it updates rather than duplicating.
4. Report what it did: rows read, created, updated, rejected and why.

### Rows that must be rejected, not imported

- No correct option marked, or more than one
- Fewer than two options
- An option with neither text nor an image
- A question id that appears twice in the sheet

## Why the app cannot do this itself

Two reasons, both hard blockers.

**Reading the sheet from the app exposes the answer key.** The sheet would
have to be public for the app to read it without credentials, and the URL
ships inside the app where anyone can extract it. Every student could then
open the sheet and read every answer. That is the whole product.

This is also why the current API is built the way it is. From the app's own
model file:

```dart
/// Only present in the finish payload — the answer key does not exist in
/// the question list.
final bool? isCorrect;
```

**Letting the app POST questions to the database means any student can.**
A student app cannot hold admin credentials — whatever it holds, the student
holds. Anyone could write arbitrary questions into the live bank.

Import belongs on the server or in the admin panel, where the credentials
are not in the student's hands.

## The separate, optional win

Once questions live in the database, sending `isCorrect` with each option
would let the app reveal right/wrong **instantly**, with no round trip. The
app already supports this: it reads the key when present and falls back to
waiting when absent, so it needs no change — it switches on by itself.

The trade is that a student who inspects the traffic can read the answers for
the questions they have been served. Marrow accepts that trade. Worth
deciding deliberately rather than by default.

The app prints which shape it is receiving, so this is easy to confirm:

```
adb logcat -s flutter | grep -E "QBANK QUIZ|DAILY QUIZ"
QBANK QUIZ  8 questions, 0 carry the answer key
```
