-- LABORATORIO N5

-- PARTE 1: CONFIGURACIÓN Y TRANSACCIONES BÁSICAS

-- Paso 1.1: Preparación del entorno
-- 1.1.1 Crear la base de datos de práctica
CREATE DATABASE laboratorio_transacciones;

-- 1.1.2 Crear las tablas necesarias
-- Tabla de cuentas bancarias
CREATE TABLE cuentas (
    id SERIAL PRIMARY KEY,
    numero_cuenta VARCHAR(20) UNIQUE NOT NULL,
    titular VARCHAR(100) NOT NULL,
    saldo DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    fecha_apertura DATE DEFAULT CURRENT_DATE,
    activa BOOLEAN DEFAULT TRUE,
    CONSTRAINT saldo_positivo CHECK (saldo >= 0)
);

-- Tabla de transacciones bancarias
CREATE TABLE movimientos (
    id SERIAL PRIMARY KEY,
    cuenta_origen VARCHAR(20),
    cuenta_destino VARCHAR(20),
    monto DECIMAL(12, 2) NOT NULL,
    tipo_operacion VARCHAR(20) NOT NULL,
    descripcion TEXT,
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'COMPLETADO'
);

-- Tabla de productos para e-commerce
CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio DECIMAL(12, 2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    categoria VARCHAR(50),
    activo BOOLEAN DEFAULT TRUE,
    CONSTRAINT stock_no_negativo CHECK (stock >= 0)
);

-- Tabla de pedidos
CREATE TABLE pedidos (
    id SERIAL PRIMARY KEY,
    cliente_nombre VARCHAR(100) NOT NULL,
    cliente_email VARCHAR(100) NOT NULL,
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(12, 2) DEFAULT 0.00,
    estado VARCHAR(20) DEFAULT 'PENDIENTE'
);

-- Tabla de detalle de pedidos
CREATE TABLE detalle_pedidos (
    id SERIAL PRIMARY KEY,
    pedido_id INTEGER REFERENCES pedidos(id),
    producto_id INTEGER REFERENCES productos(id),
    cantidad INTEGER NOT NULL,
    precio_unitario DECIMAL(12, 2) NOT NULL,
    subtotal DECIMAL(12, 2) NOT NULL
);

-- 1.1.3 Insertar datos de prueba
INSERT INTO cuentas (numero_cuenta, titular, saldo) VALUES
('CTA-001', 'Juan Perez', 5000.00),
('CTA-002', 'Maria Garcia', 3000.00),
('CTA-003', 'Carlos Lopez', 2000.00),
('CTA-004', 'Ana Martinez', 1500.00),
('CTA-005', 'Luis Torres', 4500.00);

INSERT INTO productos (nombre, precio, stock, categoria) VALUES
('Laptop HP Pavilion', 2500.00, 15, 'Electrónicos'),
('Mouse Inalámbrico', 45.00, 50, 'Accesorios'),
('Teclado Mecánico', 180.00, 30, 'Accesorios'),
('Monitor 24"', 800.00, 10, 'Electrónicos'),
('Webcam HD', 120.00, 20, 'Accesorios');

-- Verificar datos insertados
SELECT 'Cuentas' as tabla, COUNT(*) as registros FROM cuentas
UNION ALL
SELECT 'Productos' as tabla, COUNT(*) as registros FROM productos;


-- Paso 1.2: Primera transacción básica

-- 1.2.1 Transferencia bancaria simple

-- Ver estado iniciales
SELECT numero_cuenta, titular, saldo 
FROM cuentas 
WHERE numero_cuenta IN ('CTA-001', 'CTA-002');

-- Transferencia: Juan transfiere $500 a Maria
BEGIN;
	--Debitar cuenta origen
    UPDATE cuentas
	SET saldo = saldo - 500.00
	WHERE numero_cuenta = 'CTA-001';

	-- Acreditar cuenta destino
    UPDATE cuentas
	SET saldo = saldo + 500.00
	WHERE numero_cuenta = 'CTA-002';
	
    -- Registrar el movimiento
    INSERT INTO movimientos (cuenta_origen, cuenta_destino, monto, tipo_operacion, descripcion)
    VALUES ('CTA-001', 'CTA-002', 500.00, 'TRANSFERENCIA', 'Transferencia entre cuentas');
    
	-- Ver estado ANTES del commit
    SELECT numero_cuenta, titular, saldo
	FROM cuentas
	WHERE numero_cuenta IN ('CTA-001', 'CTA-002');
