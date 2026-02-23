import type Database from "better-sqlite3";

type ColumnBootstrap = {
  table: string;
  column: string;
  addSql: string;
};

const REQUIRED_COLUMNS: ColumnBootstrap[] = [
  {
    table: "user",
    column: "timeZone",
    addSql: 'ALTER TABLE "user" ADD COLUMN "timeZone" text',
  },
  {
    table: "user",
    column: "templatePresets",
    addSql: 'ALTER TABLE "user" ADD COLUMN "templatePresets" text',
  },
  {
    table: "task",
    column: "recurrenceType",
    addSql: 'ALTER TABLE "task" ADD COLUMN "recurrenceType" text NOT NULL DEFAULT \'none\'',
  },
  {
    table: "task",
    column: "recurrenceRule",
    addSql: 'ALTER TABLE "task" ADD COLUMN "recurrenceRule" text',
  },
  {
    table: "task",
    column: "recurrenceBehavior",
    addSql:
      'ALTER TABLE "task" ADD COLUMN "recurrenceBehavior" text NOT NULL DEFAULT \'after_completion\'',
  },
  {
    table: "task",
    column: "recurrenceSeriesId",
    addSql: 'ALTER TABLE "task" ADD COLUMN "recurrenceSeriesId" text',
  },
  {
    table: "task",
    column: "recurrenceProcessedAt",
    addSql: 'ALTER TABLE "task" ADD COLUMN "recurrenceProcessedAt" text',
  },
  {
    table: "security_setting",
    column: "shareAiApiKeyWithUsers",
    addSql:
      'ALTER TABLE "security_setting" ADD COLUMN "shareAiApiKeyWithUsers" integer NOT NULL DEFAULT 0',
  },
  {
    table: "security_setting",
    column: "userRegistrationEnabled",
    addSql:
      'ALTER TABLE "security_setting" ADD COLUMN "userRegistrationEnabled" integer NOT NULL DEFAULT 1',
  },
];

const REQUIRED_TABLES_SQL = [
  `
  CREATE TABLE IF NOT EXISTS "recurrence_series" (
    "id" text PRIMARY KEY NOT NULL,
    "userId" text NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
    "projectId" text REFERENCES "project"("id") ON DELETE SET NULL,
    "title" text NOT NULL,
    "description" text,
    "priority" text NOT NULL DEFAULT 'medium',
    "recurrenceType" text NOT NULL,
    "recurrenceBehavior" text NOT NULL DEFAULT 'after_completion',
    "recurrenceRule" text,
    "nextDueDate" text NOT NULL,
    "active" integer NOT NULL DEFAULT 1,
    "deletedAt" text,
    "createdAt" text NOT NULL DEFAULT (current_timestamp),
    "updatedAt" text NOT NULL DEFAULT (current_timestamp)
  );
  CREATE INDEX IF NOT EXISTS "recurrence_series_userId_idx" ON "recurrence_series" ("userId");
  CREATE INDEX IF NOT EXISTS "recurrence_series_projectId_idx" ON "recurrence_series" ("projectId");
  CREATE INDEX IF NOT EXISTS "recurrence_series_active_idx" ON "recurrence_series" ("active");
  CREATE INDEX IF NOT EXISTS "recurrence_series_nextDueDate_idx" ON "recurrence_series" ("nextDueDate");
  `,
];

function tableExists(sqlite: Database.Database, table: string): boolean {
  const row = sqlite
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1")
    .get(table) as { name: string } | undefined;
  return Boolean(row?.name);
}

function hasColumn(sqlite: Database.Database, table: string, column: string): boolean {
  const columns = sqlite.prepare(`PRAGMA table_info("${table}")`).all() as Array<{ name?: string }>;
  return columns.some((entry) => entry?.name === column);
}

export function ensureSchemaColumns(sqlite: Database.Database) {
  for (const createSql of REQUIRED_TABLES_SQL) {
    sqlite.exec(createSql);
  }

  for (const spec of REQUIRED_COLUMNS) {
    if (!tableExists(sqlite, spec.table)) {
      continue;
    }

    if (!hasColumn(sqlite, spec.table, spec.column)) {
      sqlite.exec(spec.addSql);
    }
  }
}
