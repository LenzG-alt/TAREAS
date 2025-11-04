-- LABORATORIO 6 - CONTROL DE CONCURRENCIA DISTRIBUIDA 
-- PARTE A: SQL PURO CON MÚLTIPLES TERMINALES 
-- PASO 1: PREPARACIÓN DEL ENTORNO 
-- 1.1 Crear las bases de datos 
-- Abrir Terminal 1 (como superusuario): 

-- Conectar como postgres
psql -U postgres

-- Crear base de datos
CREATE DATABASE banco_lima; 
CREATE DATABASE banco_cusco; 
CREATE DATABASE banco_arequipa; 

-- Crear usuario para la práctica
CREATE USER estudiante WITH PASSWORD 'lab2024';

-- Otorgar permisos 
GRANT ALL PRIVILEGES ON DATABASE banco_lima TO estudiante; 
GRANT ALL PRIVILEGES ON DATABASE banco_cusco TO estudiante; 
GRANT ALL PRIVILEGES ON DATABASE banco_arequipa TO estudiante; 

-- Salir
\q

-- 1.2 Estructura de tablas para BANCO_LIMA 
-- Conectar a banco_lima: 

psql -U estudiante -d banco_lima

-- Tabla de cuentas -- 
CREATE TABLE cuentas ( 
	id SERIAL PRIMARY KEY, 
	numero_cuenta VARCHAR(20) UNIQUE NOT NULL, 
	titular VARCHAR(100) NOT NULL, 
	saldo NUMERIC(15,2) NOT NULL CHECK (saldo >= 0), 
	sucursal VARCHAR(50) DEFAULT 'Lima', 
	fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	ultima_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	version INTEGER DEFAULT 1 
);

-- Tabla de log de transacciones 
CREATE TABLE transacciones_log ( 
	id SERIAL PRIMARY KEY, 
	transaccion_id VARCHAR(50) NOT NULL, 
	cuenta_id INTEGER REFERENCES cuentas(id), 
	tipo_operacion VARCHAR(20), 
	monto NUMERIC(15,2), 
	estado VARCHAR(20),
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamp_prepare TIMESTAMP, 
	timestamp_final TIMESTAMP, 
	descripcion TEXT 
);

-- Tabla de control 2PC 
CREATE TABLE control_2pc ( 
	transaccion_id VARCHAR(58) PRIMARY KEY, 
	estado_global VARCHAR(28),
	participantes TEXT[], 
	votos_commit INTEGER DEFAULT 0, 
	votos_abort INTEGER DEFAULT 0, 
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamp_decision TIMESTAMP, 
	coordinador VARCHAR(50) 
);

-- Insertar datos iniciales 
INSERT INTO cuentas (numero_cuenta, titular, saldo) VALUES 
('LIMA-001', 'Juan Pérez Rodríguez', 5000.00), 
('LIMA-002', 'María García Flores', 3000.00), 
('LIMA-003', 'Carlos López Mendoza', 7500.00), 
('LIMA-004', 'Ana Torres Vargas', 2800.00), 
('LIMA-005', 'Pedro Ramírez Castro', 6200.00); 

-- Verificar inserción 
SELECT * FROM cuentas;

-- 1.3 Estructura para BANCO_CUSCO 
-- Abrir Terminal 2 y conectar: 

psql -U estudiante -d banco_cusco 

-- Misma tablas
CREATE TABLE cuentas ( 
	id SERIAL PRIMARY KEY, 
	numero_cuenta VARCHAR(20) UNIQUE NOT NULL, 
	titular VARCHAR(100) NOT NULL, 
	saldo NUMERIC(15,2) NOT NULL CHECK (saldo >= 0), 
	sucursal VARCHAR(50) DEFAULT 'Cusco', 
	fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	ultima_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	version INTEGER DEFAULT 1 
);

-- Tabla de log de transacciones 
CREATE TABLE transacciones_log ( 
	id SERIAL PRIMARY KEY, 
	transaccion_id VARCHAR(50) NOT NULL, 
	cuenta_id INTEGER REFERENCES cuentas(id), 
	tipo_operacion VARCHAR(20), 
	monto NUMERIC(15,2), 
	estado VARCHAR(20),
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamp_prepare TIMESTAMP, 
	timestamp_final TIMESTAMP, 
	descripcion TEXT 
);

-- Tabla de control 2PC 
CREATE TABLE control_2pc ( 
	transaccion_id VARCHAR(58) PRIMARY KEY, 
	estado_global VARCHAR(28),
	participantes TEXT[], 
	votos_commit INTEGER DEFAULT 0, 
	votos_abort INTEGER DEFAULT 0, 
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamp_decision TIMESTAMP, 
	coordinador VARCHAR(50) 
);

-- Datos iniciales 
INSERT INTO cuentas (numero_cuenta, titular, saldo) VALUES 
('CUSCO-001', 'Rosa Quispe Huamán', 2000.00), 
('CUSCO-002', 'Pedro Mamani Condori', 4500.00), 
('CUSCO-003', 'Carmen Ccoa Flores', 1800.00), 
('CUSCO-004', 'Luis Apaza Choque', 5300.00), 
('CUSCO-005', 'Elena Puma Quispe', 3700.00); 

SELECT * FROM cuentas;

-- 1.4 Estructura para BANCO AREQUIPA 
-- Abrir Terminal 3 y conectar: 
 
psql -U estudiante -d banco_arequipa 
-- Misma tablas
CREATE TABLE cuentas ( 
	id SERIAL PRIMARY KEY, 
	numero_cuenta VARCHAR(20) UNIQUE NOT NULL, 
	titular VARCHAR(100) NOT NULL, 
	saldo NUMERIC(15,2) NOT NULL CHECK (saldo >= 0), 
	sucursal VARCHAR(50) DEFAULT 'Arequipa', 
	fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	ultima_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	version INTEGER DEFAULT 1 
);

-- Tabla de log de transacciones 
CREATE TABLE transacciones_log ( 
	id SERIAL PRIMARY KEY, 
	transaccion_id VARCHAR(50) NOT NULL, 
	cuenta_id INTEGER REFERENCES cuentas(id), 
	tipo_operacion VARCHAR(20), 
	monto NUMERIC(15,2), 
	estado VARCHAR(20),
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamp_prepare TIMESTAMP, 
	timestamp_final TIMESTAMP, 
	descripcion TEXT 
);

