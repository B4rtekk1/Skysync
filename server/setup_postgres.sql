CREATE DATABASE skysync;

CREATE USER skysync_user WITH ENCRYPTED PASSWORD 'changeme_strong_password';

GRANT ALL PRIVILEGES ON DATABASE skysync TO skysync_user;

\c skysync

GRANT ALL ON SCHEMA public TO skysync_user;
GRANT CREATE ON SCHEMA public TO skysync_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO skysync_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO skysync_user;

SELECT version();
\l skysync
\du skysync_user
