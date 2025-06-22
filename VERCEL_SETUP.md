# Vercel Deployment Setup Guide

## Quick Fix Applied

✅ **Created `vercel.json`** - Configures Vercel to build only the frontend
✅ **Updated `package.json`** - Separated frontend build from full build
✅ **Added SPA routing** - Handles client-side routing properly

## Environment Variables Setup

After deploying, you need to set these environment variables in your Vercel dashboard:

### 1. Go to Vercel Dashboard
- Visit [vercel.com/dashboard](https://vercel.com/dashboard)
- Select your `email-metrics` project
- Go to **Settings** → **Environment Variables**

### 2. Add These Variables

```bash
# API Configuration (Your AWS Backend)
VITE_API_URL=http://your-aws-ec2-ip

# Microsoft Authentication
VITE_MICROSOFT_CLIENT_ID=your-microsoft-client-id
VITE_MICROSOFT_TENANT_ID=your-microsoft-tenant-id
VITE_MICROSOFT_REDIRECT_URI=https://email-metrics-taupe.vercel.app/auth/callback

# App Configuration
VITE_APP_NAME=Email Analytics Dashboard
VITE_NODE_ENV=production
```

### 3. Deploy
After adding environment variables:
- Go to **Deployments** tab
- Click **Redeploy** on the latest deployment
- Or push a new commit to trigger automatic deployment

## What's Fixed

### Before (Broken)
```
https://email-metrics-taupe.vercel.app/
└── Shows: client/index.js (file listing)
```

### After (Working)
```
https://email-metrics-taupe.vercel.app/
├── / → React App (redirects to /login or /dashboard)
├── /login → Login Page
├── /dashboard → Dashboard (when authenticated)
└── All routes → Properly handled by React Router
```

## File Changes Made

1. **`vercel.json`** - New file
   - Configures build command: `npm run build`
   - Sets output directory: `dist/public`
   - Adds SPA routing rewrites
   - Optimizes asset caching

2. **`package.json`** - Updated
   - `build`: Frontend only (for Vercel)
   - `build:full`: Frontend + Backend (for AWS)

## Next Steps

1. **Set environment variables** in Vercel dashboard
2. **Redeploy** the application
3. **Test** the deployment at https://email-metrics-taupe.vercel.app/
4. **Deploy backend** to AWS using `./deploy.sh`

## Troubleshooting

If you still see issues:

1. **Check build logs** in Vercel dashboard
2. **Verify environment variables** are set correctly
3. **Ensure AWS backend** is running and accessible
4. **Check browser console** for any API connection errors

The main fix was telling Vercel how to properly build and serve your React app instead of showing the raw file structure.
