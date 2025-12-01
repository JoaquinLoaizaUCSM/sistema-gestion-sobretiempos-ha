-- Insertar empleados de ejemplo (usando puestos que existen en tabla area)
INSERT INTO empleados (codigo, nombre, dni, puesto_area, Codigo_CentroCoste, subdivision) VALUES
('E001', 'Juan Carlos Pérez López', '45678901', 'Operario de Almacén', 'CC-OPE01', 'Planta Norte'),
('E002', 'María Fernanda García Torres', '46789012', 'Contador General', 'CC-ADM01', 'Sede Central'),
('E003', 'Pedro Antonio Rodríguez Sánchez', '47890123', 'Jefe de Almacén', 'CC-OPE01', 'Planta Norte'),
('E004', 'Ana Lucía Martínez Flores', '48901234', 'Analista de Reclutamiento', 'CC-RH01', 'Sede Central'),
('E005', 'Carlos Eduardo Ramírez González', '49012345', 'Soporte Técnico Nivel 1', 'CC-TEC01', 'Planta Sur'),
('E006', 'Rosa María Gutiérrez Castro', '50123456', 'Asistente Contable', 'CC-ADM01', 'Sede Central'),
('E007', 'José Luis Hernández Vargas', '51234567', 'Operario de Almacén', 'CC-OPE01', 'Planta Norte'),
('E008', 'Carmen Elena Díaz Morales', '52345678', 'Jefe de Ventas', 'CC-VTS01', 'Zona Norte'),
('E009', 'Miguel Ángel Torres Ruiz', '53456789', 'Coordinador de Despachos', 'CC-OPE01', 'Almacén Central'),
('E010', 'Patricia Isabel Flores Mendoza', '54567890', 'Analista Financiero', 'CC-ADM01', 'Sede Central'),
('E011', 'Roberto Carlos Méndez Silva', '55678901', 'Operario de Almacén', 'CC-OPE01', 'Planta Sur'),
('E012', 'Sofía Alexandra Castro Jiménez', '56789012', 'Desarrollador Junior', 'CC-TEC01', 'Sede Central'),
('E013', 'Fernando José Ramos Ortiz', '57890123', 'Ejecutivo de Cuentas', 'CC-VTS01', 'Zona Sur'),
('E014', 'Claudia Patricia Vega Romero', '58901234', 'Jefe de Recursos Humanos', 'CC-RH01', 'Sede Central'),
('E015', 'Daniel Alejandro Cruz Navarro', '59012345', 'Gerente de TI', 'CC-TEC01', 'Planta Sur');

-- Insertar registros de asistencia con sobretiempos
INSERT INTO reporte_asistencia (fecha, codigo_empleado, codigo_turno, dia, marca_entrada, marca_salida, H25, H35, H100) VALUES
-- Semana 1 (Octubre 2024)
('2024-10-01', 'E001', 'M01', 'Martes', '08:00:00', '19:00:00', 2.0, 0, 0),
('2024-10-01', 'E003', 'M01', 'Martes', '08:00:00', '18:30:00', 1.5, 0, 0),
('2024-10-01', 'E007', 'M01', 'Martes', '08:00:00', '17:00:00', 0, 0, 0),
('2024-10-01', 'E002', 'M02', 'Martes', '09:00:00', '18:00:00', 0, 0, 0),
('2024-10-01', 'E005', 'T01', 'Martes', '14:00:00', '23:30:00', 1.5, 0, 0),

('2024-10-02', 'E001', 'M01', 'Miércoles', '08:00:00', '17:00:00', 0, 0, 0),
('2024-10-02', 'E003', 'M01', 'Miércoles', '08:00:00', '20:00:00', 2.0, 1.0, 0),
('2024-10-02', 'E007', 'M01', 'Miércoles', '08:00:00', '17:30:00', 0.5, 0, 0),
('2024-10-02', 'E008', 'M02', 'Miércoles', '09:00:00', '19:30:00', 1.5, 0, 0),
('2024-10-02', 'E009', 'T01', 'Miércoles', '14:00:00', '22:00:00', 0, 0, 0),

