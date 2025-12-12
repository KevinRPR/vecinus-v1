<?php
// cxc_inmueble.php
@session_start();
include 'layouts/session.php';
include 'layouts/head-main.php';
require_once("core/funciones.php");
require_once("layouts/vars.php");
require_once("core/PDO.class.php");

$func       = new Funciones();
$conn       = DB::getInstance();
$id_usuario = $_SESSION['userid'];

/* --------------------------------------------------------------------------
   CAPTURA SEGURA DEL ID_INMUEBLE
---------------------------------------------------------------------------*/
$id_inmueble = 0;
if (isset($_POST['id_inmueble']) && ctype_digit($_POST['id_inmueble'])) {
    $id_inmueble = (int)$_POST['id_inmueble'];
}
if ($id_inmueble === 0) {
    die('Error: id_inmueble no recibido o inválido.');
}

/* --------------------------------------------------------------------------
   CAPTURA DEL ID_CONDOMINIO (opcional)
---------------------------------------------------------------------------*/
$id_condominio_param = 0;
if (isset($_POST['id_condominio']) && ctype_digit($_POST['id_condominio'])) {
    $id_condominio_param = (int)$_POST['id_condominio'];
}

/* --------------------------------------------------------------------------
   DATOS DEL INMUEBLE Y PROPIETARIO
---------------------------------------------------------------------------*/
$sql = "SELECT
	inmueble.identificacion, 
	inmueble.alicuota, 
	propietario.nombre1, 
	propietario.nombre2, 
	propietario.apellido1, 
	propietario.apellido2, 
	propietario.t_cedula, 
	propietario.cedula, 
	propietario.celular, 
	usuario.correo
FROM
	public.inmueble AS inmueble
INNER JOIN
	public.propietario_inmueble AS propietario_inmueble
	ON inmueble.id_inmueble = propietario_inmueble.id_inmueble
INNER JOIN
	public.propietario AS propietario
	ON propietario_inmueble.id_propietario = propietario.id_propietario
INNER JOIN
	menu_login.usuario AS usuario
	ON propietario_inmueble.id_usuario = usuario.id_usuario
WHERE
	inmueble.id_inmueble = :id_inmueble";
$stmt_datos = $conn->prepare($sql);
$stmt_datos->bindParam(':id_inmueble', $id_inmueble, PDO::PARAM_INT);
$stmt_datos->execute();
$row_datos = $stmt_datos->fetch();

$identificacion = $row_datos['identificacion']  ?? '';
$alicuota       = $row_datos['alicuota']        ?? '';
$nombre1        = $row_datos['nombre1']         ?? '';
$nombre2        = $row_datos['nombre2']         ?? '';
$apellido1      = $row_datos['apellido1']       ?? '';
$apellido2      = $row_datos['apellido2']       ?? '';
$t_cedula       = $row_datos['t_cedula']        ?? '';
$cedula         = $row_datos['cedula']          ?? '';
$celular        = $row_datos['celular']         ?? '';
$correo         = $row_datos['correo']          ?? '';

/* --------------------------------------------------------------------------
   CONSULTA DEL RESUMEN DE DEUDAS POR MONEDA
---------------------------------------------------------------------------*/
$sql_summary = "
    SELECT 
        m.codigo AS moneda,
        SUM(
            GREATEST(
                COALESCE(n.monto_x_pagar, n.monto_total - n.monto_pagado),
                0
            )
        ) AS total_pendiente
    FROM notificacion_cobro n
    INNER JOIN moneda m ON n.id_moneda = m.id_moneda
    WHERE n.id_inmueble = :id_inmueble
      AND n.estado <> 'pagada'
    GROUP BY m.codigo
    ORDER BY m.codigo";
$stmt_summary = $conn->prepare($sql_summary);
$stmt_summary->bindParam(':id_inmueble', $id_inmueble, PDO::PARAM_INT);
$stmt_summary->execute();
$deudas_por_moneda = $stmt_summary->fetchAll(PDO::FETCH_ASSOC);

/* --------------------------------------------------------------------------
   CONSULTA DEL CRÉDITO DEL INMUEBLE
---------------------------------------------------------------------------*/
$sql_credito = "SELECT 
                    m.codigo AS moneda,
                    SUM(c.monto) AS total_credito
                FROM credito_a_favor c
                INNER JOIN moneda m ON c.id_moneda = m.id_moneda
                WHERE c.id_inmueble = :id_inmueble
                GROUP BY m.codigo
                ORDER BY m.codigo";
