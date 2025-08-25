* Ejemplo de uso de mysql_functions.prg
SET PROCEDURE TO mysql_functions, create_error_table ADDITIVE

* Crear tabla de registro de errores si no existe
CrearTablaErrores()

* Cadena de conexión al servidor MySQL
VLc_Conexion = "Driver={MySQL ODBC 8.0 Driver};Server=localhost;Database=test;Uid=user;Pwd=password;"

* Si la tabla no existe en MySQL, se crea a partir de la estructura DBF
IF !VerificarExisteTablaMySQL("clientes")
    CrearTablaMySQL("clientes", "clientes")
ENDIF

* Enviar todos los registros del DBF
Enviar_Tabla_Completa_MySQL("clientes", "clientes")

* Modificar un registro usando el campo clave 'id'
Modificar_Registro_MySQL("clientes", "clientes", "id")

* Eliminar registros usando el campo clave 'id'
Eliminar_Registro_MySQL("clientes", "clientes", "id")