-- Tabla de control 2PC 
CREATE TABLE control_2pc ( 
	transaccion_id VARCHAR(58) PRIMARY KEY, 
	estado_global VARCHAR(28),
	participantes TEXT[], 
	votos_commit INTEGER DEFAULT 0, 
	votos_abort INTEGER DEFAULT 0, 
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamp_decision TIMESTAMP, 
	coordinador VARCHAR(50) 
);

-- Datos iniciales 
INSERT INTO cuentas (numero_cuenta, titular, saldo) VALUES 
('AQP-001', 'Luis Vargas Bellido', 6000.00), 
('AQP-002', 'Carmen Silva Medina', 2800.00),
('AQP-003', 'Roberto Mendoza Pinto', 9200.00), 
('AQP-004', 'Isabel Díaz Salazar', 4100.00), 
('AQP-005', 'Jorge Paredes Ramos', 7000.00); 


SELECT * FROM cuentas;

-- EJERCICIO 1: TWO-PHASE COMMIT MANUAL PASO A PASO 
-- Escenario: 
-- Transferir $1,000 de LIMA-001 (Lima) a CUSCO-001 (Cusco) 
-- Generar ID de transacción único: 

-- En terminal 1(Lima) - generar UUID
SELECT 'TXN-' || to_char(now(), 'YYYYMMDD-HH24MISS') AS transaccion_id; 
-- Resultado ejemplo: TXN-20250928-143022 
-- COPIAR este ID para usar en todos los pasos

-- Usar este ID en todos los siguientes comandos
--(reemplazar 'TXN-20250928-143022' con tu ID generado) 

-- FASE 0: INICIAR TRANSACCIÓN EN TODOS LOS NODOS 

-- Terminal 1 (Lima): 

-- Iniciar transaccion
BEGIN; 

-- Registrar inicio en control 2PC
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20250928-143022', 'INICIADA', 'LIMA'); 

-- Mostrar estado
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20250928-143022'; 

-- Terminal 2 (Cusco): 
BEGIN; 

-- Registrar participacion
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20250928-143022', 'INICIADA', 'LIMA');


-- FASE 1: PREPARE (Preparación) 
-- Terminal 1 (Lima) - Participante ORIGEN: 

-- PASO 1.1: Verificar saldo suficiente 
SELECT numero_cuenta, titular, saldo 
FROM cuentas 
WHERE numero_cuenta = 'LIMA-001' 
FOR UPDATE; 

-- Si saldo >= 1000, continuar
-- Si saldo <= 1000, votar ABORT


-- PASO 1.2: Registrar operacion PENDIENTE 
INSERT INTO transacciones_log 
(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion) 
SELECT 
	'TXN-20250928-143022', 
	id, 
	'DEBITO', 
	1000.00, 
	'PENDING', 
	'Transferencia a CUSCO-001' 
FROM cuentas 
WHERE numero_cuenta = 'LIMA-001'; 


-- PASO 1.3: Cambiar estado a PREPARED 
UPDATE transacciones_log 
SET estado = 'PREPARED', 
	timestamp_prepare = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20250928-143022' 
AND tipo_operacion = 'DEBITO'; 

-- PASO 1.4: VOTAR COMMIT 
UPDATE control_2pc 
SET votos_commit = votos_commit + 1, 
	estado_global = 'PREPARANDO' 
WHERE transaccion_id = 'TXN-20250928-143022';

-- Verificar estado 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20250928-143022'; 
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20250928-143022'; 

-- IMPORTANTE: NO HACER COMMIT NI ROLLBACK AÚN 
-- La transacción sigue abierta esperando fase 2

-- Terminal 2 (Cusco) - Participante DESTINO: 

-- PASO 2.1: Verificar que cuenta destino existe 
SELECT numero_cuenta, titular, saldo 
FROM cuentas 
WHERE numero_cuenta = 'CUSCO-001' 
FOR UPDATE; 

--Si existe, continuar 
--Si no existe, votar ABORT 

-- PASO 2.2: Registrar operación PENDIENTE 
INSERT INTO transacciones_log 
(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion) 
SELECT 
	'TXN-20250928-143022', 
	id, 
	'CREDITO', 
	1000.00, 
	'PENDING', 
	'Transferencia desde LIMA-001'
FROM cuentas 
WHERE numero_cuenta = 'CUSCO-001'; 

-- PASO 2.3: Cambiar estado a PREPARED 
UPDATE transacciones_log 
SET estado = 'PREPARED', 
	timestamp_prepare = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20250928-143022' 
AND tipo_operacion = 'CREDITO'; 

-- PASO 2.4: VOTAR COMMIT 
UPDATE control_2pc 
SET votos_commit = votos_commit + 1 
WHERE transaccion_id = 'TXN-20250928-143022'; 

-- Verificar estado 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20250928-143022'; 
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20250928-143022'; 

-- IMPORTANTE: NO HACER COMMIT NI ROLLBACK AÚN
-- FASE 2: DECISIÓN (Commit o Abort) 
-- Terminal 4 (Monitor/Coordinador): 

-- Conectar a banco_lima para ver estado global 
psql -U estudiante -d banco_lima 

-- Verificar votos 
SELECT transaccion_id, estado_global, votos_commit, votos_abort, 
	CASE 
		WHEN votos_commit = 2 THEN 'TODOS VOTARON COMMIT - PROCEDER A COMMIT' 
		WHEN votos_abort > 0 THEN 'HAY VOTOS ABORT - PROCEDER A ABORT' 
		ELSE 'ESPERANDO VOTOS'
	END AS decision 
FROM control_2pc 
WHERE transaccion_id = 'TXN-20250928-143022'; 


-- Si todos votaron COMMIT (votos_commit = 2): 
-- Terminal 1 (Lima): 
 
-- EJECUTAR LA OPERACIÓN 
UPDATE cuentas 
SET saldo = saldo - 1000.00, 
	ultima_modificacion = CURRENT_TIMESTAMP, 
	version = version + 1 
WHERE numero_cuenta = 'LIMA-001'; 


-- Marcar como COMMITTED 
UPDATE transacciones_log 
SET estado = 'COMMITTED', 
	timestamp_final = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20250928-143022' 
