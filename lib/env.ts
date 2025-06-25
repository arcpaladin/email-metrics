// Load environment variables first before any other imports
import { config } from "dotenv";
import { resolve } from "path";

// Only load .env files in development - production uses runtime environment variables
if (process.env.NODE_ENV === "development") {
  config({ path: resolve(process.cwd(), ".env.local") });
  config({ path: resolve(process.cwd(), ".env.development") });
  config({ path: resolve(process.cwd(), ".env") });
  
  console.log("Environment variables loaded:");
  console.log("- DATABASE_URL:", process.env.DATABASE_URL ? `✓ Set (${process.env.DATABASE_URL.substring(0, 30)}...)` : "✗ Missing");
  console.log("- OPENAI_API_KEY:", process.env.OPENAI_API_KEY ? "✓ Set" : "✗ Missing");
  console.log("- VITE_AZURE_CLIENT_ID:", process.env.VITE_AZURE_CLIENT_ID ? "✓ Set" : "✗ Missing");
  console.log("- JWT_SECRET:", process.env.JWT_SECRET ? "✓ Set" : "✗ Missing");
} else {
  // Production - just log status of runtime environment variables
  console.log("Production environment variables:");
  console.log("- NODE_ENV:", process.env.NODE_ENV);
  console.log("- PORT:", process.env.PORT);
  console.log("- DATABASE_URL:", process.env.DATABASE_URL ? "✓ Set" : "✗ Missing");
  console.log("- JWT_SECRET:", process.env.JWT_SECRET ? "✓ Set" : "✗ Missing");
}