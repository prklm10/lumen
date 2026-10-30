# Product Requirements Document — Lumen

> A local-first, self-hosted personal workspace for **journaling, tasks, daily tracking, and learning** — Obsidian-like ownership, Notion-like UI, running entirely on your machine in Docker.

| | |
|---|---|
| **Owner** | Pradum Kumar |
| **Status** | Draft v1.1 — open questions resolved (§16) |
| **Date** | 2026-10-29 |
| **Stack** | Ruby on Rails 8.1 · Vue 3 · PostgreSQL 17 · Docker |
| **Deployment** | Local only (`localhost`), single user — LAN/phone access deferred (§10.7) |

---

## 1. Vision & Goals

### 1.1 Problem
Personal productivity is split across too many apps: a notes app for learning, a todo app for tasks, a habit tracker, and a journal. Data lives in someone else's cloud, journals are readable by the provider, and there is no single view of "how am I actually doing?"

### 1.2 Vision
One fast, beautiful, keyboard-driven local web app with four distinct spaces — **Journal, Tasks, Tracker, Learn** — sharing one design language, one search, and one analytics dashboard. Your data never leaves your machine, and your journal is unreadable even to someone holding the database.

### 1.3 Goals
| # | Goal | Measured by |
|---|---|---|
| G1 | Replace 3–4 separate apps with one | Daily use of ≥3 modules for 30 days |
| G2 | Journal is zero-knowledge encrypted | No plaintext journal content in DB, logs, disk, or backups (verified by test, §9.7) |
| G3 | Modern UI comparable to Notion/Obsidian | Command palette, slash-menu editor, dark mode, <100 ms interactions |
| G4 | Actionable analytics | Dashboard answers "what did I complete, where did time go, am I consistent?" |
| G5 | **Learn Rails & Postgres by building it** | Each phase maps to explicit learning objectives (§13) |
| G6 | One-command, lightweight Docker setup | `docker compose up`; app image ≤ 300 MB; idle RAM ≤ 400 MB total |

### 1.4 Non-Goals (v1)
- Multi-user accounts, sharing, or real-time collaboration
- Cloud sync, hosting on the public internet, or mobile native apps
- AI features (could be a later add-on)
- Plugin system (Obsidian-style) — keep the codebase simple first

---

## 2. User Persona

**Primary (and only) user:** a developer who wants to own their data, journals privately, manages personal/work todos, tracks habits, and is constantly learning (courses, books, tech topics). Comfortable with the terminal and Docker; heavy keyboard user; values aesthetics.

### Key user stories
- *As a user, I open the app and land on **Today**: today's tasks, habits to check off, and a prompt to journal.*
- *As a user, I unlock my journal with a separate passphrase; it auto-locks when I walk away.*
- *As a user, I paste a screenshot directly into a learning note and it just appears.*
- *As a user, I type `Review PR tomorrow 5pm #work !high` and a task is created with the right fields.*
- *As a user, I link `[[Postgres Indexes]]` from another note and see backlinks.*
- *As a user, I review flashcards generated from my notes and track retention.*
- *As a user, I open a weekly review showing tasks completed, habit streaks, learning hours, and mood trend.*

---

## 3. Information Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│ Sidebar                    │  Main area                           │
│ ───────                    │                                      │
│ 🔍 Search   ⌘K             │                                      │
│ ☀️ Today                   │   (page content, max-width 760px     │
│ 📓 Journal  🔒             │    for documents, full width for     │
│ ✅ Tasks                   │    boards, calendars, dashboards)    │
│    ├ Inbox                 │                                      │
│    ├ Upcoming              │                                      │
│    └ Projects ▸            │                                      │
│ 📈 Tracker                 │                                      │
│ 📚 Learn                   │                                      │
│    ├ Notes / Folders ▸     │                                      │
│    ├ Topics & Resources    │                                      │
│    └ Review (flashcards)   │                                      │
│ 📊 Analytics               │                                      │
│ 🖼  Media                   │                                      │
│ ⚙️  Settings               │                                      │
└──────────────────────────────────────────────────────────────────┘
```

The four modules are **separate data domains** (separate tables, separate routes, separate Pinia stores). They connect only through: Today view, global search (excluding journal), tags, and analytics.

---

## 4. Functional Requirements

Priority: **P0** = MVP, **P1** = v1.0, **P2** = later.

### 4.1 Authentication & App Lock (P0)
Even on localhost, the app is protected — anyone on your machine/LAN shouldn't open it.

| ID | Requirement |
|---|---|
| AUTH-1 | Single-user login using Rails 8's built-in authentication generator (`has_secure_password`, bcrypt). First run shows a setup screen to create the account. |
| AUTH-2 | Session cookie: `HttpOnly`, `SameSite=Strict`; session idle timeout configurable (default 7 days). |
| AUTH-3 | Rate-limit login (Rails 8 `rate_limit`): 5 attempts/min. |
| AUTH-4 | Server binds to `127.0.0.1` only by default (see §10). |
| AUTH-5 (P1) | Optional TOTP 2FA. |

### 4.2 Journal — Encrypted Vault (P0) 🔒

The journal is the most sensitive module and is designed **zero-knowledge**: the Rails server and Postgres **never see plaintext** journal content or the journal passphrase.

#### Features
| ID | Requirement | P |
|---|---|---|
| JRN-1 | Separate **journal passphrase** (distinct from login password), set on first use. | P0 |
| JRN-2 | Unlock screen; vault auto-locks after N minutes idle (default 10), on tab hide (optional), and on manual lock (`⌘⇧L`). | P0 |
| JRN-3 | One or more entries per day; calendar view and timeline view. | P0 |
| JRN-4 | Rich editor (same editor as Learn) — headings, lists, checklists, quotes, images. | P0 |
| JRN-5 | Per-entry **mood** (1–5 + emoji), **tags**, optional **prompt** ("What am I grateful for?"). All stored *inside* the encrypted payload. Optional per-user setting **"Also log mood to Tracker"** (off by default) copies the mood value — and only that value — to the unencrypted Mood tracker (see TRK-9). | P0 |
| JRN-6 | Autosave every 2 s of inactivity — ciphertext only is sent. | P0 |
| JRN-7 | Images in journal are encrypted in the browser before upload. | P1 |
| JRN-8 | Search within journal — performed **client-side** after unlock (decrypt into memory, index with MiniSearch). | P1 |
| JRN-9 | "On this day" — entries from same date in prior years. | P1 |
| JRN-10 | Change passphrase (re-wraps key only, no re-encryption of entries). | P0 |
| JRN-11 | Recovery key (shown once at setup, user prints/stores it). | P0 |
| JRN-12 | Encrypted export (`.lumenvault`) and decrypted export to Markdown zip (generated in browser). | P1 |
| JRN-13 | Templates (morning pages, evening reflection, weekly review). | P2 |

Full cryptographic design in **§7**.

### 4.3 Tasks (P0)
| ID | Requirement | P |
|---|---|---|
| TSK-1 | Create/edit/complete/delete tasks: title, description (rich text), due date/time, priority (none/low/med/high/urgent), status, tags, estimate (minutes). | P0 |
| TSK-2 | **Projects** (with color/icon) and optional **sections** inside projects. Inbox = tasks with no project. | P0 |
| TSK-3 | Subtasks (one level of nesting in v1). | P0 |
| TSK-4 | Views: **Today**, **Upcoming** (7 days), **Inbox**, **Project**, **Completed (log)**. | P0 |
| TSK-5 | Layouts per project: **List** and **Kanban board** (drag & drop between status columns). | P0 |
| TSK-6 | **Quick add** with natural-language parsing: `Call mom tomorrow 6pm #family !high @errands`. | P1 |
| TSK-7 | **Recurring tasks** (daily, weekdays, weekly on X, monthly, custom RRULE). Next occurrence created on completion. | P1 |
| TSK-8 | Calendar view (month/week) with drag to reschedule. | P1 |
| TSK-9 | Overdue highlighting; snooze. | P0 |
| TSK-10 | Bulk actions (multi-select → move/complete/reprioritize). | P1 |
| TSK-11 | Link a task to a learning note or resource. | P1 |
| TSK-12 | Track every status change (`task_events`) — powers analytics. | P0 |
| TSK-13 | Pomodoro/focus timer attached to a task; logs focus time. | P2 |

