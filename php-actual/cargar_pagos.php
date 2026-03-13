<?php
@session_start();
include 'layouts/session.php';
include 'layouts/head-main.php';
require_once("core/funciones.php");
require_once("layouts/vars.php");
require_once("core/PDO.class.php");

// Verificar si el usuario está autenticado
if (!isset($_SESSION['userid'])) {
    header("Location: login.php");
    exit;
}

// Verificar datos recibidos por POST
if (!isset($_POST['id_inmueble']) || !isset($_POST['identificacion']) || !isset($_POST['id_condominio'])) {
    header("Location: master_inmuebles.php");
    exit;
}

$func   = new Funciones();
$conn   = DB::getInstance();
$userid = (int)$_SESSION['userid'];
$id_inmueble = (int)$_POST['id_inmueble'];
$identificacion = htmlspecialchars($_POST['identificacion']);
$id_condominio = (int)$_POST['id_condominio'];

// Verificar permisos del usuario para el condominio
$sql = "SELECT a.id_condominio, c.nombre
        FROM administradores a
        JOIN condominio c ON a.id_condominio = c.id_condominio
        WHERE a.id_usuario = :id_usuario AND a.estatus = TRUE AND a.id_condominio = :id_condominio";
$stmt = $conn->prepare($sql);
$stmt->bindParam(':id_usuario', $userid, PDO::PARAM_INT);
$stmt->bindParam(':id_condominio', $id_condominio, PDO::PARAM_INT);
$stmt->execute();
$row_condo = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$row_condo) {
    header("Location: master_inmuebles.php");
    exit;
}

// Obtener moneda base
$stmt = $conn->prepare("SELECT id_moneda FROM condominio WHERE id_condominio = :id");
$stmt->bindParam(':id', $id_condominio, PDO::PARAM_INT);
$stmt->execute();
$moneda_base_id = (int)$stmt->fetchColumn();

// Listado de cuentas
$sql = "SELECT c.id_cuenta, c.nombre, c.tipo, m.codigo AS moneda, m.id_moneda, c.banco
        FROM cuenta c
        JOIN moneda m ON c.id_moneda = m.id_moneda
        WHERE c.id_condominio = :id
        ORDER BY c.banco, c.nombre";
$stmt = $conn->prepare($sql);
$stmt->bindParam(':id', $id_condominio, PDO::PARAM_INT);
$stmt->execute();
$cuentas = $stmt->fetchAll(PDO::FETCH_ASSOC);
?>

<head>
    <title>Cargar Pago | <?php echo NOMBREAPP ?></title>
    <?php include 'layouts/head.php'; ?>
    <link href="assets/libs/datatables.net-bs4/css/dataTables.bootstrap4.min.css" rel="stylesheet" />
    <link href="assets/libs/datatables.net-buttons-bs4/css/buttons.bootstrap4.min.css" rel="stylesheet" />
    <link href="assets/libs/datatables.net-responsive-bs4/css/responsive.bootstrap4.min.css" rel="stylesheet" />
    <?php include 'layouts/head-style.php'; ?>
    <style>
        /* Ajustar altura de todas las filas de las tablas */
        .table > tbody > tr > td,
        .table > tfoot > tr > th,
        .table > tfoot > tr > td {
            height: var(--table-row-height) !important;
            line-height: var(--table-row-height) !important;
            padding-top: 0 !important;
            padding-bottom: 0 !important;
        }

        .card {
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1rem 1.5rem;
        }

        .table th,
        .table td {
            padding: 0.75rem;
            vertical-align: middle;
            font-size: 0.9rem;
        }

        .table tr {
            height: var(--table-row-height); /* Aplicar la altura de fila definida */
        }

        .form-control {
            font-size: 0.9rem;
            height: 38px;
        }

        .step-section {
            margin-bottom: 1.5rem;
        }

        .alert-resumen {
            font-size: 0.9rem;
            padding: 0.75rem;
        }

        .alert-resumen span {
            margin-right: 1rem;
        }

        @media (max-width: 767.98px) {
            .step-mode .step-section {
                display: none;
            }

            .step-mode .step-section.active {
                display: block;
            }

            .container-fluid {
                margin: 0;
            }

            .main-content {
                min-height: 100vh;
            }
        }
    </style>
</head>

<?php include 'layouts/body.php'; ?>