AND tipo_operacion = 'DEBITO'; 

-- Actualizar control 
UPDATE control_2pc 
SET estado_global = 'CONFIRMADA', 
	timestamp_decision = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20250928-143022'; 

-- COMMIT FINAL 
COMMIT; 

-- Verificar resultado 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'LIMA-001';


-- Terminal 2 (Cusco)
-- EJECUTAR LA OPERACIÓN 
UPDATE cuentas 
SET saldo = saldo - 1000.00, 
	ultima_modificacion = CURRENT_TIMESTAMP, 
	version = version + 1 
WHERE numero_cuenta = 'CUSCO-001'; 


-- Marcar como COMMITTED 
UPDATE transacciones_log 
SET estado = 'COMMITTED', 
	timestamp_final = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20250928-143022' 
AND tipo_operacion = 'DEBITO'; 

-- Actualizar control 
UPDATE control_2pc 
SET estado_global = 'CONFIRMADA', 
	timestamp_decision = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20250928-143022'; 

-- COMMIT FINAL 
COMMIT; 

-- Verificar resultado 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'CUSCO-001';

-- VERIFICACIÓN FINAL 
-- Terminal 4 (Monitor): 

-- Ver estado final en Lima 
\c banco_lima 
SELECT * FROM cuentas WHERE numero_cuenta IN ('LIMA-001'); 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20250928-143022'; 
SELECT * FROM control_2pc WHERE transaccion_id = 'TXN-20250928-143022';

-- Ver estado final en Cusco 
\c banco_cusco 
SELECT * FROM cuentas WHERE numero_cuenta IN ('CUSCO-001'); 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20250928-143022';

-- Verificar consistencia 
\c banco_lima 
SELECT 
	'LIMA' as sucursal, 
	SUM(CASE WHEN tipo_operacion = 'DEBITO' THEN -monto ELSE monto END) as balance_transaccion 
FROM transacciones_log 
WHERE transaccion_id = 'TXN-20250928-143022' 
UNION ALL 
SELECT 
'CUSCO' as sucursal, 
SUM(CASE WHEN tipo_operacion = 'CREDITO' THEN monto ELSE -monto END) as balance_transaccion 
FROM banco_cusco.transacciones_log 
WHERE transaccion_id ='TXN-20250928-143022';

-- El balance debe ser 0 (lo que sale de Lima entra a Cusco)
-- EJERCICIO 2: SIMULACIÓN DE ABORT (Saldo Insuficiente) 
-- Escenario: Intentar transferir $10,000 de LIMA-002 (saldo: $3,000) a AQP-001 

-- Generar nuevo ID
SELECT 'TXN-' || to_char(now(),'YYYYMMDD-HH24MISS') AS transaccion_id;
-- ejemplo: TXN-20250928-144500

-- Terminal 1 (Lima): 

BEGIN; 

INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20250928-144500', 'INICIADA', 'LIMA');

-- Intentar preparar 
SELECT numero_cuenta, titular, saldo 
FROM cuentas 
WHERE numero_cuenta = 'LIMA-002' 
FOR UPDATE; 

-- Saldo 300 < 10000 = INSUFICIENTE

-- Registrar intento 
INSERT INTO transacciones_log 
(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion) 
SELECT 
	'TXN-20250928-144500', 
	id, 
	'DEBITO', 
	10000.00, 
	'PENDING', 
	'Transferencia a AQP-061 - SALDO INSUFICIENTE' 
FROM cuentas
WHERE numero_cuenta = 'LIMA-002'; 

-- VOTAR ABORT 
UPDATE control_2pc 
SET votos_abort = votos_abort + 1, 
	estado_global = 'ABORTADA'
WHERE transaccion_id = 'TXN-20250928-144500'; 

-- Marcar como ABORTADO
UPDATE transacciones_log 
SET estado = 'ABORTED', 
	timestamp_final = CURRENT_TIMESTAMP 
WHERE transaccion_id = 'TXN-20250928-144500'; 

-- ROLLBACK
ROLLBACK; 


SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20250928-144500';

-- Terminal 3 (Arequipa): 
BEGIN; 

-- Como el coordinador ya decidio ABORT, este participante tambien aborta
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20250928-144500', 'ABORTADA', 'LIMA'); 

ROLLBACK; 

-- EJERCICIO 3: SIMULACIÓN DE DEADLOCK DISTRIBUIDO 
-- Escenario: Dos transferencias cruzadas simultáneas 
-- Transferencia A: LIMA-003 > CUSCO-002 ($500) 
-- Transferencia B: CUSCO-002 > LIMA-003 ($300) 
-- Ejecutadas simultáneamente 

-- Terminal 1 (Transferencia A - Lima primero): 
BEGIN; 

-- Bloquear LIMA-003
SELECT * FROM cuentas WHERE numero_cuenta = 'LIMA-003' FOR UPDATE; 
-- BLOQUEADO

-- Esperar 5 segundo (simular procesamiento)
SELECT pg_sleep(5); 

-- Intertar bloquear CUSCO-002 (conectar a Cusco)
-- Esto requerira dblink o hacer manualmente

-- Terminal 2 (Transferencia B - Cusco primero): 
-- EJECUTAR INMEDIATAMENTE DESPUES DE TERMINAL 1
BEGIN; 

SELECT * FROM cuentas WHERE numero_cuenta = 'CUSCO-002' FOR UPDATE; 
-- BLOQUEADO

-- Esperar 2 segundos
SELECT pg_sleep(2);
-- Intertar bloquear LIMA - 003
-- ESTO CAUSARA ESPERA (terminal 1 ya lo tiene bloqueado)


-- Instalación de dblink para deadlock distribuido 
-- Terminal 1 (Lima): 
-- Salir de la transaccion actual
ROLLBACK; 

-- Instalar extension dblink
CREATE EXTENSION IF NOT EXISTS dblink; 

-- Configurar conexion a Cusco
SELECT dblink_connect('conn_cusco', 
	'host=localhost dbname=banco_cusco user=estudiante password=lab2024'); 

-- Ahora ejecutar deadlockreal: 
-- Terminal 1: 
 
BEGIN;
-- Bloquear local 
SELECT * FROM cuentas WHERE numero_cuenta = 'LIMA-003' FOR UPDATE; 