('2024-10-03', 'E001', 'M01', 'Jueves', '08:00:00', '18:00:00', 1.0, 0, 0),
('2024-10-03', 'E003', 'M01', 'Jueves', '08:00:00', '17:00:00', 0, 0, 0),
('2024-10-03', 'E007', 'M01', 'Jueves', '08:00:00', '19:30:00', 2.0, 0.5, 0),
('2024-10-03', 'E010', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0),
('2024-10-03', 'E011', 'N01', 'Jueves', '22:00:00', '06:00:00', 0, 0, 0),

('2024-10-04', 'E001', 'M01', 'Viernes', '08:00:00', '17:00:00', 0, 0, 0),
('2024-10-04', 'E003', 'M01', 'Viernes', '08:00:00', '19:00:00', 2.0, 0, 0),
('2024-10-04', 'E007', 'M01', 'Viernes', '08:00:00', '18:00:00', 1.0, 0, 0),
('2024-10-04', 'E012', 'M02', 'Viernes', '09:00:00', '20:00:00', 2.0, 0, 0),
('2024-10-04', 'E013', 'T01', 'Viernes', '14:00:00', '23:00:00', 1.0, 0, 0),

-- Trabajo en fin de semana (H35)
('2024-10-05', 'E001', 'M01', 'Sábado', '08:00:00', '17:00:00', 0, 9.0, 0),
('2024-10-05', 'E003', 'M01', 'Sábado', '08:00:00', '14:00:00', 0, 6.0, 0),
('2024-10-05', 'E007', 'M01', 'Sábado', '08:00:00', '17:00:00', 0, 9.0, 0),

-- Feriado (H100)
('2024-10-08', 'E001', 'M01', 'Martes', '08:00:00', '17:00:00', 0, 0, 9.0),
('2024-10-08', 'E005', 'M01', 'Martes', '08:00:00', '14:00:00', 0, 0, 6.0),

-- Semana 2
('2024-10-07', 'E001', 'M01', 'Lunes', '08:00:00', '17:00:00', 0, 0, 0),
('2024-10-07', 'E002', 'M02', 'Lunes', '09:00:00', '18:00:00', 0, 0, 0),
('2024-10-07', 'E003', 'M01', 'Lunes', '08:00:00', '18:30:00', 1.5, 0, 0),
('2024-10-07', 'E004', 'M02', 'Lunes', '09:00:00', '18:00:00', 0, 0, 0),
('2024-10-07', 'E005', 'T01', 'Lunes', '14:00:00', '22:00:00', 0, 0, 0),

('2024-10-09', 'E001', 'M01', 'Miércoles', '08:00:00', '19:00:00', 2.0, 0, 0),
('2024-10-09', 'E006', 'M02', 'Miércoles', '09:00:00', '18:00:00', 0, 0, 0),
('2024-10-09', 'E007', 'M01', 'Miércoles', '08:00:00', '17:00:00', 0, 0, 0),
('2024-10-09', 'E008', 'M02', 'Miércoles', '09:00:00', '20:00:00', 2.0, 0, 0),

('2024-10-10', 'E003', 'M01', 'Jueves', '08:00:00', '20:00:00', 2.0, 1.0, 0),
('2024-10-10', 'E009', 'T01', 'Jueves', '14:00:00', '23:00:00', 1.0, 0, 0),
('2024-10-10', 'E010', 'M02', 'Jueves', '09:00:00', '18:00:00', 0, 0, 0),

('2024-10-11', 'E001', 'M01', 'Viernes', '08:00:00', '18:00:00', 1.0, 0, 0),
('2024-10-11', 'E011', 'M01', 'Viernes', '08:00:00', '19:30:00', 2.0, 0.5, 0),
('2024-10-11', 'E012', 'M02', 'Viernes', '09:00:00', '18:00:00', 0, 0, 0),

-- Más registros para empleados adicionales
('2024-10-14', 'E013', 'M02', 'Lunes', '09:00:00', '19:00:00', 1.0, 0, 0),
('2024-10-14', 'E014', 'M02', 'Lunes', '09:00:00', '18:00:00', 0, 0, 0),
('2024-10-14', 'E015', 'M01', 'Lunes', '08:00:00', '18:30:00', 1.5, 0, 0),

('2024-10-15', 'E013', 'M02', 'Martes', '09:00:00', '20:00:00', 2.0, 0, 0),
('2024-10-15', 'E014', 'M02', 'Martes', '09:00:00', '18:00:00', 0, 0, 0),
('2024-10-15', 'E015', 'M01', 'Martes', '08:00:00', '17:00:00', 0, 0, 0);
