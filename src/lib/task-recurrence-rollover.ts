import { and, eq, isNotNull, isNull, lte, ne } from "drizzle-orm";
import { db } from "@/db";
import { tasks } from "@/db/schema";
import { getIsoDateForTimeZone } from "@/lib/timezone";

export function getTodayIsoDate(timeZone?: string | null): string {
  return getIsoDateForTimeZone(new Date(), timeZone ?? null);
}

/**
 * Re-opens recurring tasks whose next occurrence date is now due.
 * This enables "midnight rollover" behavior without a background worker.
 */
export async function releaseDueRecurringTasksForUser(
  userId: string,
  todayIsoDate: string,
): Promise<void> {
  await db
    .update(tasks)
    .set({
      status: "open",
      updatedAt: new Date().toISOString(),
    })
    .where(
      and(
        eq(tasks.userId, userId),
        isNull(tasks.deletedAt),
        eq(tasks.status, "done"),
        ne(tasks.recurrenceType, "none"),
        isNotNull(tasks.dueDate),
        lte(tasks.dueDate, todayIsoDate),
      ),
    );
}
