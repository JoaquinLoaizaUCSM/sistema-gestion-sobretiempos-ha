-- =====================================================================================
-- SCRIPT DE INICIALIZACIÓN DE BASE DE DATOS - SISTEMA DE REGISTRO DE SOBRETIEMPOS
-- Empresa: Industrias San Miguel del Sur SAC (Kola Real)
-- =====================================================================================

USE appdb;

-- Eliminar tablas si existen (orden inverso por dependencias)
DROP TABLE IF EXISTS reporte_asistencia;
DROP TABLE IF EXISTS empleados;
DROP TABLE IF EXISTS area;
DROP TABLE IF EXISTS centro_coste;
DROP TABLE IF EXISTS turnos;

-- =====================================================================================
-- TABLA: centro_coste
-- Almacena los centros de coste de la empresa
-- =====================================================================================
CREATE TABLE centro_coste (
  codigo_centroCoste CHAR(8) PRIMARY KEY,
  centro_coste VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

-- =====================================================================================
-- TABLA: area
-- Almacena las áreas organizativas y puestos de trabajo
-- =====================================================================================
CREATE TABLE area (
  puesto CHAR(80) PRIMARY KEY,
  unidad_organizativa VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

-- =====================================================================================
-- TABLA: turnos
-- Define los turnos de trabajo disponibles
-- =====================================================================================
CREATE TABLE turnos (
  codigo_turno CHAR(3) PRIMARY KEY,
  hora_entrada TIME NOT NULL,
  hora_salida TIME NOT NULL
) ENGINE=InnoDB;

-- =====================================================================================
-- TABLA: empleados
-- Almacena información de los trabajadores
-- =====================================================================================
CREATE TABLE empleados (
  codigo CHAR(6) PRIMARY KEY,
  puesto_area CHAR(80) NOT NULL,
  Codigo_CentroCoste CHAR(8) NOT NULL,
  nombre VARCHAR(80) NOT NULL,
  dni CHAR(8) UNIQUE NOT NULL,
  subdivision VARCHAR(100),
  FOREIGN KEY (Codigo_CentroCoste) REFERENCES centro_coste(codigo_centroCoste),
  FOREIGN KEY (puesto_area) REFERENCES area(puesto)
) ENGINE=InnoDB;

CREATE INDEX idx_nombre_empleado ON empleados(nombre);
CREATE INDEX idx_dni_empleado ON empleados(dni);

-- =====================================================================================
-- TABLA: reporte_asistencia
-- Registra la asistencia diaria y horas extras de los empleados
-- =====================================================================================
CREATE TABLE reporte_asistencia (
  fecha DATE,
  codigo_empleado CHAR(6),
  codigo_turno CHAR(3) NOT NULL,
  dia VARCHAR(15) NOT NULL,
  marca_entrada TIME NULL,
  marca_salida TIME NULL,
  H25 DECIMAL(5,2) DEFAULT 0,
  H35 DECIMAL(5,2) DEFAULT 0,
  H100 DECIMAL(5,2) DEFAULT 0,
  PRIMARY KEY (fecha, codigo_empleado),
  FOREIGN KEY (codigo_empleado) REFERENCES empleados(codigo),
  FOREIGN KEY (codigo_turno) REFERENCES turnos(codigo_turno)
) ENGINE=InnoDB;

CREATE INDEX idx_fecha_asistencia ON reporte_asistencia(fecha);
CREATE INDEX idx_empleado_fecha ON reporte_asistencia(codigo_empleado, fecha);

-- =====================================================================================
-- INSERCIÓN DE DATOS INICIALES
-- =====================================================================================

-- Centros de Coste
INSERT INTO centro_coste (codigo_centroCoste, centro_coste) VALUES
('CC-ADM01', 'Administración y Finanzas'),
('CC-VTS01', 'Ventas y Marketing'),
('CC-OPE01', 'Operaciones y Logística'),
('CC-TEC01', 'Tecnología de la Información'),
('CC-RRHH01', 'Recursos Humanos');

-- Áreas y Puestos
INSERT INTO area (puesto, unidad_organizativa) VALUES
('Gerente General', 'Gerencia'),
('Contador General', 'Administración y Finanzas'),
('Asistente Contable', 'Administración y Finanzas'),
('Analista Financiero', 'Administración y Finanzas'),
('Jefe de Ventas', 'Ventas y Marketing'),
('Ejecutivo de Cuentas', 'Ventas y Marketing'),
('Especialista en Marketing Digital', 'Ventas y Marketing'),
('Jefe de Almacén', 'Operaciones y Logística'),
('Operario de Almacén', 'Operaciones y Logística'),
('Coordinador de Despachos', 'Operaciones y Logística'),
('Gerente de TI', 'Tecnología de la Información'),
('Desarrollador Senior', 'Tecnología de la Información'),
('Desarrollador Junior', 'Tecnología de la Información'),
('Soporte Técnico Nivel 1', 'Tecnología de la Información'),
('Jefe de Recursos Humanos', 'Recursos Humanos'),
('Analista de Reclutamiento', 'Recursos Humanos');

-- Turnos de Trabajo
INSERT INTO turnos (codigo_turno, hora_entrada, hora_salida) VALUES
('M01', '08:00:00', '17:00:00'), -- Turno Mañana (con 1h de almuerzo)
('M02', '09:00:00', '18:00:00'), -- Turno Oficina
('T01', '14:00:00', '22:00:00'), -- Turno Tarde
('N01', '22:00:00', '06:00:00'), -- Turno Noche
('DES', '00:00:00', '00:00:00'); -- Descanso

-- Empleados de muestra
INSERT INTO empleados (codigo, puesto_area, Codigo_CentroCoste, nombre, dni, subdivision) VALUES
('E00001', 'Gerente General', 'CC-ADM01', 'Ana Sofía Torres', '70123456', 'Dirección'),
('E00002', 'Contador General', 'CC-ADM01', 'Carlos Alberto Rojas', '71234567', 'Contabilidad'),
('E00003', 'Asistente Contable', 'CC-ADM01', 'Lucía Méndez', '72345678', 'Contabilidad'),
('E00004', 'Analista Financiero', 'CC-ADM01', 'Pedro Pascal Gomez', '73456789', 'Finanzas'),
('E00005', 'Jefe de Ventas', 'CC-VTS01', 'Isabella Castillo', '74567890', 'Ventas Nacional'),
('E00006', 'Ejecutivo de Cuentas', 'CC-VTS01', 'Mateo Fernandez', '75678901', 'Ventas Nacional'),
('E00007', 'Ejecutivo de Cuentas', 'CC-VTS01', 'Valentina Ruiz', '76789012', 'Ventas Internacional'),
('E00008', 'Especialista en Marketing Digital', 'CC-VTS01', 'Diego Jimenez', '77890123', 'Marketing'),
('E00009', 'Jefe de Almacén', 'CC-OPE01', 'Javier Morales', '78901234', 'Almacén Central'),
('E00010', 'Operario de Almacén', 'CC-OPE01', 'Mariana Flores', '79012345', 'Recepción de Mercadería'),
('E00011', 'Operario de Almacén', 'CC-OPE01', 'Ricardo Peña', '60123457', 'Recepción de Mercadería'),
('E00012', 'Coordinador de Despachos', 'CC-OPE01', 'Camila Soto', '61234568', 'Logística de Salida'),
('E00013', 'Gerente de TI', 'CC-TEC01', 'Gabriel Navarro', '62345679', 'Jefatura TI'),
('E00014', 'Desarrollador Senior', 'CC-TEC01', 'Martina Vega', '63456780', 'Equipo de Desarrollo "Alfa"'),
('E00015', 'Desarrollador Senior', 'CC-TEC01', 'Benjamín Castro', '64567891', 'Equipo de Desarrollo "Beta"'),
('E00016', 'Desarrollador Junior', 'CC-TEC01', 'Daniela Vargas', '65678902', 'Equipo de Desarrollo "Alfa"'),
('E00017', 'Soporte Técnico Nivel 1', 'CC-TEC01', 'Sebastián Herrera', '66789013', 'Mesa de Ayuda'),
('E00018', 'Jefe de Recursos Humanos', 'CC-RRHH01', 'Sofía Romero', '67890124', 'Jefatura RRHH'),
('E00019', 'Analista de Reclutamiento', 'CC-RRHH01', 'Leonardo Ríos', '68901235', 'Selección'),
('E00020', 'Operario de Almacén', 'CC-OPE01', 'José Luis Pardo', '69012346', 'Picking y Packing'),
('E00021', 'Asistente Contable', 'CC-ADM01', 'Laura Nuñez', '40123456', 'Contabilidad'),
('E00022', 'Soporte Técnico Nivel 1', 'CC-TEC01', 'Felipe Ortiz', '41234567', 'Mesa de Ayuda');

-- Datos de asistencia de muestra (Lunes, 2023-11-06)
INSERT INTO reporte_asistencia (fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES
('2023-11-06', 'E00001', 'M02', 'Lunes', '08:55:10', '18:05:20', 0, 0, 0),
('2023-11-06', 'E00002', 'M02', 'Lunes', '08:58:00', '19:30:15', 0, 0.5, 0), 
('2023-11-06', 'E00003', 'M02', 'Lunes', '09:10:05', '18:01:00', 0, 0, 0),
('2023-11-06', 'E00005', 'M02', 'Lunes', '09:00:00', '18:30:00', 0, 0, 0),
('2023-11-06', 'E00009', 'M01', 'Lunes', '07:59:10', '17:02:30', 0, 0, 0),
('2023-11-06', 'E00010', 'M01', 'Lunes', '07:55:00', '17:00:00', 0, 0, 0),
('2023-11-06', 'E00011', 'T01', 'Lunes', '13:50:00', '22:10:45', 0, 0, 0),
('2023-11-06', 'E00014', 'M02', 'Lunes', '09:05:00', '20:00:00', 2, 0, 0),
('2023-11-06', 'E00016', 'M02', 'Lunes', '09:01:15', '18:00:00', 0, 0, 0),
('2023-11-06', 'E00017', 'M01', 'Lunes', NULL, NULL, 0, 0, 0),
('2023-11-06', 'E00019', 'M02', 'Lunes', '08:45:50', '18:15:00', 0, 0, 0),
('2023-11-06', 'E00020', 'N01', 'Lunes', '21:58:30', '06:05:00', 0, 0, 0);

-- Datos de asistencia (Martes, 2023-11-07)
INSERT INTO reporte_asistencia (fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES
('2023-11-07', 'E00001', 'M02', 'Martes', '08:57:30', '18:10:00', 0, 0, 0),
('2023-11-07', 'E00002', 'M02', 'Martes', '09:01:00', '18:00:15', 0, 0, 0),
('2023-11-07', 'E00003', 'M02', 'Martes', '09:00:15', '17:59:00', 0, 0, 0),
('2023-11-07', 'E00005', 'M02', 'Martes', '09:03:00', NULL, 0, 0, 0),
('2023-11-07', 'E00009', 'M01', 'Martes', '07:58:10', '18:05:30', 1, 0, 0), 
('2023-11-07', 'E00010', 'M01', 'Martes', '08:15:00', '17:03:00', 0, 0, 0), 
('2023-11-07', 'E00011', 'T01', 'Martes', '13:59:00', '22:00:45', 0, 0, 0),
('2023-11-07', 'E00014', 'M02', 'Martes', '09:02:00', '19:15:00', 0, 0, 0),
('2023-11-07', 'E00016', 'M02', 'Martes', '08:59:15', '18:01:00', 0, 0, 0),
('2023-11-07', 'E00017', 'M01', 'Martes', '07:59:00', '17:00:00', 0, 0, 0),
('2023-11-07', 'E00019', 'M02', 'Martes', '08:50:50', '18:05:00', 0, 0, 0),
('2023-11-07', 'E00020', 'N01', 'Martes', '21:55:00', '06:01:00', 0, 0, 0);

-- Datos de asistencia (Miércoles, 2023-11-08)
INSERT INTO reporte_asistencia (fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES
('2023-11-08', 'E00001', 'M02', 'Miércoles', '09:00:10', '18:01:20', 0, 0, 0),
('2023-11-08', 'E00002', 'M02', 'Miércoles', '08:59:00', '19:00:00', 0, 0, 0),
('2023-11-08', 'E00004', 'M02', 'Miércoles', NULL, NULL, 0, 0, 0),
('2023-11-08', 'E00008', 'M02', 'Miércoles', '09:05:11', '18:02:15', 0, 0, 0),
('2023-11-08', 'E00012', 'M01', 'Miércoles', '08:00:00', '17:30:00', 0, 0, 0),
('2023-11-08', 'E00013', 'M02', 'Miércoles', '08:55:00', '19:45:00', 0, 0, 0),
('2023-11-08', 'E00015', 'M02', 'Miércoles', '09:12:00', '18:10:00', 0, 0, 0),
('2023-11-08', 'E00018', 'M02', 'Miércoles', '08:58:20', '18:03:00', 0, 0, 0),
('2023-11-08', 'E00021', 'M02', 'Miércoles', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-08', 'E00022', 'T01', 'Miércoles', '14:01:00', '22:05:00', 0, 0, 0);
