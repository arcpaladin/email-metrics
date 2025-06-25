import { 
  users, employees, emails, tasks, emailAnalysis, organizations, emailRecipients,
  type User, type InsertUser, type Employee, type InsertEmployee, 
  type Email, type InsertEmail, type Task, type InsertTask,
  type EmailAnalysis, type InsertEmailAnalysis, type Organization, type InsertOrganization
} from "../shared/schema";
import { db } from "./db";
import { eq, desc, and, gte, sql } from "drizzle-orm";

export interface IStorage {
  // User management
  getUser(id: number): Promise<User | undefined>;
  getUserByUsername(username: string): Promise<User | undefined>;
  createUser(user: InsertUser): Promise<User>;
  
  // Organization management
  createOrganization(org: InsertOrganization): Promise<Organization>;
  getOrganizationByDomain(domain: string): Promise<Organization | undefined>;
  
  // Employee management
  createEmployee(employee: InsertEmployee): Promise<Employee>;
  getEmployeeByEmail(email: string): Promise<Employee | undefined>;
  getEmployeesByOrganization(orgId: number): Promise<Employee[]>;
  updateEmployeeLastSync(id: number): Promise<void>;
  
  // Email management
  createEmail(email: InsertEmail): Promise<Email>;
  getEmailsByEmployee(employeeId: number, limit?: number): Promise<Email[]>;
  getRecentEmails(limit?: number): Promise<(Email & { sender: Employee; analysis?: EmailAnalysis })[]>;
  
  // Task management
  createTask(task: InsertTask): Promise<Task>;
  getTasksByEmployee(employeeId: number): Promise<Task[]>;
  updateTaskStatus(id: number, status: string): Promise<void>;
  getRecentTasks(limit?: number): Promise<(Task & { assignedTo?: Employee; sourceEmail?: Email })[]>;
  
  // Email analysis
  createEmailAnalysis(analysis: InsertEmailAnalysis): Promise<EmailAnalysis>;
  getEmailAnalysis(emailId: number): Promise<EmailAnalysis | undefined>;
  
  // Analytics
  getEmailMetrics(organizationId?: number): Promise<{
    totalEmails: number;
    tasksIdentified: number;
    avgResponseTime: string;
    productivity: number;
  }>;
  
  getSentimentAnalytics(organizationId?: number): Promise<{
    positive: number;
    neutral: number;
    negative: number;
  }>;
  
  getEmailVolumeData(days: number, organizationId?: number): Promise<Array<{
    date: string;
    count: number;
  }>>;
}

