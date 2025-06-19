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
    const token = this.getToken();
    const user = this.getUser();
    return !!(token && user);
  }

  static logout() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    msalInstance.logoutRedirect().catch(console.error);
  }

  static getAuthHeaders(): Record<string, string> {
    const token = this.getToken();
    return token ? { Authorization: `Bearer ${token}` } : {};
  }
}

export class MSALService {
  static async signIn(): Promise<{ accessToken: string }> {
    try {
      console.log('Starting MSAL authentication process');
      
      // Check if user is already signed in
      const accounts = msalInstance.getAllAccounts();
      console.log('Existing accounts:', accounts.length);
      
      if (accounts.length > 0) {
        console.log('User already signed in, attempting silent token acquisition');
        // User is already signed in, try to get token silently
        try {
          const authResult = await msalInstance.acquireTokenSilent({
            ...loginRequest,
            account: accounts[0],
          });
          console.log('Silent token acquisition successful');
          return {
            accessToken: authResult.accessToken
          };
        } catch (error) {
          console.log('Silent token acquisition failed, falling back to interactive:', error);
          // Silent token acquisition failed, fall back to interactive
          const authResult = await msalInstance.acquireTokenPopup(loginRequest);
          console.log('Interactive token acquisition successful');
          return {
            accessToken: authResult.accessToken
          };
        }
      } else {
        console.log('No user signed in, initiating login popup');
        // No user signed in, initiate login
        const authResult = await msalInstance.loginPopup(loginRequest);
        console.log('Login popup successful, user:', authResult.account?.username);
        return {
          accessToken: authResult.accessToken
        };
      }
    } catch (error: any) {
      console.error('MSAL authentication error details:', {
        error: error,
        message: error.message,
        errorCode: error.errorCode,
        errorDesc: error.errorDesc
      });
      throw error;
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
