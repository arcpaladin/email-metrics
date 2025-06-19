# Azure App Registration Setup Guide

## Configure Azure App Registration for Local Development

### Step 1: Access Azure Portal
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Select your application (ID: `bf2af7cb-a6f7-4675-bb2f-3adc2b4ce94c`)

### Step 2: Configure Authentication
1. Click on **Authentication** in the left sidebar
2. Under **Platform configurations**, click **Add a platform**
3. Select **Single-page application (SPA)**
4. Add these redirect URIs:
   ```
   https://localhost:5001/
   https://localhost:5001
   http://localhost:5000/
   http://localhost:5000
   ```

### Step 3: Configure Token Settings
1. In the **Authentication** section, ensure these are checked:
   - ✅ Access tokens (used for implicit flows)
   - ✅ ID tokens (used for implicit and hybrid flows)

### Step 4: API Permissions
1. Click on **API permissions** in the left sidebar
2. Ensure these Microsoft Graph permissions are granted:
   - `User.Read` (delegated)
   - `Mail.Read` (delegated)
3. Click **Grant admin consent** if required

### Step 5: Get Your Application Details
1. Go to **Overview** section
2. Copy these values to your `.env.local` file:
   - **Application (client) ID** → `VITE_AZURE_CLIENT_ID`
   - **Directory (tenant) ID** → `VITE_AZURE_TENANT_ID`

### Troubleshooting Common Issues

#### Redirect URI Mismatch Error
- Ensure exact match including trailing slashes
- Check both HTTP and HTTPS variants are added
- Verify the application type is set to **Single-page application (SPA)**

#### Permission Issues
- Ensure admin consent is granted for Mail.Read permission
- Check that the user has a valid Microsoft 365 license

#### Authentication Flow Issues
- Clear browser cache and localStorage
- Verify the tenant ID is correct
- Ensure the application is not disabled

### Example .env.local Configuration
```env
VITE_AZURE_CLIENT_ID=bf2af7cb-a6f7-4675-bb2f-3adc2b4ce94c
VITE_AZURE_TENANT_ID=your-tenant-id-here
VITE_REDIRECT_URI=https://localhost:5001/
```

### Testing Authentication
1. Run `npm run dev`
2. Navigate to `https://localhost:5001`
3. Click "Sign in with Microsoft"
4. Complete the authentication flow
5. Verify email data loads in the dashboard