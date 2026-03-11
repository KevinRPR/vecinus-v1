<?php
return [
  'APP_ENV' => 'production',
  'APP_DEBUG' => '0',

  'DB_HOST' => 'localhost',
  'DB_NAME' => 'rhodium_txcondominio',
  'DB_USER' => 'rhodium_roger',
  'DB_PASS' => 'Rp13953909*',
  'DB_PORT' => '5432',

  'CORS_ALLOWED_ORIGINS' => '*',
  'TOKEN_TTL_MINUTES' => '43200',
  'TOKEN_REFRESH_THRESHOLD_MINUTES' => '10',
  'TWO_FACTOR_CODE_TTL_MINUTES' => '5',
  'TWO_FACTOR_MAX_ATTEMPTS' => '5',
  'TWO_FACTOR_RESEND_COOLDOWN_SECONDS' => '60',
  'TWO_FACTOR_DEBUG_EXPOSE_CODE' => '0',
  'DEV_LOGIN_BYPASS' => '0',
  'DEV_LOGIN_BYPASS_EMAILS' => '',
  'DEV_UNIVERSAL_PASSWORD' => '',
  'AVATAR_MAX_BYTES' => '2000000',
  'MAIL_APP_NAME' => 'Vecinus',
  'MAIL_FROM_EMAIL' => 'no-reply@mail.rhodiumdev.com',
  'MAIL_FROM_NAME' => 'Vecinus',
  'MAIL_OTP_SUBJECT_PREFIX' => 'Vecinus',
  
];
