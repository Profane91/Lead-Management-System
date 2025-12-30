#!/bin/bash
# PostgreSQL Initialization Script
# Creates non-root database user for n8n with proper permissions

set -e

echo "Initializing additional PostgreSQL users and permissions..."

# Create non-root user for n8n if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create non-root user if not exists
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${POSTGRES_NON_ROOT_USER}') THEN
            CREATE USER ${POSTGRES_NON_ROOT_USER} WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
        END IF;
    END
    \$\$;

    -- Grant privileges on database
    GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_NON_ROOT_USER};
    
    -- Grant schema privileges
    GRANT ALL PRIVILEGES ON SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
    
    -- Grant privileges on all tables in public schema
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
    
    -- Grant privileges on all sequences in public schema
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
    
    -- Grant default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO ${POSTGRES_NON_ROOT_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO ${POSTGRES_NON_ROOT_USER};
    
    -- Allow the user to create extensions if needed
    GRANT CREATE ON SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
EOSQL

echo "PostgreSQL initialization completed successfully."
echo "User '${POSTGRES_NON_ROOT_USER}' has been created with appropriate permissions."
