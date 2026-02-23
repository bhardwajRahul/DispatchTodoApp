CREATE TABLE `recurrence_series` (
	`id` text PRIMARY KEY NOT NULL,
	`userId` text NOT NULL,
	`projectId` text,
	`title` text NOT NULL,
	`description` text,
	`priority` text DEFAULT 'medium' NOT NULL,
	`recurrenceType` text NOT NULL,
	`recurrenceBehavior` text DEFAULT 'after_completion' NOT NULL,
	`recurrenceRule` text,
	`nextDueDate` text NOT NULL,
	`active` integer DEFAULT true NOT NULL,
	`deletedAt` text,
	`createdAt` text DEFAULT (current_timestamp) NOT NULL,
	`updatedAt` text DEFAULT (current_timestamp) NOT NULL,
	FOREIGN KEY (`userId`) REFERENCES `user`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`projectId`) REFERENCES `project`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE INDEX `recurrence_series_userId_idx` ON `recurrence_series` (`userId`);--> statement-breakpoint
CREATE INDEX `recurrence_series_projectId_idx` ON `recurrence_series` (`projectId`);--> statement-breakpoint
CREATE INDEX `recurrence_series_active_idx` ON `recurrence_series` (`active`);--> statement-breakpoint
CREATE INDEX `recurrence_series_nextDueDate_idx` ON `recurrence_series` (`nextDueDate`);--> statement-breakpoint
ALTER TABLE `task` ADD `recurrenceSeriesId` text;--> statement-breakpoint
CREATE INDEX `task_recurrenceSeriesId_idx` ON `task` (`recurrenceSeriesId`);