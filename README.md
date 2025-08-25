# DBF2SQL

Utilidades para trabajar con tablas **DBF** desde Visual FoxPro y sincronizar
su contenido con un servidor **MySQL**. El archivo `mysql_functions.prg`
incluye numerosas funciones para generar estructuras, crear tablas, transferir
datos y mantener registros.

## Funciones principales

- `GenEstrucDbf(pTabla)` – Genera un cursor con la estructura de una tabla DBF.
- `GenEstrucDbfIndices(pTabla)` – Obtiene información de los índices.
- `GenerarEstructuraMySQLServer(pTabla)` – Devuelve la sentencia `CREATE TABLE`.
- `GenerarEstructuraMySQLServerIndices(pTabla)` – Produce sentencias `CREATE INDEX`.
- `ObtenerCamposDBF(pTabla)` / `ObtenerCamposMySQL(pTabla)` – Listan las columnas de cada origen.
- `VerificarExisteTablaMySQL(pTabla)` – Comprueba si una tabla existe en MySQL.
- `CrearTablaMySQL(pTabla_DBF, pTabla_MySQL)` – Crea en MySQL la estructura de un DBF.
- `Enviar_Tabla_Completa_MySQL(pTabla_DBF, pTabla_MySQL)` – Inserta registros de la DBF en MySQL.
- `Modificar_Registro_MySQL(pTabla_DBF, pTabla_MySQL, pCamposWhere)` – Actualiza registros.
- `Eliminar_Registro_MySQL(pTabla_DBF, pTabla_MySQL, pCamposWhere)` – Elimina registros.
- `SafeTrim(vValue)` – Quita espacios de valores de tipo carácter.
- `GuardarError(...)` – Registra detalles de errores en un archivo DBF.
- `CrearTablaErrores([dir])` – Genera la tabla `PMS_Errores.dbf` utilizada por `GuardarError`.

## Ejemplo de uso

```xbase
SET PROCEDURE TO mysql_functions, create_error_table ADDITIVE

* Crear tabla de errores si no existe
CrearTablaErrores()

* Cadena de conexión para MySQL
VLc_Conexion = "Driver={MySQL ODBC 8.0 Driver};Server=localhost;Database=test;Uid=user;Pwd=password;"

* Crear tabla en MySQL a partir de la estructura DBF
CrearTablaMySQL("clientes", "clientes")

* Enviar todos los registros del DBF
Enviar_Tabla_Completa_MySQL("clientes", "clientes")

* Actualizar un registro, usando 'id' como condición
Modificar_Registro_MySQL("clientes", "clientes", "id")

* Eliminar un registro
Eliminar_Registro_MySQL("clientes", "clientes", "id")
```

Para un ejemplo ejecutable consulte `example_usage.prg`.
