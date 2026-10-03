# Backend: upload a CSV to build a quiz's questions

The admin panel's quiz flow changed. A quiz lesson is no longer assembled from
a published Google Sheet read live by tab name — the admin now picks a
**subject** and one of its **topics** (both mandatory, both from the existing
taxonomy) and **uploads a CSV**, the same way a Test's paper is uploaded.

Backend is live at `https://doctorapp-backend-cl2h.onrender.com`. Every request
below carries `Authorization: Bearer <admin token>`.

## What the panel does today, and why it needs you

Right now the browser does all of it:

1. parses the CSV in Dart,
2. `GET /api/questions?subjectId=&topicId=&limit=100` to spot duplicates,
3. `POST /api/questions` **once per row**,
4. `POST /api/quizzes { title, subjectId, topicId, questionCount }`.

Three things are wrong with that, and none of them can be fixed in the panel:

- the duplicate check only sees the first 100 questions in the topic, so a
  bigger topic re-imports rows it already has;
- 40 rows means 40 round trips with no transaction — a failure at row 25
  leaves 24 questions in the bank and no quiz;
- the quiz is only a *filter* over subject + topic, so it can serve questions
  that were never in the uploaded file, and `questionCount` picks a random
  subset per student. The admin who uploaded 40 specific questions expects
  those 40.

## 1. `POST /api/admin/subjects/:subjectId/topics/:topicId/questions/upload`

Required. `multipart/form-data`, file field named **`file`**.

A flat `POST /api/admin/questions/upload` with `subjectId` and `topicId` as
form fields is equally fine — tell us which one you built.

Accept these content types on the multer filter: `text/csv`,
`application/vnd.ms-excel`, `application/octet-stream`. A browser sends any of
the three for the same `.csv`, and the Test upload has already rejected a good
file for this reason.

### CSV contract

Columns are addressed **by header name**, so their order does not matter and
unknown columns are ignored.

| Column | Required | Notes |
|---|---|---|
| `question_text` | yes | A blank one is a trailing empty row — skip it silently, it is not an error |
| `question_image_url` | no | Plain URL, stored as-is |
| `option1` … `option6` | at least 2 | A column blank in **both** text and image is not an option and is dropped |
| `option1_image_url` … `option6_image_url` | no | Index-aligned with the option of the same number. **An option may be an image with no text** — a diagram question often has four pictures and nothing to read, so an empty `optionText` must be stored, not rejected |
| `correct_option` | yes | **1-based**, and must point at an option that is actually filled |
| `difficulty` | no | `easy` \| `medium` \| `hard`, case-insensitive, default `medium` |
| `marks_correct` | no | Default `1` |
| `marks_incorrect` | no | Default `0`. Genuinely negative values are normal |
| `explanation` | no | |
| `tags` | no | Comma-separated, same as the `tags` array on `POST /api/questions` |
| `status` | no | `active` \| `inactive`, default `active`. **An inactive row is not imported** |

Example:

```csv
question_text,question_image_url,difficulty,tags,status,option1,option2,option3,option4,correct_option,marks_correct,marks_incorrect,explanation
Which organism causes CAP?,,medium,"pulmonology,dha",active,Streptococcus pneumoniae,Mycobacterium tuberculosis,Pseudomonas aeruginosa,Aspergillus fumigatus,1,2,-0.5,Most common community-acquired pathogen.
Identify the rhythm,https://img.example/ecg.png,hard,cardiology,active,Atrial fibrillation,Atrial flutter,Sinus tachycardia,VT,2,2,-0.5,
```

An empty image cell is normal — images are optional on a quiz question. Never
reject a row because an image is missing, and never fetch the URL to check it.

### Behaviour

- Store each valid row exactly as `POST /api/questions` stores one today: same
  option objects (`optionText`, `optionImageUrl`, `isCorrect`, `displayOrder`),
  same tag handling, same difficulty values. Nothing about the single-question
  endpoint should change.
- **Dedupe inside the (subjectId, topicId) pair**, on question text normalised
  by: trim, lowercase, collapse every run of whitespace to one space. A
  duplicate is skipped, counted, and its **existing id is still returned** —
  the admin re-uploading a corrected file must not end up with a quiz missing
  the rows that were already there.
