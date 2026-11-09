# Lumen

A local-first workspace for journaling, tasks, daily tracking and learning — Rails 8 + Vue 3 + PostgreSQL, running on your own machine. See [`docs/PRD.md`](docs/PRD.md) for the full product spec and roadmap.

**Status:** Phase 0 (foundation) — sign-in, app shell, Docker. Modules arrive in Phases 1–6.

## Run it (Docker)

Requires Docker Desktop.

```sh
make setup   # once: creates .env with a random DB password + your Rails master key
make up      # builds and starts → http://localhost:3000
```

If port 3000 is already taken, set `LUMEN_PORT` in `.env` (e.g. `LUMEN_PORT=3100`) and run `make up` again.

The first visit asks you to create your account. Data lives in the `lumen_pg_data` and `lumen_storage` Docker volumes, so `make down` / `make up` keeps it.

`make help` lists everything else (`logs`, `console`, `psql`, `ps`, `size`…).

## Develop in Docker (live reload)

Your project folder is mounted into the containers, so edits on your Mac show up in the
container straight away, and files created inside it (`bin/rails g migration …`) appear on
your Mac. Rails reloads code on the next request; Vite hot-reloads Vue/CSS in the browser.

```sh
make dev-up        # http://localhost:3200 (Vite on :3036, Postgres on localhost:5433, user/pass lumen/lumen)
make dev-logs      # follow Rails + Vite
make dev-bash      # shell in the web container: bin/rails g …, bin/rails db:migrate, …
make dev-test      # run the Rails tests in the container
make dev-restart   # restart Rails + Vite (picks up new gems / npm packages)
make dev-down      # stop (gems, node_modules and the dev database are kept in volumes)
```

It runs beside the production stack (`make up`) with its own database. Gems and
`node_modules` live in Docker volumes because macOS-built native binaries can't run in
Linux; after changing `Gemfile` or `package.json`, run `make dev-restart` and they
install automatically. Don't run `bin/dev` at the same time — both use port 3036.

## Develop (no Docker)

Requires Ruby 3.4.12 (`.ruby-version`), Node 24 (`.nvmrc`) and a local PostgreSQL.

```sh
nvm use                      # Node 24
bundle install && npm install
bin/rails db:prepare
bin/dev                      # Rails on :3000 + Vite (HMR) on :3036
```

## What's inside

| Module | Highlights |
|---|---|
| **Tasks** | Inbox / Today / Upcoming / Completed, projects with sections, list or Kanban board, subtasks, tags, recurring tasks, natural-language quick add (`c`: “Call mom tomorrow 6pm #family !high every week”) |
| **Learn** | Block editor (`/` menu, Markdown shortcuts, tables, callouts, code), folders, `[[wiki links]]` + backlinks, `#tags`, images, topics, resources, study log, SM-2 flashcards (`Question :: Answer`) |
| **Tracker** | Yes/no, count, duration, number and 1–5 trackers; streaks, heatmaps, backfill |
| **Journal** | End-to-end encrypted in the browser (Argon2id + AES-256-GCM); the server stores only ciphertext. Recovery key, auto-lock, search and “On this day” on-device |
| **Analytics** | Throughput, completion and on-time rates, productive hours, habit consistency, learning time, weekly review |

Everything else: ⌘K search across notes and tasks, trash (30 days), JSON / Markdown / encrypted journal exports in Settings.

## Back up and restore (Docker stack)

```sh
make backup                                   # → backups/lumen-YYYYMMDD-HHMMSS.tar.gz (database + uploads; keeps 14)
make restore FILE=backups/lumen-….tar.gz      # replaces all current data; asks you to confirm
```

Journal entries are already ciphertext inside a backup.

## Journal leak test

With the dev stack running (`make dev-up`) and Chrome installed:

```sh
make canary EMAIL=you@example.com PASSWORD=…  # writes an entry with a random canary, then checks
                                              # requests, a pg_dump, the logs and storage for it
```

## Test

```sh
make test    # Rails tests, Vitest, vue-tsc typecheck
make lint    # RuboCop + Brakeman
```

## Layout

| Path | What |
|---|---|
| `app/controllers/api/v1/` | JSON API (session cookie + CSRF header) |
| `app/controllers/spa_controller.rb` | Serves the Vue shell for every non-API route |
| `app/frontend/` | Vue app — `features/` per module, `components/ui/` = shadcn-vue |
| `app/resources/` | Alba serializers |
| `Dockerfile` | 4-stage build: frontend → minimal libvips → gems → slim runtime |
| `compose.yml` | `app` + `db`, localhost-only, read-only root FS, memory limits |
