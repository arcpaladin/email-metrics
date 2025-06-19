#!/bin/bash

# Setup Local HTTPS for Email Analytics Dashboard
# This script generates SSL certificates and configures HTTPS for local development

set -e

echo "🔐 Setting up HTTPS for local development..."

# Check if OpenSSL is available
if ! command -v openssl &> /dev/null; then
    echo "❌ OpenSSL is required but not installed. Please install OpenSSL first."
    exit 1
fi

# Generate SSL certificates if they don't exist
if [ ! -f "key.pem" ] || [ ! -f "cert.pem" ]; then
    echo "📜 Generating SSL certificates..."
    
    # Generate private key
    openssl genrsa -out key.pem 2048
    
    # Generate certificate signing request
    openssl req -new -key key.pem -out csr.pem -subj "/C=US/ST=CA/L=San Francisco/O=Development/CN=localhost"
    
    # Generate self-signed certificate
    openssl x509 -req -days 365 -in csr.pem -signkey key.pem -out cert.pem
    
    # Clean up CSR file
    rm csr.pem
    
    echo "✅ SSL certificates generated successfully"
else
    echo "✅ SSL certificates already exist"
fi

# Set proper permissions
chmod 600 key.pem
chmod 644 cert.pem

# Update environment variables for HTTPS
if [ -f ".env.local" ]; then
    # Update existing .env.local file
    if grep -q "VITE_REDIRECT_URI" .env.local; then
        sed -i.bak 's|VITE_REDIRECT_URI=.*|VITE_REDIRECT_URI=https://localhost:5001|' .env.local
        echo "✅ Updated VITE_REDIRECT_URI in .env.local"
    else
        echo "VITE_REDIRECT_URI=https://localhost:5001" >> .env.local
        echo "✅ Added VITE_REDIRECT_URI to .env.local"
    fi
else
    echo "⚠️  .env.local file not found. Please create it with your environment variables."
fi

# Display setup information
echo ""
echo "🚀 Local HTTPS setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Configure your Azure app registration to accept https://localhost:5001 as a redirect URI"
echo "2. Update your .env.local file with your Azure credentials:"
echo "   - VITE_AZURE_CLIENT_ID=your-client-id"
echo "   - VITE_AZURE_TENANT_ID=your-tenant-id"
echo "3. Run 'npm run dev' to start the development server"
echo ""
echo "🌐 Your application will be available at:"
echo "   - HTTP:  http://localhost:5000  (for general access)"
echo "   - HTTPS: https://localhost:5001 (for Microsoft authentication)"
echo ""
echo "⚠️  Your browser will show a security warning for the self-signed certificate."
echo "   Click 'Advanced' → 'Proceed to localhost' to continue."
echo ""