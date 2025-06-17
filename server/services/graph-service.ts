import { Client } from '@microsoft/microsoft-graph-client';

export interface GraphEmailMessage {
  id: string;
  subject?: string;
  bodyPreview?: string;
  receivedDateTime: string;
  sender?: {
    emailAddress: {
      name?: string;
      address?: string;
    };
  };
  toRecipients?: Array<{
    emailAddress: {
      name?: string;
      address?: string;
    };
  }>;
  importance?: string;
  hasAttachments?: boolean;
  conversationId?: string;
  isRead?: boolean;
}

export interface GraphUser {
  id?: string;
  displayName?: string;
  mail?: string;
  department?: string;
  jobTitle?: string;
}

export class GraphService {
  private graphClient: Client;

  constructor(accessToken: string) {
    this.graphClient = Client.init({
      authProvider: (done) => {
        done(null, accessToken);
      },
    });
  }

  async getUserEmails(userId: string, options: {
    top?: number;
    skip?: number;
    orderBy?: string;
    filter?: string;
  } = {}): Promise<GraphEmailMessage[]> {
    try {
      const { top = 50, skip = 0, orderBy = 'receivedDateTime desc' } = options;

      const emails = await this.graphClient
        .api(`/users/${userId}/messages`)
        .top(top)
        .skip(skip)
        .orderby(orderBy)
        .select('id,subject,bodyPreview,receivedDateTime,sender,toRecipients,importance,hasAttachments,conversationId,isRead')
        .get();

      return emails.value || [];
    } catch (error) {
      console.error('Error fetching emails:', error);
      throw error;
    }
  }

  async getUserProfile(userId: string): Promise<GraphUser> {
    try {
      return await this.graphClient.api(`/users/${userId}`).get();
    } catch (error) {
      console.error('Error fetching user profile:', error);
      throw error;
    }
  }

  async getOrganizationUsers(): Promise<GraphUser[]> {
    try {
      const users = await this.graphClient
        .api('/users')
        .select('id,displayName,mail,department,jobTitle')
        .get();
      
      return users.value || [];
    } catch (error) {
      console.error('Error fetching organization users:', error);
      throw error;
    }
  }

  async getCurrentUser(): Promise<GraphUser> {
    try {
      return await this.graphClient.api('/me').get();
    } catch (error) {
      console.error('Error fetching current user:', error);
      throw error;
    }
  }
}
