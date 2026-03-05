<?php

return [
    'APP_ENV' => 'local',
    'APP_DEBUG' => '1',
    'DB_HOST' => 'localhost',
    'DB_NAME' => 'database_name',
    'DB_USER' => 'database_user',
    'DB_PASS' => 'database_password',
    'DB_PORT' => '5432',
    'CORS_ALLOWED_ORIGINS' => 'http://localhost:3000,http://127.0.0.1:3000',
    'TOKEN_TTL_MINUTES' => '43200',
    'TOKEN_REFRESH_THRESHOLD_MINUTES' => '10',
    'DEV_LOGIN_BYPASS' => '0',
    'DEV_LOGIN_BYPASS_EMAILS' => 'test@example.com',
    'AVATAR_MAX_BYTES' => '2000000',
];
