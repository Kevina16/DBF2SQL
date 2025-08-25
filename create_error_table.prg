* create_error_table.prg
* Crea la tabla DBF utilizada por GuardarError para almacenar errores
*
* Uso:
*   SET PROCEDURE TO create_error_table ADDITIVE
*   CrearTablaErrores([tcDir])
*
* Si no se proporciona un directorio, se busca primero la ruta legacy
* VGc_Unidad+"\Systems\NT_Pos\Data". Si no existe, se utiliza la
* carpeta "Data" dentro del proyecto y se crea en caso necesario.

FUNCTION ObtenerDataDir
    LOCAL lcDir, lcLegacy
    lcDir = ""
    * Intentar usar la ruta legacy si la variable VGc_Unidad existe
    IF TYPE("VGc_Unidad") = "C" AND !EMPTY(VGc_Unidad)
        lcLegacy = ADDBS(VGc_Unidad) + "Systems\\NT_Pos\\Data"
        IF DIRECTORY(lcLegacy)
            lcDir = lcLegacy
        ENDIF
    ENDIF
    * Si no existe la ruta legacy, usar carpeta Data del proyecto
    IF EMPTY(lcDir)
        lcDir = ADDBS(CURDIR()) + "Data"
        IF !DIRECTORY(lcDir)
            MD (lcDir)
        ENDIF
    ENDIF
    PUBLIC G_DATA_DIR
    G_DATA_DIR = lcDir
    RETURN lcDir
ENDFUNC

FUNCTION CrearTablaErrores
    LPARAMETERS tcDir
    IF EMPTY(tcDir)
        tcDir = ObtenerDataDir()
    ELSE
        IF !DIRECTORY(tcDir)
            MD (tcDir)
        ENDIF
        PUBLIC G_DATA_DIR
        G_DATA_DIR = tcDir
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

