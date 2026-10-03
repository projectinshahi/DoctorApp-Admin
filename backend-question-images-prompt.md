# Question images for the Test module — what the backend has to do

**Nothing is required.** The panel's image flow runs on endpoints that already
work: a 148-row import with four pictures went through cleanly, images and all.
Read §1 for what the panel now does, §2 for the one wording change worth making,
and §3 only if uploading a paper's pictures turns out to be slow. §4 is the one
thing still blocking, and it is not about images.

---

## 1. What the panel does now (no server change)

An admin uploading a 150-question paper has the CSV and a folder of pictures
named the way the paper names them (`q18_rhabdomyolysis.png`,
`q116_nephrotic_syndrome.png`).

1. **Add images** in the wizard's CSV step picks any number of files and sends
   each one to the endpoint that already exists:

   ```
   POST /api/uploads/question-image
   Authorization: Bearer <admin token>
   multipart/form-data, field "image", one file
   → 200 { "url": "...", "publicId": "...", "originalFilename": "...", "bytes": 12345 }
   ```

2. The panel keeps `filename (lower case) → url` in memory for that wizard
   session.

3. When the CSV is sent, the panel rewrites every image column in it — any
   header containing `image`, so `question_image_filename`,
   `question_image_url` and `option_a_image_url` through `option_f_image_url` —
   replacing a bare filename with the address it was uploaded to. A cell that
   already holds an `http://` or `https://` address is left alone.

So **the server only ever receives full addresses in image cells.** It never
has to resolve a filename against anything, and the import route needs no
knowledge of which pictures belong to which test.

A name the admin did not upload is reported in the panel before the file is
sent, so it should rarely reach you at all.

---

## 2. One wording change, and two things to verify

### 2a. The "not uploaded to this test" warning is misleading

An import whose image cells hold full Cloudinary addresses now reports:

```
question_image_url: 4 rows use images from res.cloudinary.com, which were not
uploaded to this test. They will import - check the URLs load. Lines: 19, 20, 23, 116
```

Those files **were** uploaded, through `POST /api/uploads/question-image`. They
are simply not registered against this test, because that endpoint is not
test-scoped - it cannot be, since it is used while a question has no id yet.

As written, the warning tells an admin their upload failed when it succeeded.
Suggested wording:

```
4 rows link to images hosted elsewhere rather than to files uploaded for this
test. They will import - open the test to check the pictures load.
Lines: 19, 20, 23, 116
```

Nothing about the behaviour needs to change. It imports, and that is right.

### 2b. Verify - the upload endpoint

`POST /api/uploads/question-image` accepts `jpg, jpeg, png, webp, svg` up to 2MB
and returns the four fields above. The panel reports the server's own message
per file, so a refusal just needs a clear `{"error":{"message":"..."}}`.

### 2c. Verify - the single-question write

`POST`/`PATCH` on a question must store and return `questionImageUrl` and
`optionAImageUrl` ... `optionFImageUrl`, alongside `optionA` ... `optionF`.
This is the path an admin uses to add a question by hand or to fix one the CSV
got wrong, and it is the one route that does not go through the importer at all.

If a key is unknown to the endpoint, **say so with a 400**. Accepting a question
and silently storing it without its options leaves an admin looking at a
question that cannot be answered, with nothing on screen to explain it.

## 3. Optional: one request for many files

Only worth doing if a paper's worth of pictures is slow. Today the panel sends
one request per file because that is what the endpoint takes; 40 images is 40
round trips, each with its own TLS and auth cost.

```
POST /api/uploads/question-images          (plural)
Authorization: Bearer <admin token>
multipart/form-data, field "images", up to 25 files per request

200 {
  "images": [
    { "originalFilename": "q18_rhabdomyolysis.png",
      "url": "https://res.cloudinary.com/.../q18_rhabdomyolysis.png",
      "publicId": "...", "bytes": 148223 }
  ],
  "refused": [
    { "filename": "q22_adrenal_crisis_stress.png",
      "message": "That file is 3.1MB. The limit is 2MB." }
  ]
}
```

Rules that matter to the panel:

- **A refused file must not fail the request.** Partial success is the normal
  case: one picture over the limit should not throw away 24 good uploads. Return
  200 with that file in `refused`.
- `originalFilename` must come back **exactly as sent**, including case. It is
  the key the panel matches CSV cells against.
- Keep the singular endpoint working; the question form uploads one file at a
  time and has no reason to change.

Tell me when it is live and I will switch the panel over — it is a small change
to one loop.

## 3b. Optional: orphaned uploads

An admin who uploads pictures and then abandons the wizard leaves files in
Cloudinary that no question references. The panel cannot clean these up: it
does not know which other questions use them, and a form can be closed by
shutting a browser tab.

If this grows, a sweep is better than anything the client can do: delete
upload-route assets older than, say, 30 days whose URL appears in no question,
option, lesson or note row. Not urgent — these are kilobytes.

---

## 4. Still blocking, and nothing to do with images

`backend-test-upload-prompt.md` §1 — six options — is **not shipped**. Uploading
the admin's own file still fails with

```
"E" must be one of A, B, C, D
```

on every row whose answer is the fifth option. Until that lands, a paper written
against six options cannot be imported whatever its pictures do. That is the one
to do first.
