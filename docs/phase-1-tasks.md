# Phase 1 — Tasks MVP: Backend Requirements

**Status:** ✅ implemented: backend (`app/models/task.rb`, `app/queries/tasks_query.rb`, `app/controllers/api/v1/*`) and UI (`app/frontend/features/tasks/`).
**Goal:** a todo app you can use every day: projects, sections, tasks, subtasks, tags, plus the Today / Inbox / Upcoming / Completed views, all backed by an append-only `task_events` log that Phase 5 analytics will read.

This document is the **contract between the backend and the UI**. The UI will be built against the exact request and response shapes below. If you change a shape, update this file so the two stay in sync.

PRD references: §4.3 (TSK-1–5, 9, 12), §8.1 (tags), §8.3 (tasks), §9 (API), §13 (learning map).

---

## 1. Scope

### In scope (Phase 1)
| ID | What |
|---|---|
| TSK-1 | Task CRUD: title, description (JSON), due date and optional time, priority, status, tags, estimate |
| TSK-2 | Projects (name, color, icon, archive) and sections inside projects. **Inbox** means tasks with no project. |
| TSK-3 | Subtasks, one level deep |
| TSK-4 | Views: Today, Upcoming (7 days), Inbox, Project, Completed log |
| TSK-5 | List layout only. Ordering by drag and drop is supported through `position`. |
| TSK-9 | Overdue flag. Snoozing is just a `PATCH` to `due_date`, so it needs no extra endpoint. |
| TSK-12 | Every create and status change is written to `task_events` |
| GLB-4 | Shared `tags` and `taggings` tables (polymorphic, so notes and resources can reuse them later) |
| — | Sidebar counts endpoint (badges) |
| — | Simple title search `?q=` (Postgres full-text search) |

### Out of scope (later phases, so don't build these yet)
Kanban (Phase 6), recurring tasks (6), natural-language quick-add (6), bulk actions (6), calendar view (7), trash UI and restore (6; we only soft-delete now), linking tasks to notes (6), focus timer (7), analytics endpoints (5).

---

## 2. Global conventions

These already exist from Phase 0. Keep using them.

- **Base class:** every controller goes under `Api::V1` and inherits from `Api::V1::BaseController`. Authentication is required by default through the `Authentication` concern.
- **Errors:** use the existing `render_error` and `render_validation_errors` helpers. Every error has this shape:
  ```json
  { "error": { "code": "validation_failed", "message": "Title can't be blank", "details": { "title": ["can't be blank"] } } }
  ```

  | Status | When | `code` |
  |---|---|---|
  | 401 | not signed in | `unauthenticated` (already handled) |
  | 404 | record not found, or already discarded | `not_found` (already handled) |
  | 422 | validation failure | `validation_failed` |
  | 422 | bad param value (unknown `view`, malformed date) | `invalid_parameter` |
  | 409 | business-rule conflict (see each endpoint) | specific code |