<div id="layout-wrapper">
    <?php include 'layouts/menu.php'; ?>
    <div class="main-content">
        <div class="page-content">
            <div class="container-fluid">
                <div class="row mb-3 align-items-center">
                    <div class="col-md-1 text-end">
                        <button type="button" class="btn btn-primary form-control" onclick="window.history.back()">Volver</button>
                    </div>
                    <div class="col-md-11 text-center">
                        <h4 class="display-8 mb-4">Cargar Pago del Inmueble: <?php echo $identificacion; ?></h4>
                    </div>
                </div>

                <form id="formCargarPago" action="cargar_pago_mod.php" method="POST">
                    <input type="hidden" name="id_inmueble" value="<?php echo $id_inmueble; ?>">
                    <input type="hidden" name="id_condominio" value="<?php echo $id_condominio; ?>">

                    <div class="card mb-3">
                        <div class="card-header">
                            <h5 class="mb-0 text-primary">Datos del Pago</h5>
                        </div>
                        <div class="card-body">
                            <div class="row g-3">
                                <div class="col-12 col-md-3">
                                    <label class="form-label">Fecha de pago:</label>
                                    <input type="date" class="form-control" name="fecha_pago" required value="<?php echo date('Y-m-d'); ?>">
                                </div>
                                <div class="col-12 col-md-6">
                                    <label class="form-label">Observaciones:</label>
                                    <input type="text" class="form-control text-uppercase" id="observacion_pago" name="observacion_pago" maxlength="100" value="PAGO">
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="step-section step-1 active">
                        <div class="card mb-3">
                            <div class="card-header">
                                <h5 class="mb-0 text-primary">Formas de Pago (Bancos y Créditos)</h5>
                            </div>
                            <div class="card-body">
                                <table class="table table-striped table-bordered table-hover" id="tablaFormasPago">
                                    <thead class="table-light">
                                        <tr>
                                            <th>Banco</th>
                                            <th>Cuenta</th>
                                            <th>Moneda</th>
                                            <th>Referencia</th>
                                            <th>Monto</th>
                                            <th>Tasa</th>
                                            <th>Base</th>
                                        </tr>
                                    </thead>
                                    <tbody id="tablaFormasPagoBody"></tbody>
                                </table>
                                <div id="resumenMontosPorMoneda" class="alert alert-primary p-2 mt-3 d-none alert-resumen"></div>
                                <div class="text-center mt-3 d-block d-md-none">
                                    <button type="button" class="btn btn-outline-primary" onclick="mostrarStep(2)">Siguiente</button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="step-section step-2">
                        <div class="card mb-3">
                            <div class="card-header">
                                <h5 class="mb-0 text-primary">Notificaciones Pendientes</h5>
                            </div>
                            <div class="card-body">
                                <table class="table table-striped table-bordered table-hover" id="tablaPendientes">
                                    <thead class="table-light">
                                        <tr>
                                            <th>F. Emisión</th>
                                            <th>Descripción</th>
                                            <th>Moneda</th>
                                            <th class="text-end">Por pagar</th>
                                            <th class="text-end">Tasa</th>
                                            <th class="text-end">Base</th>
                                            <th class="text-center">Pagar</th>
                                            <th>Abono</th>
                                        </tr>
                                    </thead>
                                    <tbody></tbody>
                                </table>
                                <div id="resumenPendientes" class="alert alert-primary p-2 mt-3 d-none alert-resumen"></div>
                                <div id="creditosDiv" class="alert alert-info py-2 mt-3 d-none"></div>
                                <div class="text-center mt-3 d-block d-md-none">
                                    <button type="button" class="btn btn-outline-secondary" onclick="mostrarStep(1)">Volver</button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="card">
                        <div class="card-body text-end">
                            <button type="submit" class="btn btn-primary">Guardar Pago</button>
                        </div>
                    </div>
                </form>
            </div>
        </div>
        <?php include 'layouts/footer.php'; ?>
    </div>
</div>

<?php include 'layouts/right-sidebar.php'; ?>
<?php include 'layouts/vendor-scripts.php'; ?>

<script src="assets/libs/datatables.net/js/jquery.dataTables.min.js"></script>
<script src="assets/libs/datatables.net-bs4/js/dataTables.bootstrap4.min.js"></script>
<script src="assets/libs/datatables.net-responsive/js/dataTables.responsive.min.js"></script>
<script src="assets/libs/datatables.net-responsive-bs4/js/responsive.bootstrap4.min.js"></script>
<script src="assets/js/bootstrap.bundle.min.js"></script>
<script src="assets/js/app.js"></script>

