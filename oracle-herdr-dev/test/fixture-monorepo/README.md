# fixture-monorepo

Disposable monorepo used only to exercise the development environment:

- `frontend/` — Vite + React + TypeScript (pnpm, oxfmt, ESLint, vtsls)
- `backend/`  — minimal Go HTTP server (gopls, goimports, gofmt)

It is copied to `~/src/fixture-monorepo` on the VM by `bin/setup-worktrees`,
initialised as its own Git repository, and checked out five times as Git
worktrees under `~/worktrees/1..5` (one Herdr workspace each).

Ports come from the per-worktree `.workspace.env` file (generated, not
committed). See `docs/architecture.md` in the parent repository.

Run the pieces by hand from a worktree:

    set -a; . ./.workspace.env; set +a
    (cd frontend && pnpm install && pnpm dev)     # http://127.0.0.1:$FRONTEND_PORT
    (cd backend  && go run ./cmd/server)          # http://127.0.0.1:$API_PORT/api/health
