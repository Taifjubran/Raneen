-- Initial database setup for Raneen
-- This file is executed when the PostgreSQL container is first created

-- Create development database if it doesn't exist
SELECT 'CREATE DATABASE raneen_development'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'raneen_development')\gexec

-- Create test database if it doesn't exist  
SELECT 'CREATE DATABASE raneen_test'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'raneen_test')\gexec

-- Connect to the development database
\c raneen_development;

-- Enable required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For text search improvements

-- Grant all privileges to postgres user
GRANT ALL PRIVILEGES ON DATABASE raneen_development TO postgres;
GRANT ALL PRIVILEGES ON DATABASE raneen_test TO postgres;