-- Esperar 5 segundos 
SELECT pg_sleep(5);

-- Intentar bloquear remoto en Cusco 
SELECT * FROM dblink('conn_cusco', 
'SELECT * FROM cuentas WHERE numero_cuenta = ''CUSCO-002'' FOR UPDATE' 
) AS t1(id int, numero_cuenta varchar, titular varchar, saldo numeric, sucursal varchar, fecha_creacion timestamp, ultima_modificacion timestamp, version int); 

-- SE QUEDARÁ ESPERANDO 

-- Terminal 2 (Cusco): 
 
-- Instalar dblink 
CREATE EXTENSION IF NOT EXISTS dblink; 

SELECT dblink_connect('conn_lima', 
	'host=localhost dbname=banco_lima user=estudiante password=lab2024'); 
BEGIN;

-- Bloquear local
SELECT * FROM cuentas WHERE numero_cuenta = 'LIMA-003' FOR UPDATE; 

-- Esperar 2 segundos 
SELECT pg_sleep(2);

-- Intentar bloquear remoto en Lima 
SELECT * FROM dblink('conn_lima', 
'SELECT * FROM cuentas WHERE numero_cuenta = ''LIMA-003'' FOR UPDATE' 
) AS t1(id int, numero_cuenta varchar, titular varchar, saldo numeric, sucursal varchar, fecha_creacion timestamp, ultima_modificacion timestamp, version int); 

-- DEADLOCK DETECTADO 
-- PostgresqL abortará una de las transacciones

-- Resultado esperado: 
-- ERROR: deadlock detected  
-- DETAIL: Process X waits for ShareLock on transaction Y; blocked by process 
-- Z.
-- Process Z waits for ShareLock on transaction X; blocked by process X. 


-- Limpieza: 
-- En ambas terminales
ROLLBACK; 

-- PARTE B: AUTOMATIZACIÓN CON PL/pgSQL 
-- PASO 4: CREAR FUNCIONES ALMACENADAS 
-- 4.1 Función de preparación (PREPARE) 
-- Terminal 1 (Lima): 

\c banco_lima 

CREATE OR REPLACE FUNCTION preparar_debito( 
	p_transaccion_id VARCHAR, 
	p_numero_cuenta VARCHAR, 
	p_monto NUMERIC 
) RETURNS BOOLEAN AS $$ 
DECLARE 
	v_cuenta_id INTEGER; 
	v_saldo_actual NUMERIC; 
BEGIN 
	-- Bloquear y verificar cuenta
	SELECT id, saldo INTO v_cuenta_id, v_saldo_actual 
	FROM cuentas
	WHERE numero_cuenta = p_numero_cuenta 
	FOR UPDATE

	-- Verificar si cuenta existe
	IF NOT FOUND THEN
		RAISE NOTICE 'Cuenta % no encontrada', p_numero_cuenta; 
		RETURN FALSE; 
	END IF 

 	-- Verificar saldo suficiente
	IF v_saldo_actual < p_monto THEN 
		RAISE NOTICE 'Saldo insuficiente. Disponible: %, Requerido: %', 
			v_saldo_actual, p_monto; 
		RETURN FALSE; 
	END IF; 
	
	-- Registrar en log 
	INSERT INTO transacciones_log (transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion) 
	VALUES (
		p_transaccion_id, 
		v_cuenta_id, 
		'DEBITO', 
		p_monto, 
		'PREPARED', 
		'Preparado para débito' 
	);

	RAISE NOTICE 'VOTE-COMMIT para cuenta %', p_numero_cuenta; 
	RETURN TRUE; 

EXCEPTION 
	WHEN OTHERS THEN 
		RAISE NOTICE 'Error en preparación: %', SQLERRM; 
		RETURN FALSE; 
END; 
$$ LANGUAGE plpgsql; 

-- Probar la función

BEGIN; 
SELECT preparar_debito('TXN-TEST-001', 'LIMA-001', 500.00); 
-- Debe retornar TRUE 
ROLLBACK;

BEGIN; 
SELECT preparar_debito('TXN-TEST-002', 'LIMA-001', 50000.00); 
-- Debe retornar FALSE (saldo insuficiente) 
ROLLBACK; 

-- 4.2 Función de preparación crédito 
-- Terminal 2 (Cusco): 
 
\c banco_cusco 

CREATE OR REPLACE FUNCTION preparar_credito( 
	p_transaccion_id VARCHAR, 
	p_numero_cuenta VARCHAR, 
	p_monto NUMERIC 
) RETURNS BOOLEAN AS $$ 
DECLARE 
	v_cuenta_id INTEGER; 
BEGIN 
	-- Bloquear y verificar cuenta 
	SELECT id INTO v_cuenta_id 
	FROM cuentas 
	WHERE numero_cuenta = p_numero_cuenta 
	FOR UPDATE;
	
	-- Verificar si cuenta existe 
	IF NOT FOUND THEN 
		RAISE NOTICE 'Cuenta % no encontrada', p_numero_cuenta; 
		RETURN FALSE; 
	END IF; 
	
	-- Registrar en log  
	INSERT INTO transacciones_log 
	(transaccion_id, cuenta_id, tipo_operacion, monto, estado, descripcion) 
	VALUES( 
		p_transaccion_id, 
		v_cuenta_id, 
		'CREDITO', 
		p_monto, 
		'PREPARED', 
		'Preparado para crédito' 
	);
	
	RAISE NOTICE 'VOTE-COMMIT para cuenta %', p_numero_cuenta; 
	RETURN TRUE; 
	
EXCEPTION 
	WHEN OTHERS THEN 
		RAISE NOTICE 'Error en preparación: %', SQLERRM; 
		RETURN FALSE; 
END; 
$$ LANGUAGE plpgsql; 

-- 4.3 Función de commit 
-- Terminal 1 (Lima): 
 
CREATE OR REPLACE FUNCTION confirmar_transaccion( 
	p_transaccion_id VARCHAR 
) RETURNS VOID AS $$ 
DECLARE 
	v_registro RECORD; 
