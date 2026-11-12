# Task: an admin can reset their own password

Paste this into Claude inside the **backend** repo (`doctorapp-backend`).
Where it says `<admin email>` and `<new password>`, the person pasting this
will give you the values — ask them, and never write either into a file, a
commit, a test fixture or a log line.

## Why

The admin is locked out of the panel right now and there is no way back in
without opening the database by hand. The student reset flow exists and
works; admins are simply not part of it.

What I checked against production (`https://doctorapp-backend-cl2h.onrender.com`)
on 2026-11-12:

| Request | Result |
|---|---|
| `POST /api/auth/admin/login` with the admin's real password | `401 {"error":{"message":"Invalid email or password"}}` |
| `POST /api/auth/forgot-password {"email": "<admin email>"}` | `200 {"message":"If an account exists for that email, a code has been sent.","resendAfterSeconds":60}` — but **no email arrives**, so it is looking in the student table only |
| `POST /api/auth/reset-password {}` | `400 {"error":{"code":"INVALID_OTP","message":"Enter the 6-digit code from the email"}}` — the route exists |
| `POST /api/auth/admin/forgot-password`, `.../admin/reset-password` | `404` — no admin equivalents |

So the code path is there. It just does not know admins exist.

## Part 0 — unlock this account today (do this first)

Before the feature, get the admin back in: set `<admin email>` to
`<new password>` with a one-off script or a single statement run once against
production.

Hash it with the **same** bcrypt the login route verifies with, at the same
cost factor the rest of the codebase uses.

Then report back: which table and column you updated, and that it touched
exactly one row. The panel side has been guessing at `"Admin"."password"`
with no way to check. If no admin row exists for that email, say so plainly
and create one with the role the login route requires, rather than updating
nothing and reporting success.

## Part 1 — admins join the reset flow

Make the two existing routes work for admin accounts. **Do not add new
endpoints** unless the shared ones genuinely cannot work — the panel has to
be wired up either way, and one flow for both is less to keep in step.

`POST /api/auth/forgot-password`

- Body: `{ "email": string, "scope": "admin" | "student" }`.
- `scope` is optional and defaults to `"student"`, so the student app keeps
  working untouched.
- `scope: "admin"` looks the email up among admins and emails a 6-digit code
  to it.
- Keep the answer generic and unchanged: `200 { message, resendAfterSeconds }`
  whether or not the account exists.

`POST /api/auth/reset-password`

- Body: `{ "email": string, "otp": string, "newPassword": string, "scope": "admin" | "student" }`.
- A code issued for an admin resets **only** that admin, and a student's code
  only that student, even when the same address exists in both tables. An
  admin code must never be accepted where a student one is expected.
- On success: `200 { "message": "..." }`. The panel then signs in through
  `POST /api/auth/admin/login` as usual — no token in this response.

Rules to keep, matching what the student flow already does:

- The code expires (10 minutes is fine) and is single use.
- Resend is rate limited — the `resendAfterSeconds: 60` the route already
  reports.
- Wrong code: `400 { "error": { "code": "INVALID_OTP", "message": ... } }`,
  with a cap on attempts per code.
- The new password gets the same strength rule as everywhere else, and the
  message says the rule when it fails.
- Resetting invalidates whatever sessions or tokens that admin had.
- Never put the code itself in the response body or in a log line.

## Part 2 — tell me the exact contract back

Reply with, for each of the two routes: the final request body, the success
body, and every error body with its status code and `error.code`. The panel's
"Forgot password?" button is dead at the moment and I will wire it to exactly
what you send back, so guessed field names cost another round trip.

Also say whether the email carrying the code is the same template students
get, or an admin one.

## Commit

Its own commit, and deploy to the environment the panel talks to
(`doctorapp-backend-cl2h.onrender.com`).

## Done when

1. The admin can sign in with the password set in Part 0.
2. `POST /api/auth/forgot-password` with `scope: "admin"` puts a 6-digit code
   in that admin's inbox.
3. That code, with a new password, is accepted by
   `POST /api/auth/reset-password` with `scope: "admin"`, and the new password
   signs in at `POST /api/auth/admin/login`.
4. The same code is refused a second time, and after it expires.
5. A student code cannot reset an admin, and an admin code cannot reset a
   student.
6. The student app's existing forgot-password flow is unchanged — it sends no
   `scope` and behaves exactly as before.
