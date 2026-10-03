# The push sent when a test is published

## What happens today

Publishing a test sends every student a notification the admin never sees and
cannot influence:

```
New mock test
testing
```

The title is hard-coded and the body is the test's internal title. "testing" was
a title an admin typed while trying the wizard out; it went to every student on
the course.

Two problems, in order of how much they cost:

1. **A draft title is not an announcement.** Admins name tests for themselves —
   `testing`, `NHB`, `1-14 mock`. Those names are now student-facing copy.
2. **The text says nothing useful.** Not which exam, not how many questions, not
   how long. A student cannot tell one "New mock test" from the next.

## What to change

### 1. Accept the text on the publish call

```
POST /api/admin/tests/:id/publish
{
  "notify": true,                                  // default true
  "notificationTitle": "Kuwait Prometric — Mock 3", // optional
  "notificationBody":  "148 questions · 300 minutes. Open when you have a clear run at it."
}
```

- `notify: false` publishes silently. Needed for a paper being republished after
  a fix, where a second push reads as a second test.
- Both text fields optional. When they are absent, fall back to §2.
- Trim and cap them server-side (title ~60 chars, body ~160) — a long title is
  truncated by the phone, mid-word.

Reply with what was sent, so the panel can confirm it:

```
200 { "test": { ... }, "notified": 412 }
```

### 2. A better default

When no text is given, compose from what the test already knows rather than
printing its title:

```
New mock test · Kuwait Prometric Exam
148 questions, 300 minutes. Tap to start when you are ready.
```

### 3. Never notify twice for the same test

An admin who unpublishes to fix question 38 and publishes again must not send a
second announcement. Record that a test has been announced and skip it on later
publishes unless `notify: true` is passed explicitly.

## What I will add in the panel once this lands

Two fields on the publish step — a title and a body, pre-filled with the default
from §2 so an admin can publish without typing anything — and a "Notify
students" switch wired to `notify`. The count from `notified` goes on the
confirmation, so publishing says how many people it reached.

Tell me when the endpoint accepts these and I will wire it up.
