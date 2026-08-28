# Backend endpoints the student app needed

> **All five shipped and are live.** Kept as the record of what was asked for
> and why. The app now consumes every one of them — see
> `student-app-backend-requests-done.md` in the backend repo for the responses
> as built.
>
> Two things landed differently from the ask below:
> - **#1 came back as unlimited retakes**, not one-attempt-per-quiz. The
>   client-side restriction has been removed.
> - **#3 has no batch endpoint.** The `attempt` object went onto each lesson in
>   `GET /api/users/me/selection/content` instead, which is better — the topic
>   screen already loads that tree, so it costs zero extra calls.
>
> The path in #3 below was also written wrong: it is
> `GET /api/users/me/selection/content`, not `/selection/content`.

Written from the app side after the QBank attempt-flow work. Everything here
is either **faked locally right now** or **enforced only in the app**, which
means it is not really enforced at all.

Base: `https://doctorapp-backend-30gd.onrender.com/api`
Auth: `Authorization: Bearer <student access token>` on all of them.
Same lesson gates as the existing quiz calls — 409 select-a-course, 404,
403 wrong course, 403 locked + `requiredPlans`.

Ordered by what hurts most.

---

## 1. One attempt per quiz is not enforced on the server

**This is a correctness hole, not a feature request.**

The app now shows a finished quiz as read-only: it calls
`GET /users/me/lessons/:id/quiz-attempts`, sees a completed attempt, and opens
the review instead of starting a new one.

But `POST /users/me/lessons/:id/quiz-attempts` still happily creates attempt #4
after #3 was completed. So the rule holds only for people using the app as
intended. Anyone hitting the API directly gets unlimited attempts, and two
devices racing the same quiz will produce two live attempts.

**Asking for:** the start endpoint refuses to create a second attempt once one
is completed.

```
POST /users/me/lessons/:id/quiz-attempts
```

Either behaviour works for the app — pick one and tell me which:

- **A — return the finished attempt.** `200` with the completed attempt and its
  full review, exactly like `GET /users/me/quiz-attempts/:id` on a finished one,
  plus `"completed": true`. The app renders the review and never has to ask
  history first. This is the one I'd pick: it removes a whole round trip.
- **B — refuse it.** `409 { "error": { "message": "This quiz has already been
  completed", "attemptId": 3 } }`. The app then fetches that attempt.

If it should stay unlimited and I've got the rule wrong, say so — I'll take the
restriction back out of the app.

### 1b. Empty attempts pile up

Opening a quiz and leaving without answering creates a permanent empty attempt.
Lesson 38 currently has attempt #4 with `answeredCount: 0` sitting on top of
three finished ones. It made my first pass at the rule above wrong, because I
keyed off the newest attempt rather than the newest *completed* one.

**Asking for:** either don't create the attempt until the first answer is
posted, or drop empty ones when a new attempt starts. Not urgent — the app
copes — but it will keep confusing anyone reading the data.

---

## 2. Saved questions (bookmarks)

Right now the bookmark toggle on each question writes to `SharedPreferences`.
It does not sync between devices and it dies on sign-out. The QBank
"Bookmarks — 0 Bookmarks" card is still hardcoded to zero.

**Asking for three endpoints:**

```
POST   /users/me/saved-questions      { "questionId": 17 }   → 201
DELETE /users/me/saved-questions/17                          → 204
GET    /users/me/saved-questions                             → 200
```

`POST` on something already saved should be a no-op `200`, not a 409 — the app
toggles optimistically and a duplicate is not an error.

`GET` response:

```json
{
  "count": 12,
  "questions": [
    {
      "questionId": 17,
      "questionText": "...",
      "questionImageUrl": null,
      "difficulty": "medium",
      "marksCorrect": 2,
      "marksIncorrect": -0.5,
      "lessonId": 38,
      "lessonTitle": "Cardiology",
      "savedAt": "2026-08-28T09:00:00.000Z",
      "options": [
        { "id": 216, "optionText": "Inferior wall", "optionImageUrl": null, "displayOrder": 0 }
      ],
      "correctOptionId": 216,
      "explanation": "II, III, aVF are the inferior leads."
    }
  ]
}
```

**The one decision worth getting right:** `correctOptionId` and `explanation`
must be sent **only when the student has already answered that question in a
completed attempt**. Otherwise a student saves a question from a quiz they
haven't finished and reads the answer straight out of the bookmark list — the
same leak the serve endpoint is careful to avoid. Send them as `null` when they
haven't earned them yet, and the app will show the question without a reveal.

`count` at the top level is what the QBank card needs; it saves me fetching the
whole list just to print a number.

---

## 3. Attempt status for many lessons in one call

The topic detail screen shows a **Continue** pill on any quiz left half-done.
To do that it currently fires **one `GET /users/me/lessons/:id/quiz-attempts`
per quiz in the topic**. Four quizzes, four calls, every time the screen opens.
It works, but it is an N+1 and it will get worse as topics grow.

**Asking for one of these:**

```
GET /users/me/quiz-attempts/status?lessonIds=36,38,40
```

```json
{
  "statuses": [
    {
      "lessonId": 38,
      "attemptId": 3,
      "completed": true,
      "answeredCount": 3,
      "totalQuestions": 3,
      "score": 3.5,
      "totalMarks": 6
    },
    { "lessonId": 40, "attemptId": null, "completed": false, "answeredCount": 0, "totalQuestions": 5 }
  ]
}
```

One row per requested lesson, `attemptId: null` where the student has never
started. That is enough to drive both the Continue pill and the
"Completed — 3.5 marks" row, and it drops four calls to one.

**Or, better if it's cheap:** fold the same object into the existing
`GET /users/me/selection/content` tree as a `quizAttempt` field on each quiz
lesson. Then the topic screen costs zero extra calls, because it already has
that tree.

---

## 4. Continue MCQs across the whole course

The QBank tab has a **"Continue MCQs"** card that does nothing — there is no
way to ask "what did this student leave half-finished anywhere?". Per-lesson
history can't answer it without walking every lesson in the course.

```
GET /users/me/quiz-attempts?status=in_progress
```

```json
{
  "attempts": [
    {
      "attemptId": 5,
      "lessonId": 38,
      "lessonTitle": "Cardiology",
      "chapterTitle": "Internal Medicine",
      "answeredCount": 1,
      "totalQuestions": 3,
      "startedAt": "2026-08-28T09:45:39.671Z"
    }
  ]
}
```

Newest first. Only attempts with at least one answer — an attempt somebody
opened and closed is not something to continue, and showing it reads as noise.

If #1 option A lands, this also wants a `status=completed` variant so the card
can offer "review your past quizzes" — but that is a nice-to-have, not a
blocker.

---

## 5. Lesson bookmarks

Lower priority, same shape as #2 but for lessons rather than questions. The
bookmark icon on the video/lesson detail screen (`_isBookmarked`) is currently
a local `setState` that is thrown away the moment the screen closes — it does
not persist at all, not even on the device.

```
POST   /users/me/saved-lessons   { "lessonId": 38 }
DELETE /users/me/saved-lessons/38
GET    /users/me/saved-lessons
```

Say the word and I'll wire it the same way as saved questions.

---

## Nothing needed for

- **Screenshot blocking** — handled entirely on-device (`FLAG_SECURE` on
  Android, a blanked capture on iOS).
- **The paywall / plans flow** — the existing plan endpoints cover it.
- **Video mini-player / picture-in-picture**, if we build it — client-side only.
