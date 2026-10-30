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

## Develop (no Docker)

Requires Ruby 3.4.12 (`.ruby-version`), Node 24 (`.nvmrc`) and a local PostgreSQL.

```sh
nvm use                      # Node 24
bundle install && npm install
bin/rails db:prepare
bin/dev                      # Rails on :3000 + Vite (HMR) on :3036
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