- Also dedupe **within the file** — the same stem twice in one CSV is one
  question.
- One transaction for the whole file: if a valid row fails to write, roll the
  file back rather than half-importing it.
- Invalid *rows* do not fail the file. Import the good ones and report the bad
  ones (below). Zero valid rows is a `400` carrying the same issue list.

### Response `200`

```json
{
  "imported": 38,
  "duplicates": 2,
  "questionIds": [910, 911, 912],
  "message": "Imported 38 question(s). 2 were already in this topic.",
  "issues": [
    {
      "row": 7,
      "field": "correct_option",
      "message": "correct_option is 5 but this row has 4 options",
      "severity": "error"
    },
    {
      "row": 12,
      "field": "status",
      "message": "Row is inactive and was not imported",
      "severity": "warning"
    }
  ]
}
```

- `questionIds` — **imported + duplicates, in file order.** This is the part
  the panel cannot do without: it pins the quiz to exactly these ids, so an id
  left out is a question that silently vanishes from the quiz.
- `issues[]` is the same shape the Test upload already returns — `row`,
  `field`, `message`, `severity` — because the panel reuses that renderer.
  `row` is the **physical line number in the file**, the one the admin's
  spreadsheet shows, so they can go and fix it.
- `severity: "error"` means that row was not imported. `"warning"` means it was
  skipped or adjusted on purpose. Absent counts as `"error"`.
- `message` is shown to the admin verbatim, so write it for them, not for a log.

## 2. `POST /api/admin/quizzes/upload` — optional, but it closes the gap

One call instead of three:

```
multipart/form-data
  file          the CSV
  title         quiz title
  subjectId
  topicId
  lessonId      optional - link the quiz to this lesson in the same transaction
```

It creates the questions, creates the quiz, **pins it to the uploaded ids
(`mode: "manual"`)**, links the lesson if one was given, and replies with the
quiz row plus the same `imported` / `duplicates` / `issues` block as §1.

Without this, the panel still has a window where the questions are written and
the quiz create fails, and the admin has to clean up by hand. Keep the
three-step path working either way.

## 3. What must not change

- `GET /api/subjects/:subjectId/topics` already feeds the now-mandatory Topic
  dropdown — no change wanted.
- `PUT /api/admin/quizzes/:id/questions` already pins a set in manual mode. The
  panel will call it with the ids from §1 unless §2 ships.
- `POST /api/questions`, `GET /api/questions`, `POST /api/quizzes` stay exactly
  as they are — the panel still uses all three elsewhere.
- Nothing on the student side changes.

## Reply with

1. the exact route(s) you implemented, and the multipart field name if it is
   not `file`;
2. whether `questionCount` should still be sent on `POST /api/quizzes` once the
   set is pinned, or whether a pinned quiz ignores it;
3. one sample response from a file that had both a duplicate and a bad row, so
   the panel can be wired against the real shape rather than this document.

## 4. Also needed: attach a subject to a course

The panel can now create a **topic** from the quiz form
(`POST /api/subjects/:subjectId/topics` — already live, no change wanted).

It cannot create a **subject**, because the Subject dropdown is fed by
`GET /api/admin/courses/:courseId/subjects` and `POST /api/subjects` makes a
global subject that the course does not know about. The new subject would be
created and then not appear in the list, which is worse than no button.

So either:

- **`POST /api/admin/courses/:courseId/subjects { "subjectId": 7 }`** — links an
  existing subject to a course, `409` if it is already linked, and a matching
  `DELETE /api/admin/courses/:courseId/subjects/:subjectId` to unlink; or
- let `POST /api/subjects` take an optional `courseId` and do the link in the
  same call.

Either is fine — say which one exists and the panel will add the button.

Worth knowing: `GET /api/admin/courses/:courseId/subjects` currently answers
with **every** subject in the system when the course has none linked
(`fallback: true`). That is useful, but it means an admin can tag a lesson with
a subject that has nothing to do with the course, and cannot tell the
difference. Keep the flag; it is the only thing that makes the list readable.
