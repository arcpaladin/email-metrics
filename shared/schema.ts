import { pgTable, text, serial, integer, boolean, timestamp, real, json } from "drizzle-orm/pg-core";
import { relations } from "drizzle-orm";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const organizations = pgTable("organizations", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  domain: text("domain").notNull().unique(),
  settings: json("settings").default({}),
  createdAt: timestamp("created_at").defaultNow(),
});

export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  username: text("username").notNull().unique(),
  password: text("password").notNull(),
});

export const employees = pgTable("employees", {
  id: serial("id").primaryKey(),
  organizationId: integer("organization_id").references(() => organizations.id),
  email: text("email").notNull().unique(),
  displayName: text("display_name"),
  department: text("department"),
  role: text("role"),
  isActive: boolean("is_active").default(true),
  lastSync: timestamp("last_sync"),
  createdAt: timestamp("created_at").defaultNow(),
});

export const emails = pgTable("emails", {
  id: serial("id").primaryKey(),
  messageId: text("message_id").notNull().unique(),
  conversationId: text("conversation_id"),
  senderId: integer("sender_id").references(() => employees.id),
  subject: text("subject"),
  bodyPreview: text("body_preview"),
  receivedAt: timestamp("received_at").notNull(),
  isRead: boolean("is_read").default(false),
  importance: text("importance"),
  hasAttachments: boolean("has_attachments").default(false),
  createdAt: timestamp("created_at").defaultNow(),
});

export const emailRecipients = pgTable("email_recipients", {
  id: serial("id").primaryKey(),
  emailId: integer("email_id").references(() => emails.id),
  recipientId: integer("recipient_id").references(() => employees.id),
  recipientType: text("recipient_type"), // TO, CC, BCC
});

export const tasks = pgTable("tasks", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  description: text("description"),
  assignedToId: integer("assigned_to_id").references(() => employees.id),
  createdById: integer("created_by_id").references(() => employees.id),
  status: text("status").default("identified"), // identified, in_progress, completed
  priority: text("priority"), // high, medium, low
  dueDate: timestamp("due_date"),
  completionDate: timestamp("completion_date"),
  confidenceScore: real("confidence_score"),
  sourceEmailId: integer("source_email_id").references(() => emails.id),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

export const emailAnalysis = pgTable("email_analysis", {
  id: serial("id").primaryKey(),
  emailId: integer("email_id").references(() => emails.id).unique(),
  sentiment: text("sentiment"), // positive, negative, neutral
  urgencyScore: integer("urgency_score"), // 1-10 scale
  topics: text("topics").array(),
  actionItems: text("action_items").array(),
  keyEntities: json("key_entities").default({}),
  aiSummary: text("ai_summary"),
  processingVersion: text("processing_version"),
  createdAt: timestamp("created_at").defaultNow(),
});

// Relations
export const organizationsRelations = relations(organizations, ({ many }) => ({
  employees: many(employees),
}));

export const employeesRelations = relations(employees, ({ one, many }) => ({
  organization: one(organizations, {
    fields: [employees.organizationId],
    references: [organizations.id],
  }),
  sentEmails: many(emails),
  receivedEmails: many(emailRecipients),
  assignedTasks: many(tasks, { relationName: "assignedTasks" }),
  createdTasks: many(tasks, { relationName: "createdTasks" }),
}));

export const emailsRelations = relations(emails, ({ one, many }) => ({
  sender: one(employees, {
    fields: [emails.senderId],
    references: [employees.id],
  }),
  recipients: many(emailRecipients),
  analysis: one(emailAnalysis),
  tasks: many(tasks),
}));

export const emailRecipientsRelations = relations(emailRecipients, ({ one }) => ({
  email: one(emails, {
    fields: [emailRecipients.emailId],
    references: [emails.id],
  }),
  recipient: one(employees, {
    fields: [emailRecipients.recipientId],
    references: [employees.id],
  }),
}));

export const tasksRelations = relations(tasks, ({ one }) => ({
  assignedTo: one(employees, {
    fields: [tasks.assignedToId],
    references: [employees.id],
    relationName: "assignedTasks",
  }),
  createdBy: one(employees, {
    fields: [tasks.createdById],
    references: [employees.id],
    relationName: "createdTasks",
  }),
  sourceEmail: one(emails, {
    fields: [tasks.sourceEmailId],
    references: [emails.id],
  }),
}));

export const emailAnalysisRelations = relations(emailAnalysis, ({ one }) => ({
  email: one(emails, {
    fields: [emailAnalysis.emailId],
    references: [emails.id],
  }),
}));

// Insert schemas
export const insertUserSchema = createInsertSchema(users).omit({
  id: true,
});

export const insertOrganizationSchema = createInsertSchema(organizations).omit({
  id: true,
  createdAt: true,
});

export const insertEmployeeSchema = createInsertSchema(employees).omit({
  id: true,
  createdAt: true,
});

export const insertEmailSchema = createInsertSchema(emails).omit({
  id: true,
  createdAt: true,
});

export const insertTaskSchema = createInsertSchema(tasks).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertEmailAnalysisSchema = createInsertSchema(emailAnalysis).omit({
  id: true,
  createdAt: true,
});

// Types
export type InsertUser = z.infer<typeof insertUserSchema>;
export type User = typeof users.$inferSelect;
export type Organization = typeof organizations.$inferSelect;
export type Employee = typeof employees.$inferSelect;
export type Email = typeof emails.$inferSelect;
export type Task = typeof tasks.$inferSelect;
export type EmailAnalysis = typeof emailAnalysis.$inferSelect;
export type EmailRecipient = typeof emailRecipients.$inferSelect;

export type InsertOrganization = z.infer<typeof insertOrganizationSchema>;
export type InsertEmployee = z.infer<typeof insertEmployeeSchema>;
export type InsertEmail = z.infer<typeof insertEmailSchema>;
export type InsertTask = z.infer<typeof insertTaskSchema>;
export type InsertEmailAnalysis = z.infer<typeof insertEmailAnalysisSchema>;
