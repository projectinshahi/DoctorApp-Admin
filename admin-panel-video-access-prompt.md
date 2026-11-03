# Task: Free / Premium on each video — finish it and ship it

Paste this into Claude inside **this repo** (`admin_drapp`).

## The backend is live — stop waiting

`backend-video-access-prompt.md` asked for this. It is done, merged to backend
`main` (commit `da76772`), and the database is migrated (2026-11-03).

- `videos[]` now accepts and returns **`accessType`** (`free` | `premium`) and
  **`description`**, next to `title`, `videoUrl`, `videoPublicId`,
  `thumbnailUrl`, `durationSeconds`.
- **The video's own setting decides**, exactly the table in your prompt:

  | lesson | video | student without a subscription |
  |---|---|---|
  | free | free | plays |
  | free | premium | locked |
  | premium | free | **plays** — the sample |
  | premium | premium | locked |

  It is also true in a premium **course**: a free video plays there too, and
  needs no free-preview flag.
- The **lesson's** own `accessType` / `isFreePreview` now covers only its
  **quiz, notes and text**. It no longer locks videos.
- Enforced on the server: a locked video comes back to students with
  `videoUrl: null`.
- **A row without `accessType` keeps what that video already had** (matched by
  `videoUrl`). A new row without it is **premium**. Re-saving from an old build
  cannot open a paid video.
- Existing videos kept their lock when the migration ran: 7 free, 2 premium.
- A bad value returns `400 videos[N].accessType must be 'free' or 'premium'`.
  Show the message as is.

## What is already done here (uncommitted — keep it)

- `lesson_videos_sheet.dart` (Add video from the row): Free / Premium switch,
  description and thumbnail per row, and `toJson` sends `accessType`.
- `LessonDetailScreen.dart`: the playlist shows a Free / Premium pill and the
  description per video.
- `lesson_detail_model.dart`: `LessonVideo.accessType`, `isFree`,
  `description`.

## What to do

### 1. Lesson videos sheet (Add video)

- Delete the note "Free / premium, description and thumbnail per video save
  once the backend stores them." It is no longer true.
- Default a **new** row's switch from the course: **Premium on a premium
  course, Free on a free course**. Always send `accessType` explicitly.
- Label it **Free** / **Premium**. On a premium course, use **Free sample** as
  the free label.

### 2. Lesson form (`add_edit_lesson_sheet.dart`) — the Videos list

`_VideoDraft` there still has no access or description, so the form and the
sheet disagree. Bring it level with the sheet's row:

- Add `free` (bool), `description` (controller), and `thumbnailUrl` to
  `_VideoDraft`, filled by `_VideoDraft.from(LessonVideo)`.
- Each row gets the same Free / Premium switch and the optional description
  field. Use the same widget as the sheet, so the two cannot drift. Extract
  it if needed.
- `toJson` always sends `'accessType': free ? 'free' : 'premium'`, plus
  `description` and `thumbnailUrl` when set.
- New rows default the way §1 says.

### 3. Lesson form — the lesson-level Free switch

The lesson is no longer free or premium as a whole. Its videos are.

- **Remove `_FreeSwitch` from the top of the form.**
- Show it only where it still means something: **inside the Quiz section**
  (quiz lessons), and next to notes / text if the form has them. Label it
  **"Quiz access: Free / Premium"** (or "Notes & text access").
- On a video lesson with no quiz, notes or text, do not show it. Keep resending
  the `_accessType` / `_isFreePreview` the lesson already has, so nothing
  changes silently.
- The free-preview logic (`coursePremium && isFree` → free preview) stays
  for that quiz / notes switch only. A video needs none of it.

### 4. Lesson detail screen — set it from the playlist

Make the per-video pill a control:

- Tap the pill → it flips Free ↔ Premium. For Premium → Free, confirm: "Part 2
  will play for everyone, including students without a subscription."
- Save immediately with `PUT /api/lessons/:id`, sending **the full `videos`
  list** with that row's `accessType` changed. The list is replace-all, so
  every row is sent with its `title`, `description`, `videoUrl`,
  `videoPublicId`, `thumbnailUrl`, `durationSeconds`, `accessType`.
- While saving, show a spinner on that pill. On error, put it back and show
  `error.message`.
- Replace the screen's state with the `lesson` in the response.
- Change the lesson-level premium badge on that screen to describe the quiz /
  notes only, or remove it on a video-only lesson.

### 5. Syllabus row (course tree)

- Show the mix, not the lesson's tier: **`3 videos · 1 free`**, or
  **`All free`** / **`All premium`** when they agree.
- Drop the lesson-level `Premium` / `Free` chip on video lessons. On a quiz
  lesson it now means the quiz, so label it **`Quiz: Premium`**.

### 6. Commit

Commit the work above together with the uncommitted per-video changes, and
delete `backend-video-access-prompt.md`: its request is answered. Push.

## Save request, for reference

`POST /api/chapters/:chapterId/lessons` and `PUT /api/lessons/:id`:

```jsonc
{
  "videos": [
    { "videoUrl": "https://.../part1.mp4", "title": "Part 1", "accessType": "free",
      "description": "Anterior pituitary, hormones and axes.",
      "thumbnailUrl": "https://res.cloudinary.com/.../part1.jpg",
      "videoPublicId": "lesson_videos/abc", "durationSeconds": 610 },
    { "videoUrl": "https://.../part2.mp4", "title": "Part 2", "accessType": "premium" }
  ]
}
```

Rules:

- **Replace-all**, in array order. Always send the whole list on screen.
- `[]` removes every video.
- Leaving the key out leaves the list alone.

Responses return each video with `id`, `title`, `description`, `videoUrl`,
`videoPublicId`, `thumbnailUrl`, `durationSeconds`, `displayOrder`,
`accessType`.

## Done when

1. In Add video, add Part 1 as Free and Part 2 as Premium, then save. Reopen
   the lesson form: same switches, same descriptions.
2. In the lesson form, flip Part 2 to Free, save, and reopen the detail
   screen: both pills say Free.
3. On the detail screen, tap Part 1's pill to make it Premium and confirm.
   Reload: it stays Premium.
4. A video lesson's form has no lesson-level Free switch. A quiz lesson
   has "Quiz access" inside its quiz section.
5. Editing only a lesson's title leaves every video's Free / Premium as it was.
6. The syllabus row reads like `2 videos · 1 free`.
7. No request sends a video row without `accessType`.