### 4.4 Daily Tracker (P0)
Habits and daily metrics — non-journal, so stored as normal (unencrypted) data to allow SQL analytics.

| ID | Requirement | P |
|---|---|---|
| TRK-1 | Define **trackers** with type: `boolean` (did it), `count` (glasses of water), `duration` (minutes of exercise), `numeric` (weight, sleep hours), `scale` (energy 1–5). | P0 |
| TRK-2 | Target + frequency: daily, N times/week, specific weekdays. | P0 |
| TRK-3 | One-tap check-in on Today view; backfill past days. | P0 |
| TRK-4 | Streaks (current, longest), completion %. | P0 |
| TRK-5 | GitHub-style yearly heatmap per tracker. | P0 |
| TRK-6 | Archive tracker (keeps history). | P0 |
| TRK-7 | Optional note per check-in. | P1 |
| TRK-8 | Correlations ("on days you exercised, task completion was +18%"). | P2 |
| TRK-9 | Built-in **Mood** tracker (`scale`, 1–5). Each tracker has a visible 🔓 *unencrypted* badge; mood can be logged here directly or mirrored from the journal (JRN-5) so it is available to SQL analytics and correlations. Setting UI warns that mirrored mood is not encrypted. | P1 |

### 4.5 Learn — Knowledge Base (P0)
The Obsidian-like part.

