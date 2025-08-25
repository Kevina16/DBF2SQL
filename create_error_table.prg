* create_error_table.prg
* Crea la tabla DBF utilizada por GuardarError para almacenar errores
*
* Uso:
*   SET PROCEDURE TO create_error_table ADDITIVE
*   CrearTablaErrores([tcDir])
*
* Si no se proporciona un directorio, se usa el directorio actual.
*
FUNCTION CrearTablaErrores
    LPARAMETERS tcDir
    IF EMPTY(tcDir)
        tcDir = CURDIR()
    ENDIF
    lcFile = ADDBS(tcDir) + "PMS_Errores.dbf"

    IF !FILE(lcFile)
        CREATE TABLE (lcFile) ;
            (CdgErr C(10), ;
             DscErr C(100), ;
             DetErr M, ;
             DetErr2 M, ;
             CdgUsu C(20), ;
             FecErr T, ;
             Nom_PC C(30))
        INDEX ON CdgErr TAG CdgErr
    ENDIF
ENDFUNC
