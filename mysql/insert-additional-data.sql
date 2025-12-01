-- =====================================================================================
-- SCRIPT DE INSERCIÓN DE DATOS ADICIONALES PARA PRUEBAS
-- Este script puede ejecutarse después de inicializar el sistema para agregar más datos
-- =====================================================================================

USE appdb;

-- Insertar más empleados
INSERT INTO empleados (codigo, puesto_area, Codigo_CentroCoste, nombre, dni, subdivision) VALUES
('E00023', 'Operario de Almacén', 'CC-OPE01', 'Andrea Morales Silva', '42123457', 'Recepción de Mercadería'),
('E00024', 'Ejecutivo de Cuentas', 'CC-VTS01', 'Roberto Gonzales', '43234568', 'Ventas Nacional'),
('E00025', 'Desarrollador Junior', 'CC-TEC01', 'Patricia Luna', '44345679', 'Equipo de Desarrollo "Beta"'),
('E00026', 'Asistente Contable', 'CC-ADM01', 'Miguel Ángel Reyes', '45456780', 'Contabilidad'),
('E00027', 'Coordinador de Despachos', 'CC-OPE01', 'Fernanda Torres', '46567891', 'Logística de Salida'),
('E00028', 'Soporte Técnico Nivel 1', 'CC-TEC01', 'Jorge Luis Campos', '47678902', 'Mesa de Ayuda'),
('E00029', 'Analista de Reclutamiento', 'CC-RRHH01', 'Mónica Ramirez', '48789013', 'Selección'),
('E00030', 'Especialista en Marketing Digital', 'CC-VTS01', 'Andrés Paredes', '49890124', 'Marketing');

