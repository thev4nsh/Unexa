# UNEXA

> One app for your whole institute — built for schools, coachings, and colleges.

## ✨ The Project

UNEXA is a multi-tenant institute management app built with **Flutter + Firebase**. Every institute gets its own isolated space inside one app, and everything runs on Firebase (Auth, Firestore, Storage, App Check) — there is no separate backend server.

What's inside:

- **5 roles** — Admin, Co-Admin, Moderator, CR (moderator + student), Student — each with exactly the powers they need, nothing more
- **Verification workflow** — students join with an institute code, staff approve / reject / ban with a full ban hierarchy, reasons shown to the user, and "All Users" management for admins
- **Academic setup** — departments, batches, sections, subjects, and a faculty roster, all managed live from the app
- **Timetable** — batch/section-scoped class schedules that update for students in real time
- **Announcements, calendar events, and official PDF documents** (routine, holidays) uploaded by staff
- **Audit logs** — who approved whom, who banned whom, when, and why
- **In-app update system** — version checked against a Firebase config, with in-app download
- **Cross-platform** — Android and iOS from one codebase, portrait-locked with a consistent UI on every device
- **Security-first** — hardened Firestore & Storage rules, App Check, and a ban hierarchy enforced server-side, so the client can never bypass permissions

## 👤 About the Developer

UNEXA is designed, built, and maintained end-to-end by **Vansh** — from the Firebase architecture and security rules down to the pixel-level UI.

- GitHub: [@thev4nsh](https://github.com/thev4nsh)
- Email: [vansh.yadhuvanshi01@gmail.com](mailto:vansh.yadhuvanshi01@gmail.com)