$stmt_credito = $conn->prepare($sql_credito);
$stmt_credito->bindParam(':id_inmueble', $id_inmueble, PDO::PARAM_INT);
$stmt_credito->execute();
$creditos_por_moneda = $stmt_credito->fetchAll(PDO::FETCH_ASSOC);
?>
<head>
    <title>Notificaciones CxC | <?= NOMBREAPP ?></title>
    <?php include 'layouts/head.php'; ?>
    <link href="assets/libs/datatables.net-bs4/css/dataTables.bootstrap4.min.css" rel="stylesheet" />
    <link href="assets/libs/datatables.net-buttons-bs4/css/buttons.bootstrap4.min.css" rel="stylesheet" />
    <link href="assets/libs/datatables.net-responsive-bs4/css/responsive.bootstrap4.min.css" rel="stylesheet" />
    <?php include 'layouts/head-style.php'; ?>
</head>

<?php include 'layouts/body.php'; ?>
<input type="hidden" name="id_inmueble_" id="id_inmueble_" value="<?= $id_inmueble; ?>">
<input type="hidden" name="id_condominio" id="id_condominio" value="<?= $id_condominio_param; ?>">


<div id="layout-wrapper">
<?php include 'layouts/menu.php'; ?>

<div class="main-content">
  <div class="page-content">
    <div class="container-fluid">

      <div class="row mb-3">
        <div class="col-2">
          <button type="button" class="btn btn-primary" onclick="volver()">Volver</button>
        </div>
      </div>

      <div class="row g-3 mb-4">
        <div class="col-md-3">
          <h1 class="display-6 mb-0">Notificaciones de Cobro</h1>
        </div>
        <div class="col-md-3">
          <div class="card h-100">
            <div class="card-body">
              <h5>Inmueble: <span class="fw-bold"><?= htmlspecialchars($identificacion); ?></span></h5>
              <p class="mb-0 small"><strong>Alicuota:</strong> <?= htmlspecialchars($alicuota); ?></p>
              <p class="mb-0 small"><strong>Propietario:</strong> <?= htmlspecialchars("$nombre1 $nombre2 $apellido1 $apellido2"); ?></p>
              <p class="mb-0 small"><strong>Cédula:</strong> <?= htmlspecialchars("$t_cedula-$cedula"); ?></p>
              <p class="mb-0 small"><strong>Celular:</strong> <?= htmlspecialchars($celular); ?></p>
              <p class="mb-0 small"><strong>Email:</strong> <?= htmlspecialchars($correo); ?></p>
            </div>
          </div>
        </div>
        <div class="col-md-3">
          <div class="card h-100">
            <div class="card-body">
              <h5>Deudas por Pagar</h5>
              <ul class="list-unstyled mb-0">
                <?php if ($deudas_por_moneda): ?>
                  <?php foreach ($deudas_por_moneda as $deuda): ?>
                    <li><strong><?= htmlspecialchars($deuda['moneda']); ?></strong>
                        <?= number_format($deuda['total_pendiente'], 2, ',', '.'); ?>
                    </li>
                  <?php endforeach; ?>
                <?php else: ?>
                  <li>No hay deudas pendientes.</li>
                <?php endif; ?>
              </ul>
            </div>
          </div>
        </div>
        <div class="col-md-3">
          <div class="card h-100">
            <div class="card-body">
              <h5>Créditos Disponibles</h5>
              <ul class="list-unstyled mb-0">
                <?php if ($creditos_por_moneda): ?>
                  <?php foreach ($creditos_por_moneda as $credito): ?>
                    <li><strong><?= htmlspecialchars($credito['moneda']); ?></strong>
                        <?= number_format($credito['total_credito'], 2, ',', '.'); ?>
                    </li>
                  <?php endforeach; ?>
                <?php else: ?>
                  <li>No hay créditos disponibles.</li>
                <?php endif; ?>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <!-- DataTable -->
      <div class="card">
        <div class="card-body">
          <table id="tablaInmuebles" class="table table-bordered dt-responsive nowrap w-100">
            <thead>
              <tr>
                <th>Notificación</th>
                <th>Emisión</th>
                <th>Concepto</th>
                <th>Moneda</th>
                <th>Total</th>
                <th>Pagado</th>
                <th>X Pagar</th>
                <th>Estado</th>
                <th>Acciones</th>
              </tr>
            </thead>
          </table>
        </div>
      </div>

    </div>
  </div>
  <?php include 'layouts/footer.php'; ?>
