# Backend performance — measured numbers, and what they point at

**For the backend developer.** Everything here was measured on a real device
against the live server, with the app's own request timing. The app side is
done: requests are de-duplicated, content is cached on disk, and screens no
longer wait on calls they do not need. What is left is server time.

## The measurements

Every call, grouped by endpoint. Multiple figures are repeated calls to the
same endpoint in one session.

```
GET  /api/health                             143ms      baseline

GET  /api/users/me/saved                     113 bytes
     4528  4352  2181  1067   590   567 ms

GET  /api/users/me/home                      779 bytes
     4860  3948  2750  1673  1666  1499  1288  1242  1187 ms

GET  /api/users/me/courses/:id/daily-quiz    6323 bytes
     5336  4935  3002 ms

POST /api/users/me/lessons/:id/quiz-attempts 1302–2191 bytes
     4545  3177  3032  1944 ms

POST /api/users/me/quiz-attempts/:id/answers 628–790 bytes
     4241  3254 ms

POST /api/users/me/quiz-attempts/:id/finish  2287 bytes
     1761  1636 ms

GET  /api/users/me/lessons/:id/quiz-attempts 220 bytes    (history)
     1541  1069 ms
```

## What stands out

**`GET /users/me/saved` returns 113 bytes and has taken 4528ms.**

113 bytes is an empty result — the student has no bookmarks:

```json
{"counts":{"all":0,"question":0,"lesson":0},"questions":[],"lessons":[]}
```

Four and a half seconds to determine that nothing exists. That is the single
most diagnostic number here. Returning nothing cannot be serialisation,
payload size or bandwidth — the time is spent looking, and something is
looking through a whole table to find none.

The same shape repeats everywhere: 779 bytes taking 1.2–4.9s, 628 bytes
taking 4.2s. Payload size barely correlates with time, which rules out
serialisation and the network and leaves the query.

**The spread is as bad as the average.** `/home` ranges 1187ms to 4860ms for
a byte-identical response. Same request, same device, same session. That is
contention or lock waiting, not a fixed cost.

## Where to look, in order

1. **Indexes on the user-id columns.** Every endpoint above filters by the
   signed-in user. If `saved`, `quiz_attempts`, `quiz_attempt_answers` and
   whatever `/home` reads are not indexed on their user column, each request
   scans the table. That fits every number here, including the empty result.

2. **Per-row queries in a loop.** `/daily-quiz` returns 6323 bytes for 10
   questions. If options are fetched per question, that is 11 round trips
   inside one request.

3. **The `EXPLAIN` on `/saved`.** Start with the cheapest one to reason
   about: it returns nothing, so whatever it is doing is pure overhead.

## What "good" looks like

`/api/health` answers in 143ms on the same instance, so the platform is not
the limit. Every endpoint above returns under 2KB. Once the queries are
indexed these should be in the 150–400ms range, and the spread should close.

## What the app already does, so you can rule it out

- **Requests are de-duplicated.** The course tree was being fetched 8 times
  per session with the waits stacking (1.7s, 2.4s, 4.2s, 6.5s); `/saved` was
  fetched twice back to back. Concurrent callers now share one request.
- **Content is cached on disk** — course tree, home summary, bookmarks,
  profile — and painted before the network is asked, so a warm launch shows
  content immediately.
- **Nothing unnecessary is awaited.** The answer POST is detached, the
  history fetch no longer gates the review, and quizzes with an existing
  attempt are prefetched.

So repeated identical calls, cold-start paint and UI blocking are all
accounted for. The times above are one request each, measured at the socket.

## Two things that are already fixed, for the record

**The QBank answer key now ships with the questions.** Confirmed live on both
`POST /lessons/:id/quiz-attempts` and `GET /quiz-attempts/:id`:

```
QBANK QUIZ  3 questions, 3 carry the answer key
```

The app marks answers locally, so `POST .../answers` — the 4241ms call — no
longer blocks anything. It still runs, detached, because it is what makes an
attempt survive the app being killed and what feeds the review and the
admin's per-student stats. Speeding it up is still worth doing; it is just no
longer in a student's way.

**Grand Tests are still locked and must stay that way.** They are ranked and
compared between students, so their key is released only by `/submit`. The
app has a test asserting the served test question carries no key.

## One request that would remove a wait entirely

```
GET /api/lessons/:lessonId/quiz     → questions, creates nothing
```

Today the only endpoint returning questions is `POST /attempts`, which
*creates* the attempt. That means a quiz the student has never opened cannot
be prefetched — doing so would mark quizzes as started that nobody opened,
filling Continue MCQs and inflating the attemptCount the one-attempt rule
depends on.

With a read-only endpoint the app could warm every quiz in the background,
and opening one would cost nothing at all.
