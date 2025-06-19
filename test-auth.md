# Authentication Testing Guide

## Current Configuration
- Application ID: `bf2af7cb-a6f7-4675-bb2f-3adc2b4ce94c`
- Tenant ID: `e2a77653-f63f-4609-8e8d-c76e4b63ec7a`
- Local URLs: HTTP port 5000, HTTPS port 5001

## Azure Portal Configuration Required

1. **Go to Azure Portal**: https://portal.azure.com
2. **Navigate to**: Azure Active Directory > App registrations
3. **Find your app**: Search for ID `bf2af7cb-a6f7-4675-bb2f-3adc2b4ce94c`
4. **Click Authentication** in the left sidebar
5. **Add Platform**: Single-page application (SPA)
6. **Add these redirect URIs**:
   ```
   https://localhost:5001/
   https://localhost:5001
   http://localhost:5000/
   http://localhost:5000
   ```

7. **Token Configuration**:
   - ✅ Access tokens (used for implicit flows)
   - ✅ ID tokens (used for implicit and hybrid flows)

8. **API Permissions**:
   - Microsoft Graph > User.Read (Delegated)
   - Microsoft Graph > Mail.Read (Delegated)
   - Click "Grant admin consent"

## Testing Steps

1. Open https://localhost:5001 in your browser
2. Accept the security warning for self-signed certificate
3. Click "Sign in with Microsoft"
4. Complete authentication with your Microsoft account
5. Check browser console for detailed authentication logs

## Troubleshooting

If authentication still fails, check:
- Browser console for MSAL error details
- Network tab for failed requests
- Ensure popup blockers are disabled
- Clear browser cache and localStorage
- Verify the Azure app has the correct permissions granted