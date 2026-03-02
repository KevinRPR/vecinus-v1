<?php
/**
 * Archivo de conexion exclusivo para la API movil.
 * Version basada en la configuracion del sistema de escritorio.
 */

require_once(__DIR__ . "/env.php");

class ConexionAPI {
    private static $instancia = null;
    private $conn;

    private $host;
    private $dbname;
    private $user;
    private $pass;
    private $port;

    private function __construct() {
        $this->host = env_value('DB_HOST', 'localhost');
        $this->dbname = env_value('DB_NAME', '');
        $this->user = env_value('DB_USER', '');
        $this->pass = env_value('DB_PASS', '');
        $this->port = env_value('DB_PORT', '5432');

        if ($this->dbname === '' || $this->user === '') {
            http_response_code(500);
            echo json_encode([
                "error" => "Configuracion de base de datos incompleta."
            ]);
            exit;
        }

        try {
            $dsn = "pgsql:host={$this->host};port={$this->port};dbname={$this->dbname}";
            $this->conn = new PDO($dsn, $this->user, $this->pass);
            $this->conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $this->conn->exec("SET NAMES 'UTF8'");
        } catch (PDOException $e) {
            error_log("DB connection error: " . $e->getMessage());
            http_response_code(500);
            echo json_encode([
                "error" => "Error de conexion con la base de datos."
            ]);
            exit;
        }
    }

    public static function getInstance() {
        if (!self::$instancia) {
            self::$instancia = new ConexionAPI();
        }
        return self::$instancia->conn;
    }
}
?>