<script>
    /* Utilidades numéricas */
    const fmtDisp = (n, d = 2) => {
        let p = (+n).toFixed(d).split('.');
        p[0] = p[0].replace(/\B(?=(\d{3})+(?!\d))/g, '.');
        return p.join(',');
    };
    const fmt = (n, d = 2) => (+n).toFixed(d);

    /* DataTables init */
    function initDT(sel) {
        if ($.fn.DataTable.isDataTable(sel)) $(sel).DataTable().destroy();
        $(sel).DataTable({
            paging: false,
            info: false,
            searching: false,
            ordering: false,
            autoWidth: false,
            responsive: true,
            language: {
                url: 'assets/libs/datatables.net/i18n/es-ES.json'
            }
        });
    }

    /* Variables globales */
    let abonosMod = false;
    window.totMon = {}, window.totBase = {}, window.monMay = null;

    /* Actualizar observación automática */
    function updateObservacion() {
        let totalNotifs = [], partialNotifs = [];
        let totalBase = 0;

        // Recolectar notificaciones pagadas total o parcialmente
        $('#tablaPendientes tbody tr').each(function() {
            const $row = $(this);
            const abono = parseFloat($row.find('.abono').val()) || 0;
            const montoPorPagar = parseFloat($row.find('td:eq(3)').text());
            const idNotif = $row.data('id');
            if ($row.find('.chk-sel').is(':checked') && abono > 0) {
                if (abono >= montoPorPagar) {
                    totalNotifs.push(`#${idNotif}`);
                } else {
                    partialNotifs.push(`#${idNotif}`);
                }
                totalBase += abono * parseFloat($row.data('tasa'));
            }
        });

        // Construir mensaje
        let mensaje = '';
        if (totalNotifs.length > 0) {
            mensaje += `PAGA TOTALMENTE NOTIF: ${totalNotifs.join(',')}`;
        }
        if (partialNotifs.length > 0) {
            mensaje += `${totalNotifs.length > 0 ? ' Y ' : ''}PARCIALMENTE  ${partialNotifs.join(',')}`;
        }
        if (window.monMay && $('#creditosDiv').is(':visible')) {
            const cred = parseFloat($('#creditosDiv strong').text());
            mensaje += `${mensaje ? ' ' : ''}DEJANDO EN CREDITO EN ${window.monMay} ${fmtDisp(cred)}`;
        }
        $('#observacion_pago').val(mensaje || 'PAGO');
    }

    /* Recalcular resumen */
    function recalcular() {
        window.totMon = {}, window.totBase = {};
        let totalB = 0;
        const proc = (inp, isCred) => {
            const mon = inp.dataset.moneda,
                monto = parseFloat(inp.value || 0),
                sel = isCred ? `[data-id-moneda="${inp.dataset.idMoneda}"]` : `[data-id="${inp.dataset.id}"]`,
                tasa = parseFloat(document.querySelector('.tasa-cambio' + sel)?.value || 1); // Valor predeterminado de 1 si no hay tasa
            if (tasa <= 0) {
                console.warn(`Tasa inválida (${tasa}) detectada para ${mon}, usando 1 como valor predeterminado.`);
                tasa = 1; // Forzar tasa mínima de 1
            }
            const base = monto / tasa;
            window.totMon[mon] = (window.totMon[mon] || 0) + monto;
            window.totBase[mon] = (window.totBase[mon] || 0) + base;
            totalB += base;
            const baseInp = document.querySelector('.monto-base' + sel);
            if (baseInp) baseInp.value = fmtDisp(base);
        };
        document.querySelectorAll('.monto-por-cuenta').forEach(i => proc(i, false));
        document.querySelectorAll('.monto-por-credito').forEach(i => proc(i, true));
        window.monMay = Object.keys(window.totBase).sort((a, b) => window.totBase[b] - window.totBase[a])[0] || null;
        let h = '';
        Object.entries(window.totMon).forEach(([m, v]) => h += `<span class="me-3">${m}: ${fmtDisp(v)}</span>`);
        h += `<strong class="ms-3">Total base: ${fmtDisp(totalB)}</strong>`;
        $('#resumenMontosPorMoneda').html(h).removeClass('d-none');
        updateObservacion(); // Actualizar observación después de recalcular
        return totalB;
    }

    /* Distribución automática */
    function distribuirAuto() {
        if (abonosMod) return;
        let saldo = recalcular();
        $('#tablaPendientes tbody tr').each(function() {
            const $r = $(this),
                por = parseFloat($r.find('td:eq(3)').text()),
                tasa = parseFloat($r.data('tasa')) || 1; // Valor predeterminado de 1 si no hay tasa
            if (tasa <= 0) {
                console.warn(`Tasa inválida (${tasa}) detectada para notificación, usando 1 como valor predeterminado.`);
                tasa = 1; // Forzar tasa mínima de 1
            }
            const chk = $r.find('.chk-sel'),
                ab = $r.find('.abono');
            if (saldo > 0) {
                chk.prop('checked', true);
                ab.prop('disabled', false);
                const abPos = Math.min(por, saldo / tasa);
                ab.val(fmt(abPos));
                saldo -= abPos * tasa;
            } else {
                chk.prop('checked', false);
                ab.val('').prop('disabled', true);
            }
        });
        if (saldo > 0 && window.monMay) {
            const tMay = window.totBase[window.monMay] / window.totMon[window.monMay],
                cred = fmt(saldo / tMay);
            $('#creditosDiv').removeClass('d-none')
                .html(`Crédito a favor: <strong>${cred}</strong> (${window.monMay})`);
        } else $('#creditosDiv').addClass('d-none').empty();
        updateObservacion(); // Actualizar observación después de distribuir
    }

    /* Carga AJAX tablas */
    function cargarFormas(id) {
        const tbody = $('#tablaFormasPago tbody').html('<tr><td colspan="7" class="text-center">Cargando…</td></tr>');
        $.post('creditos_disponibles.php', {
            id_inmueble: id
        }, res => {
            tbody.empty();
            res.cuentas.forEach(c => {
                const tasa = parseFloat(c.tasa) || 1; // Valor predeterminado de 1 si no hay tasa
                tbody.append(`
                    <tr>
                        <td>${c.banco || ''}</td>
                        <td>${c.nombre}</td>
                        <td>${c.moneda}</td>
                        <td><input type="text" class="form-control referencia-pago" name="referencia[${c.id_cuenta}]" ${c.tipo.toLowerCase() !== 'banco' ? 'readonly' : ''}></td>
                        <td><input type="number" class="form-control monto-por-cuenta" name="monto_cuenta[${c.id_cuenta}]" step="0.01" min="0" data-moneda="${c.moneda}" data-id="${c.id_cuenta}"></td>
                        <td><input type="number" class="form-control tasa-cambio" name="tasa_cambio[${c.id_cuenta}]" step="0.0001" value="${tasa.toFixed(4)}" ${c.moneda_base ? 'readonly' : ''} data-id="${c.id_cuenta}"></td>
                        <td><input type="text" class="form-control monto-base" readonly data-id="${c.id_cuenta}"></td>
                        <input type="hidden" name="tipo_origen[${c.id_cuenta}]" value="${c.tipo.toLowerCase()}">
                    </tr>
                `);
            });
            res.creditos.forEach(c => {
                const tasa = parseFloat(c.tasa) || 1; // Valor predeterminado de 1 si no hay tasa
                tbody.append(`
                    <tr>
                        <td>CRÉDITO</td>
                        <td>CRÉDITO FISCAL</td>
                        <td>${c.moneda}</td>
                        <td><input type="text" class="form-control" readonly value="DISP: ${c.saldo.toFixed(2)} ${c.moneda}"></td>
                        <td><input type="number" class="form-control monto-por-credito" name="monto_credito[${c.id_moneda}]" step="0.01" min="0" max="${c.saldo}" data-moneda="${c.moneda}" data-id-moneda="${c.id_moneda}"></td>
                        <td><input type="number" class="form-control tasa-cambio" name="tasa_cambio_credito[${c.id_moneda}]" step="0.0001" value="${tasa.toFixed(4)}" ${c.moneda_base ? 'readonly' : ''} data-id-moneda="${c.id_moneda}"></td>
                        <td><input type="text" class="form-control monto-base" readonly data-id-moneda="${c.id_moneda}"></td>
                        <input type="hidden" name="tipo_origen_credito[${c.id_moneda}]" value="credito">
                    </tr>
                `);
            });
            if (!res.cuentas.length && !res.creditos.length) {
                tbody.append('<tr><td colspan="7" class="text-center">Sin formas de pago.</td></tr>');
            }
            initDT('#tablaFormasPago');
            recalcular();
        }, 'json');
    }

    function cargarPendientes(id) {
        const tbody = $('#tablaPendientes tbody').html('<tr><td colspan="8" class="text-center">Cargando…</td></tr>');
        $.post('notificaciones_pendientes.php', {
            id_inmueble: id
        }, res => {
            tbody.empty();
            let tot = {},
                base = 0;
            res.forEach(n => {
                const m = parseFloat(n.monto_x_pagar),
                    b = m * parseFloat(n.tasa);
                tot[n.codigo_moneda] = (tot[n.codigo_moneda] || 0) + m;
                base += b;
                tbody.append(`
                    <tr data-id="${n.id_notificacion}" data-tasa="${n.tasa}" data-id-moneda="${n.id_moneda}">
                      <td>${n.fecha_emision}</td><td>${n.descripcion}</td><td>${n.codigo_moneda}</td>
                      <td class="text-end">${fmt(n.monto_x_pagar)}</td><td class="text-end">${fmt(n.tasa, 4)}</td>
                      <td class="text-end">${fmt(b)}</td>
                      <td class="text-center"><input type="checkbox" class="form-check-input chk-sel"></td>
                      <td><input type="number" class="form-control abono" step="0.01" disabled max="${n.monto_x_pagar}"></td>
                    </tr>`);
            });
            if (!res.length) tbody.append('<tr><td colspan="8" class="text-center">Sin pendientes.</td></tr>');
            let h = '';
            Object.entries(tot).forEach(([m, v]) => h += `<span class="me-3">${m}: ${fmtDisp(v)}</span>`);
            h += `<strong class="ms-3">Total base: ${fmtDisp(base)}</strong>`;
            $('#resumenPendientes').html(h).removeClass('d-none');
            initDT('#tablaPendientes');
            distribuirAuto();
        }, 'json');
    }

    /* Navegación pasos (solo móviles) */
    function mostrarStep(x) {
        if (window.innerWidth < 768) {
            document.getElementById('layout-wrapper').style.setProperty('--step-mode', '1');
            $('.step-section').removeClass('active');
            $('.step-' + x).addClass('active');
        }
    }

    function resetSteps() {
        document.getElementById('layout-wrapper').style.removeProperty('--step-mode');
    }

    /* Main */
    $(function() {
        const id = <?php echo $id_inmueble; ?>;
        abonosMod = false;
        $('#resumenMontosPorMoneda, #resumenPendientes, #creditosDiv').addClass('d-none').empty();
        cargarFormas(id);
        cargarPendientes(id);
        resetSteps();

        /* Listeners */
        $(document).on('input', '.monto-por-cuenta, .tasa-cambio, .monto-por-credito', () => {
            if (!abonosMod) distribuirAuto();
        });
        $(document).on('change', '.chk-sel', function() {
            const $a = $(this).closest('tr').find('.abono');
            $a.prop('disabled', !this.checked);
            if (!this.checked) $a.val('');
            updateObservacion();
        });
        $(document).on('input', '.abono', function() {
            abonosMod = true;
            let pagB = 0;
            $('#tablaPendientes tbody tr').each(function() {
                pagB += ((parseFloat($(this).find('.abono').val()) || 0) * parseFloat($(this).data('tasa')));
            });
            const saldo = recalcular() - pagB;
            if (saldo > 0 && window.monMay) {
                const tMay = window.totBase[window.monMay] / window.totMon[window.monMay],
                    cred = fmt(saldo / tMay);
                $('#creditosDiv').removeClass('d-none').html(`Crédito a favor: <strong>${cred}</strong> (${window.monMay})`);
            } else $('#creditosDiv').addClass('d-none').empty();
            updateObservacion();
        });

        /* Submit */
        $('#formCargarPago').on('submit', function(e) {
            e.preventDefault();

            const form = $(this);
            const data = form.serializeArray();  // Captura todos los inputs normales
            const notif = [];

            // Agregar manualmente tipo_origen[]
            form.find('input[name^="tipo_origen"]').each(function() {
                data.push({ name: this.name, value: this.value });
            });

            // Recolectar notificaciones marcadas
            $('#tablaPendientes tbody tr').each(function() {
                const ab = parseFloat($(this).find('.abono').val()) || 0;
                if ($(this).find('.chk-sel').is(':checked') && ab > 0) {
                    notif.push({
                        id_notificacion: $(this).data('id'),
                        abono: ab,
                        tasa: $(this).data('tasa'),
                        id_moneda: $(this).data('id-moneda')
                    });
                }
            });

            // Agregar notificaciones al payload
            data.push({
                name: 'notificaciones',
                value: JSON.stringify(notif)
            });

            // Si hay crédito a favor, incluirlo también
            if (window.monMay && $('#creditosDiv').is(':visible')) {
                const cred = $('#creditosDiv strong').text().replace('.', '').replace(',', '.');
                data.push(
                    { name: 'credito', value: cred },
                    { name: 'moneda_credito', value: window.monMay }
                );
            }

            // Enviar datos al backend
            $.post('guardar_pago.php', data, r => {
                Swal.fire({
                    icon: r.status,
                    title: r.status === 'success' ? 'Éxito' : 'Error',
                    text: r.message
                }).then(() => {
                    if (r.status === 'success') {
                        window.location.href = 'master_inmuebles.php';
                    }
                });
            }, 'json').fail(x => Swal.fire('Error', 'No se pudo guardar el pago.', 'error'));
        });
    });
</script>

