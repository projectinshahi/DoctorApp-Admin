# Student app: a lesson is several videos, and each one sells itself

## What changed underneath you

Backend `da76772`, live on `https://doctorapp-backend-cl2h.onrender.com`,
database migrated 2026-11-03. The admin panel already writes all of this.

1. **A lesson holds a list of videos**, not one. `lesson.videos[]`, in
   `displayOrder`. Each row:

   ```jsonc
   { "id": 31, "title": "Part 1", "description": "Anterior pituitary…",
     "videoUrl": "https://youtu.be/…", "thumbnailUrl": "https://…/part1.jpg",
     "videoPublicId": "lesson_videos/abc", "durationSeconds": 610,
     "displayOrder": 0, "accessType": "free" }
   ```

   `lesson.videoUrl` still exists and still mirrors `videos[0]`, so nothing
   breaks today — it just stops being the whole truth.

2. **Access is per video now.** `accessType` is `free` | `premium` on each
   row, and **the video's own setting decides**:

   | lesson | video | student without a subscription |
   |---|---|---|
   | free | free | plays |
   | free | premium | locked |
   | premium | free | **plays** — the sample |
   | premium | premium | locked |

   True inside a premium course too. No free-preview flag is involved.

3. **The lesson's own `accessType` / `isFreePreview` now covers only its
   quiz, notes and text.** It no longer says anything about its videos. Any
   code that reads the lesson's tier to gate a video is now wrong.

4. **The server strips a locked video's URL**: a premium part a student has
   not paid for arrives with `videoUrl: null`, exactly as a locked lesson does
   today.

## What that means for the tab

Your own description is the thing to change: the AI Video tab is a list of
**lessons**, and a lesson is now a container. Three concrete consequences.

### A. `AiVideoTab.videosIn(chapter)` returns videos, not lessons

The rule it encodes - *not a quiz, and either has media or is locked* - still
holds, but one level down. A lesson with three parts is three rows, or one row
that opens to three. Pick one and make the chapter counts use the same
function, the way they do now; that is what kept the 0/4 bug from coming back.

Keep the locked ones in the list for the same reason as before. It matters
more now, not less: the free part of a paid lesson is the advert, and the
padlocked parts beside it are what the advert is for.

### B. A row's chip and padlock come from the video

`isOpen` moves to the video: `accessType == 'free' || videoUrl != null`,
with the existing exception intact - an unlocked row whose URL was stripped
stays shut, because an empty player is a worse answer than a padlock.

A lesson that mixes tiers must not show one chip for all its parts. If you
keep one row per lesson, say the mix - "3 videos · 1 free" - and let the parts
carry their own chips inside.

### C. The detail screen is a playlist

`StudentLessonDetailScreen` plays `videos[0]` today. It needs to pick a part,
play it, and offer the rest - the same player selection as now (YouTube by
URL shape, `video_player` otherwise), only per part. A padlocked part answers
with the plan dialog where an open one plays; both live in the same list.

## The one thing to settle before building

**Progress is per lesson.** `PUT /lessons/:id/progress` and
`lastPositionSeconds` have no notion of which video. With three parts, a
student who finishes part 1 and starts part 2 either overwrites one position
with the other, or the lesson is marked complete on the strength of its first
video.

The server decides `completed`, so this is a backend question, not an app one.
Ask for one of:

- `PUT /lessons/:id/videos/:videoId/progress`, with the lesson rolling up as
  complete when every **open** part is; or
- `videoId` accepted on the existing route, and `lesson.videos[].progress`
  returned with the tree.

Until that exists, keep writing progress for the lesson as a whole and resume
only part 1, rather than writing one part's position over another's. Say so in
the UI if it helps: a wrong resume point is worse than none.

## Smaller things worth checking

- **Saved / bookmarks** are per lesson. Decide whether saving a lesson saves
  all its parts, or whether `SavedProvider` needs a video id. Per lesson is
  defensible; just make it deliberate.
- **Thumbnails**: use `video.thumbnailUrl` when it is there, falling back to
  the lesson's cover and then to `img.youtube.com`. The admin can set a
  still per part now.
- **Duration**: `durationSeconds` is per video and often null for a pasted
  YouTube link. Show it only when it is there.
- **DemoContent** in the guest preview should carry a multi-part lesson, with
  one part free and one locked. It is the clearest thing the preview can show,
  and it exercises the new rules.

## Done when

1. A lesson with three parts shows three playable items, counted the same way
   in the chapter card and the list.
2. A premium lesson whose part 1 is free plays part 1 for a signed-out visitor
   and padlocks the rest.
3. No screen decides a video's access from the lesson's `accessType`.
4. A locked part never opens an empty player.
5. Progress still writes exactly once per position change, and resumes
   somewhere defensible.