export class DatabaseStorage implements IStorage {
  async getUser(id: number): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.id, id));
    return user || undefined;
  }

  async getUserByUsername(username: string): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.username, username));
    return user || undefined;
  }

  async createUser(insertUser: InsertUser): Promise<User> {
    const [user] = await db
      .insert(users)
      .values(insertUser)
      .returning();
    return user;
  }

  async createOrganization(org: InsertOrganization): Promise<Organization> {
    const [organization] = await db
      .insert(organizations)
      .values(org)
      .returning();
    return organization;
  }

  async getOrganizationByDomain(domain: string): Promise<Organization | undefined> {
    const [org] = await db.select().from(organizations).where(eq(organizations.domain, domain));
    return org || undefined;
  }

  async createEmployee(employee: InsertEmployee): Promise<Employee> {
    const [emp] = await db
      .insert(employees)
      .values(employee)
      .returning();
    return emp;
  }

  async getEmployeeByEmail(email: string): Promise<Employee | undefined> {
    const [emp] = await db.select().from(employees).where(eq(employees.email, email));
    return emp || undefined;
  }

  async getEmployeesByOrganization(orgId: number): Promise<Employee[]> {
    return await db.select().from(employees).where(eq(employees.organizationId, orgId));
  }

  async updateEmployeeLastSync(id: number): Promise<void> {
    await db
      .update(employees)
      .set({ lastSync: new Date() })
      .where(eq(employees.id, id));
  }

  async createEmail(email: InsertEmail): Promise<Email> {
    const [emailRecord] = await db
      .insert(emails)
      .values(email)
      .returning();
    return emailRecord;
  }

  async getEmailsByEmployee(employeeId: number, limit: number = 50): Promise<Email[]> {
    return await db
      .select()
      .from(emails)
      .where(eq(emails.senderId, employeeId))
      .orderBy(desc(emails.receivedAt))
      .limit(limit);
  }

  async getRecentEmails(limit: number = 10): Promise<(Email & { sender: Employee; analysis?: EmailAnalysis })[]> {
    return await db
      .select({
        id: emails.id,
        messageId: emails.messageId,
        conversationId: emails.conversationId,
        senderId: emails.senderId,
        subject: emails.subject,
        bodyPreview: emails.bodyPreview,
        receivedAt: emails.receivedAt,
        isRead: emails.isRead,
        importance: emails.importance,
        hasAttachments: emails.hasAttachments,
        createdAt: emails.createdAt,
        sender: employees,
        analysis: emailAnalysis,
      })
      .from(emails)
      .leftJoin(employees, eq(emails.senderId, employees.id))
      .leftJoin(emailAnalysis, eq(emails.id, emailAnalysis.emailId))
      .orderBy(desc(emails.receivedAt))
      .limit(limit) as any;
  }

  async createTask(task: InsertTask): Promise<Task> {
    const [taskRecord] = await db
      .insert(tasks)
      .values(task)
      .returning();
    return taskRecord;
  }

  async getTasksByEmployee(employeeId: number): Promise<Task[]> {
    return await db
      .select()
      .from(tasks)
      .where(eq(tasks.assignedToId, employeeId))
      .orderBy(desc(tasks.createdAt));
  }

  async updateTaskStatus(id: number, status: string): Promise<void> {
    await db
      .update(tasks)
      .set({ status, updatedAt: new Date() })
      .where(eq(tasks.id, id));
  }

  async getRecentTasks(limit: number = 10): Promise<(Task & { assignedTo?: Employee; sourceEmail?: Email })[]> {
    return await db
      .select({
        id: tasks.id,
        title: tasks.title,
        description: tasks.description,
        assignedToId: tasks.assignedToId,
        createdById: tasks.createdById,
        status: tasks.status,
        priority: tasks.priority,
        dueDate: tasks.dueDate,
        completionDate: tasks.completionDate,
        confidenceScore: tasks.confidenceScore,
        sourceEmailId: tasks.sourceEmailId,
        createdAt: tasks.createdAt,
        updatedAt: tasks.updatedAt,
        assignedTo: employees,
        sourceEmail: emails,
      })
      .from(tasks)
      .leftJoin(employees, eq(tasks.assignedToId, employees.id))
      .leftJoin(emails, eq(tasks.sourceEmailId, emails.id))
      .orderBy(desc(tasks.createdAt))
      .limit(limit) as any;
  }

  async createEmailAnalysis(analysis: InsertEmailAnalysis): Promise<EmailAnalysis> {
    const [analysisRecord] = await db
      .insert(emailAnalysis)
      .values(analysis)
      .returning();
    return analysisRecord;
  }

  async getEmailAnalysis(emailId: number): Promise<EmailAnalysis | undefined> {
    const [analysis] = await db
      .select()
      .from(emailAnalysis)
      .where(eq(emailAnalysis.emailId, emailId));
    return analysis || undefined;
  }

  async getEmailMetrics(organizationId?: number): Promise<{
    totalEmails: number;
    tasksIdentified: number;
    avgResponseTime: string;
    productivity: number;
  }> {
    const totalEmailsResult = await db
      .select({ count: sql<number>`count(*)` })
      .from(emails)
      .leftJoin(employees, eq(emails.senderId, employees.id))
      .where(organizationId ? eq(employees.organizationId, organizationId) : undefined);

    const tasksResult = await db
      .select({ count: sql<number>`count(*)` })
      .from(tasks)
      .leftJoin(employees, eq(tasks.assignedToId, employees.id))
      .where(organizationId ? eq(employees.organizationId, organizationId) : undefined);

    return {
      totalEmails: totalEmailsResult[0]?.count || 0,
      tasksIdentified: tasksResult[0]?.count || 0,
      avgResponseTime: "4.2h", // This would need more complex calculation
      productivity: 87, // This would need more complex calculation
    };
  }

  async getSentimentAnalytics(organizationId?: number): Promise<{
    positive: number;
    neutral: number;
    negative: number;
  }> {
    const sentimentData = await db
      .select({
        sentiment: emailAnalysis.sentiment,
        count: sql<number>`count(*)`,
      })
      .from(emailAnalysis)
      .leftJoin(emails, eq(emailAnalysis.emailId, emails.id))
      .leftJoin(employees, eq(emails.senderId, employees.id))
      .where(organizationId ? eq(employees.organizationId, organizationId) : undefined)
      .groupBy(emailAnalysis.sentiment);

    const result = { positive: 0, neutral: 0, negative: 0 };
    sentimentData.forEach(item => {
      if (item.sentiment === 'positive') result.positive = item.count;
      else if (item.sentiment === 'neutral') result.neutral = item.count;
      else if (item.sentiment === 'negative') result.negative = item.count;
    });

    return result;
  }

  async getEmailVolumeData(days: number, organizationId?: number): Promise<Array<{
    date: string;
    count: number;
  }>> {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const volumeData = await db
      .select({
        date: sql<string>`date(${emails.receivedAt})`,
        count: sql<number>`count(*)`,
      })
      .from(emails)
      .leftJoin(employees, eq(emails.senderId, employees.id))
      .where(
        and(
          gte(emails.receivedAt, startDate),
          organizationId ? eq(employees.organizationId, organizationId) : undefined
        )
      )
      .groupBy(sql`date(${emails.receivedAt})`)
      .orderBy(sql`date(${emails.receivedAt})`);

    return volumeData;
  }
}

export const storage = new DatabaseStorage();
