# Task: what the panel needs for the student app's new Videos design

Paste this into Claude inside **this repo** (`admin_drapp`).

## Why

The student app's Videos screens (Figma **Dr app → work space**, frames
"iPhone 13 & 14 - 50" and "- 51") show:

- **Subjects** as cards with a round **organ icon**, a title and "8 Videos".
  Each card is a **lesson**, grouped under **chapter** chips ("Medicine").
- Inside a subject, each **video** as a row: thumbnail with length badge,
  title, **"18.4k views"**, and a bookmark.

Everything the app shows comes from what the admin sets here. Nothing in the
panel's save requests changes.

## Backend (branch `video-views-saves`, going to `main`)

- Each video in `lesson.videos[]` now also returns **`viewCount`**
  (read-only, counted when students start it). Do not send it on save; the
  server ignores it.
- **Saving a lesson now keeps each video's identity.** A row whose
  `videoUrl` is unchanged is updated in place, so its view count and
  students' bookmarks survive. Changing a row's **link** makes it a new video,
  with 0 views and no bookmarks. Warn about that in the UI (see §3).

## What to build

### 1. Lesson cover image = the subject card's icon

In the lesson form, relabel **Cover image** as **"Icon (shown on the
subject card)"**, with the help text "Square, simple icon on a transparent or
white background, at least 256×256. Shown in a circle."

- Preview it **in a circle** at the size the app uses, beside the field.
- Keep using the existing upload and the `thumbnailUrl` / `thumbnailPublicId`
  fields. Nothing new on the API.

### 2. Each video's thumbnail and title

The app's row is thumbnail + title (2 lines) + views.

- In the video row editor (lesson form and the Add video sheet), make the
  **thumbnail** obvious: a 16:9 preview with an "Upload thumbnail" button.
  Use the same upload the panel already uses for it
  (`POST /api/uploads/question-image` → `url` → `thumbnailUrl`).
- Show a character counter on the video **title**, with a soft warning past
  60 characters: "Students see 2 lines."

### 3. Show the views

- On the lesson detail screen's playlist, show **"18.4k views"** under each
  video (`viewCount`; format `950`, `1.2k`, `18.4k`, `1.2M`). Show nothing at
  0.
- In the video row editor, when the admin edits a saved video's **link**,
  show inline: "Changing the link makes this a new video: its 18.4k views
  and students' bookmarks start again." Only when `viewCount > 0`.

### 4. Subjects count only published videos

The app's "8 Videos" counts **published** videos the student can see. On the
course tree row, keep showing all videos with the draft count
(`8 videos · 2 draft`), so the admin can see why the app says 6.

## Commit

Its own commit, and push.

## Done when

1. A lesson's cover image previews as a circle, labelled as the subject icon.
2. A video row has a clear thumbnail upload, and its title warns past 60
   characters.
3. The detail playlist shows each video's views.
4. Editing a viewed video's link shows the "new video" warning.
