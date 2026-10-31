# Task: bring back several videos per lesson (one quiz stays)

Paste this into Claude inside **this repo** (`admin_drapp`).

## Decision (2026-10-31)

- A lesson holds **several videos**: add, reorder, remove.
- A lesson keeps **one quiz**. Do **not** build a quiz list, a `LessonVideo`
  rework, `QuizSummary.isTakenBy`, or remove `QuizService.linkQuizToLesson`.
  That plan was dropped.
- Leave the quiz picker exactly as it is today, including the change that
  hides it on video lessons.

## Backend status — nothing to wait for

- The multi-video API is live on `https://doctorapp-backend-cl2h.onrender.com`
  (backend commit `dda141a`, on `main`).
- The database is migrated and up to date (checked 2026-10-31). No new
  migration is needed for videos.

## What to do

Commit `94fedab` "Go back to one video per lesson" removed the video list from
`lib/Screen/Dashbord/add_edit_lesson_sheet.dart`. Undo **only that file's
video-list part**:

1. Remove the block in `initState` that trims `_videos` to one row and
   disposes the extras.
2. Bring back `_addVideo()` and the **Add video** button next to the
   `Videos (optional)` label.
3. Bring back `_moveVideo(index, delta)` and the ↑ / ↓ buttons on each row.
   Disable ↑ on the first row and ↓ on the last.
4. `_removeVideo` removes the row again, instead of clearing it.
5. Label rows `Video 1`, `Video 2`…, and bring back the empty state
   "No videos yet. A lesson can be quiz-only."
6. Bring back the help text: "Paste a YouTube link or a direct link to the
   video file. Add as many as the lesson needs — the order here is the order
   students get."

`git show 94fedab -- lib/Screen/Dashbord/add_edit_lesson_sheet.dart` is the
exact diff to reverse. Do not touch the other files in that commit, or
anything about the quiz picker or the Rapid Recall strip.

## API contract (unchanged, for reference)

`POST /api/chapters/:chapterId/lessons` and `PUT /api/lessons/:id`:

```jsonc
"videos": [
  { "videoUrl": "https://...", "title": "Part 1", "videoPublicId": "lesson_videos/abc", "durationSeconds": 610 },
  { "videoUrl": "https://youtu.be/xyz" }
]
```

- Replace-all, in array order: `[]` removes every video, and leaving the key
  out leaves them alone. **Always send the full list on screen.**
- `videoUrl` is the only required field. A row without one gets
  `400 videos[N].videoUrl is required`. Fully blank rows may be dropped
  before sending, as `_videoPayload` does now.
- Responses carry `lesson.videos[]` in order. `lesson.videoUrl` is still
  video 1.

## Why this matters now

Since `94fedab`, opening a lesson that has 2+ videos trims the form to one,
and saving it **deletes the others** on the server. Once the list is back,
that stops.

## Done when

1. Add 3 videos, save, and reopen: 3 videos, same order.
2. Move video 3 to the top, save, and reopen: the order is kept.
3. Remove one, save, and reopen: it is gone.
4. Edit only the title of a 3-video lesson: all 3 videos are still there.
5. A lesson with no videos and a quiz still saves.
6. The quiz picker behaves exactly as before.