- **Serializers:** Alba resources go in `app/resources/`, for example `TaskResource`. **JSON keys are snake_case.**
- **Timestamps** are ISO 8601 with offset (`"2026-10-30T18:00:00+05:30"`). **Dates** look like `"2026-10-30"`.
- **Time zone:** all "today", "overdue" and "this week" logic uses **`Current.user.time_zone`**, never server UTC. Add an `around_action` in `BaseController` that wraps each request in `Time.use_zone(Current.user.time_zone)`, skipping it when no user is signed in. After that, `Date.current` and `Time.zone.now` are correct everywhere.
- **Single user:** the domain tables have **no `user_id`**, because the app enforces exactly one user. This matches PRD §8.
- **Soft delete:** user content uses `discarded_at`. You can use the [`discard`](https://github.com/jhawthorn/discard) gem or write `scope :kept` and a `discard!` method yourself. Discarded rows never appear in any response, and `find` on one returns 404.
- **Strong params** everywhere. Unknown keys are ignored.
- **Status codes:**
  - `POST` create → **201** with the resource
  - `PATCH` → **200** with the resource
  - `DELETE` → **204**
  - action endpoints (`complete`, `reopen`, `reorder`) → **200**

---

## 3. Database schema

Write these as migrations. **Put the rules in the database** (CHECK constraints, foreign keys, NOT NULL), not only in model validations. `schema.rb` can represent check constraints and stored generated columns (`t.virtual ..., stored: true`), so you don't need `structure.sql` yet.

### 3.1 `tags`
| column | type | rules |
|---|---|---|
| id | bigint PK | |
| name | citext | NOT NULL, UNIQUE, CHECK `char_length(name) BETWEEN 1 AND 50` |
| color | string | nullable; one of the palette names in §3.6 |
| timestamps | | |

### 3.2 `taggings`
| column | type | rules |
|---|---|---|
| id | bigint PK | |
| tag_id | FK → tags | NOT NULL, **ON DELETE CASCADE** |
| taggable_type | string | NOT NULL |
| taggable_id | bigint | NOT NULL |
| created_at | | |

Add a UNIQUE index on `(tag_id, taggable_type, taggable_id)` and a regular index on `(taggable_type, taggable_id)`.

### 3.3 `projects`
| column | type | rules |
|---|---|---|
| id | bigint PK | |
| name | string | NOT NULL, CHECK `char_length(name) BETWEEN 1 AND 100` |
| color | string | NOT NULL, default `'violet'`, CHECK that it is in the palette |
| icon | string | nullable; a Lucide icon name such as `"book"` or `"briefcase"`; the UI sends kebab-case |
| position | numeric | NOT NULL |
| archived_at | timestamptz | nullable |
| timestamps | | |

### 3.4 `sections`
| column | type | rules |
|---|---|---|
| id | bigint PK | |
| project_id | FK → projects | NOT NULL, **ON DELETE CASCADE** |
| name | string | NOT NULL, 1–100 chars |
| position | numeric | NOT NULL |
| timestamps | | |

### 3.5 `tasks`
| column | type | rules |
|---|---|---|
| id | bigint PK | |
| project_id | FK → projects | nullable (null means Inbox), **ON DELETE SET NULL** |
| section_id | FK → sections | nullable, **ON DELETE SET NULL** (deleting a section moves its tasks to the project root) |
| parent_id | FK → tasks | nullable, **ON DELETE CASCADE** |
| title | text | NOT NULL, CHECK `char_length(btrim(title)) BETWEEN 1 AND 500` |
| description | jsonb | nullable (TipTap/ProseMirror document JSON) |
| status | `status_enum` (Postgres enum) | NOT NULL default `'todo'`: `todo`, `in_progress`, `done`, `cancelled` |
| priority | `priority_enum` (Postgres enum) | NOT NULL default `'none'`: `none`, `low`, `medium`, `high`, `urgent`. Enums sort in declaration order, so `ORDER BY priority DESC` puts urgent first. |
| due_date | date | nullable |
| due_at | timestamptz | nullable; set only when a time of day is chosen |
| estimate_minutes | integer | nullable, CHECK `> 0 AND <= 10080` |
| completed_at | timestamptz | nullable |
| position | numeric | NOT NULL |
| search_vector | tsvector | `GENERATED ALWAYS AS (to_tsvector('simple', coalesce(title,''))) STORED` |
| discarded_at | timestamptz | nullable |
| timestamps | | |

**Constraints**
- `CHECK ((status = 'done') = (completed_at IS NOT NULL))`. A task is done exactly when `completed_at` is set. This is stricter than the PRD, which only required the forward direction.
- `CHECK (due_at IS NULL OR due_date IS NOT NULL)`. A due time requires a due date.
- `CHECK (parent_id IS NULL OR parent_id <> id)`.

**Indexes**
- `(due_date) WHERE discarded_at IS NULL AND status IN ('todo','in_progress')`. This **partial index** serves the Today and Upcoming views.
- `(project_id, section_id, position) WHERE discarded_at IS NULL`
- `(parent_id)`
- `(completed_at DESC, id DESC) WHERE status = 'done' AND discarded_at IS NULL`, for the Completed log
- GIN index on `(search_vector)`

### 3.6 Color palette
```
gray, red, orange, amber, yellow, lime, green, teal, cyan, blue, indigo, violet, purple, pink
```
Keep these in one Ruby constant, for example `Palette::COLORS`, and reuse it in the CHECK constraint migration, the validations and `GET /api/v1/meta`. The UI maps each name to a Tailwind color.

### 3.7 `task_events` (append-only)
| column | type | rules |
|---|---|---|
| id | bigint PK | |
| task_id | FK → tasks | NOT NULL, **ON DELETE CASCADE** |
| event | `event_enum` | NOT NULL: `created`, `status_changed`, `rescheduled`, `discarded` |
| from_status | text | nullable |
| to_status | text | nullable |
| from_due_date | date | nullable |
| to_due_date | date | nullable |
| occurred_at | timestamptz | NOT NULL default `now()` |

Add an index on `(task_id, occurred_at)` and one on `(occurred_at)`. There is **no `updated_at`**: rows are never updated. The model should be read-only after create (`def readonly? = persisted?`).

---

## 4. Domain rules (models)

### Task
1. **Title:** strip whitespace. Blank → 422.
2. **Completing:** when `status` changes to `done`, set `completed_at = Time.current`. When it changes away from `done`, set `completed_at = nil`. Do this in the model, for example `before_save`, so every code path follows it.
3. **Due date and time:**
   - When the client sends `due_at`, derive `due_date = due_at.in_time_zone.to_date`.
   - Clearing `due_date` also clears `due_at`.
   - Sending only `due_date` keeps the task "all-day" (`due_at` null).
4. **Subtasks (one level):**
   - A task with a `parent_id` cannot itself be a parent. Validate this both ways: the parent must have no `parent_id`, and a task with children can't be given a `parent_id`.
   - A subtask **always inherits** its parent's `project_id` and `section_id`. Copy them on save and ignore client values.
   - When a parent moves to another project or section, its subtasks move with it.
   - A parent can be completed while subtasks are still open. Don't auto-complete or block; the UI will show "2/5 done".
5. **Section:** `section_id` must belong to the task's `project_id`, otherwise 422. Moving a task to another project, or to the Inbox, clears `section_id` unless a valid one is sent too.
6. **Archived project:** you cannot create a task in an archived project (422). Existing tasks stay.
7. **Position:**
   - New tasks go to the **end** of their container: `max(position) + 1` among siblings, where siblings share the same `(project_id, section_id, parent_id)`.
   - Reordering sends explicit positions (§5.4). Positions are `numeric`, so the UI can send midpoints like `1.5`.
8. **Events:** write them in `after_create` / `after_save`, i.e. **inside the same transaction** as the change, so a rolled-back save never leaves a phantom event:
   - create → `created` with `to_status`
   - status change → `status_changed` with from/to
   - `due_date` change → `rescheduled` with from/to dates
   - discard → `discarded`

   One update can write several events, for example rescheduled plus status_changed.
9. **Discarding a parent** also discards its subtasks, in one transaction.

### Project
- `name` is required and the color must be in the palette.
- Archived means `archived_at` is not null. **Deleting** a project that still has kept (non-discarded) tasks → **409 `project_not_empty`**. The user should archive it or move the tasks first.
- New projects go to the end (`position`).

### Tag
- Names are trimmed, any leading `#` is stripped, and comparison is case-insensitive through citext.
- Tags are created implicitly through `tag_names` on a task (find or create).
- Deleting a tag removes its taggings (CASCADE). Tasks are not affected.

---

## 5. API

All paths are under `/api/v1`.

### 5.1 Task JSON (`TaskResource`)
```json
{
  "id": 42,
  "title": "Read chapter 3 of PG internals",
  "description": { "type": "doc", "content": [] },
  "status": "todo",
  "priority": "high",
  "due_date": "2026-10-31",
  "due_at": "2026-10-31T18:00:00+05:30",
  "overdue": false,
  "estimate_minutes": 45,
  "completed_at": null,
  "position": 3.0,
  "project_id": 7,
  "section_id": null,
  "parent_id": null,
  "subtask_count": 4,
  "subtask_done_count": 1,
  "tags": [{ "id": 3, "name": "postgres", "color": "blue" }],
  "created_at": "2026-10-30T09:12:00+05:30",
  "updated_at": "2026-10-30T09:12:00+05:30"
}
```
- `overdue` is computed and true when the task is open (`todo` or `in_progress`) and either:
  - `due_at` is set and earlier than now, or
  - `due_at` is null and `due_date` is earlier than today in the user's time zone.
- `position` is a JSON number (the BigDecimal column is converted with `to_f`).
- `subtask_count` and `subtask_done_count` count kept subtasks only and are 0 for subtasks. **Avoid N+1 queries:**
  - Option 1: preload the counts in one grouped query.
  - Option 2: use `counter_cache`-style columns.
  - Your choice; Option 1 is good Postgres practice with `count(*) FILTER (WHERE status='done')`.
- `GET /tasks/:id` also returns `"subtasks": [TaskJSON, ...]`, ordered by position. List endpoints leave it out.

### 5.2 Tasks endpoints
| Method | Path | Body / params | Response |
|---|---|---|---|
| GET | `/tasks` | see filters below | `{ "tasks": [TaskJSON], "next_cursor": null \| "..." }` |
| GET | `/tasks/:id` | — | TaskJSON plus `subtasks` |
| POST | `/tasks` | `{ "task": { ...writable fields } }` | 201 TaskJSON |
| PATCH | `/tasks/:id` | `{ "task": { ...partial } }` | 200 TaskJSON |
| DELETE | `/tasks/:id` | — | 204 (soft delete; subtasks discarded too) |
| POST | `/tasks/:id/complete` | — | 200 TaskJSON (no-op if already done) |
| POST | `/tasks/:id/reopen` | — | 200 TaskJSON with status `todo` (no-op if not done or cancelled) |
| PATCH | `/tasks/reorder` | see §5.4 | 200 `{ "tasks": [{ "id", "position", "section_id" }] }` |
| GET | `/tasks/counts` | — | see §5.5 |

**Writable fields:** `title, description, status, priority, due_date, due_at, estimate_minutes, project_id, section_id, parent_id, tag_names` (array of strings; it **replaces** the task's tag set; omit it to leave tags unchanged, send `[]` to clear them).

**`GET /tasks` filters.** Exactly one `view` is required, otherwise 422 `invalid_parameter`. Only top-level tasks are returned (`parent_id IS NULL`) unless noted otherwise.

| `view` | Returns | Order |
|---|---|---|
| `today` | open tasks with `due_date <= today` (overdue included), **plus** tasks completed today | overdue first, then by `due_at` (nulls last), priority desc, position |
| `upcoming` | open tasks with `due_date` from today to today + 6 | `due_date`, `due_at` nulls last, priority desc, position |
| `inbox` | open tasks with `project_id IS NULL` | position |
| `project` | requires `project_id`; open tasks in that project, all sections | `section_id` nulls first, then position. The UI groups by section. |
| `completed` | `status = 'done'`, all projects | `completed_at DESC, id DESC`, paginated |
| `search` | requires `q`; open and done tasks whose `search_vector @@ plainto_tsquery('simple', q)`; **includes subtasks** | `ts_rank` desc, limit 20 |

**Optional on every view:**
- `tag=<name>` narrows to tasks with that tag.
- `include_done=true` also returns done tasks in the `inbox` and `project` views (the "show completed" toggle).
- Cancelled tasks are not returned by any view in Phase 1, including `completed`. They only exist for history and analytics.

**Pagination (`completed` only):**
- Accepts `limit` (default 50, max 100) and `cursor`. `cursor` is an opaque string, for example a base64 encoding of `completed_at|id`.
- Use keyset pagination `WHERE (completed_at, id) < (?, ?)`, **not** `OFFSET`.
- `next_cursor` is null when there are no more rows. Every other view returns `next_cursor: null` and no limit; the lists are small.

### 5.3 Validation examples the UI depends on
| Request | Result |
|---|---|
| `POST /tasks {task:{title:""}}` | 422, `details.title` present |
| `POST /tasks {task:{title:"x", priority:"extreme"}}` | 422, `details.priority` |
| `POST /tasks {task:{title:"x", section_id:<section from another project>}}` | 422, `details.section_id` |
| `POST /tasks {task:{title:"x", parent_id:<a subtask>}}` | 422, `details.parent_id` |
| `POST /tasks {task:{title:"x", project_id:<archived>}}` | 422, `details.project_id` |
| `GET /tasks?view=nope` | 422 `invalid_parameter` |
| `GET /tasks/<discarded id>` | 404 |

### 5.4 Reorder
```json
PATCH /api/v1/tasks/reorder
{ "moves": [ { "id": 12, "position": 2.5, "section_id": 4 } ] }
```
- `section_id` is optional. Include it to move the task across sections within the **same** project.
- The whole request runs in **one transaction**. Any invalid move (unknown id, wrong project section) → 422 and nothing changes.
- At most 200 moves per request.
- A reorder is **not** a status change, so it writes no events.

### 5.5 Counts (for sidebar badges)
```json
GET /api/v1/tasks/counts
{ "inbox": 5, "today": 3, "overdue": 1, "upcoming": 9, "projects": { "7": 12, "9": 0 } }
```
These are open top-level tasks only and use the same rules as the views. `today` includes overdue tasks; `overdue` is the subset. Try to do it in **one or two SQL queries** using `count(*) FILTER (WHERE ...)` for the scalar counts and a `GROUP BY` for the projects.

### 5.6 Projects
`ProjectJSON`:
```json
{ "id": 7, "name": "Learning Rails", "color": "violet", "icon": "book", "position": 1.0,
  "archived": false, "archived_at": null, "open_task_count": 12,
  "sections": [{ "id": 4, "name": "Week 1", "position": 1.0, "project_id": 7 }],
  "created_at": "...", "updated_at": "..." }
```

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/projects` | `?include_archived=true` (default: active only) | `{ "projects": [ProjectJSON] }` by position |
| GET | `/projects/:id` | — | ProjectJSON |
| POST | `/projects` | `{ project: { name, color, icon } }` | 201 |
| PATCH | `/projects/:id` | `{ project: { name, color, icon, position, archived } }` | 200; `archived: true/false` sets or clears `archived_at` |
| DELETE | `/projects/:id` | — | 204, or **409 `project_not_empty`** |

### 5.7 Sections (nested under projects)
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/projects/:project_id/sections` | `{ section: { name } }` | 201 SectionJSON (`id, name, position, project_id`) |
| PATCH | `/projects/:project_id/sections/:id` | `{ section: { name, position } }` | 200 |
| DELETE | `/projects/:project_id/sections/:id` | — | 204 (its tasks move to the project root through ON DELETE SET NULL) |

A section looked up through the wrong project → 404. Use `project.sections.find(id)`.

### 5.8 Tags
| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/tags` | — | `{ "tags": [{ id, name, color, task_count }] }` by name |
| PATCH | `/tags/:id` | `{ tag: { name, color } }` | 200; a rename that collides → 422 |
| DELETE | `/tags/:id` | — | 204 |

### 5.9 Meta
```json
GET /api/v1/meta
{ "colors": ["gray", "red", ...], "priorities": [{ "value": "none", "label": "None" }, ... { "value": "urgent", "label": "Urgent" }],
  "statuses": ["todo", "in_progress", "done", "cancelled"] }
```
This is small and static, so the UI never hard-codes values the backend owns.

---

## 6. Tests (Minitest)

Add fixtures for at least: two projects (one archived), one section, an Inbox task, an overdue task, a task due today, a task due in 3 days, a done task, a parent with two subtasks, and two tags.

**Model tests**
- [ ] completing sets `completed_at`; reopening clears it
- [ ] the DB check rejects `status='done'` with null `completed_at` (`update_column` → `ActiveRecord::StatementInvalid`, which proves the DB itself enforces it)
- [ ] a subtask inherits project and section; a sub-subtask is rejected
- [ ] a section from another project is rejected
- [ ] `due_at` derives `due_date` in the **user's** zone. Test with a time near midnight, for example `Asia/Kolkata` vs UTC.
- [ ] the events written for create, status change, reschedule and discard
- [ ] tag names are normalized (`"#Postgres "` → `postgres`, and it matches an existing `POSTGRES`)

**Request tests**, one file per controller:
- [ ] every endpoint returns 401 when signed out
- [ ] each `view` returns the right tasks in the right order (use the fixtures above)
- [ ] `today` includes tasks completed today and excludes ones completed yesterday
- [ ] completed pagination: two pages, no duplicates, `next_cursor` null at the end
- [ ] reorder is all-or-nothing
- [ ] counts match the views
- [ ] deleting a project with tasks returns 409; deleting an empty one returns 204
- [ ] discarded tasks are absent from every view and 404 on show
- [ ] `tag_names` replaces the tags; omitting it leaves them alone

**Performance check.** Seed about 5,000 tasks (`db/seeds.rb` or a rake task) and run `EXPLAIN ANALYZE` on the `today` query. You should see your partial index being used. Write down what you find; it's great learning material.

---

## 7. Definition of done
- [ ] Migrations run cleanly on a fresh DB (`bin/rails db:reset`) **and** inside Docker (`make build && make up`).
- [ ] `bin/rails test`, `bin/rubocop` and `bin/brakeman` are all green.
- [ ] Every endpoint in §5 works with curl. Sign in first; see the README for the CSRF cookie flow, or test through `bin/rails test`.
- [ ] No N+1 queries on `GET /tasks?view=today` with 50 tasks. Check the dev log: it should run a constant number of queries, about 4–5, whatever the task count. Optionally add the `prosopite` or `bullet` gem in development.
- [ ] This document is updated if any shape changed.

When this is done, tell me and I'll build the UI: the Tasks pages (Inbox, Today, Upcoming, Project, Completed), the task detail drawer, quick add (`c`), drag-to-reorder, sidebar projects with count badges, ⌘K task search, and Today page integration.

---

## 8. Learning notes: what to study while building this

| You'll touch | Read up on |
|---|---|
| Check constraints, partial indexes, generated columns | Rails guides "Active Record Migrations" (`add_check_constraint`, `t.virtual`); PG docs §5.4 Constraints, §11.8 Partial Indexes |
| `ON DELETE CASCADE / SET NULL` | `add_foreign_key ..., on_delete:`; think about why each FK in §3 has the option it does |
| Polymorphic taggings | Rails guide "Associations → Polymorphic"; `has_many :tags, through: :taggings` |
| Self-referential subtasks | `belongs_to :parent, class_name: "Task", optional: true`; `has_many :subtasks, foreign_key: :parent_id` |
| Callbacks vs service objects | `after_save` runs inside the save's transaction (good for rows that must match the change, like `task_events`); `after_commit` runs after it (good for side effects outside the DB: jobs, emails, cache busting). Complete/reopen live on the model. |
| Time zones | `Time.use_zone`, `Date.current` vs `Date.today` (only one is correct here), `in_time_zone` |
| Keyset pagination | Row-value comparison `(a, b) < (x, y)` and why `OFFSET` gets slow |
| Aggregates | `count(*) FILTER (WHERE ...)`, `GROUP BY`, `.group(:project_id).count` |
| Full-text search | `to_tsvector`, `plainto_tsquery`, `ts_rank`, GIN indexes; why `'simple'` instead of `'english'` for short titles |
| Transactions | `ActiveRecord::Base.transaction`, and what happens when you raise inside one |
| Scopes | `scope :open`, `scope :kept`, composing scopes for each `view` (a `TasksQuery` object is a nice pattern) |
