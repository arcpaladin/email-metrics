import { AuthUser } from './types';

const TOKEN_KEY = 'auth_token';
const USER_KEY = 'auth_user';

export class AuthManager {
  static setAuth(token: string, user: AuthUser) {
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(USER_KEY, JSON.stringify(user));
  }

  static getToken(): string | null {
    return localStorage.getItem(TOKEN_KEY);
  }

  static getUser(): AuthUser | null {
    const userStr = localStorage.getItem(USER_KEY);
    return userStr ? JSON.parse(userStr) : null;
  }

  static isAuthenticated(): boolean {
    return !!this.getToken();
  }

  static logout() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
  }

  static getAuthHeaders() {
    const token = this.getToken();
    return token ? { Authorization: `Bearer ${token}` } : {};
  }
}

// Microsoft Graph SDK mock for authentication
export class MockMSAL {
  static async signIn(): Promise<{ accessToken: string }> {
    // In a real implementation, this would use @azure/msal-browser
    // For demo purposes, we'll simulate the OAuth flow
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({
          accessToken: 'mock_access_token_' + Math.random().toString(36).substr(2, 9)
        });
      }, 1000);
    });
  }
}
