# Backend: six-option questions, and what to do with a PDF paper

Two changes to the Test module's import, both found while testing the admin
panel against the live backend at `https://doctorapp-backend-cl2h.onrender.com`.
Admin bearer token on every request, as now.

## 1. Questions with six options

Some questions carry six answers, not four. The panel now reads, edits and
sends `optionE` and `optionF`; the backend has to keep them.

### CSV import — `POST /api/admin/tests/:testId/questions/upload`

Accept two more optional column pairs, exactly like the existing four:

```
option_e, option_e_image_url
option_f, option_f_image_url
```

- Both are **optional**. A file without them, or with them blank, is a normal
  four-option paper and must keep importing exactly as it does today.
- `correct_option` may now be `A`–`F`. It must still point at a column that is
  actually filled: `F` on a row where `option_f` and `option_f_image_url` are
  both empty is an error, reported on that row as it is today.
- An option that is **blank in both** its text and image column is not an
  option. Do not store it, and do not count it.
- As with A–D, an option may be an **image with no text** — a blank
  `option_e` with a filled `option_e_image_url` is a valid option.
- A hole is an error: `option_f` filled while `option_e` is empty should come
  back as an issue on that row rather than being silently shifted up.

### Manual add/edit — `POST`/`PATCH` on a test's questions

The panel sends all six pairs on every save:

```json
{
  "questionText": "...",
  "questionImageUrl": "",
  "optionA": "...", "optionAImageUrl": "",
  "optionB": "...", "optionBImageUrl": "",
  "optionC": "...", "optionCImageUrl": "",
  "optionD": "...", "optionDImageUrl": "",
  "optionE": "",    "optionEImageUrl": "",
  "optionF": "",    "optionFImageUrl": "",
  "correctOption": "D",
  "explanation": "", "section": "", "subject": "", "topic": "",
  "questionOrder": 7
}
```

- An **empty string means "this option is not there"**, and on an edit it means
  "remove the option that was there". The panel sends empties on purpose: a key
  left out would leave the old value in place.
- `correctOption` is validated the same way as in the CSV: A–F, and it must
  address a filled option.

### Anywhere a question is read back

`GET` of a test's questions and `GET /api/admin/tests/:id/preview` must return
all six when they exist — as a six-item `options` array, or as `optionE` /
`optionF` columns. The panel already reads both shapes, so either is fine, but
a six-option question that reads back as four would lose two answers the next
time an admin saves it.

## 2. PDF papers - the panel converts them, you do nothing

Admins upload printed papers. The panel now reads them itself: the PDF's text
is extracted in the browser, parsed into questions, shown for checking, and
then sent to **the existing** `POST /api/admin/tests/:testId/questions/upload`
as a normal CSV. Instructions PDFs are read the same way and land in the
`instructions` text field.

So there is **no new endpoint and no new field for this** - but two things
about the generated file matter:

1. It is uploaded with the name `<paper>.csv`, built in the browser. If
   `multer` sniffs the content type rather than the extension, a
   browser-generated file can arrive as `application/octet-stream` - accept
   that alongside `text/csv` and `application/vnd.ms-excel`.
2. Its header is exactly
   `question_text,option_a,...,correct_option,explanation`, with `option_e`
   and `option_f` present only when some question has five or six options -
   which is §1 above.

A question the parser could not find an answer for is sent with
`correct_option` blank, on purpose: the admin was told how many, and the
importer's own error for that row is the right place for it to be refused.
Please make sure a blank `correct_option` is reported **per row** rather than
failing the whole file - otherwise one unreadable answer key in a 150-question
paper throws away the other 149.

## 3. Per-test instructions — already working, just confirming

`instructions` is sent on create (`POST /api/admin/courses/:courseId/tests`)
and on edit (`PATCH /api/admin/tests/:id`), and it stays editable after
publishing. The panel has a field for it in the wizard and in the edit sheet.

Two things worth confirming:

1. there is no length cap that silently truncates a long instruction block;
2. editing only `instructions` on a published test does **not** drop it back to
   draft — changing the question count does, and that is correct, but a
   wording fix should not unpublish a live paper.

If you would rather attach an instructions **PDF** per test than type the text,
that is a new field (`instructionsFileUrl`) and an upload route — tell us and
we will spec it.
