import { msalInstance, loginRequest } from './msal-config';
import { AuthenticationResult } from '@azure/msal-browser';
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
    msalInstance.logoutRedirect().catch(console.error);
  }

  static getAuthHeaders() {
    const token = this.getToken();
    return token ? { Authorization: `Bearer ${token}` } : {};
  }
}

export class MSALService {
  static async signIn(): Promise<{ accessToken: string }> {
    try {
      // Check if user is already signed in
      const accounts = msalInstance.getAllAccounts();
      
      if (accounts.length > 0) {
        // User is already signed in, try to get token silently
        try {
          const authResult = await msalInstance.acquireTokenSilent({
            ...loginRequest,
            account: accounts[0],
          });
          return {
            accessToken: authResult.accessToken
          };
        } catch (error) {
          // Silent token acquisition failed, fall back to interactive
          const authResult = await msalInstance.acquireTokenPopup(loginRequest);
          return {
            accessToken: authResult.accessToken
          };
        }
      } else {
        // No user signed in, initiate login
        const authResult = await msalInstance.loginPopup(loginRequest);
        return {
          accessToken: authResult.accessToken
        };
      }
    } catch (error: any) {
      console.error('Authentication error:', error);
      throw new Error('Microsoft Graph API authentication failed. Please ensure your Azure AD application is properly configured with the required permissions.');
    }
  }

  static async handleRedirectPromise(): Promise<{ accessToken: string } | null> {
    try {
      const response = await msalInstance.handleRedirectPromise();
      if (response) {
        return {
          accessToken: response.accessToken
        };
      }
      return null;
    } catch (error) {
      console.error('Redirect handling error:', error);
      return null;
    }
  }
}
