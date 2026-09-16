# UNEXA

> One app for your whole institute — built for schools, coachings, and colleges.

## ✨ The Project

UNEXA is a multi-tenant institute management app built with **Flutter + Firebase**. Every institute gets its own isolated space inside one app, and everything runs on Firebase (Auth, Firestore, Storage, App Check) — there is no separate backend server.

## 🔗 Roles & connections

| Role | Sees | Can do |
|---|---|---|
| **Owner** | Everything | Create institutes, override anything |
| **Admin** | Full dashboard | All institute operations, promote/demote every role, ban at admin level, reverse approvals |
| **Co-Admin** | Full dashboard | Manage academics, timetable, announcements & documents, promote Moderator/CR, ban at moderator level |
| **Moderator** | Verification panel | Approve / reject / ban (moderator level) / unban own bans |
| **CR** | Student app + Verification | Everything a student has, plus the verification powers of a moderator |
| **Student** | Student app | Timetable, announcements, calendar, documents, profile |

Every action flows everywhere in real time — a student approved by a CR appears instantly for admins, a batch created by a co-admin is immediately selectable by students, and every approve/ban/role-change is written to the audit log with who, when, and why. Bans are a strict hierarchy enforced server-side in Firestore rules, so no client can bypass them.

## ✨ Features

- **Verification workflow** — students join with an institute code, staff approve / reject / ban with reasons shown to the user, plus an "All Users" management tab for admins
- **Academic setup** — departments, batches with sections, subjects, and a faculty roster, all managed live from the app
- **Timetable** — batch/section-scoped class schedules that update for students in real time
- **Announcements, calendar events, and official PDF documents** (routine, holidays) uploaded by staff
- **Audit logs** — the full history of who did what, when, and why
- **In-app update system** — version checked against a Firebase config, with in-app download
- **Cross-platform** — Android and iOS from one codebase, portrait-locked with a consistent UI on every device
- **Security-first** — hardened Firestore & Storage rules, Firebase App Check, and server-enforced ban hierarchy

## 👤 About the Developer

UNEXA is designed, built, and maintained end-to-end by **Vansh** — from the Firebase architecture and security rules down to the pixel-level UI.

- GitHub: [@thev4nsh](https://github.com/thev4nsh)
- Email: [vansh.yadhuvanshi01@gmail.com](mailto:vansh.yadhuvanshi01@gmail.com)