| ID | Requirement | P |
|---|---|---|
| LRN-1 | **Notes** with block editor (TipTap): headings, lists, todo, code blocks w/ syntax highlighting, callouts, tables, images, math (KaTeX, P2), embeds. | P0 |
| LRN-2 | **Slash menu** (`/`) and **Markdown shortcuts** (`#`, `-`, `>`, ```` ``` ````). | P0 |
| LRN-3 | **Folders** (nested, unlimited depth) + drag & drop reordering in sidebar tree. | P0 |
| LRN-4 | **Wiki-links** `[[Note title]]` with autocomplete; creates note if missing. | P0 |
| LRN-5 | **Backlinks** panel on each note. | P0 |
| LRN-6 | Tags (`#postgres`) shared app-wide. | P0 |
| LRN-7 | Full-text search across notes, tasks, resources (Postgres FTS + trigram fuzzy). | P0 |
| LRN-8 | **Topics** (e.g. "Rails", "System Design") grouping notes, resources, sessions. | P1 |
| LRN-9 | **Resources**: books/courses/videos/articles with URL, type, status (to-learn / in-progress / done), progress %, rating. | P1 |
| LRN-10 | **Study sessions**: log time spent per topic (manual or timer). | P1 |
| LRN-11 | **Flashcards** with spaced repetition (SM-2 algorithm). Create from a note block via `::` syntax or "Make card" action. | P1 |
| LRN-12 | **Graph view** of note links (force-directed). | P2 |
| LRN-13 | Note version history (snapshots on significant edits). | P2 |
| LRN-14 | Import/export Markdown (Obsidian-vault compatible folder). | P1 |
| LRN-15 | Pin/favorite notes; recent notes. | P0 |

### 4.6 Media / Image Uploads (P0)
| ID | Requirement | P |
|---|---|---|
| MED-1 | Upload via drag & drop, paste from clipboard, or file picker — in any editor. | P0 |
| MED-2 | Active Storage with **local disk** service, mounted Docker volume. | P0 |
| MED-3 | Formats: JPEG, PNG, WebP, GIF, AVIF, HEIC (converted). Max 20 MB (configurable). Validate by content type sniffing, not extension. | P0 |
| MED-4 | Automatic variants via **libvips**: `thumb` (320px), `medium` (1024px), served as WebP. EXIF/GPS metadata stripped. | P0 |
| MED-5 | Direct uploads (browser → Rails → disk) with progress bar. | P0 |
| MED-6 | Media library page: grid of all non-journal images, with "used in" references; delete orphans. | P1 |
| MED-7 | Journal images encrypted client-side; stored as opaque `application/octet-stream` blobs; **no variants/thumbnails generated server-side** (server can't see them). Thumbnails generated in-browser and encrypted too. | P1 |
| MED-8 | Lightbox viewer with zoom. | P1 |

### 4.7 Today / Home (P0)
A single daily cockpit:
- Greeting + date, quick-add bar
- Today's & overdue tasks
- Habit check-ins for today
- Journal card: "Write today's entry" (locked/unlocked state; never shows content preview unless unlocked)
- Learning: flashcards due, current resource progress
- Mini stats: tasks done today, current streaks

### 4.8 Analytics (P0 → P1)
All analytics computed with SQL in Postgres (great learning ground), cached, and displayed with charts.

**Tasks**
| Metric | Chart |
|---|---|
| Tasks completed per day/week/month | Bar |
| Created vs completed (are you keeping up?) | Dual line |
| Completion rate % = completed / (completed + overdue-open) in period | KPI tile + trend |
| On-time rate (completed before due) | KPI tile |
| Avg. time-to-complete (created → done) | KPI, by priority |
| Completion by project / tag | Horizontal bar |
| Productive hours (hour-of-day × weekday completion) | Heatmap |
| Overdue backlog over time | Area |
| Estimate accuracy (estimate vs focus time, P2) | Scatter |

**Tracker**
- Per-habit consistency %, current/longest streak, yearly heatmap
- Numeric trackers: line chart with 7-day moving average (window function)
- Weekday consistency ("you skip workouts on Fridays")

**Learning**
- Study hours per topic per week (stacked bar)
- Resources completed; notes created; links created (knowledge growth)
- Flashcard: reviews/day, retention %, cards due forecast

**Journal (privacy-preserving)**
- Server can only compute **writing streak & entry count** from entry dates (the only unencrypted metadata).
- Mood trend & word count are computed **in the browser after unlock** from decrypted data — never sent to server.
- Exception by user choice: if mood mirroring is on (JRN-5/TRK-9), mood trend is also available server-side via the Mood tracker.

**Reviews**
- **Weekly Review** page (P1): auto-summary of the week across all modules — including **completed task titles** (tasks are not sensitive and stay unencrypted) — plus a prompt to write a reflection. Only the reflection is saved as an encrypted journal entry; the summary is regenerated from live data and never copied into the journal.
- Date range selector: 7d / 30d / 90d / 1y / custom.

### 4.9 Global Features
| ID | Requirement | P |
|---|---|---|
| GLB-1 | **Command palette** `⌘K`: navigate, search, create anything, run actions. | P0 |
| GLB-2 | Keyboard shortcuts everywhere (`c` new task, `n` new note, `j` journal, `g t` go to tasks, `?` shortcut list). | P0 |
| GLB-3 | Light / dark / system theme. | P0 |
| GLB-4 | Tags shared across Tasks, Notes, Resources (journal tags are private/encrypted). | P0 |
| GLB-5 | Trash with 30-day restore (soft delete). | P1 |
| GLB-6 | Backup & restore (§10.6). | P0 |
| GLB-7 | Settings: timezone, week start, auto-lock timeout, theme, default views. | P0 |
| GLB-8 | **Mobile-responsive** down to 375px (phone): collapsible sidebar → bottom nav, touch targets ≥ 44px, quick-add & habit check-in optimised for one hand. | P2 |
| GLB-9 | **LAN / phone access over HTTPS** (opt-in): Caddy reverse proxy with mkcert certificate; see §10.7. *Deferred.* | P2 |
| GLB-10 | Installable **PWA** (manifest + icons, no offline sync in v1) so it opens like an app from the phone home screen. | P2 |

---

## 5. UX & UI Design

### 5.1 Design principles
1. **Content first** — chrome recedes; generous whitespace; documents at ~720–760px width.
2. **Keyboard first** — every action reachable by keyboard; command palette is the hub.
3. **Fast** — optimistic updates; no full-page reloads; skeletons instead of spinners.
4. **Calm** — muted neutrals, one accent color, subtle motion (150–200 ms ease-out).
5. **Consistent** — one component library, one editor, shared tokens.

### 5.2 Visual language
| Token | Value |
|---|---|
| Font (UI) | **Inter** variable (self-hosted, no Google CDN — local-first) |
| Font (mono) | **JetBrains Mono** |
| Base size | 14px UI, 16px editor |
| Radius | 6px (controls), 10px (cards/popovers) |
| Neutrals | Zinc scale (`zinc-50` … `zinc-950`) |
| Accent | User-selectable (default violet `#7c5cff`) |
| Elevation | Borders over shadows; soft shadow only on popovers/modals |
| Icons | **Lucide** |
| Motion | Respect `prefers-reduced-motion` |

### 5.3 Key UI patterns (Notion/Obsidian-inspired)
- Collapsible sidebar with tree, drag-reorder, hover actions (`…`, `+`)
- Page header: icon/emoji + cover image (optional) + title inline-editable
- Block editor with slash menu, floating bubble toolbar on selection, drag handles on blocks
- Popover-based property editing (due date picker, priority, tags) like Notion database props
- Split view (P2): note on left, backlinks/outline on right
- Toasts with **Undo** for destructive actions
- Empty states with illustration + single primary action
- Locked journal: blurred card with lock icon and passphrase field

### 5.4 Accessibility
WCAG AA contrast in both themes, focus rings visible, all interactive components from an accessible headless library (Reka UI), ARIA on custom widgets.

---

## 6. Technical Architecture

### 6.1 Stack decisions
| Layer | Choice | Why |
|---|---|---|
| Backend | **Rails 8.1** (Ruby 3.4) | Learning goal; Rails 8 ships auth generator, Solid Queue, Solid Cache, Thruster — no Redis needed. |
| API style | JSON REST under `/api/v1`, served by the same Rails app | Learn conventional REST controllers, strong params, serializers. |
| Serialization | **Alba** (fast, simple) or Jbuilder | Alba is lighter/faster; Jbuilder is Rails-default. |
| Frontend | **Vue 3** (Composition API, `<script setup>`) + **TypeScript** | |
| Build | **Vite** via `vite_rails` gem | Single repo, HMR in dev, assets precompiled into Rails `public/` in prod → **no Node in the runtime image**. |
| State | **Pinia** + **TanStack Query (vue-query)** for server cache | Clean separation of server vs UI state, optimistic updates. |
| Routing | Vue Router (SPA); Rails catch-all route serves the SPA shell | |
| UI kit | **Tailwind CSS v4** + **shadcn-vue** (built on Reka UI) | Notion-like modern look, accessible, you own the components. |
| Editor | **TipTap 2/3** (ProseMirror) | Notion-style blocks, slash menu, extensible (wiki-links, flashcards). |
| Charts | **Apache ECharts** (tree-shaken via `vue-echarts`) | Heatmaps, calendars, themes built-in. |
| Drag & drop | `vue-draggable-plus` (SortableJS) | Kanban, sidebar tree. |
| Dates | `date-fns` + `chrono-node` (NL date parsing for quick-add) | |
| Client crypto | **Web Crypto API** (AES-GCM) + **hash-wasm** (Argon2id) | Native, audited primitives. |
| DB | **PostgreSQL 17** | FTS, `jsonb`, `pg_trgm`, window functions, `generate_series`. |
| Jobs | **Solid Queue** (Postgres-backed), running inside Puma | No Redis, no extra container. |
| Cache | **Solid Cache** (Postgres-backed) | Analytics query caching. |
| Files | **Active Storage** (Disk service) + **libvips** via `image_processing` | vips is ~10× faster and far smaller than ImageMagick. |
| Web server | **Puma** behind **Thruster** (Rails 8 default) | Gzip/brotli, asset caching, X-Sendfile — no Nginx needed. |
| Tests | Minitest (Rails default) + Vitest + Playwright (E2E) | |
| Lint | RuboCop (rails-omakase), ESLint, Prettier, Brakeman (security) | |

### 6.2 High-level diagram
```
 Browser (Vue SPA)
 ┌───────────────────────────────────────────────┐
 │ Vue Router · Pinia · vue-query · TipTap       │
 │ ┌───────────────────────────┐                 │
 │ │ CryptoService (Web Crypto)│◄── journal key  │
 │ │ encrypt/decrypt in memory │    lives ONLY   │
 │ └───────────────────────────┘    in memory    │
 └──────────────┬────────────────────────────────┘
                │ HTTPS-less localhost JSON (journal = ciphertext only)
 ┌──────────────▼────────────────────────────────┐
 │ Thruster → Puma → Rails 8.1                    │
 │  /api/v1/* controllers · Solid Queue (in-Puma)│
 │  Active Storage (Disk) · libvips              │
 └──────┬──────────────────────────┬─────────────┘
        │                          │
 ┌──────▼───────┐          ┌───────▼────────┐
 │ PostgreSQL 17│          │ /rails/storage │
 │ (volume)     │          │ (volume)       │
 └──────────────┘          └────────────────┘
```

### 6.3 Repository layout
```
journal/
├── app/
│   ├── controllers/api/v1/   # tasks_controller.rb, notes_controller.rb, ...
│   ├── models/               # task.rb, note.rb, journal_entry.rb ...
│   ├── queries/              # analytics SQL objects (TaskCompletionQuery)
│   ├── serializers/          # Alba resources
│   ├── jobs/                 # RecurringTaskJob, AnalyticsRefreshJob, PurgeTrashJob
│   └── frontend/             # ← Vue app (vite_rails source dir)
│       ├── entrypoints/application.ts
│       ├── components/ui/    # shadcn-vue components
│       ├── features/         # journal/, tasks/, tracker/, learn/, analytics/
│       ├── lib/crypto/       # vault.ts, argon2.ts, aes.ts
│       ├── stores/  router/  api/
├── db/migrate/  db/views/    # SQL views (scenic gem, optional)
├── docker/                   # entrypoint, pg init
├── Dockerfile  compose.yml  compose.dev.yml  .dockerignore
└── docs/PRD.md
```

---

## 7. Journal Encryption Design (Zero-Knowledge)

### 7.1 Threat model
| Threat | Protected? |
|---|---|
| Someone copies the Postgres data dir / a `pg_dump` / a backup | ✅ Only ciphertext |
| Someone reads Rails logs, Solid Queue tables, cache, Active Storage files | ✅ Only ciphertext ever reaches the server |
| Someone has your app **login** password | ✅ Journal needs a separate passphrase |
| Server-side code bug / malicious gem on the server | ✅ Server never has the key |
| Someone with access to your **unlocked** browser session | ❌ Mitigated by auto-lock |
| Malware/keylogger on your machine | ❌ Out of scope |
| You forget passphrase AND lose recovery key | ❌ Data is unrecoverable (by design) |

> **Why not Rails' built-in `encrypts` (Active Record Encryption)?** It's excellent, but the key lives on the server (credentials/env), so anyone with the server's disk has both data and key, and plaintext exists in Ruby memory/logs. We use it as a **learning exercise for a different field** (e.g. TOTP secret), not for the journal.

### 7.2 Key hierarchy (envelope encryption)
```
Journal passphrase ──Argon2id(salt, m=64MiB, t=3, p=1)──► KEK (256-bit, never stored)
                                                            │ AES-256-GCM wrap
Random DEK (256-bit, generated once) ◄──────────────────────┘
   │  stored on server ONLY as: wrapped_dek_by_passphrase, wrapped_dek_by_recovery_key
   ▼
Each entry: AES-256-GCM(DEK, random 96-bit IV, plaintext JSON, AAD = entry_id‖version)
```
- **DEK** encrypts all entries; **KEK** only wraps the DEK. Changing passphrase = re-wrap DEK (instant), no entry re-encryption.
- **Recovery key**: 128-bit random, shown once as a 24-word / base32 string; derives a second KEK that also wraps the DEK.
- **AAD** binds ciphertext to its row id, so ciphertexts can't be swapped between entries undetected.
- Argon2id params stored in `journal_vaults.kdf_params` (jsonb) so they can be raised later.

### 7.3 Flows
**Setup:** browser generates salt + DEK + recovery key → derives KEK → wraps DEK twice → `POST /api/v1/journal/vault` with `{salt, kdf_params, wrapped_dek, wrapped_dek_recovery, verifier}`. The passphrase never leaves the browser.

**Unlock:** `GET /vault` → derive KEK from passphrase → unwrap DEK (GCM auth failure = wrong passphrase) → import DEK as **non-extractable** `CryptoKey` held in a module-scoped variable (not Pinia devtools-visible, not localStorage/sessionStorage/IndexedDB).

**Write:** editor content `{title, doc(TipTap JSON), mood, tags, prompt, word_count}` → `JSON.stringify` → AES-GCM encrypt → `PUT /entries/:id {ciphertext, iv, version}`.

**Lock:** drop `CryptoKey` reference, clear decrypted entries from stores, clear editor, clear MiniSearch index, navigate to lock screen.

### 7.4 What the server stores (unencrypted metadata)
Only: `id`, `entry_date`, `created_at`, `updated_at`, `version`, `ciphertext byte length`. **Titles, mood, tags, word count are all encrypted.** (Trade-off accepted: entry dates are visible — needed for calendar/streaks without unlocking.)

### 7.5 Hardening checklist
- `config.filter_parameters += [:ciphertext, :wrapped_dek, :passphrase, ...]`
- Journal endpoints excluded from any request-body logging
- No draft caching in `localStorage`; autosave sends ciphertext only
- Strict **Content-Security-Policy** (no inline scripts, `connect-src 'self'`) to reduce XSS risk — XSS is the main way a key could be stolen
- Web Crypto requires a secure context — `http://localhost` qualifies; LAN access therefore **must** use HTTPS (Caddy + mkcert, §10.7); plain-HTTP LAN access is refused
- Journal images: encrypted in browser, uploaded as opaque blobs, decrypted to `blob:` URLs, revoked on lock
- Unit tests verifying round-trip, wrong-passphrase failure, tamper detection; **integration test greps the DB dump and log files for a known plaintext canary** (must find nothing)

---

## 8. Data Model (PostgreSQL)

Conventions: `bigint` identity PKs (Rails default) · `timestamptz` everywhere · soft delete via `discarded_at` (Discard gem) on user content · DB-level constraints (`NOT NULL`, `CHECK`, FKs) not just model validations.

### 8.1 Core
```sql
users            (id, email_address citext UNIQUE, password_digest, timezone, settings jsonb, created_at, updated_at)
sessions         (id, user_id FK, ip_address, user_agent, created_at)   -- Rails 8 auth generator
tags             (id, name citext UNIQUE, color, created_at)
taggings         (id, tag_id FK, taggable_type, taggable_id, UNIQUE(tag_id, taggable_type, taggable_id))
```

### 8.2 Journal (encrypted)
```sql
journal_vaults   (id, user_id FK UNIQUE, kdf_algo text, kdf_params jsonb, salt bytea,
                  wrapped_dek bytea, wrapped_dek_iv bytea,
                  recovery_salt bytea, wrapped_dek_recovery bytea, wrapped_dek_recovery_iv bytea,
                  created_at, updated_at)
journal_entries  (id, user_id FK, entry_date date NOT NULL, ciphertext bytea NOT NULL,
                  iv bytea NOT NULL CHECK (octet_length(iv) = 12),
                  version int NOT NULL DEFAULT 1, created_at, updated_at, discarded_at)
  INDEX (user_id, entry_date)
journal_attachments (id, journal_entry_id FK, blob via Active Storage, iv bytea)  -- encrypted bytes
```

### 8.3 Tasks
```sql
projects    (id, name, color, icon, position int, archived_at, created_at, updated_at)
sections    (id, project_id FK, name, position)
tasks       (id, project_id FK NULL, section_id FK NULL, parent_id FK tasks NULL,
             title text NOT NULL, description jsonb,           -- TipTap JSON
             status text NOT NULL DEFAULT 'todo' CHECK (status IN ('todo','in_progress','done','cancelled')),
             priority smallint NOT NULL DEFAULT 0 CHECK (priority BETWEEN 0 AND 4),
             due_at timestamptz, due_date date, estimate_minutes int,
             recurrence_rule text,                             -- RFC 5545 RRULE
             completed_at timestamptz, position numeric,       -- fractional ordering
             search_vector tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(title,''))) STORED,
             created_at, updated_at, discarded_at)
  INDEX (status, due_date) WHERE discarded_at IS NULL          -- partial index
  INDEX USING gin (search_vector)
  CHECK (status <> 'done' OR completed_at IS NOT NULL)
task_events (id, task_id FK, event text, from_status, to_status, occurred_at timestamptz)  -- append-only
focus_sessions (id, task_id FK NULL, started_at, ended_at, duration_seconds)               -- P2
```

### 8.4 Tracker
```sql
trackers       (id, name, icon, color, kind text CHECK (kind IN ('boolean','count','duration','numeric','scale')),
                unit text, target numeric, frequency jsonb,   -- {"type":"weekly","times":3} / {"days":[1,3,5]}
                position, archived_at, created_at, updated_at)
tracker_entries(id, tracker_id FK, logged_on date NOT NULL, value numeric NOT NULL, note text,
                created_at, updated_at, UNIQUE (tracker_id, logged_on))
```

### 8.5 Learn
```sql
folders     (id, parent_id FK folders NULL, name, position, created_at, updated_at)   -- tree via recursive CTE
notes       (id, folder_id FK NULL, topic_id FK NULL, title text NOT NULL, icon, cover_image,
             content jsonb NOT NULL DEFAULT '{}',          -- TipTap JSON (source of truth)
             content_text text,                             -- plain text extracted on save (search)
             search_vector tsvector GENERATED ALWAYS AS (
                setweight(to_tsvector('english', coalesce(title,'')), 'A') ||
                setweight(to_tsvector('english', coalesce(content_text,'')), 'B')) STORED,
             pinned boolean DEFAULT false, created_at, updated_at, discarded_at)
  INDEX USING gin (search_vector), INDEX USING gin (title gin_trgm_ops)
note_links  (id, source_note_id FK, target_note_id FK NULL, target_title text, UNIQUE(source, target_title))
topics      (id, name, color, description, created_at)
resources   (id, topic_id FK, title, url, kind text, status text, progress smallint CHECK (progress BETWEEN 0 AND 100),
             rating smallint, started_on, finished_on, created_at, updated_at)
study_sessions (id, topic_id FK, resource_id FK NULL, started_at, duration_minutes int, notes text)
flashcards  (id, note_id FK NULL, topic_id FK NULL, front text, back text,
             ease numeric DEFAULT 2.5, interval_days int DEFAULT 0, repetitions int DEFAULT 0,
             due_on date NOT NULL DEFAULT current_date, created_at, updated_at)
flashcard_reviews (id, flashcard_id FK, grade smallint CHECK (grade BETWEEN 0 AND 5), reviewed_at)
note_versions (id, note_id FK, content jsonb, created_at)   -- P2
```

### 8.6 Media
Active Storage tables (`active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`). Notes/tasks reference images by blob signed id inside TipTap JSON; a `MediaReferenceSync` callback records usage for orphan cleanup.

### 8.7 Analytics (SQL views)
```sql
-- daily_task_stats: one row per day even with zero completions
CREATE VIEW daily_task_stats AS
SELECT d::date AS day,
       count(t.id) FILTER (WHERE t.completed_at::date = d) AS completed,
       count(t.id) FILTER (WHERE t.created_at::date  = d) AS created
FROM generate_series(current_date - 365, current_date, interval '1 day') d
LEFT JOIN tasks t ON t.completed_at::date = d OR t.created_at::date = d
GROUP BY d;
```
Plus a **materialized view** `habit_streaks` (gaps-and-islands with window functions) refreshed by `AnalyticsRefreshJob` on tracker changes. *(Timezone: all day-bucketing uses `AT TIME ZONE users.timezone`.)*

---

## 9. API Design (selected)

All under `/api/v1`, JSON, CSRF token required (Rails `protect_from_forgery` with header token read by the SPA), session cookie auth.

| Method | Path | Notes |
|---|---|---|
| POST | `/session` · DELETE `/session` | login / logout |
| GET/POST/PATCH | `/journal/vault` | vault metadata (salt, wrapped keys) |
| GET | `/journal/entries?from=&to=` | returns ciphertext + dates |
| POST/PUT/DELETE | `/journal/entries/:id` | body: `{entry_date, ciphertext(base64), iv, version}`; optimistic locking on `version` |
| GET/POST/PATCH/DELETE | `/tasks`, `/tasks/:id` | filters: `view=today|upcoming|inbox`, `project_id`, `tag`, `status` |
| POST | `/tasks/:id/complete` · `/tasks/:id/reopen` | member routes; emit `task_events` |
| PATCH | `/tasks/reorder` | bulk positions |
| CRUD | `/projects`, `/sections` | |
| CRUD | `/trackers`, PUT `/trackers/:id/entries/:date` | idempotent upsert per day |
| CRUD | `/folders`, `/notes`; GET `/notes/:id/backlinks` | |
| CRUD | `/topics`, `/resources`, `/study_sessions` | |
| GET | `/flashcards/due` · POST `/flashcards/:id/review` | SM-2 scheduling server-side |
| POST | `/uploads` (Active Storage direct upload) | |
| GET | `/search?q=` | unified results; journal excluded |
| GET | `/analytics/tasks?range=30d`, `/analytics/tracker`, `/analytics/learning`, `/analytics/overview` | cached via Solid Cache, busted on writes |
| GET | `/today` | aggregated home payload (one request) |

Errors: `{ error: { code, message, details } }`, proper status codes (422 validation, 409 version conflict, 401, 404).
Pagination: cursor-based (`?after=`), using `pagy` keyset.

---

## 10. Docker & Deployment (Local)

### 10.1 Requirements
| ID | Requirement |
|---|---|
| DKR-1 | `docker compose up -d` starts everything; first run auto-runs `db:prepare`. |
| DKR-2 | **Production app image ≤ 300 MB** (measured 293 MB in Phase 0; the `ruby:3.4-slim` base alone is 184 MB, gems ~85 MB); **no Node, no compilers, no dev/test gems** in final image. Enforced in CI. |
| DKR-3 | Only 2 containers in prod (`app`, `db`). (Future: a 3rd, `caddy`, only with the `lan` profile — §10.7.) Jobs run inside Puma (`SOLID_QUEUE_IN_PUMA=true`); cache/queue in same Postgres. |
| DKR-4 | Default: ports published to **`127.0.0.1` only**. With `lan` profile: only Caddy publishes `0.0.0.0:443` (+ `80` → redirect); `app` stays on 127.0.0.1. Postgres never published in prod. |
| DKR-5 | Named volumes: `pg_data`, `storage` (uploads). |
| DKR-6 | Healthchecks on both services; `app` waits for `db` healthy. |
| DKR-7 | Runs as non-root user (uid 1000). Read-only root filesystem where possible (`tmp`/`log` as tmpfs). |
| DKR-8 | Separate `compose.dev.yml` with Vite dev server + bind mounts + HMR. |
| DKR-9 | Memory limits: app 512 MB, db 256 MB (tunable). |
| DKR-10 | Multi-arch build (arm64 for Apple Silicon, amd64). |
| DKR-11 | *(Deferred)* `lan` profile uses `caddy:2-alpine` (~50 MB); certs from mkcert mounted read-only. |

### 10.2 Image-size strategy
| Technique | Saving |
|---|---|
| Multi-stage build: `frontend` (Node, Vite) · `vips` (compile libvips) · `build` (gems) → `final` (runtime only) | Drops Node (~150 MB), build-essential (~250 MB) |
| `ruby:3.4-slim` base (Debian) — **not** full `ruby:3.4` | ~800 MB → ~200 MB base |
| **libvips compiled from source** with only JPEG/PNG/WebP/GIF/HEIC/AVIF codecs — Debian's `libvips` package pulls ImageMagick, Poppler, GnuPG, HDF5, OpenEXR… | runtime libs 121 MB → 18 MB |
| Bootsnap precompiles `app/` + `lib/` only (not every gem) | −44 MB |
| No `curl`/`postgresql-client` (healthcheck uses Ruby's `net/http`; `pg` gem bundles libpq) | ~10 MB |
| `BUNDLE_WITHOUT="development:test"`, `BUNDLE_DEPLOYMENT=1` | |
| Remove gem caches & build artifacts: `rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git` | 20–60 MB |
| `bootsnap precompile` at build time | faster boot |
| `jemalloc` (`libjemalloc2`, `LD_PRELOAD`) | ~30–40% less Ruby RAM |
| `.dockerignore`: `node_modules`, `log`, `tmp`, `storage`, `.git`, `app/frontend` (after build), tests | smaller context, faster builds |
| BuildKit cache mounts for `apt`, `bundle`, `npm` | faster rebuilds |
| `postgres:17-alpine` for DB (~100 MB vs ~430 MB debian) | ~330 MB |
| Vite: tree-shaking, code-splitting per route, ECharts modular import, brotli precompressed | small JS payload |

> *Why slim (Debian) rather than Alpine for Ruby?* musl-libc causes native-gem headaches (pg, nokogiri) and sometimes slower Ruby; slim is the Rails 8 default and the size difference after multi-stage is small. Alpine is used for Postgres where it's well-supported.

### 10.3 Dockerfile (original sketch — see the real `Dockerfile` in the repo root)
```dockerfile
# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.7
FROM ruby:${RUBY_VERSION}-slim AS base
WORKDIR /rails
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update -qq && apt-get install --no-install-recommends -y \
      curl libjemalloc2 libvips42 postgresql-client && rm -rf /var/lib/apt/lists/*
ENV RAILS_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development:test" LD_PRELOAD=libjemalloc.so.2

FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
      build-essential git libpq-dev libyaml-dev pkg-config nodejs npm
COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache \
    && bundle exec bootsnap precompile --gemfile
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN bundle exec bootsnap precompile app/ lib/ \
 && SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile \
 && rm -rf node_modules app/frontend tmp/cache

FROM base
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
RUN groupadd --system --gid 1000 rails && useradd rails --uid 1000 --gid 1000 --create-home \
 && chown -R rails:rails db log storage tmp
USER 1000:1000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
```

### 10.4 compose.yml (reference sketch)
```yaml
services:
  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: lumen
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
      POSTGRES_DB: lumen_production
    volumes: [pg_data:/var/lib/postgresql/data]
    secrets: [db_password]
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U lumen"], interval: 5s, retries: 10 }
    command: ["postgres", "-c", "shared_buffers=64MB", "-c", "max_connections=30"]
    mem_limit: 256m
    restart: unless-stopped

  app:
    build: .
    image: lumen:latest
    ports: ["127.0.0.1:3000:80"]
    environment:
      DATABASE_URL: postgres://lumen@db/lumen_production
      SOLID_QUEUE_IN_PUMA: "true"
      WEB_CONCURRENCY: "0"        # single Puma process (threads only) — lowest RAM
      RAILS_MAX_THREADS: "5"
    env_file: .env                # RAILS_MASTER_KEY
    volumes: [storage:/rails/storage]
    depends_on: { db: { condition: service_healthy } }
    healthcheck: { test: ["CMD", "curl", "-fs", "http://localhost/up"], interval: 10s }
    read_only: true
    tmpfs: [/rails/tmp, /rails/log]
    mem_limit: 512m
    restart: unless-stopped

  caddy:                          # DEFERRED (§10.7) — only with: docker compose --profile lan up -d
    image: caddy:2-alpine
    profiles: [lan]
    ports: ["443:443", "80:80"]
    volumes:
      - ./docker/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./docker/certs:/certs:ro     # generated by mkcert (§10.7)
      - caddy_data:/data
    depends_on: [app]
    mem_limit: 64m
    restart: unless-stopped

volumes: { pg_data: {}, storage: {}, caddy_data: {} }
secrets: { db_password: { file: ./docker/secrets/db_password.txt } }
```

### 10.5 Developer experience
- `bin/dev` (host) **or** `docker compose -f compose.dev.yml up` (Rails + Vite + Postgres in containers, source bind-mounted, HMR on `localhost:3036`)
- `bin/setup` seeds sample data (projects, notes, trackers) for UI development
- Makefile shortcuts: `make up`, `make console`, `make psql`, `make backup`, `make test`

### 10.6 Backups
- `make backup` → `pg_dump -Fc` + tar of `storage` volume → `backups/lumen-YYYYMMDD.tar.zst`
- Optional daily backup via Solid Queue recurring job (`config/recurring.yml`) to a mounted host folder; keep last 14
- Journal data inside backups is already ciphertext; optionally encrypt whole archive with `age`
- `make restore FILE=...` documented and **tested** (restore drill in CI)

### 10.7 LAN / phone access (HTTPS) — *deferred, design kept for later*
Web Crypto (needed for the journal) only works in a **secure context**: `http://localhost` qualifies, but `http://192.168.x.x` does not — so phone access requires real HTTPS.

**Setup (one-time, `make lan-setup`):**
1. `brew install mkcert && mkcert -install` — creates a local root CA trusted by your Mac.
2. `mkcert -cert-file docker/certs/lumen.pem -key-file docker/certs/lumen-key.pem lumen.local "$(scutil --get LocalHostName).local" <LAN-IP> localhost`
3. Install the mkcert root CA (`mkcert -CAROOT` → `rootCA.pem`) on the phone: iOS → install profile, then *Settings → General → About → Certificate Trust Settings* → enable; Android → *Install CA certificate*. **Never share `rootCA-key.pem`.**
4. `docker compose --profile lan up -d` → open `https://<your-mac>.local` on the phone.

**Caddyfile**
```caddy
{ auto_https off }
:443 {
  tls /certs/lumen.pem /certs/lumen-key.pem
  encode zstd gzip
  reverse_proxy app:80
  header Strict-Transport-Security "max-age=31536000"
}
:80 { redir https://{host}{uri} permanent }
```

**Rails changes when `LAN_MODE=true`:** `config.assume_ssl = true`, `config.force_ssl = true`, `config.hosts << /.*\.local/ << ENV["LAN_IP"]`, session cookie `secure: true`, trusted proxy = Caddy container.

**Extra security on LAN:** login rate-limit stays on; optional IP allow-list for the home subnet; journal auto-lock default drops to 5 min on mobile; "Sign out other sessions" in Settings; sessions table shows device/IP.

**Out of scope:** access from outside the home network (use Tailscale yourself if ever needed — no port forwarding).

---

## 11. Non-Functional Requirements

| Category | Requirement |
|---|---|
| Performance | p95 API < 100 ms for CRUD, < 300 ms for analytics (cached < 50 ms); initial JS ≤ 250 KB gzip; route chunks lazy-loaded; Lighthouse perf ≥ 90 |
| Journal crypto | Unlock (Argon2id) 0.5–1.5 s on M-series Mac; encrypt/decrypt per entry < 5 ms |
| Scale (single user) | Smooth with 10k notes, 50k tasks, 5k journal entries, 10 GB media |
| Resource use | Idle RAM ≤ 400 MB combined; cold start ≤ 10 s |
| Reliability | No data loss on container restart; autosave; optimistic locking prevents overwrite across tabs |
| Security | CSP, CSRF, Brakeman clean, `bundle audit` & `npm audit` in CI, upload type sniffing, EXIF stripping, rate-limited login |
| Privacy | No external network calls at runtime (self-hosted fonts, no analytics/telemetry, no CDN) |
| Portability | Data exportable to Markdown/JSON/CSV at any time — no lock-in |
| Maintainability | ≥ 80% model/service test coverage; typed frontend; conventional Rails structure |

---

## 12. Milestones & Roadmap

Each phase is shippable and maps to learning goals (§13).

| Phase | Duration (est.) | Scope | Exit criteria |
|---|---|---|---|
| **0 — Foundation** ✅ | 1 wk | `rails new --database=postgresql`, vite_rails + Vue + TS + Tailwind + shadcn-vue, Rails 8 auth, app shell (sidebar, theme, ⌘K stub), Dockerfile + compose, CI (lint/test) | Login → empty shell in Docker; image ≤ 300 MB (actual: 293 MB, 202 MB RAM app + 60 MB db) |
| **1 — Tasks MVP** | 2 wks | Projects, tasks, subtasks, Today/Inbox/Upcoming, list view, task_events, tags | Daily-drivable todo app |
| **2 — Learn MVP** | 2–3 wks | TipTap editor, folders tree, notes, image upload/paste, wiki-links, backlinks, FTS search | Write and link notes with images |
| **3 — Tracker** | 1 wk | Trackers, check-ins, streaks, heatmaps, Today integration | Habits tracked from Today page |
| **4 — Encrypted Journal** | 2 wks | Vault setup/unlock/lock, Argon2id + AES-GCM, entries, calendar, mood, recovery key, canary leak test | Zero plaintext verified |
| **5 — Analytics v1** | 1–2 wks | SQL views, analytics endpoints, ECharts dashboard, Today stats | Task + tracker dashboards live |
| **6 — v1.0 polish** | 2–3 wks | Kanban, recurring tasks, NL quick-add, resources, study sessions, flashcards (SM-2), Mood tracker + mirroring, weekly review, trash, backups, export | Feature-complete v1 |
| **7 — Later (P2)** | — | Graph view, journal images, calendar view, focus timer, correlations, note history, **mobile layout + LAN HTTPS (§10.7)**, PWA | |

---

## 13. Learning Map — Rails & Postgres concepts per feature

| Feature | Rails concepts | Postgres concepts |
|---|---|---|
| Auth | Rails 8 auth generator, `has_secure_password`, `Current` attributes, `before_action`, `rate_limit` | `citext` extension, unique indexes |
| Tasks | Models/associations, validations, enums, scopes, strong params, REST + member routes, callbacks vs service objects, Alba serializers | `CHECK` constraints, partial indexes, FK `ON DELETE`, fractional ordering, transactions |
| Task events | `after_commit`, concerns (`Trackable`) | Append-only tables, `timestamptz`, indexing time-series |
| Recurring tasks | Active Job + Solid Queue, `config/recurring.yml` | `SELECT ... FOR UPDATE SKIP LOCKED` (how Solid Queue works) |
| Notes & folders | Self-referential associations, polymorphic taggings, `jsonb` attributes | `jsonb` operators & GIN, **recursive CTEs** for folder trees |
| Search | Query objects, `pg_search` (or hand-written) | `tsvector`, generated columns, `setweight`, `ts_rank`, `pg_trgm` similarity |
| Wiki-links | Callbacks parsing content, `upsert_all` | `INSERT ... ON CONFLICT`, anti-joins for orphans |
| Images | Active Storage, direct uploads, variants, validations | Blob metadata tables |
| Tracker | Upserts, date handling & time zones | `UNIQUE (tracker_id, logged_on)`, **gaps-and-islands** streaks |
| Journal | API design for opaque data, optimistic locking (`lock_version`), `filter_parameters`, Active Record Encryption (for TOTP secret) | `bytea`, `octet_length` checks |
| Analytics | Query objects, `find_by_sql`, caching (Solid Cache, `Rails.cache.fetch`), cache keys | `generate_series`, `date_trunc`, `FILTER`, **window functions** (moving avg, `LAG`, `ROW_NUMBER`), views, **materialized views**, `EXPLAIN ANALYZE` |
| Flashcards | Plain Ruby service (SM-2), unit testing | Date arithmetic, indexes on `due_on` |
| Trash | `discard` gem, default scopes pitfalls | Partial indexes `WHERE discarded_at IS NULL` |
| Docker | Production config, credentials, `bin/docker-entrypoint`, Thruster | `pg_dump`/`pg_restore`, tuning `shared_buffers`, connection limits |
| Testing | Minitest, fixtures, system tests, request tests | Transactional tests, `db:schema` vs `structure.sql` (use `structure.sql` for views/generated columns) |

---

## 14. Testing Strategy
- **Models/services (Minitest):** validations, constraints, SM-2 math, streak calc, recurrence.
- **Request tests:** every API endpoint incl. auth & 4xx paths.
- **Frontend (Vitest):** crypto module (round-trip, wrong key, tamper, IV uniqueness), NL quick-add parser, stores.
- **E2E (Playwright):** login → create task → complete → see in analytics; journal setup → write → lock → unlock; image paste.
- **Security tests:** plaintext-canary leak test (§7.5), Brakeman, CSP header assertions.
- **Docker:** CI builds image and asserts size ≤ 300 MB; compose healthcheck hits `/up`.

---

## 15. Risks & Mitigations
| Risk | Impact | Mitigation |
|---|---|---|
| Forgotten journal passphrase | Permanent loss | Recovery key at setup with forced "I've saved it" confirmation; periodic reminder; encrypted export |
| XSS steals in-memory key | Journal compromise | Strict CSP, sanitize editor HTML, no `v-html` on user content, dependency audits |
| Scope creep (4 apps in one) | Never finishes | Strict phase gates; P0 only until Phase 5 |
| TipTap/editor complexity | Slow progress | Start with StarterKit; add custom extensions (wiki-link, flashcard) incrementally |
| Time-zone bugs in streaks/analytics | Wrong stats | Store `timestamptz`; bucket by user TZ in SQL; tests around DST/midnight |
| Image volume growth | Disk use | WebP variants, orphan cleanup job, media library with sizes |
| Docker data loss | Catastrophic | Named volumes, documented backup/restore, restore drill |

---

## 16. Decisions Log
| # | Question | Decision | Where applied |
|---|---|---|---|
| D1 | App name | **Lumen** | Title, Docker names |
| D2 | Task titles in weekly review? | Yes — tasks stay **unencrypted**; review shows task titles; only the written reflection is encrypted | §4.8 |
| D3 | LAN / phone access | **Deferred to later (Phase 7)**. Design kept in §10.7 (Caddy + mkcert, opt-in `lan` profile) | GLB-8/9, §10.7, Phase 7 |
| D4 | Source of truth for notes | **TipTap JSON in Postgres `jsonb`** + Markdown import/export | §4.5, §8.5 |
| D5 | Mood unencrypted in Tracker? | Yes — **per-user opt-in** mirroring from journal to a built-in Mood tracker, clearly labelled unencrypted | JRN-5, TRK-9, §4.8 |

### Revisit later
- D3 details (when LAN access is picked up): `.local` mDNS vs fixed LAN IP; journal unlock allowed on all devices vs per-device opt-in.

---

## 17. Glossary
- **DEK / KEK** — Data Encryption Key / Key Encryption Key (envelope encryption).
- **Argon2id** — memory-hard password hashing/KDF, resistant to GPU cracking.
- **AES-GCM** — authenticated encryption: confidentiality + tamper detection.
- **SM-2** — SuperMemo-2 spaced-repetition scheduling algorithm.
- **Gaps-and-islands** — SQL technique to find consecutive runs (streaks).
- **Solid Queue / Solid Cache** — Rails 8's database-backed job queue and cache.
