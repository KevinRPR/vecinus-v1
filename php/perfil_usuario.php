<?php

header("Content-Type: application/json; charset=UTF-8");

require_once(__DIR__ . "/config/conexion.php");
require_once(__DIR__ . "/helpers.php");

apply_cors();
handle_preflight();

$conn = ConexionAPI::getInstance();
$input = json_decode(file_get_contents("php://input"), true) ?? [];

$token = trim($input['token'] ?? '');
$action = strtolower(trim($input['accion'] ?? 'consultar'));

if (!$token) {
    respond_error("Token requerido.", 400);
}

try {
    $userId = resolve_user_id_from_token($conn, $token);
} catch (Exception $e) {
    respond_error("Token invalido o expirado.", 401);
}

try {
    switch ($action) {
        case 'actualizar':
        case 'update':
            update_profile($conn, $userId, $input);
            break;
        case 'password':
        case 'contrasena':
        case 'cambiar_password':
            change_password($conn, $userId, $input);
            break;
        case 'avatar':
        case 'foto':
        case 'imagen':
            update_avatar($conn, $userId, $input);
            break;
        case '2fa_status':
        case 'two_factor_status':
            ensure_security_schema($conn);
            send_two_factor_status($conn, $userId);
            break;
        case '2fa_request':
        case 'two_factor_request':
            ensure_security_schema($conn);
            request_two_factor_code($conn, $userId, $input);
            break;
        case '2fa_verify':
        case 'two_factor_verify':
            ensure_security_schema($conn);
            verify_two_factor_code($conn, $userId, $input);
            break;
        case '2fa_disable':
        case 'two_factor_disable':
            ensure_security_schema($conn);
            disable_two_factor($conn, $userId);
            break;
        case '2fa_enable':
        case 'two_factor_enable':
            respond_error("Usa 2fa_verify para activar 2FA.", 400);
            break;
        case 'contact_verification_request':
            ensure_security_schema($conn);
            request_contact_verification($conn, $userId, $input);
            break;
        default:
            send_profile($conn, $userId);
            break;
    }
} catch (Exception $e) {
    respond_error($e->getMessage(), 400);
}