BEGIN 
-- Obtener todas las operaciones preparadas 
	FOR v_registro IN 
		SELECT cuenta_id, tipo_operacion, monto 
		FROM transacciones_log 
		WHERE transaccion_id = p_transaccion_id 
		AND estado = 'PREPARED' 
	LOOP
		-- Ejecutar operación 
		IF v_registro.tipo_operacion = 'DEBITO' THEN 
		UPDATE cuentas 
		SET saldo = saldo - v_registro.monto, 
			ultima_modificacion = CURRENT_TIMESTAMP, 
			version = version + 1 
		WHERE id = v_registro.cuenta_id; 
		
		ELSIF v_registro.tipo_operacion = 'CREDITO' THEN 
			UPDATE cuentas 
			SET saldo = saldo + v_registro.monto, 
				ultima_modificacion = CURRENT_TIMESTAMP, 
				version = version + 1 
			WHERE id = v_registro.cuenta_id; 
		END IF; 

		-- Actualizar log 
		UPDATE transacciones_log 
		SET estado = 'COMMITTED', 
			timestamp_final = CURRENT_TIMESTAMP 
		WHERE transaccion_id = p_transaccion_id 
			AND cuenta_id = v_registro.cuenta_id; 
		
		RAISE NOTICE 'Operación % confirmada para cuenta ID %', 
			v_registro.tipo_operacion, v_registro.cuenta_id; 
	END LOOP; 
	
	-- Actualizar control 2PC 
	UPDATE control_2pc 
	SET estado_global = 'CONFIRMADA', 
		timestamp_decision = CURRENT_TIMESTAMP 
	WHERE transaccion_id = p_transaccion_id; 
	
	RAISE NOTICE 'Transacción % confirmada exitosamente', p_transaccion_i 
END; 
$$ LANGUAGE plpgsql; 

-- Copiar la misma función en Cusco (Terminal 2) 
-- 4.4 Función de abort 
-- Terminal 1 (Lima) y Terminal 2 (Cusco): 

CREATE OR REPLACE FUNCTION abortar_transaccion( 
	p_transaccion_id VARCHAR 
) RETURNS VOID AS $$ 
BEGIN 
	-- Marcar todas las opeaciones como Abortadas 
	UPDATE transacciones_log 
	SET estado = 'ABORTED', 
		timestamp_final = CURRENT_TIMESTAMP 
	WHERE transaccion_id = p_transaccion_id; 

	-- Actualizar control 
	UPDATE control_2pc 
	SET estado_global = 'ABORTADA', 
		timestamp_decision = CURRENT_TIMESTAMP 
	WHERE transaccion_id = p_transaccion_id; 

	RAISE NOTICE 'Transacción % abortada', p_transaccion_id; 
END; 
$$ LANGUAGE plpgsql;

-- EJERCICIO 4: USAR FUNCIONES PARA 2PC AUTOMATIZADO 
-- Escenario: Transferir $800 de LIMA-004 a CUSCO-003 
-- Terminal 1 (Lima): 

-- Generar id 
SELECT 'TXN-' || to_char(now(), 'YYYYMMDD-HH24MISS') AS transaccion_id; 
-- ejemplo: TXN-20250928-150000

BEGIN;

-- Registrar en control
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20250928-150000', 'PREPARANDO', 'LIMA'); 

-- FASE PREPARE
SELECT preparar_credito('TXN-20250928-150000', 'LIMA-004', 800.00); 
-- Resultado: TRUE = VOTE-COMMIT
-- NO HACER COMMIT TODAVIA

-- Terminal 2 (Cusco)
BEGIN;

-- Registrar en control
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador) 
VALUES ('TXN-20250928-150000', 'PREPARANDO', 'LIMA'); 

-- FASE PREPARE
SELECT preparar_credito('TXN-20250928-150000', 'CUSCO-003', 800.00); 
-- Resultado: TRUE = VOTE-COMMIT
-- NO HACER COMMIT TODAVIA

-- Terminal 4 (Monitor - verificar votos): 

\c banco_lima 

-- Verificar estado de preparación 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20250928-150000'; 

\c banco_cusco 

SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20250928-150000';

-- Si ambos votaron COMMIT, ejecutar FASE 2: 
-- Terminal 1 (Lima): 

-- FASE  COMMIT 
SELECT confirmar_transaccion('TXN-20250928-150000');

-- COMMIT de la transacción 
COMMIT;

-- Verificar resultado 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'LIMA-004'; 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20250928-1500000'; 

-- Terminal 2 (Cusco): 

-- FASE COMMIT 
SELECT confirmar_transaccion('TXN-20250928-1500800');

-- COMMIT de la transacción 
COMMIT;

-- Verificar resultado 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'CUSCO-003'; 
SELECT * FROM transacciones_log WHERE transaccion_id = 'TXN-20250928-156000';

-- PASO 5: FUNCIÓN COORDINADORA COMPLETA 
-- 5.1 Crear función coordinadora avanzada 
-- Terminal 1 (Lima): 

CREATE OR REPLACE FUNCTION transferencia_distribuida_coordinador( 
	p_cuenta_origen VARCHAR, 
	p_cuenta_destino VARCHAR, 
	p_monto NUMERIC, 
	p_db_destino VARCHAR 
) RETURNS TABLE ( 
exito BOOLEAN, 
mensaje TEXT, 
transaccion_id VARCHAR 
) AS $ 
DECLARE 
	v_transaccion_id VARCHAR; 
	v_prepare_origen BOOLEAN; 
	v_prepare destino BOOLEAN; 
	v_dblink_name VARCHAR; 
	v_dblink_conn VARCHAR; 
BEGIN 
	-- Generar ID único 
	v_transaccion_id := 'TXN-' || to_char(now(), 'YYYYMMDD-HH24MI') || '-' || 
					floor(random() * 10000)::TEXT;
					
	-- Configurar conexión según destino 
	v_dblink_name := 'conn_' || p_db_destino; 
	v_dblink_conn := 'host=localhost dbname=banco_' || p_db_destino || 
					'user=estudiante password=lab2024'; 
	-- Conectar a base de datos destino 
	PERFORM dblink_connect (v_dblink_name, v_dblink_conn);

-- Iniciar en control 
INSERT INTO control_2pc (transaccion_id, estado_global, coordinador, participantes) 
VALUES (v_transaccion_id, 'PREPARANDO', 'LIMA', ARRAY['LIMA', UPPER(p_db_destino)]);

