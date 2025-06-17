export interface DashboardMetrics {
  totalEmails: number;
  tasksIdentified: number;
  avgResponseTime: string;
  productivity: number;
}

export interface SentimentData {
  positive: number;
  neutral: number;
  negative: number;
}

export interface EmailVolumeData {
  date: string;
  count: number;
}

export interface RecentEmail {
  id: number;
  subject?: string;
  bodyPreview?: string;
  receivedAt: string;
  sender: {
    displayName?: string;
    email: string;
  };
  analysis?: {
    sentiment?: string;
    urgencyScore?: number;
  };
}

export interface RecentTask {
  id: number;
  title: string;
  description?: string;
  status: string;
  priority?: string;
  confidenceScore?: number;
  sourceEmail?: {
    subject?: string;
  };
  assignedTo?: {
    displayName?: string;
  };
  dueDate?: string;
}

export interface TeamMember {
  id: number;
  displayName?: string;
  email: string;
  department?: string;
  role?: string;
}

export interface AuthUser {
  id: number;
  email: string;
  displayName?: string;
  role?: string;
  organizationId?: number;
}
