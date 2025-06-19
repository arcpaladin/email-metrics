import { Configuration, PublicClientApplication } from '@azure/msal-browser';

// Get the appropriate redirect URI based on environment
const getRedirectUri = () => {
  if (import.meta.env.DEV) {
    // Use HTTPS for development if available, fallback to HTTP
    return window.location.protocol === 'https:' 
      ? `${window.location.origin}/`
      : 'https://localhost:5001/';
  }
  return `${window.location.origin}/`;
};

export const msalConfig: Configuration = {
  auth: {
    clientId: import.meta.env.VITE_AZURE_CLIENT_ID || '00000000-0000-0000-0000-000000000000',
    authority: `https://login.microsoftonline.com/${import.meta.env.VITE_AZURE_TENANT_ID || 'common'}`,
    redirectUri: getRedirectUri(),
    postLogoutRedirectUri: getRedirectUri(),
  },
  cache: {
    cacheLocation: 'localStorage',
    storeAuthStateInCookie: false,
  },

};

export const loginRequest = {
  scopes: [
    'User.Read',
    'Mail.Read'
  ],
};

export const msalInstance = new PublicClientApplication(msalConfig);

// Initialize MSAL
msalInstance.initialize().catch(console.error);