-- FASE 1: PREPARE  
RAISE NOTICE '--- FASE 1: PREPARE --- '

-- Preparar débito local 
v_prepare_origen := preparar_debito(v_transaccion_id, p_cuenta_origen, p_monto); 
RAISE NOTICE 'Prepare ORIGEN: %', CASE WHEN v_prepare_origen THEN 'COMMIT' ELSE 'ABORT' END; 

-- Preparar crédito remoto 
SELECT resultado INTO v_prepare destino 
FROM dblink(v_dblink_name, 
	format('SELECT preparar_credito(%L, %L, %s)', 
			v_transaccion_id, p_cuenta_destino, p_monto) 
) AS t1(resultado BOOLEAN); 
RAISE NOTICE 'Prepare DESTINO: %', CASE WHEN v_prepare destino THEN 'COMMIT' ELSE 'ABORT' END;

-- FASE 2: DECISIÓN 
RAISE NOTICE '--- FASE 2: DECISIÓN --- ' 

IF v_prepare_origen AND v_prepare destino THEN -- 
	-- COMMIT GLOBAL 
	RAISE NOTICE 'Decisión: GLOBAL-COMMIT';
	
	-- Confirmar local 
	PERFORM confirmar_transaccion(v_transaccion_id);
	
	-- Confirmar remoto 
	PERFORM dblink exec(v_dblink_name, 
		format ('SELECT confirmar_transaccion(%L)', v_transaccion_id)
	);
	-- Desconectar 
	PERFORM dblink_disconnect(v_dblink_name); 
	
	RETURN QUERY SELECT TRUE, 'Transferencia exitosa', v_transaccion_id; 
ELSE 
	-- ABORT GLOBAL 
	RAISE NOTICE 'Decisión: GLOBAL-ABORT';
	
	-- Abortar local 
	PERFORM abortar_transaccion(v_transaccion_id);
	
	-- Abortar remoto 
	PERFORM dblink_exec(v_dblink_name, 
		format('SELECT abortar_transaccion(%L)', v_transaccion_id)
	);
	
		-- Desconectar 
		PERFORM dblink disconnect(v_dblink_name); 
		RETURN QUERY SELECT FALSE, 'Transferencia abortada - Verificar logs', v_transaccion_id; 
	END IF; 
EXCEPTION 
	WHEN OTHERS THEN
	-- En caso de error, abortar todo 
	RAISE NOTICE 'Error: %', SQLERRM; 
	BEGIN 
		PERFORM abortar_transaccion(v_transaccion_id); 
		PERFORM dblink_disconnect(v_dblink_name); 
	EXCEPTION 
		WHEN OTHERS THEN NULL; 
	END; 
		RETURN QUERY SELECT FALSE, 'Error: ' || SQLERRM, v_transaccion_id;
END; 
$ LANGUAGE plpgsql;

-- 5.2 Usar la función coordinadora 
-- Terminal 1 (Lima): 

-- Asegurarse de que dblink está disponible 
CREATE EXTENSION IF NOT EXISTS dblink;  

-- Ejecutar transferencia automatizada 
BEGIN; 

SELECT * FROM transferencia_distribuida_coordinador ( 
	'LIMA-005', 
	'CUSCO-004', 
	1200.00, 
	'cusco' 
); 

COMMIT;

-- Verificar resultados 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero cuenta = 'LIMA-005'; 

-- Terminal 2 (Cusco): 
 
-- Verificar que se recibió el crédito 
SELECT numero_cuenta, titular, saldo FROM cuentas WHERE numero_cuenta = 'CUSCO-004';

-- Ver log de transacciones 
SELECT * FROM transacciones_log ORDER BY timestamp_inicio DESC LIMIT 5; 

-- PARTE C: SAGA PATTERN CON TRIGGERS 
-- PASO 6: IMPLEMENTAR SAGA CON COMPENSACIONES 
-- 6.1 Crear tablas para SAGA 
-- Terminal 1 (Lima): 
 
\c banco_lima 

-- Tabla de órdenes SAGA 
CREATE TABLE saga_ordenes ( 
	orden_id VARCHAR(50) PRIMARY KEY, 
	tipo VARCHAR(50),
	estado VARCHAR(20), 
	datos JSONB,
	paso_actual INTEGER DEFAULT 0, 
	timestamp_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
	timestamo_final TIMESTAMP 
);

-- Tabla de pasos SAGA 
CREATE TABLE saga_pasos ( 
	id SERIAL PRIMARY KEY, 
	orden_id VARCHAR(50) REFERENCES saga_ordenes(orden_id), 
	numero_paso INTEGER, 
	nombre_paso VARCHAR(100), 
	estado VARCHAR(20), 
	accion_ejecutada TEXT, 
	compensacion_ejecutada TEXT, 
	timestamp_ejecucion TIMESTAMP, 
	timestamp_compensacion TIMESTAMP, 
	error_mensaje TEXT 
); 

-- Tabla de eventos SAGA 
CREATE TABLE saga eventos ( 
	id SERIAL PRIMARY KEY, 
	orden_id VARCHAR(50) REFERENCES saga_ordenes(orden_id), 
	tipo_evento VARCHAR(50), 
	descripcion TEXT, 
	timestamp_evento TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
);

-- Copiar las mismas tablas en Cusco y Arequipa 
-- 6.2 Crear función para ejecutar SAGA 
-- Terminal 1 (Lima): 
 
CREATE OR REPLACE FUNCTION ejecutar_saga_transferencia( 
	p_cuenta_origen VARCHAR, 
	p_cuenta_destino VARCHAR, 
	p_monto NUMERIC, 
	p_db_destino VARCHAR 
) RETURNS TABLE ( 
	exito BOOLEAN, 
	orden_id VARCHAR, 
	mensaje TEXT 
) AS $ 
DECLARE 
	v_orden_id VARCHAR; 
	v_pasol_exito BOOLEAN := FALSE; 
	v_paso2 exito BOOLEAN := FALSE; 
	v_paso3_exito BOOLEAN := FALSE; 
	v_cuenta_origen_id INTEGER; 
	v_saldo_origen NUMERIC; 
