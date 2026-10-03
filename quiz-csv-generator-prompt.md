# Prompt: write a question sheet for the admin panel

Paste everything below into ChatGPT / Claude / Gemini, filling in the four
values at the top. Save the reply as a `.csv` file and upload it in the quiz
form of the admin panel.

---

You are writing a multiple-choice question bank as a CSV file.

**Topic:** {SUBJECT} — {TOPIC}
**Exam:** {EXAM, e.g. DHA Dubai / MOH / Prometric}
**How many questions:** {COUNT}
**Difficulty mix:** {e.g. 40% easy, 40% medium, 20% hard}

## Output format

Reply with **the CSV and nothing else** — no explanation before or after, no
``` fences, no numbering. The first line must be exactly this header:

```
question_text,question_image_url,difficulty,tags,status,option1,option1_image_url,option2,option2_image_url,option3,option3_image_url,option4,option4_image_url,correct_option,marks_correct,marks_incorrect,explanation
```

Then one line per question, in that same column order.

## Rules for every row

- `question_text` — the question stem. Never leave it blank.
- `question_image_url` — leave empty unless the question genuinely needs a
  picture. If it does, use a real `https://` URL. Never invent a URL that does
  not exist.
- `difficulty` — exactly `easy`, `medium` or `hard`.
- `tags` — two or three lowercase keywords separated by commas, wrapped in
  double quotes, e.g. `"cardiology,ecg"`.
- `status` — always `active`.
- `option1` … `option4` — four plausible answers. Wrong options must be
  genuinely tempting: no joke answers, no options that are obviously absurd,
  and no "all of the above" / "none of the above".
- `option1_image_url` … `option4_image_url` — leave empty for a normal
  question. An option may be an image with blank text, but only if the question
  really is a picture-comparison one.
- `correct_option` — **1-based**: `1` means option1 is right, `4` means
  option4. Vary it across the file; do not put the answer in position 1 every
  time.
- `marks_correct` — `2`.
- `marks_incorrect` — `-0.5`.
- `explanation` — one or two sentences saying *why* the right answer is right.
  Not a restatement of the option.

## CSV mechanics, which matter more than the content

- Any field containing a comma, a quote or a colon must be wrapped in double
  quotes: `"A 55-year-old man, previously well, presents with..."`.
- A double quote inside a quoted field is written twice: `""`.
- No line breaks inside a field. One question = one line.
- No blank lines, no trailing commentary line, no extra columns.
- Plain ASCII punctuation — straight quotes, a normal hyphen, no smart quotes
  and no em dashes.

## Worked example of one correct line

```
"A patient with COPD has FEV1/FVC of 0.58. What pattern is this?",,easy,"pulmonology,spirometry",active,Obstructive,,Restrictive,,Mixed,,Normal,,1,2,-0.5,A ratio below 0.70 defines an obstructive pattern.
```

## Before you answer, check

1. every line has exactly 17 commas' worth of fields;
2. every `correct_option` points at an option that is actually filled in;
3. no two questions are the same question reworded;
4. the count matches what was asked for.
