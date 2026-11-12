# Task: Draft / Published on each video, following the lesson

Paste this into Claude inside **this repo** (`admin_drapp`).

## The rule (required by the client)

Each video in a lesson is **Draft** or **Published**, and the **lesson's
status comes first**:

| Admin does | What happens to the videos |
|---|---|
| Sets the lesson to **Draft** (or Archived) | **every** video in it becomes Draft, automatically |
| Sets the lesson back to **Published** | **every** video in it becomes Published again |
| Lesson stays Published | each video keeps its own Draft / Published |
| Adds a video to a **Draft** lesson | it is saved as Draft |
| Adds a video to a **Published** lesson | Published, unless the admin chose Draft |

Students only ever see **Published videos of Published lessons**.

## Backend — live, nothing to wait for

Backend `main` commit `f87026f`. The database is migrated (2026-11-05). All 9
existing videos are in published lessons, so all are Published.

- `videos[]` rows now accept and return **`status`**: `"draft"` |
  `"published"`.
- The server **enforces the rule above**: the lesson's status overrides
  whatever the rows say. The panel must show the result, not fight it.
- **A status change on the lesson carries its videos even when the save sends
  no `videos` list.** A one-field `PUT /api/lessons/:id { "status": "draft" }`
  (for example a status chip on the lesson row) drafts all its videos.
- A row sent without `status` keeps what that video had (matched by
  `videoUrl`). A new row is `published`, and becomes `draft` if the lesson
  is draft.
- Bad value: `400 videos[N].status must be 'draft' or 'published'`. Show the
  message as is.
- `lesson.videoUrl` now points at the first **published** video, and is null
  when none is published. The panel should read `videos[]`, not that field.

## What to build

### 1. Model

`LessonVideo` (`lib/models/lesson_detail_model.dart`): add `status`
(`'draft' | 'published'`, default `'published'` when absent) and
`bool get isPublished`. Parse it in `fromJson`. Every `toJson` that builds a
`videos[]` row sends `'status'`.

### 2. Lesson detail screen — a status control per video

Next to the Free / Premium pill (`_accessPill` / `_toggleAccess`), add a
**Draft / Published** pill that works the same way:

- Tap it to flip. Save at once with `PUT /api/lessons/:id`, sending the
  **full** `videos` list with that row's `status` changed, the same way
  `_toggleAccess` does. Reuse its saving / error / rollback handling.
- Use the `lesson` in the response as the new state. It is the server's
  answer after the rule is applied.
- **When the lesson is Draft:** every video pill shows Draft, and tapping one
  does nothing except a snackbar: "This lesson is a draft. Publish the lesson
  to publish its videos." Do not send a request the server will override.
- A Draft video row is shown **dimmed**, with a small "Draft — students can't
  see this" line.

### 3. Lesson form (`add_edit_lesson_sheet.dart`) and Add video sheet (`lesson_videos_sheet.dart`)

- Each video row gets the same Draft / Published switch. Share one widget
  with the detail screen, as the Free / Premium switch is shared.
- **New row default** = the lesson's current status (`_status`): Draft
  lesson → Draft, Published lesson → Published.
- **When the admin changes the lesson's status in the form:**
  - to Draft / Archived → set every row to Draft on screen and disable the
    switches, with the note "All videos are drafts while the lesson is."
  - to Published → set every row to Published on screen. The admin can then
    draft individual ones before saving.
- `toJson` always sends `status`.

### 4. The lesson's own status change — confirm it

Wherever the panel changes a lesson's status (the form's status chips, and
any status control on the lesson row):

- Published → Draft / Archived: confirm "Move this lesson to draft? All N
  videos in it will become drafts and students won't see them."
- Draft → Published: confirm "Publish this lesson? All N videos in it will be
  published."
- Then refresh the lesson from the response, so the video pills update.

### 5. Course tree row

Show drafts in the count when there are any: **`5 videos · 2 draft`**.
On a draft lesson the existing Draft chip is enough, so don't repeat it per
video.

## Save request, for reference

`PUT /api/lessons/:id` (and `POST /api/chapters/:chapterId/lessons`):

```jsonc
{
  "status": "published",
  "videos": [
    { "videoUrl": "https://.../part1.mp4", "title": "Part 1", "accessType": "free",    "status": "published" },
    { "videoUrl": "https://.../part2.mp4", "title": "Part 2", "accessType": "premium", "status": "draft" }
  ]
}
```

The list is still **replace-all**: send every row on screen, with all its
fields (`title`, `description`, `videoUrl`, `videoPublicId`, `thumbnailUrl`,
`durationSeconds`, `accessType`, `status`).

## Commit

Commit with its own message and push. `student-app-video-parts-prompt.md`
is untracked and not part of this task, so leave it alone.

## Done when

1. Published lesson with 3 videos: draft Part 2 from the detail screen and
   reload. Part 2 is Draft and dimmed, Parts 1 and 3 are Published.
2. Set the lesson to Draft and confirm: all 3 show Draft, and their pills
   don't flip.
3. Set the lesson back to Published and confirm: all 3 show Published,
   including Part 2.
4. Add a video to a Draft lesson: it saves as Draft.
5. In the form, switching the lesson to Draft greys out and drafts every
   video row before saving.
6. A student account never sees a Draft video (check one on the phone).
