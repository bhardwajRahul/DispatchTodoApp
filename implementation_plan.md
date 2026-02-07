# Dispatch — Implementation Plan

## Phase 1: Authentication & User Foundation

Get OAuth2 login working end-to-end so all subsequent work can happen behind a protected session.

- [x] **1.1** Register a GitHub OAuth App and populate `AUTH_SECRET`, `AUTH_GITHUB_ID`, `AUTH_GITHUB_SECRET` in `.env.local`.
- [x] **1.2** Generate the initial Drizzle migration from the existing schema (`users`, `accounts`, `sessions`) and apply it to create `dispatch.db`.
- [x] **1.3** Wire NextAuth.js to persist users/accounts/sessions into SQLite via a Drizzle adapter (or manual callbacks).
- [x] **1.4** Build a sign-in page (`src/app/login/page.tsx`) with a "Sign in with GitHub" button.
- [x] **1.5** Build a minimal top-level layout with a nav bar that shows the authenticated user's name/avatar and a sign-out button.
- [x] **1.6** Confirm the `withAuth` wrapper correctly rejects unauthenticated API calls with 401.

## Phase 2: Core Data Model & CRUD APIs

Define the first domain entities and build the REST endpoints that the UI will consume.

- [x] **2.1** Design the tasks table schema in `src/db/schema.ts` — fields: `id`, `userId`, `title`, `description`, `status` (enum: open/in_progress/done), `priority` (low/medium/high), `dueDate`, `createdAt`, `updatedAt`.
- [x] **2.2** Design the notes table schema — fields: `id`, `userId`, `title`, `content` (markdown text), `createdAt`, `updatedAt`.
- [x] **2.3** Generate and run a Drizzle migration for the new tables.
- [x] **2.4** Implement `GET /api/tasks` (list, with filters for status/priority), `POST /api/tasks` (create).
- [x] **2.5** Implement `GET /api/tasks/[id]`, `PUT /api/tasks/[id]`, `DELETE /api/tasks/[id]`.
- [x] **2.6** Implement `GET /api/notes`, `POST /api/notes`.
- [x] **2.7** Implement `GET /api/notes/[id]`, `PUT /api/notes/[id]`, `DELETE /api/notes/[id]`.
- [x] **2.8** Add input validation for all POST/PUT endpoints (reject malformed payloads with 400).

## Phase 2.5: Test Infrastructure & Coverage for Phases 1–2

Set up Vitest and write tests covering the authentication layer and all CRUD API routes.

- [x] **2.5.1** Install Vitest, configure `vitest.config.ts` with path aliases, add `npm run test` / `npm run test:watch` scripts.
- [x] **2.5.2** Create test helpers: in-memory SQLite test database factory (`src/test/db.ts`), mock session controller and `NextResponse` mock (`src/test/setup.ts`).
- [x] **2.5.3** Write unit tests for `withAuth`, `jsonResponse`, `errorResponse` in `src/lib/__tests__/api.test.ts` — covers 401 rejection, session pass-through, route context forwarding, and response formatting.
- [x] **2.5.4** Write integration tests for tasks CRUD in `src/app/api/tasks/__tests__/route.test.ts` — covers create, list, filter by status/priority, get by id, update (partial & full), delete, ownership isolation, and input validation (32 tests).
- [x] **2.5.5** Write integration tests for notes CRUD in `src/app/api/notes/__tests__/route.test.ts` — covers create, list, search-by-title, get by id, update, delete, ownership isolation, and input validation (27 tests).

## Phase 3: UI — Task & Note Management

Build the front-end pages that let the user interact with tasks and notes.

- [ ] ** 3.0.1** Ensure GitHub account creation works. 
- [ ] **3.1** Create a dashboard page (`/`) showing a summary: open task count, recent notes, upcoming due dates.
- [ ] **3.2** Build a tasks list page (`/tasks`) with filtering (status, priority) and sorting (due date, created date).
- [ ] **3.3** Build a task detail/edit page or modal for creating and editing a single task.
- [ ] **3.4** Build a notes list page (`/notes`) with search-by-title.
- [ ] **3.5** Build a note editor page (`/notes/[id]`) with a markdown text area and live preview.
- [ ] **3.6** Implement a shared `useFetch` hook or thin API client (`src/lib/client.ts`) to standardize client-side API calls with error handling.
- [ ] **3.7** Add optimistic UI updates for task status toggles (open -> done, etc.).
- [ ] **3.8** Write tests for the API client (`src/lib/client.ts`) covering fetch wrappers, error handling, and response parsing.

## Phase 4: Daily Dispatch View & Workflow

The signature feature: a daily "dispatch" view that aggregates what's relevant for today.

- [ ] **4.1** Design a `dispatches` table — fields: `id`, `userId`, `date` (unique per user per day), `summary` (markdown), `createdAt`, `updatedAt`.
- [ ] **4.2** Implement CRUD API routes for dispatches (`/api/dispatches`, `/api/dispatches/[id]`).
- [ ] **4.3** Write integration tests for dispatch CRUD routes (create, get, update, delete, auto-create today, ownership isolation).
- [ ] **4.4** Build the daily dispatch page (`/dispatch`) that auto-creates today's entry if it doesn't exist.
- [ ] **4.5** Show today's tasks (due today or overdue) inline within the dispatch view.
- [ ] **4.6** Allow linking/unlinking tasks to a dispatch (a join table or JSON array of task IDs).
- [ ] **4.7** Add a "complete day" action that marks the dispatch as finalized and rolls unfinished tasks to the next day.
- [ ] **4.8** Write tests for dispatch-specific logic: task linking, day completion, task rollover.

## Phase 5: Polish, Search & Quality of Life

Harden the app and add cross-cutting features that make daily use pleasant.

- [ ] **5.1** Add global search across tasks, notes, and dispatches (SQLite FTS5 or simple `LIKE` queries).
- [ ] **5.2** Add keyboard shortcuts for common actions (new task, new note, navigate to dispatch).
- [ ] **5.3** Add a dark mode toggle (Tailwind's `dark:` variant, stored in localStorage).
- [ ] **5.4** Add toast notifications for success/error feedback on mutations.
- [ ] **5.5** Add pagination to list endpoints and UI (`?page=&limit=` query params).
- [ ] **5.6** Write a seed script (`src/db/seed.ts`) that populates sample data for development.
- [ ] **5.7** Review and harden all API routes: rate-limit awareness, consistent error messages, edge cases.
- [ ] **5.8** Write tests for search endpoint, pagination logic, and any new API routes added in this phase.
- [ ] **5.9** Ensure `npm test` passes in CI-like fashion (all tests green, no flaky tests) as a final gate.