COMMIT;

-- Ver estado DESPUÉS del commit
    SELECT numero_cuenta, titular, saldo
	FROM cuentas
	WHERE numero_cuenta IN ('CTA-001', 'CTA-002');


-- 1.2.2 Demostrar el comportamiento sin COMMIT

-- Abrir una nueva conexión/terminal para este ejercicio
BEGIN;
	UPDATE cuentas
	SET saldo = saldo - 100.00
	WHERE numero_cuenta = 'CTA-003';
	
	-- Ver el saldo en esta sesión
	SELECT numero_cuenta, saldo FROM cuentas WHERE numero_cuenta = 'CTA-003';
	
	-- En OTRA ventana/conexión, ejecutar:
	--  SELECT numero_cuenta, saldo FROM cuentas WHERE numero_cuenta = 'CTA-003';
	
	-- ¿Qué observan? Los cambios no son visibles en otras sesiones hasta el COMMIT
	-- Volver a la primera ventana y hacer rollback
	
	ROLLBACK;
	-- Verificar que el saldo volvió a su estado original
SELECT numero_cuenta, saldo FROM cuentas WHERE numero_cuenta = 'CTA-003';



-- Paso 1.3: Transacción de pedido e-commerce

-- 1.3.1 Crear un pedido completo

-- Ver inventario inicial
SELECT id, nombre, precio, stock FROM productos WHERE id IN (1, 2, 3);
    
-- PEDIDO: Cliente compra 1 Laptop + 2 Mouse + 1 Teclado
BEGIN;
	-- Crear el pedido principal
	INSERT INTO pedidos (cliente_nombre, cliente_email, estado)
	VALUES ('Roberto Silva', 'roberto@email.com', 'PROCESANDO');
		
	-- Obtener el ID del pedido recién creado
	-- En PostgreSQL, podemos usar RETURNING o variables
	
-- Método alternativo más claro
END;


-- Reiniciemos con un enfoque más didáctico:
BEGIN;

    -- 1. Verificar stock disponible ANTES de procesar
    SELECT nombre, stock FROM productos WHERE id IN (1, 2, 3);
	
    -- 2. Crear el pedido
    INSERT INTO pedidos (cliente_nombre, cliente_email, estado)
    VALUES ('Roberto Silva', 'roberto@email.com', 'PROCESANDO');
	
    -- 3. Obtener el ID del pedido (para simplificar, asumimos que es el último)
    -- En práctica real usarían RETURNING o variables
    
	-- 4. Agregar detalles del pedido y actualizar inventario
	-- Laptop HP pavilion
    INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
    VALUES (1, 1, 1, 2500.00, 2500.00);
    INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
    VALUES (1, 2, 2, 45.00, 90.00);
    INSERT INTO detalle_pedidos (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
    VALUES (1, 3, 1, 180.00, 180.00);
    -- Actualizar stock
    UPDATE productos SET stock = stock - 1 WHERE id = 1;
    UPDATE productos SET stock = stock - 2 WHERE id = 2;
    UPDATE productos SET stock = stock - 1 WHERE id = 3;
    -- 5. Calcular y actualizar el total del pedido
    UPDATE pedidos SET total = (SELECT SUM(subtotal) FROM detalle_pedidos WHERE pedido_id = 1),
                      estado = 'CONFIRMADO'
    WHERE id = 1;
    -- Verificar el estado antes del commit
    SELECT * FROM pedidos WHERE id = 1
    UNION ALL
    SELECT 'STOCK', id, nombre, stock::text, '' FROM productos WHERE id IN (1, 2, 3);
COMMIT;
    -- Verificar estado final
    SELECT * FROM pedidos WHERE id = 1;
    SELECT id, nombre, stock FROM productos WHERE id IN (1, 2, 3);