<?php

function _load_env(): array {
    static $env = null;
    if ($env !== null) {
        return $env;
    }

    $env = [];
    $localPath = __DIR__ . '/env.local.php';
    if (file_exists($localPath)) {
        $local = require $localPath;
        if (is_array($local)) {
            $env = $local;
        }
    }

    $keys = [
        'APP_ENV',
        'APP_DEBUG',
        'DB_HOST',
        'DB_NAME',
        'DB_USER',
        'DB_PASS',
        'DB_PORT',
        'CORS_ALLOWED_ORIGINS',
        'TOKEN_TTL_MINUTES',
        'TOKEN_REFRESH_THRESHOLD_MINUTES',
        'TWO_FACTOR_CODE_TTL_MINUTES',
        'TWO_FACTOR_MAX_ATTEMPTS',
        'TWO_FACTOR_RESEND_COOLDOWN_SECONDS',
        'TWO_FACTOR_DEBUG_EXPOSE_CODE',
        'DEV_LOGIN_BYPASS',
        'DEV_LOGIN_BYPASS_EMAILS',
        'DEV_UNIVERSAL_PASSWORD',
        'AVATAR_MAX_BYTES',
        'MAIL_APP_NAME',
        'MAIL_FROM_EMAIL',
        'MAIL_FROM_NAME',
        'MAIL_OTP_SUBJECT_PREFIX',
        'SMTP_HOST',
        'SMTP_PORT',
        'SMTP_USERNAME',
        'SMTP_PASSWORD',
        'SMTP_SECURE',
        'SMTP_TIMEOUT_SECONDS',
        'EVIDENCE_MAX_BYTES',
    ];

    foreach ($keys as $key) {
        $value = getenv($key);
        if ($value !== false && $value !== '') {
            $env[$key] = $value;
        }
    }

    return $env;
}

function env_value(string $key, $default = null) {
    $env = _load_env();
    return array_key_exists($key, $env) ? $env[$key] : $default;
}

function env_bool(string $key, bool $default = false): bool {
    $value = env_value($key, null);
    if ($value === null) {
        return $default;
    }
    $normalized = strtolower(trim((string)$value));
    return in_array($normalized, ['1', 'true', 'yes', 'on'], true);
}

function env_int(string $key, int $default): int {
    $value = env_value($key, null);
    if ($value === null) {
        return $default;
    }
    $parsed = (int)$value;
    return $parsed > 0 ? $parsed : $default;
}

function env_list(string $key): array {
    $raw = env_value($key, '');
    if (!is_string($raw) || $raw === '') {
        return [];
    }
    $parts = array_map('trim', explode(',', $raw));
    return array_values(array_filter($parts, fn($item) => $item !== ''));
}