function ensure_security_schema(PDO $conn): void {
    if (security_schema_ready($conn)) {
        return;
    }

    try {
        $conn->exec("
            ALTER TABLE menu_login.usuario
                ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS two_factor_channel VARCHAR(16) NULL,
                ADD COLUMN IF NOT EXISTS two_factor_updated_at TIMESTAMP NULL;
        ");

        $conn->exec("
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
        ");

        $conn->exec("
            CREATE INDEX IF NOT EXISTS idx_u2f_user_created
            ON menu_login.user_two_factor_challenge (user_id, created_at DESC);
        ");
    } catch (Throwable $e) {
        // If another process created it meanwhile, continue normally.
        if (security_schema_ready($conn)) {
            return;
        }
        log_error('2FA schema bootstrap failed', [
            'error' => $e->getMessage(),
        ]);
        throw new Exception(
            'La configuracion de 2FA no esta lista en el servidor. Ejecuta la migracion SQL con un usuario administrador.'
        );
    }
}

function security_schema_ready(PDO $conn): bool {
    $colsStmt = $conn->query("
        SELECT COUNT(*)::INT AS total
        FROM information_schema.columns
        WHERE table_schema = 'menu_login'
          AND table_name = 'usuario'
          AND column_name IN ('two_factor_enabled', 'two_factor_channel', 'two_factor_updated_at')
    ");
    $cols = (int)($colsStmt->fetch(PDO::FETCH_ASSOC)['total'] ?? 0);
    if ($cols < 3) {
        return false;
    }

    $tableStmt = $conn->query("SELECT to_regclass('menu_login.user_two_factor_challenge') AS tbl");
    $table = (string)($tableStmt->fetch(PDO::FETCH_ASSOC)['tbl'] ?? '');
    return $table !== '';
}

function send_profile(PDO $conn, int $userId): void {
    $stmt = $conn->prepare("
        SELECT id_usuario, nombre, apellido, correo
        FROM menu_login.usuario
        WHERE id_usuario = :id
        LIMIT 1
    ");
    $stmt->execute([":id" => $userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        respond_error("Usuario no encontrado.", 404);
    }

    respond_success(["usuario" => build_user_payload($user)]);
}

function send_two_factor_status(PDO $conn, int $userId): void {
    $stmt = $conn->prepare("
        SELECT two_factor_enabled, two_factor_channel
        FROM menu_login.usuario
        WHERE id_usuario = :id
        LIMIT 1
    ");
    $stmt->execute([":id" => $userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];

    respond_success([
        "enabled" => ($row['two_factor_enabled'] ?? false) ? true : false,
        "channel" => $row['two_factor_channel'] ?? null,
    ]);
}

function request_two_factor_code(PDO $conn, int $userId, array $input): void {
    $channel = strtolower(trim($input['canal'] ?? 'email'));
    if (!in_array($channel, ['email', 'sms'], true)) {
        $channel = 'email';
    }

    $user = load_user_contact($conn, $userId);
    $contact = (string)($user['correo'] ?? '');
    $hint = mask_email($contact);

    create_otp_challenge(
        $conn,
        $userId,
        'two_factor',
        $channel,
        $hint,
        $contact
    );
}

function verify_two_factor_code(PDO $conn, int $userId, array $input): void {
    $code = preg_replace('/\D+/', '', (string)($input['codigo'] ?? ''));
    if ($code === '' || strlen($code) !== 6) {
        respond_error("Codigo OTP invalido.", 400);
    }

    $challenge = load_active_challenge($conn, $userId, 'two_factor');
    if (!$challenge) {
        respond_error("No hay un codigo activo para validar.", 400);
    }

    $expiresAt = strtotime((string)$challenge['expires_at']);
    if ($expiresAt === false || $expiresAt < time()) {
        consume_challenge($conn, (int)$challenge['id']);
        respond_error("El codigo OTP expiro. Solicita uno nuevo.", 400);
    }

    $attempts = (int)($challenge['attempts'] ?? 0);
    $maxAttempts = (int)($challenge['max_attempts'] ?? 5);
    if ($attempts >= $maxAttempts) {
        respond_error("Demasiados intentos. Solicita un codigo nuevo.", 429);
    }

    $expectedHash = (string)($challenge['code_hash'] ?? '');
    $providedHash = otp_hash($userId, $code);
    if (!hash_equals($expectedHash, $providedHash)) {
        $update = $conn->prepare("
            UPDATE menu_login.user_two_factor_challenge
            SET attempts = attempts + 1
            WHERE id = :id
        ");
        $update->execute([":id" => $challenge['id']]);
        respond_error("Codigo OTP incorrecto.", 400);
    }

    consume_challenge($conn, (int)$challenge['id']);

    $channel = (string)($challenge['channel'] ?? 'email');
    $stmt = $conn->prepare("
        UPDATE menu_login.usuario
        SET two_factor_enabled = TRUE,
            two_factor_channel = :channel,
            two_factor_updated_at = NOW()
        WHERE id_usuario = :id
    ");
    $stmt->execute([
        ":channel" => $channel,
        ":id" => $userId,
    ]);

    respond_success([
        "enabled" => true,
        "channel" => $channel,
    ]);
}

function disable_two_factor(PDO $conn, int $userId): void {
    $stmt = $conn->prepare("
        UPDATE menu_login.usuario
        SET two_factor_enabled = FALSE,
            two_factor_channel = NULL,
            two_factor_updated_at = NOW()
        WHERE id_usuario = :id
    ");
    $stmt->execute([":id" => $userId]);

    $cleanup = $conn->prepare("
        UPDATE menu_login.user_two_factor_challenge
        SET consumed_at = NOW()
        WHERE user_id = :id
          AND consumed_at IS NULL
    ");
    $cleanup->execute([":id" => $userId]);

    respond_success([
        "enabled" => false,
        "channel" => null,
    ]);
}

function request_contact_verification(PDO $conn, int $userId, array $input): void {
    $kind = strtolower(trim((string)($input['tipo'] ?? '')));
    $value = trim((string)($input['valor'] ?? ''));
    if (!in_array($kind, ['email', 'phone'], true)) {
        respond_error("Tipo de verificacion invalido.", 400);
    }
    if ($value === '') {
        respond_error("Valor requerido para verificar contacto.", 400);
    }

    if ($kind === 'email' && !filter_var($value, FILTER_VALIDATE_EMAIL)) {
        respond_error("Correo invalido.", 400);
    }
    if ($kind === 'phone') {
        $digits = preg_replace('/\D+/', '', $value);
        if ($digits === null || strlen($digits) < 7) {
            respond_error("Telefono invalido.", 400);
        }
    }

    $purpose = $kind === 'email' ? 'contact_email' : 'contact_phone';
    $hint = $kind === 'email' ? mask_email($value) : mask_phone($value);
    $channel = $kind === 'email' ? 'email' : 'sms';

    create_otp_challenge(
        $conn,
        $userId,
        $purpose,
        $channel,
        $hint,
        $value
    );
}

function create_otp_challenge(
    PDO $conn,
    int $userId,
    string $purpose,
    string $channel,
    ?string $targetHint,
    ?string $targetValue
): void {
    $cooldownSeconds = env_int('TWO_FACTOR_RESEND_COOLDOWN_SECONDS', 60);
    $lastChallengeStmt = $conn->prepare("
        SELECT created_at
        FROM menu_login.user_two_factor_challenge
        WHERE user_id = :id
          AND purpose = :purpose
        ORDER BY created_at DESC
        LIMIT 1
    ");
    $lastChallengeStmt->execute([
        ":id" => $userId,
        ":purpose" => $purpose,
    ]);
    $lastChallenge = $lastChallengeStmt->fetch(PDO::FETCH_ASSOC);
    if ($lastChallenge && isset($lastChallenge['created_at'])) {
        $lastAt = strtotime((string)$lastChallenge['created_at']);
        if ($lastAt !== false) {
            $elapsed = time() - $lastAt;
            if ($elapsed < $cooldownSeconds) {
                $remaining = max(1, $cooldownSeconds - $elapsed);
                throw new Exception("Debes esperar {$remaining} segundo(s) para reenviar el codigo.");
            }
        }
    }

    $code = str_pad((string)random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    $hash = otp_hash($userId, $code);
    $ttlMinutes = env_int('TWO_FACTOR_CODE_TTL_MINUTES', 5);
    $maxAttempts = env_int('TWO_FACTOR_MAX_ATTEMPTS', 5);
    $expiresAt = date('Y-m-d H:i:s', strtotime("+{$ttlMinutes} minutes"));

    $invalidate = $conn->prepare("
        UPDATE menu_login.user_two_factor_challenge
        SET consumed_at = NOW()
        WHERE user_id = :id
          AND purpose = :purpose
          AND consumed_at IS NULL
    ");
    $invalidate->execute([
        ":id" => $userId,
        ":purpose" => $purpose,
    ]);

    $insert = $conn->prepare("
        INSERT INTO menu_login.user_two_factor_challenge
            (user_id, purpose, code_hash, channel, target_hint, target_value, expires_at, attempts, max_attempts)
        VALUES
            (:user_id, :purpose, :code_hash, :channel, :target_hint, :target_value, :expires_at, 0, :max_attempts)
    ");
    $insert->execute([
        ":user_id" => $userId,
        ":purpose" => $purpose,
        ":code_hash" => $hash,
        ":channel" => $channel,
        ":target_hint" => $targetHint,
        ":target_value" => $targetValue,
        ":expires_at" => $expiresAt,
        ":max_attempts" => $maxAttempts,
    ]);

    if ($channel === 'email') {
        $targetEmail = trim((string)($targetValue ?? ''));
        if ($targetEmail === '') {
            $user = load_user_contact($conn, $userId);
            $targetEmail = trim((string)($user['correo'] ?? ''));
        }

        if ($targetEmail === '' || !filter_var($targetEmail, FILTER_VALIDATE_EMAIL)) {
            throw new Exception('No hay un correo valido para enviar el codigo OTP.');
        }

        $sent = send_otp_email(
            $targetEmail,
            $code,
            $ttlMinutes,
            $purpose,
        );

        if (!$sent) {
            throw new Exception(
                'No se pudo enviar el codigo OTP al correo. Revisa la configuracion de correo del servidor.'
            );
        }
    }

    $payload = [
        "message" => "Codigo generado.",
        "purpose" => $purpose,
        "channel" => $channel,
        "target_hint" => $targetHint,
        "expires_at" => $expiresAt,
    ];

    if (env_bool('APP_DEBUG', false) || env_bool('TWO_FACTOR_DEBUG_EXPOSE_CODE', false)) {
        $payload["debug_code"] = $code;
    }

    respond_success($payload);
}

function load_active_challenge(PDO $conn, int $userId, string $purpose): ?array {
    $stmt = $conn->prepare("
        SELECT id, code_hash, expires_at, attempts, max_attempts, channel
        FROM menu_login.user_two_factor_challenge
        WHERE user_id = :id
          AND purpose = :purpose
          AND consumed_at IS NULL
        ORDER BY created_at DESC
        LIMIT 1
    ");
    $stmt->execute([
        ":id" => $userId,
        ":purpose" => $purpose,
    ]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    return $row ?: null;
}

function consume_challenge(PDO $conn, int $challengeId): void {
    $stmt = $conn->prepare("
        UPDATE menu_login.user_two_factor_challenge
        SET consumed_at = NOW()
        WHERE id = :id
    ");
    $stmt->execute([":id" => $challengeId]);
}

function load_user_contact(PDO $conn, int $userId): array {
    $stmt = $conn->prepare("
        SELECT id_usuario, correo
        FROM menu_login.usuario
        WHERE id_usuario = :id
        LIMIT 1
    ");
    $stmt->execute([":id" => $userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        respond_error("Usuario no encontrado.", 404);
    }
    return $row;
}

function otp_hash(int $userId, string $code): string {
    return hash('sha256', $userId . '|' . $code);
}

function mask_email(string $email): string {
    $email = trim($email);
    if ($email === '' || strpos($email, '@') === false) {
        return 'correo registrado';
    }
    [$name, $domain] = explode('@', $email, 2);
    if ($name === '') {
        return '***@' . $domain;
    }
    if (strlen($name) <= 2) {
        $masked = substr($name, 0, 1) . '*';
    } else {
        $masked = substr($name, 0, 2) . str_repeat('*', max(1, strlen($name) - 2));
    }
    return $masked . '@' . $domain;
}

function mask_phone(string $phone): string {
    $digits = preg_replace('/\D+/', '', $phone) ?? '';
    if ($digits === '') {
        return 'telefono registrado';
    }
    if (strlen($digits) <= 4) {
        return str_repeat('*', strlen($digits));
    }
    return str_repeat('*', strlen($digits) - 4) . substr($digits, -4);
}

function send_otp_email(
    string $to,
    string $code,
    int $ttlMinutes,
    string $purpose
): bool {
    $appName = trim((string)env_value('MAIL_APP_NAME', 'Vecinus'));
    $fromEmail = trim((string)env_value('MAIL_FROM_EMAIL', ''));
    $fromName = trim((string)env_value('MAIL_FROM_NAME', $appName));
    $subjectPrefix = trim((string)env_value('MAIL_OTP_SUBJECT_PREFIX', $appName));
    $subject = $subjectPrefix !== ''
        ? "{$subjectPrefix}: Codigo de verificacion"
        : 'Codigo de verificacion';

    $purposeLabel = 'verificacion de seguridad';
    if ($purpose === 'two_factor') {
        $purposeLabel = 'activacion de autenticacion en dos pasos';
    } elseif ($purpose === 'contact_email') {
        $purposeLabel = 'verificacion de correo';
    } elseif ($purpose === 'contact_phone') {
        $purposeLabel = 'verificacion de telefono';
    }

    $body = implode("\n", [
        "Hola,",
        "",
        "Tu codigo para {$purposeLabel} es: {$code}",
        "Este codigo vence en {$ttlMinutes} minuto(s).",
        "",
        "Si no solicitaste este codigo, ignora este correo.",
        "",
        $appName,
    ]);

    $smtpHost = trim((string)env_value('SMTP_HOST', ''));
    $smtpPort = (int)env_int('SMTP_PORT', 465);
    $smtpUsername = trim((string)env_value('SMTP_USERNAME', ''));
    $smtpPassword = (string)env_value('SMTP_PASSWORD', '');
    $smtpSecure = strtolower(trim((string)env_value('SMTP_SECURE', 'ssl')));
    $smtpTimeout = (int)env_int('SMTP_TIMEOUT_SECONDS', 15);

    if ($fromEmail === '') {
        $fromEmail = $smtpUsername;
    }

    if ($smtpHost !== '' && $smtpUsername !== '' && $smtpPassword !== '') {
        return smtp_send_mail(
            host: $smtpHost,
            port: $smtpPort > 0 ? $smtpPort : 465,
            secure: $smtpSecure,
            timeoutSeconds: $smtpTimeout > 0 ? $smtpTimeout : 15,
            username: $smtpUsername,
            password: $smtpPassword,
            fromEmail: $fromEmail,
            fromName: $fromName,
            toEmail: $to,
            subject: $subject,
            body: $body,
        );
    }

    if ($smtpHost !== '' || $smtpUsername !== '' || $smtpPassword !== '') {
        log_error('OTP SMTP config incomplete, using mail() fallback', [
            'smtp_host_set' => $smtpHost !== '',
            'smtp_user_set' => $smtpUsername !== '',
            'smtp_pass_set' => $smtpPassword !== '',
        ]);
    }

    // Fallback conservador para entornos que aun no tengan SMTP configurado.
    $headers = [
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
    ];
    if ($fromEmail !== '') {
        $safeName = preg_replace('/[\r\n]+/', ' ', $fromName) ?: $appName;
        $headers[] = "From: {$safeName} <{$fromEmail}>";
        $headers[] = "Reply-To: {$fromEmail}";
    }
    $sent = @mail($to, $subject, $body, implode("\r\n", $headers));
    if (!$sent) {
        $mailError = error_get_last();
        log_error('OTP mail() failed', [
            'to' => $to,
            'purpose' => $purpose,
            'error' => $mailError['message'] ?? null,
            'sendmail_path' => ini_get('sendmail_path'),
        ]);
    }
    return $sent;
}

function smtp_send_mail(
    string $host,
    int $port,
    string $secure,
    int $timeoutSeconds,
    string $username,
    string $password,
    string $fromEmail,
    string $fromName,
    string $toEmail,
    string $subject,
    string $body
): bool {
    $socket = null;
    try {
        if (!filter_var($toEmail, FILTER_VALIDATE_EMAIL)) {
            throw new RuntimeException('SMTP destinatario invalido.');
        }
        if (!filter_var($fromEmail, FILTER_VALIDATE_EMAIL)) {
            throw new RuntimeException('SMTP remitente invalido.');
        }

        $secureMode = strtolower(trim($secure));
        if (!in_array($secureMode, ['ssl', 'tls', 'none', ''], true)) {
            $secureMode = 'ssl';
        }

        $transport = $secureMode === 'ssl' ? 'ssl' : 'tcp';
        $remote = "{$transport}://{$host}:{$port}";
        $errno = 0;
        $errstr = '';
        $socket = @stream_socket_client(
            $remote,
            $errno,
            $errstr,
            $timeoutSeconds,
            STREAM_CLIENT_CONNECT
        );
        if ($socket === false) {
            throw new RuntimeException("No se pudo conectar a SMTP ({$errno}) {$errstr}");
        }
        stream_set_timeout($socket, $timeoutSeconds);

        smtp_expect_greeting($socket);
        smtp_send_command($socket, 'EHLO ' . smtp_helo_name(), [250], 'EHLO');

        if ($secureMode === 'tls') {
            smtp_send_command($socket, 'STARTTLS', [220], 'STARTTLS');
            $cryptoEnabled = @stream_socket_enable_crypto(
                $socket,
                true,
                STREAM_CRYPTO_METHOD_TLS_CLIENT
            );
            if ($cryptoEnabled !== true) {
                throw new RuntimeException('No se pudo habilitar TLS en SMTP.');
            }
            smtp_send_command($socket, 'EHLO ' . smtp_helo_name(), [250], 'EHLO (post TLS)');
        }

        smtp_send_command($socket, 'AUTH LOGIN', [334], 'AUTH LOGIN');
        smtp_send_command($socket, base64_encode($username), [334], 'SMTP username');
        smtp_send_command($socket, base64_encode($password), [235], 'SMTP password');

        smtp_send_command($socket, 'MAIL FROM:<' . $fromEmail . '>', [250], 'MAIL FROM');
        smtp_send_command($socket, 'RCPT TO:<' . $toEmail . '>', [250, 251], 'RCPT TO');
        smtp_send_command($socket, 'DATA', [354], 'DATA');

        $headers = [
            'Date: ' . date(DATE_RFC2822),
            'Message-ID: <' . bin2hex(random_bytes(12)) . '@' . smtp_message_domain() . '>',
            'From: ' . smtp_format_address($fromEmail, $fromName),
            'To: ' . $toEmail,
            'Subject: ' . smtp_encode_header($subject),
            'MIME-Version: 1.0',
            'Content-Type: text/plain; charset=UTF-8',
            'Content-Transfer-Encoding: 8bit',
            'Reply-To: ' . $fromEmail,
        ];
        $payload = implode("\r\n", $headers) . "\r\n\r\n" . normalize_crlf($body);
        smtp_send_data($socket, $payload);
        smtp_send_command($socket, '.', [250], 'SMTP message commit');
        smtp_send_command($socket, 'QUIT', [221], 'QUIT');
        return true;
    } catch (Throwable $e) {
        log_error('OTP SMTP send failed', [
            'to' => $toEmail,
            'host' => $host,
            'port' => $port,
            'secure' => $secure,
            'smtp_user' => $username,
            'smtp_password_len' => strlen($password),
            'smtp_password_hash8' => substr(hash('sha256', $password), 0, 8),
            'from' => $fromEmail,
            'error' => $e->getMessage(),
        ]);
        return false;
    } finally {
        if (is_resource($socket)) {
            @fclose($socket);
        }
    }
}

function smtp_expect_greeting($socket): void {
    $response = smtp_read_response($socket);
    $code = (int)substr($response, 0, 3);
    if ($code !== 220) {
        throw new RuntimeException('SMTP greeting invalido: ' . $response);
    }
}

function smtp_send_command($socket, string $command, array $expectedCodes, string $step): string {
    $written = @fwrite($socket, $command . "\r\n");
    if ($written === false) {
        throw new RuntimeException("No se pudo escribir comando SMTP en {$step}.");
    }
    $response = smtp_read_response($socket);
    $code = (int)substr($response, 0, 3);
    if (!in_array($code, $expectedCodes, true)) {
        throw new RuntimeException("SMTP {$step} fallo: {$response}");
    }
    return $response;
}

function smtp_read_response($socket): string {
    $response = '';
    $maxLines = 30;
    for ($i = 0; $i < $maxLines; $i++) {
        $line = fgets($socket, 2048);
        if ($line === false) {
            break;
        }
        $response .= $line;
        if (preg_match('/^\d{3}\s/', $line) === 1) {
            break;
        }
    }
    $response = trim($response);
    if ($response === '') {
        throw new RuntimeException('SMTP no devolvio respuesta.');
    }
    return $response;
}

function smtp_send_data($socket, string $data): void {
    $lines = preg_split("/\r\n|\n|\r/", $data);
    if ($lines === false) {
        $lines = [$data];
    }
    foreach ($lines as $line) {
        $safeLine = (string)$line;
        if (str_starts_with($safeLine, '.')) {
            $safeLine = '.' . $safeLine;
        }
        $written = @fwrite($socket, $safeLine . "\r\n");
        if ($written === false) {
            throw new RuntimeException('No se pudo enviar DATA por SMTP.');
        }
    }
}

function smtp_format_address(string $email, string $name): string {
    $cleanName = trim(preg_replace('/[\r\n]+/', ' ', $name) ?? '');
    if ($cleanName === '') {
        return $email;
    }
    return smtp_encode_header($cleanName) . " <{$email}>";
}

function smtp_encode_header(string $value): string {
    $clean = trim(preg_replace('/[\r\n]+/', ' ', $value) ?? '');
    if ($clean === '') {
        return '';
    }
    if (function_exists('mb_encode_mimeheader')) {
        return mb_encode_mimeheader($clean, 'UTF-8', 'B', "\r\n");
    }
    return '=?UTF-8?B?' . base64_encode($clean) . '?=';
}

function normalize_crlf(string $value): string {
    $normalized = preg_replace("/\r\n|\r|\n/", "\r\n", $value);
    return $normalized === null ? $value : $normalized;
}

function smtp_helo_name(): string {
    $host = $_SERVER['HTTP_HOST'] ?? gethostname() ?? 'localhost';
    $host = strtolower(trim((string)$host));
    return $host !== '' ? $host : 'localhost';
}

function smtp_message_domain(): string {
    $host = smtp_helo_name();
    if (strpos($host, ':') !== false) {
        $parts = explode(':', $host);
        return $parts[0] !== '' ? $parts[0] : 'localhost';
    }
    return $host;
}

function update_profile(PDO $conn, int $userId, array $input): void {
    $nombre = trim($input['nombre'] ?? '');
    $apellido = trim($input['apellido'] ?? '');
    $correo = trim($input['correo'] ?? '');

    if ($nombre === '' || $apellido === '') {
        throw new Exception("Nombre y apellido son requeridos.");
    }

    $fields = [
        "nombre" => $nombre,
        "apellido" => $apellido,
    ];

    if ($correo !== '') {
        if (!filter_var($correo, FILTER_VALIDATE_EMAIL)) {
            throw new Exception("Correo invalido.");
        }
        $fields["correo"] = $correo;
    }

    $setParts = [];
    $params = [":id" => $userId];

    foreach ($fields as $key => $value) {
        $setParts[] = "{$key} = :{$key}";
        $params[":{$key}"] = $value;
    }

    $sql = "UPDATE menu_login.usuario SET " . implode(', ', $setParts) . " WHERE id_usuario = :id";
    $stmt = $conn->prepare($sql);
    $stmt->execute($params);

    send_profile($conn, $userId);
}

function change_password(PDO $conn, int $userId, array $input): void {
    $current = $input['password_actual'] ?? '';
    $new = $input['password_nueva'] ?? '';

    if (!$current || !$new) {
        throw new Exception("Debes indicar contrasena actual y nueva.");
    }

    if (strlen($new) < 6) {
        throw new Exception("La nueva contrasena debe tener al menos 6 caracteres.");
    }

    $stmt = $conn->prepare("
        SELECT contrasena
        FROM menu_login.usuario
        WHERE id_usuario = :id
        LIMIT 1
    ");
    $stmt->execute([":id" => $userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    $stored = $row['contrasena'] ?? '';
    $isModern = preg_match('/^\\$2[aby]\\$|^\\$argon2/', $stored) === 1;
    $legacyOk = hash_equals(sha1($current), $stored);
    $modernOk = $isModern ? password_verify($current, $stored) : false;

    if (!$legacyOk && !$modernOk) {
        throw new Exception("La contrasena actual no es valida.");
    }

    $newHash = password_hash($new, PASSWORD_DEFAULT);
    $stmt = $conn->prepare("
        UPDATE menu_login.usuario
        SET contrasena = :password
        WHERE id_usuario = :id
    ");
    $stmt->execute([
        ":password" => $newHash,
        ":id" => $userId
    ]);

    respond_success(["message" => "Contrasena actualizada."]);
}

function update_avatar(PDO $conn, int $userId, array $input): void {
    $imageData = $input['avatar_base64'] ?? '';

    if (!$imageData) {
        throw new Exception("Imagen requerida.");
    }

    $url = save_avatar_from_base64($userId, $imageData);
    respond_success([
        "avatar_url" => $url
    ]);
}
?>
