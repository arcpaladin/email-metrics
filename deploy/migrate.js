import { neon } from '@neondatabase/serverless';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const sql = neon(process.env.DATABASE_URL);

async function runMigrations() {
  console.log('Starting database migrations...');
  
  try {
    // Create organizations table
    await sql`
      CREATE TABLE IF NOT EXISTS organizations (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        domain TEXT NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `;
    console.log('✅ Organizations table created/verified');

    // Create employees table
    await sql`
      CREATE TABLE IF NOT EXISTS employees (
        id SERIAL PRIMARY KEY,
        organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
        email TEXT NOT NULL UNIQUE,
        display_name TEXT,
        department TEXT,
        role TEXT,
        last_sync_at TIMESTAMP,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `;
    console.log('✅ Employees table created/verified');

    // Create emails table
    await sql`
      CREATE TABLE IF NOT EXISTS emails (
        id SERIAL PRIMARY KEY,
        message_id TEXT NOT NULL UNIQUE,
        conversation_id TEXT,
        sender_id INTEGER REFERENCES employees(id) ON DELETE SET NULL,
        subject TEXT,
        body_preview TEXT,
        received_at TIMESTAMP NOT NULL,
        is_read BOOLEAN DEFAULT FALSE,
        importance TEXT CHECK (importance IN ('low', 'normal', 'high')),
        has_attachments BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `;
    console.log('✅ Emails table created/verified');

    // Create email_analysis table
    await sql`
      CREATE TABLE IF NOT EXISTS email_analysis (
        id SERIAL PRIMARY KEY,
        email_id INTEGER REFERENCES emails(id) ON DELETE CASCADE,
        sentiment TEXT CHECK (sentiment IN ('positive', 'negative', 'neutral')),
        urgency_score DECIMAL(3,2) CHECK (urgency_score >= 0 AND urgency_score <= 1),
        topics TEXT[],
        action_items TEXT[],
        key_entities JSONB,
        ai_summary TEXT,
        processing_version TEXT DEFAULT '1.0',
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `;
    console.log('✅ Email analysis table created/verified');

    // Create tasks table
    await sql`
      CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        assigned_to_id INTEGER REFERENCES employees(id) ON DELETE SET NULL,
        status TEXT DEFAULT 'identified' CHECK (status IN ('identified', 'in_progress', 'completed', 'cancelled')),
        priority TEXT CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
        due_date TIMESTAMP,
        confidence_score DECIMAL(3,2) CHECK (confidence_score >= 0 AND confidence_score <= 1),
        source_email_id INTEGER REFERENCES emails(id) ON DELETE SET NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );
    `;
    console.log('✅ Tasks table created/verified');

    // Create indexes for better performance
    await sql`
      CREATE INDEX IF NOT EXISTS idx_employees_email ON employees(email);
      CREATE INDEX IF NOT EXISTS idx_employees_organization ON employees(organization_id);
      CREATE INDEX IF NOT EXISTS idx_emails_sender ON emails(sender_id);
      CREATE INDEX IF NOT EXISTS idx_emails_received_at ON emails(received_at DESC);
      CREATE INDEX IF NOT EXISTS idx_emails_message_id ON emails(message_id);
      CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON tasks(assigned_to_id);
      CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
      CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
    `;
    console.log('✅ Database indexes created/verified');

    // Create updated_at trigger function
    await sql`
      CREATE OR REPLACE FUNCTION update_updated_at_column()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
      END;
      $$ language 'plpgsql';
    `;
    console.log('✅ Updated_at trigger function created');

    // Create triggers for updated_at columns
    const tables = ['organizations', 'employees', 'emails', 'email_analysis', 'tasks'];
    for (const table of tables) {
      await sql`
        DROP TRIGGER IF EXISTS ${sql(table)}_updated_at_trigger ON ${sql(table)};
        CREATE TRIGGER ${sql(table)}_updated_at_trigger
          BEFORE UPDATE ON ${sql(table)}
          FOR EACH ROW
          EXECUTE FUNCTION update_updated_at_column();
      `;
    }
    console.log('✅ Updated_at triggers created for all tables');

    console.log('\n🎉 Database migrations completed successfully!');
    console.log('Database is ready for the Email Analytics application.');
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

// Run migrations if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  runMigrations()
    .then(() => {
      console.log('Migration process completed.');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Migration process failed:', error);
      process.exit(1);
    });
}

export { runMigrations };
