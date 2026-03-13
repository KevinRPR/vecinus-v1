-- Ejecutar con un usuario con permisos de DDL (owner o superuser).
-- Ajusta:
--   1) menu_login_api por el usuario real de tu API.
--   2) tu_base_de_datos por el nombre real de tu DB.

ALTER TABLE menu_login.usuario
    ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS two_factor_channel VARCHAR(16) NULL,
    ADD COLUMN IF NOT EXISTS two_factor_updated_at TIMESTAMP NULL;

CREATE TABLE IF NOT EXISTS menu_login.user_two_factor_challenge (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    purpose VARCHAR(24) NOT NULL DEFAULT 'two_factor',
    code_hash VARCHAR(128) NOT NULL,
    channel VARCHAR(16) NOT NULL DEFAULT 'email',
    target_hint VARCHAR(120) NULL,
    target_value VARCHAR(180) NULL,
    expires_at TIMESTAMP NOT NULL,
    attempts INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 5,
    consumed_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_u2f_user_created
ON menu_login.user_two_factor_challenge (user_id, created_at DESC);

-- Permisos minimos para el usuario de la API.
GRANT CONNECT ON DATABASE tu_base_de_datos TO menu_login_api;
GRANT USAGE ON SCHEMA menu_login TO menu_login_api;

GRANT SELECT, INSERT, UPDATE ON TABLE menu_login.usuario TO menu_login_api;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE menu_login.user_two_factor_challenge TO menu_login_api;

-- Necesario si se usa SERIAL (secuencia para id).
GRANT USAGE, SELECT ON SEQUENCE menu_login.user_two_factor_challenge_id_seq TO menu_login_api;
