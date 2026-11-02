# Per-video free / premium

## What the panel wants to do

An admin builds a lesson out of parts — Part 1, Part 2, Part 3 — and wants the
first one open to everyone and the rest behind a subscription. A free sample is
how a paid course sells itself, and today the choice is all-or-nothing at the
lesson.

Two places in the panel would set it, once the API carries it:

1. **Add video** on a lesson row, and the Videos list in the lesson form — a
   Free / Premium switch per row, set as the video is added.
2. The lesson detail screen's playlist — each part shows which it is.

## Why this is blocked

`videos[]` takes exactly four fields today:

```jsonc
"videos": [
  { "videoUrl": "https://...", "title": "Part 1",
    "videoPublicId": "lesson_videos/abc", "durationSeconds": 610 }
]
```

Anything else the panel sends is dropped. I will not ship a switch that an
admin sets, saves, and finds reset on the next open — a control that silently
does nothing is worse than no control.

## What to change

### 1. Accept and return `accessType` on each video

```jsonc
"videos": [
  { "videoUrl": "https://...", "title": "Part 1", "accessType": "free" },
  { "videoUrl": "https://...", "title": "Part 2", "accessType": "premium" }
]
```

- `free` | `premium`, same vocabulary as the lesson and the deck.
- **Default `premium`** when the key is absent, so a paid lesson does not open
  itself by accident on an older client. Rows saved before this existed are
  premium.
- Returned on every read that returns `videos[]`, so the panel can show it.
- Replace-all still applies: the whole list is sent on every save.

### 2. Decide what it means next to the lesson's own access

The rule I would expect, stated so the student app and the panel agree:

| lesson | video | student without a subscription |
|--------|-------|-------------------------------|
| free | free | plays |
| free | premium | locked |
| premium | free | **plays** — this is the sample |
| premium | premium | locked |

In other words the video's own setting decides, and a free video inside a
premium lesson is the case the feature exists for. If you want the lesson to
win instead, say so and I will build the panel to match — but it has to be one
rule, written down, not inferred by each client.

### 3. The student app

Whatever rule you pick, the lock has to be enforced where the video URL is
served, not only hidden in the UI. A premium part whose link is still in the
payload is a premium part anyone can watch.

## Done when

1. `PUT /api/lessons/:id` with two videos, one `free` and one `premium`, saves
   both and returns both with their `accessType`.
2. Re-saving a lesson from an older client does not flip anything to free.
3. A student with no subscription can play the free part of a premium lesson
   and is refused the premium ones.

Tell me when it is live and I will add the switch to both places in the panel.
