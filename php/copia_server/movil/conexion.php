<?php
/**
 * Archivo de conexión exclusivo para la API móvil
 * Versión basada en la configuración del sistema de escritorio
 */

class ConexionAPI {
    private static $instancia = null;
    private $conn;

    // ⚙️ Configuración tomada de la versión escritorio
    private $host = "localhost";
    private $dbname = "rhodium_txcondominio";
    private $user = "rhodium_roger";
    private $pass = "Rp13953909*";
    private $port = "5432";

    private function __construct() {
        try {
            $dsn = "pgsql:host={$this->host};port={$this->port};dbname={$this->dbname}";
            $this->conn = new PDO($dsn, $this->user, $this->pass);
            $this->conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $this->conn->exec("SET NAMES 'UTF8'");
        } catch (PDOException $e) {
            http_response_code(500);
            echo json_encode([
                "error" => "Error de conexión con la base de datos.",
                "detalle" => $e->getMessage()
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