BEGIN
	-- Generar ID de orden 
	v_orden_id := 'SAGA-' || to_char(now(), 'YYYYMMDD-HH24MISS');
	
	-- Crear orden SAGA 
	INSERT INTO saga_ordenes (orden_id, tipo, estado, datos) 
	VALUES ( 
		v_orden_id, 
		'TRANSFERENCIA', 
		'INICIADA', 
		jsonb_build_object( 
			'cuenta_origen', p_cuenta_origen, 
			'cuenta_destino', p_cuenta_destino, 
			'monto', p_monto, 
			'db_destino', p_db destino
		)
	);

	-- Definir pasos 
	INSERT INTO saga_pasos (orden_id, numero_paso, nombre paso, estado) 
	VALUES 
		(v_orden_id, 1, 'Bloquear Fondos Origen', 'PENDIENTE'), 
		(v_orden_id, 2, 'Transferir a Destino', 'PENDIENTE'), 
		(v_orden_id, 3, 'Confirmar Débito Origen', 'PENDIENTE'); -- 
	
	-- Actualizar estado 
	UPDATE saga_ordenes SET estado = 'EN PROGRESO', paso_actual = 1 
	WHERE orden_id = v_orden_id; 

	-- ======== PASO 1: Bloquear Fondos Origen ========
	RAISE NOTICE '--- PASO 1: Bloquear Fondos Origen ---'; 
		
	BEGIN 
		SELECT id, saldo INTO v_cuenta_origen_id, v_saldo origen 
		FROM cuentas 
		WHERE numero_cuenta = p_cuenta_origen 
		FOR UPDATE;
			
		
		IF NOT FOUND THEN 
			RAISE EXCEPTION 'Cuenta origen % no encontrada', p_cuenta_origen;  
		END IF; 
		
		IF v_saldo origen < p_monto THEN 
			RAISE EXCEPTION 'Saldo insuficiente. Disponible: %, Requerido: %', 
			v_saldo_origen, p_monto; 
		END IF;
	
		-- Marcar fondos como bloqueados (usando version como lock) 
		UPDATE cuentas 
			SET version = version + 1 
		WHERE id = v_cuenta_origen_id;
		
		-- Registrar éxito 
		UPDATE saga_pasos 
		SET estado = 'EJECUTADO', 
			timestamp_ejecucion = CURRENT_TIMESTAMP, 
			accion_ejecutada = format('Bloqueados $%s en cuenta %s', p_monto, p_cuenta_origen) 
		WHERE orden_id = v_orden_id AND numero_paso = 1; 

		INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
		VALUES (v_orden_id, 'PASO COMPLETADO', 'Paso 1: Fondos bloqueados');
		
		v_pasol exito := TRUE; 
		RAISE NOTICE 'Paso 1 completado'; 
		
	EXCEPTION 
		WHEN OTHERS THEN 
			UPDATE saga_pasos 
			SET estado = 'FALLIDO', 
				timestamp_ejecucion = CURRENT_TIMESTAMP, 
				error_mensaje = SQLERRM 
			WHERE orden_id = v_orden_id AND numero paso = 1; 
			
			INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
			VALUES (v_orden_id, 'PASO_FALLIDO', 'Paso 1: ' || SQLERRM); 
			
			RAISE NOTICE 'Paso 1 falló: %', SQLERRM;
			
				-- Finalizar SAGA como fallida 
				UPDATE saga_ordenes SET estado = 'FALLIDA', timestamp_final = CURRENT_TIMESTAMP 
				WHERE orden_id = v_orden_id; 
				RETURN QUERY SELECT FALSE, v_orden_id, 'Fallo en paso 1: ' || SQLERRM; 
				RETURN; 
		END;


	-- ============ PASO 2: Transferir a Destino ============: 
	RAISE NOTICE  ' --- PASO 2: Transferir a Destino ---'; 
	
	UPDATE saga_ordenes SET paso_actual = 2 WHERE orden_id = v_orden_id; 
	
	BEGIN
	
		-- Simular transferencia a destino (usando dblink) 
		PERFORM dblink_connect('conn_destino', 
			format('host=localhost dbname=banco_%s user=estudiante password=lab2024', p_db_destino) 
		);

		-- Acreditar en destino 
		PERFORM dblink_exec('conn_destino', 
			format('UPDATE cuentas SET saldo = saldo + %s WHERE numero_cuenta = %L', 
			p_monto, p_cuenta destino) 
		);
		
		PERFORM dblink_disconnect('conn_destino'); 
		
		-- Registrar éxito 
		UPDATE saga_pasos 
		SET estado = 'EJECUTADO', 
			timestamp_ejecucion = CURRENT_TIMESTAMP, 
			accion_ejecutada = format('Acreditados $%s en cuenta %s', p_monto, p_cuenta_destino) 
		WHERE orden_id = v_orden_id AND numero_paso = 2; 

		INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
		VALUES (v_orden_id, 'PASO COMPLETADO', 'Paso 2: Fondos acreditados en destino'); 

		v_paso2_exito := TRUE; 
		RAISE NOTICE 'Paso 2 completado'; 
		
	EXCEPTION 
		WHEN OTHERS THEN 
			UPDATE saga_pasos 
			SET estado = 'FALLIDO', 
				timestamp_ejecucion = CURRENT_TIMESTAMP, 
				error_mensaje = SQLERRM 
			WHERE orden_id = v_orden_id AND numero_paso = 2; 
			
			INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
			VALUES (v_orden_id, 'PASO_FALLIDO', 'Paso 2: ' || SQLERRM); 
			
			RAISE NOTICE 'Paso 2 falló: %', SQLERRM;
			
			-- COMPENSAR PASO 1 
			RAISE NOTICE 'Iniciando compensaciones...'; 
			UPDATE saga_ordenes SET estado = 'COMPENSANDO' WHERE orden_id = v_orden_id;
	
			-- Compensación: Desbloquear fondos 
			UPDATE cuentas 
			SET version = version - 1 
			WHERE id = v_cuenta_origen_id; 
			
			UPDATE saga_pasos 
			SET estado = 'COMPENSADO', 
				timestanp_compensacion = CURRENT_TIMESTANP, 
				conpensacion_ejecutada - 'Fondos desbloqueados' 
			WHERE orden_id = v_orden_id AND numero_paso = 1; 
			
			INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
			VALUES (v_orden_id, 'COMPENSACION_EJECUTADA', 'Compensación Paso 1: Fondos desbloqueados');
	
			-- Finalizar SAGA como compensada 
			UPDATE saga_ordenes SET estado = 'COMPENSADA', timestamp_final = CURRENT_TIMESTAMP 
			WHERE orden_id = v_orden_id; 
			
			RETURN QUERY SELECT FALSE, v_orden_id, 'Fallo en paso 2 (compensado): ' || SQLERRM; 
			RETURN; 
		END;

	-- ========== PASO 3: Confirmar Débito Origen ==========
	RAISE NOTICE '--- PASO 3: Confirmar Débito Origen ---'
	
	UPDATE saga_ordenes SET paso_actual = 3 WHERE orden_id = v_orden_id; 
	
	BEGIN
		-- Ejecutar débito final 
		UPDATE cuentas 
		SET saldo = saldo - p_monto, 
			ultima_modificacion = CURRENT_TIMESTAMP 
		WHERE id = v_cuenta_origen_id; 
	
		-- Registrar éxito 
		UPDATE saga_pasos 
		SET estado = 'EJECUTADO', 
			timestamp_ejecucion = CURRENT_TIMESTAMP, 
			accion_ejecutada = format('Debitados $%s de cuenta %s', p_monto, p_cuenta origen) 
		WHERE orden_id = v_orden_id AND numero_paso = 3; 
		
		INSERT INTO saga_eventos (orden_id, tipo_evento, descripcion) 
		VALUES (v_orden_id, 'PASO COMPLETADO', 'Paso 3: Débito confirmado'); 
	
		v_paso3_exito := TRUE; 
		RAISE NOTICE 'Paso 3 completado';
		
		-- SAGA COMPLETADA 
		UPDATE saga ordenes SET estado = 'COMPLETADA', timestamp_final = CURRENT_TIMESTAMP 
		WHERE orden_id = v_orden_id; 
	
		RAISE NOTICE 'SAGA completada exitosamente';
		
		RETURN QUERY SELECT TRUE, v_orden_id, 'Transferencia SAGA completada';
		
	EXCEPTION 
		WHEN OTHERS THEN 
			UPDATE saga_pasos 
			SET estado = 'FALLIDO', 
				timestamp_ejecucion = CURRENT_TIMESTAMP, 
				error_mensaje = SQLERRM 
			WHERE orden_id = v_orden_id AND numero_paso = 3;
			
			RAISE NOTICE 'Paso 3 falló: %', SQLERRM;
			
			-- COMPENSAR PASO 2 y PASO 1 
			RAISE NOTICE 'Iniciando compensaciones completas...'; 
			UPDATE saga_ordenes SET estado = 'COMPENSANDO' WHERE orden_id = v_orden_id; -- 
	
			-- Compensación Paso 2: Revertir crédito en destino 
			BEGIN 
				PERFORM dblink_connect('conn_destino', 
					format('host=localhost dbname-banco %s user=estudiante password=lab2024', p_db_destino)
				);
				
				PERFORM dblink_exec('conn_destino', 
					format('UPDATE cuentas SET saldo = saldo - %s WHERE numero cuenta = %L', 
						p_monto, p_cuenta destino) 
				);
				
				PERFORM dblink_disconnect('conn_destino'); 
				
					UPDATE saga_pasos 
					SET estado = 'COMPENSADO', 
						timestamp_compensacion = CURRENT_TIMESTAMP, 
						compensacion_ejecutada = 'Crédito revertido en destino' 
					WHERE orden_id = v_orden_id AND numero_paso = 2; 
			EXCEPTION 
				WHEN OTHERS THEN 
					RAISE NOTICE 'Error en compensación paso 2: %', SQLERRM; 
	
			END;
		
			-- Compensación Paso 1: Desbloquear fondos 
			UPDATE cuentas 
			SET version = version - 1 
			WHERE id = v_cuenta_origen_id; 
			
			UPDATE saga_pasos 
			SET estado = 'COMPENSADO', 
				timestamp_compensacion = CURRENT_TIMESTAMP, 
				compensacion_ejecutada = 'Fondos desbloqueados' 
			WHERE orden_id = v_orden_id AND numero_paso = 1;
			
			-- Finalizar SAGA 
			UPDATE saga_ordenes SET estado = "COMPENSADA", timestamp_final = CURRENT_TIMESTAMP 
			WHERE orden_id = v_orden_id; 
			
			RETURN QUERY SELECT FALSE, v_orden_id, 'Fallo en paso 3 (compensado): ' || SQLERRM; 
	END; 