-- Insertar registros de asistencia para Jueves, 2023-11-09
INSERT INTO reporte_asistencia (fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES
('2023-11-09', 'E00001', 'M02', 'Jueves', '08:56:00', '18:20:00', 0, 0, 0),
('2023-11-09', 'E00002', 'M02', 'Jueves', '09:02:00', '20:15:00', 2, 0.25, 0),
('2023-11-09', 'E00003', 'M02', 'Jueves', '09:01:00', '18:00:00', 0, 0, 0),
('2023-11-09', 'E00005', 'M02', 'Jueves', '09:05:00', '19:00:00', 0, 0, 0),
('2023-11-09', 'E00006', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-09', 'E00007', 'M02', 'Jueves', '08:58:00', '18:05:00', 0, 0, 0),
('2023-11-09', 'E00009', 'M01', 'Jueves', '08:00:00', '19:00:00', 2, 0, 0),
('2023-11-09', 'E00010', 'M01', 'Jueves', '07:58:00', '17:05:00', 0, 0, 0),
('2023-11-09', 'E00011', 'T01', 'Jueves', '13:55:00', '23:00:00', 0, 1, 0),
('2023-11-09', 'E00012', 'M01', 'Jueves', '08:05:00', '17:00:00', 0, 0, 0),
('2023-11-09', 'E00013', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-09', 'E00014', 'M02', 'Jueves', '09:03:00', '21:00:00', 2, 1, 0),
('2023-11-09', 'E00015', 'M02', 'Jueves', '09:10:00', '18:15:00', 0, 0, 0),
('2023-11-09', 'E00016', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-09', 'E00017', 'M01', 'Jueves', '08:00:00', '17:00:00', 0, 0, 0),
('2023-11-09', 'E00018', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-09', 'E00019', 'M02', 'Jueves', '08:55:00', '18:10:00', 0, 0, 0),
('2023-11-09', 'E00020', 'N01', 'Jueves', '22:00:00', '06:00:00', 0, 0, 0);

-- Insertar registros de asistencia para Viernes, 2023-11-10
INSERT INTO reporte_asistencia (fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES
('2023-11-10', 'E00001', 'M02', 'Viernes', '08:58:00', '18:00:00', 0, 0, 0),
('2023-11-10', 'E00002', 'M02', 'Viernes', '09:00:00', '19:30:00', 0, 0.5, 0),
('2023-11-10', 'E00003', 'M02', 'Viernes', '09:05:00', '18:05:00', 0, 0, 0),
('2023-11-10', 'E00004', 'M02', 'Viernes', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-10', 'E00005', 'M02', 'Viernes', '09:00:00', '20:00:00', 2, 0, 0),
('2023-11-10', 'E00006', 'M02', 'Viernes', '09:02:00', '18:00:00', 0, 0, 0),
('2023-11-10', 'E00007', 'M02', 'Viernes', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-10', 'E00008', 'M02', 'Viernes', '09:10:00', '18:15:00', 0, 0, 0),
('2023-11-10', 'E00009', 'M01', 'Viernes', '08:00:00', '17:00:00', 0, 0, 0),
('2023-11-10', 'E00010', 'M01', 'Viernes', '08:10:00', '17:00:00', 0, 0, 0),
('2023-11-10', 'E00011', 'T01', 'Viernes', '14:00:00', '22:00:00', 0, 0, 0),
('2023-11-10', 'E00012', 'M01', 'Viernes', '08:00:00', '17:00:00', 0, 0, 0),
('2023-11-10', 'E00013', 'M02', 'Viernes', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-10', 'E00014', 'M02', 'Viernes', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-10', 'E00015', 'M02', 'Viernes', '09:15:00', '18:10:00', 0, 0, 0),
('2023-11-10', 'E00016', 'M02', 'Viernes', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-10', 'E00017', 'M01', 'Viernes', '08:00:00', '17:00:00', 0, 0, 0),
('2023-11-10', 'E00018', 'M02', 'Viernes', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-10', 'E00019', 'M02', 'Viernes', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-10', 'E00020', 'N01', 'Viernes', '22:00:00', '06:05:00', 0, 0, 0),
('2023-11-10', 'E00021', 'M02', 'Viernes', '09:00:00', '18:00:00', 0, 0, 0),
('2023-11-10', 'E00022', 'T01', 'Viernes', '14:00:00', '22:00:00', 0, 0, 0);

-- Insertar registros de asistencia para Sábado, 2023-11-11
INSERT INTO reporte_asistencia (fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES
('2023-11-11', 'E00009', 'M01', 'Sábado', '08:00:00', '13:00:00', 0, 0, 0),
('2023-11-11', 'E00010', 'M01', 'Sábado', '08:00:00', '13:00:00', 0, 0, 0),
('2023-11-11', 'E00011', 'M01', 'Sábado', '08:00:00', '15:00:00', 2, 0, 0),
('2023-11-11', 'E00012', 'M01', 'Sábado', '08:00:00', '13:00:00', 0, 0, 0),
('2023-11-11', 'E00020', 'M01', 'Sábado', '08:00:00', '14:00:00', 1, 0, 0);

-- Insertar registros de asistencia para Domingo, 2023-11-12 (Horas al 100%)
INSERT INTO reporte_asistencia (fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES
('2023-11-12', 'E00009', 'M01', 'Domingo', '08:00:00', '13:00:00', 0, 0, 5),
('2023-11-12', 'E00010', 'M01', 'Domingo', '08:00:00', '13:00:00', 0, 0, 5),
('2023-11-12', 'E00020', 'M01', 'Domingo', '08:00:00', '12:00:00', 0, 0, 4);

-- Insertar registros de asistencia recientes (mes actual) para facilitar pruebas
-- Usamos fecha del mes actual
INSERT INTO reporte_asistencia (fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES
('2025-11-01', 'E00001', 'M02', 'Lunes', '09:00:00', '18:00:00', 0, 0, 0),
('2025-11-01', 'E00002', 'M02', 'Lunes', '09:00:00', '19:00:00', 0, 0, 0),
('2025-11-01', 'E00005', 'M02', 'Lunes', '09:00:00', '20:30:00', 2, 0.5, 0),
('2025-11-01', 'E00014', 'M02', 'Lunes', '09:00:00', '21:00:00', 2, 1, 0),

('2025-11-02', 'E00001', 'M02', 'Martes', '09:00:00', '18:00:00', 0, 0, 0),
('2025-11-02', 'E00002', 'M02', 'Martes', '09:15:00', '18:00:00', 0, 0, 0),
('2025-11-02', 'E00005', 'M02', 'Martes', '09:00:00', '18:00:00', 0, 0, 0),
('2025-11-02', 'E00014', 'M02', 'Martes', '09:00:00', '19:30:00', 0, 0.5, 0),

('2025-11-03', 'E00001', 'M02', 'Miércoles', '09:00:00', '18:00:00', 0, 0, 0),
('2025-11-03', 'E00002', 'M02', 'Miércoles', '09:00:00', '18:00:00', 0, 0, 0),
('2025-11-03', 'E00005', 'M02', 'Miércoles', '09:20:00', '18:00:00', 0, 0, 0),
('2025-11-03', 'E00014', 'M02', 'Miércoles', '09:00:00', '22:00:00', 2, 2, 0),

('2025-11-04', 'E00001', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0),
('2025-11-04', 'E00002', 'M02', 'Jueves', '09:00:00', '20:00:00', 2, 0, 0),
('2025-11-04', 'E00005', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0),
('2025-11-04', 'E00014', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0);

-- Verificar datos insertados
SELECT 'Empleados registrados:' as info, COUNT(*) as total FROM empleados
UNION ALL
SELECT 'Registros de asistencia:', COUNT(*) FROM reporte_asistencia
UNION ALL
SELECT 'Total horas extras (H25+H35+H100):', ROUND(SUM(H25 + H35 + H100), 2) FROM reporte_asistencia;

SELECT '✅ Datos adicionales insertados correctamente' as resultado;