</div>
<?php include 'layouts/right-sidebar.php'; ?>
</div>

<?php include 'layouts/vendor-scripts.php'; ?>
<script src="assets/libs/datatables.net/js/jquery.dataTables.min.js"></script>
<script src="assets/libs/datatables.net-bs4/js/dataTables.bootstrap4.min.js"></script>
<script src="assets/libs/datatables.net-responsive/js/dataTables.responsive.min.js"></script>
<script src="assets/libs/datatables.net-responsive-bs4/js/responsive.bootstrap4.min.js"></script>
<script src="assets/libs/sweetalert2/sweetalert2.min.js"></script>

<script>
$(document).ready(function() {
  const idCondo = $('#id_condominio').val();

  $('#tablaInmuebles').DataTable({
    processing: true,
    serverSide: true,
    ajax: {
      url: 'cxc_inmuebles_data.php',
      type: 'POST',
      data: function(d) {
        d.id_inmueble = $('#id_inmueble_').val();
      }
    },
    columns: [
      { data: 'id_notificacion' },
      { data: 'fecha_emision' },
      { data: 'descripcion' },
      { data: 'moneda_notificacion' },
      { data: 'monto_total' },
      { data: 'monto_pagado' },
      { data: 'monto_x_pagar' },
      { 
        data: 'estado',
        render: function(data) {
          const e = (data || '').toLowerCase();
          if (e === 'pagada') return '<span class="badge bg-success">Pagada</span>';
          if (e === 'parcialmente_pagada') return '<span class="badge bg-warning">Parcial</span>';
          if (e === 'pendiente') return '<span class="badge bg-danger">Pendiente</span>';
          if (e === 'cancelada') return '<span class="badge bg-secondary">Cancelada</span>';
          return data || '';
        }
      },
      { 
        data: null,
       
render: function(data, type, row) {
  let buttons = `
    <button class="btn btn-sm btn-secondary me-1 ver-notificacion" data-id="${row.id_notificacion}">
      <i class="fas fa-eye"></i> Ver
    </button>`;

  if (row.estado.toLowerCase() === 'pagada' || row.estado.toLowerCase() === 'parcialmente_pagada') {
    buttons += `
      <button class="btn btn-sm btn-info me-1 ver-recibo" data-id="${row.id_notificacion}">
        <i class="fas fa-file-pdf"></i> Recibo
      </button>`;
  }

  const enviados = row.envios_count || 0;
  buttons += `
    <div class="btn-group">
      <button class="btn btn-sm btn-outline-primary reenviar-email" 
              data-id="${row.id_notificacion}" 
              data-token="${row.token}" 
              data-tipo="notificacion">
        <i class="fas fa-envelope"></i> Reenviar (${enviados})
      </button>
      <button class="btn btn-sm btn-outline-secondary enviar-a-email" 
              data-id="${row.id_notificacion}" 
              data-token="${row.token}" 
              data-tipo="notificacion">
        <i class="fas fa-paper-plane"></i> Enviar a...
      </button>
    </div>`;

  if (row.estado.toLowerCase() === 'pagada' || row.estado.toLowerCase() === 'parcialmente_pagada') {
    buttons += `
      <div class="btn-group ms-1">
        <button class="btn btn-sm btn-outline-success reenviar-recibo" 
                data-id="${row.id_notificacion}" 
                data-token="${row.token_recibo}" 
                data-tipo="recibo">
          <i class="fas fa-envelope"></i> Reenviar Recibo
        </button>
        <button class="btn btn-sm btn-outline-dark enviar-recibo-a-email" 
                data-id="${row.id_notificacion}" 
                data-token="${row.token_recibo}" 
                data-tipo="recibo">
          <i class="fas fa-paper-plane"></i> Enviar Recibo a...
        </button>
      </div>`;
  }

  return buttons;
}



      }
    ],
    language: { url: 'Spanish.json' },
    order: [[1, 'asc']]
  });

  // === Ver Notificación
  $('#tablaInmuebles').on('click', '.ver-notificacion', function() {
    const id = $(this).data('id');
    window.open('generar_notificacion.php?id_notificacion=' + id, '_blank');
  });

  // === Ver Recibo
  $('#tablaInmuebles').on('click', '.ver-recibo', function() {
    const id = $(this).data('id');
    window.open('generar_recibo.php?id_notificacion=' + id, '_blank');
  });

  // === FUNCIÓN GENÉRICA PARA ENVIAR EMAIL ===
  function enviarEmail(id, idCondo, destino, tipo, token) {
    $.post('email/enviar_email.php', { 
        tipo: tipo,
        id: id,
        token: token,
        id_condominio: idCondo,
        destino: destino 
      }, function(resp){
        if (resp.status === 'ok') {
          Swal.fire('Éxito', resp.message, 'success');
          $('#tablaInmuebles').DataTable().ajax.reload(null,false);
        } else {
          Swal.fire('Error', resp.message || 'No se pudo enviar', 'error');
          console.error(resp);
        }
      }, 'json'
    ).fail(() => Swal.fire('Error','No se pudo contactar el servidor','error'));
  }

  // === REENVIAR NOTIFICACIÓN AL CORREO REGISTRADO ===
  $('#tablaInmuebles').on('click', '.reenviar-email', function() {
    const id = $(this).data('id');
    const token = $(this).data('token');
    const tipo = $(this).data('tipo');
    const idCondo = $('#id_condominio').val();

    Swal.fire({
      title: 'Reenviar Email',
      text: 'Se enviará al correo registrado del propietario.',
      icon: 'question',
      showCancelButton: true,
      confirmButtonText: 'Enviar'
    }).then(r => {
      if (r.isConfirmed) {
        enviarEmail(id, idCondo, 'default', tipo, token);
      }
    });
  });

  // === ENVIAR NOTIFICACIÓN A OTRO CORREO ===
  $('#tablaInmuebles').on('click', '.enviar-a-email', function() {
    const id = $(this).data('id');
    const token = $(this).data('token');
    const tipo = $(this).data('tipo');
    const idCondo = $('#id_condominio').val();

    Swal.fire({
      title: 'Enviar a otro correo',
      input: 'email',
      inputPlaceholder: 'ejemplo@correo.com',
      showCancelButton: true,
      confirmButtonText: 'Enviar',
      inputValidator: (value) => {
        if (!value) return 'Debes ingresar un correo';
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) return 'Formato inválido';
      }
    }).then(r => {
      if (r.isConfirmed && r.value) {
        enviarEmail(id, idCondo, r.value, tipo, token);
      }
    });
  });

  // === REENVIAR RECIBO AL CORREO REGISTRADO ===
  $('#tablaInmuebles').on('click', '.reenviar-recibo', function() {
    const id = $(this).data('id');
    const token = $(this).data('token');
    const tipo = $(this).data('tipo');
    const idCondo = $('#id_condominio').val();

    Swal.fire({
      title: 'Reenviar Recibo',
      text: 'Se enviará el recibo al correo registrado del propietario.',
      icon: 'question',
      showCancelButton: true,
      confirmButtonText: 'Enviar'
    }).then(r => {
      if (r.isConfirmed) {
        enviarEmail(id, idCondo, 'default', tipo, token);
      }
    });
  });

  // === ENVIAR RECIBO A OTRO CORREO ===
  $('#tablaInmuebles').on('click', '.enviar-recibo-a-email', function() {
    const id = $(this).data('id');
    const token = $(this).data('token');
    const tipo = $(this).data('tipo');
    const idCondo = $('#id_condominio').val();

    Swal.fire({
      title: 'Enviar Recibo a otro correo',
      input: 'email',
      inputPlaceholder: 'ejemplo@correo.com',
      showCancelButton: true,
      confirmButtonText: 'Enviar',
      inputValidator: (value) => {
        if (!value) return 'Debes ingresar un correo';
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) return 'Formato inválido';
      }
    }).then(r => {
      if (r.isConfirmed && r.value) {
        enviarEmail(id, idCondo, r.value, tipo, token);
      }
    });
  });

});

function volver(){ window.history.back(); }
</script>