END; 
$ LANGUAGE plpgsql;


-- 6.3 Probar SAGA exitosa 
-- Terminal 1 (Lima): 

BEGIN; 

SELECT * FROM ejecutar_saga_transferencia( 
	'LIMA-081', 
	'CUSCO-805', 
	300.00, 
	'cusco' 
);

COMMIT; 

-- Ver el flujo completo de SAGA
SELECT * FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1; 
SELECT * FROM saga_pasos WHERE orden_id = ( 
	SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1 
) ORDER BY numero_paso; 
SELECT * FROM saga_eventos WHERE orden_id = ( 
	SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1 
) ORDER BY timestamp_evento; 

-- 6.4 Probar SAGA con fallo y compensación 
-- Terminal 1 (Lima): 

BEGIN;

-- Intentar transferir a cuenta inexistente (forzar fallo en paso 2) 
SELECT * FROM ejecutar_saga_transferencia( 
	'LIMA-002', 
	'CUSCO-999', 
	500.00, 
	'cusco' 
);

COMMIT; 

-- Ver cómo se compensó 
SELECT * FROM saga_ordenes ORDER BY timestamp_inicio DESC LINIT 1; 
SELECT 
	numero_paso, 
	nombre_paso, 
	estado, 
	accion_ejecutada, 
	compensacion_ejecutada, 
	error_mensaje 
FROM saga_pasos 
WHERE orden_id = (SELECT orden_id FROM saga_ordenes ORDER BY timestamp_inicio DESC LIMIT 1) 
ORDER BY numero_paso;

-- Ver eventos de compensación 
SELECT * FROM saga_eventos 
WHERE orden_id = (SELECT orden_id FROM saga ordenes ORDER BY timestamp_inicio DESC LIMIT 1) 
ORDER BY timestamp_evento
