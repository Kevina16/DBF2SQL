*---------------------------------------------------------------------*
* Ing. Kevin Acuña Quirós 2025
* Funciones para trabajar con MySQL
*---------------------------------------------------------------------*
* Este módulo proporciona utilidades de Visual FoxPro para migrar y
* sincronizar datos entre tablas DBF y MySQL. Incluye funciones para
* inspeccionar estructuras, generar sentencias DDL y mantener datos.
*
* Principales funciones:
*   - GenEstrucDbf(pTabla): crea un cursor con la estructura de una tabla DBF.
*   - GenEstrucDbfIndices(pTabla): obtiene información de los índices de la DBF.
*   - GenerarEstructuraMySQLServer(pTabla): devuelve un "CREATE TABLE" para MySQL.
*   - GenerarEstructuraMySQLServerIndices(pTabla): genera sentencias "CREATE INDEX".
*   - ObtenerCamposDBF(pTabla) y ObtenerCamposMySQL(pTabla): listan las columnas existentes
*     en cada origen.
*   - VerificarExisteTablaMySQL(pTabla): comprueba si una tabla existe en MySQL.
*   - CrearTablaMySQL(pTabla_DBF, pTabla_MySQL): crea en MySQL la estructura de la DBF.
*   - Enviar_Tabla_Completa_MySQL(pTabla_DBF, pTabla_MySQL): transfiere registros al servidor.
*   - Modificar_Registro_MySQL(...)/Eliminar_Registro_MySQL(...): actualizan o eliminan registros
*     con datos provenientes de la DBF.
*   - SafeTrim(vValue): elimina espacios en valores de carácter.
*   - GuardarError(...): registra errores en un archivo DBF de auditoría.
FUNCTION GenEstrucDbf
    LPARAMETERS pTabla
    pTabla = STRTRAN(ALLTRIM(pTabla),"-","_")
    LOCAL mTabla, mNumCamp, mDscCamp, mTipCamp, mTamCamp, mDecCamp, mEsIndice
    LOCAL nFields, i, nIndex, cIndexField

    * Crear el cursor para almacenar la estructura
    CREATE CURSOR Cur_Estru (NumCamp C(3), DscCamp C(10), TipCamp C(20), TamCamp N(3), DecCamp C(5), EsIndice L(1))
    INDEX ON NumCamp TAG NumCamp
    INDEX ON ALLTRIM(DscCamp) TAG DscCamp
    SET ORDER TO
    
    * Verificar si la tabla existe
    IF !USED(pTabla)
        *MESSAGEBOX("La tabla " + pTabla + " no está abierta.", 16, "Error")
        *
        VLc_DscErr = "ERROR EN LA FUNCION [GenEstrucDbf] pTabla SE ENCUENTRA CERRADA!"
        VLc_DetErr = "NO SE PUDO OBTENER LA ESTRUCTURA DE LA TABLA "+ALLTRIM(pTabla)
        GuardarError(VLc_DscErr, VLc_DetErr, "", G_USERNAME )
        RETURN .F.
    ENDIF

    * Seleccionar la tabla y obtener su estructura
    SELECT (pTabla)
    nFields = AFIELDS(aEstructura)  && Obtener la estructura en un arreglo

    * Recorrer el arreglo de la estructura y llenar el cursor
    FOR i = 1 TO nFields
        mNumCamp = TRANSFORM(i, "999")  && Número de campo
        mDscCamp = aEstructura[i, 1]    && Nombre del campo
        mTipCamp = aEstructura[i, 2]    && Tipo de campo
        mTamCamp = aEstructura[i, 3]    && Tamaño del campo
        mDecCamp = IIF(aEstructura[i, 4] > 0, TRANSFORM(aEstructura[i, 4], "999"), "")  && Decimales

        * Verificar si el campo es parte de algún índice
        mEsIndice = .F.
        FOR nIndex = 1 TO TAGCOUNT()
            cIndexField = UPPER(KEY(nIndex))
            IF UPPER(mDscCamp) $ cIndexField
                mEsIndice = .T.
                EXIT
            ENDIF
        ENDFOR
        *Insertar los datos en el cursor
        INSERT INTO Cur_Estru (NumCamp, DscCamp, TipCamp, TamCamp, DecCamp, EsIndice) ;
            VALUES (mNumCamp, mDscCamp, mTipCamp, mTamCamp, mDecCamp, mEsIndice)
    ENDFOR
    *
    SELECT Cur_Estru
        * Reemplazar guiones en los nombres de los campos
        REPLACE ALL DscCamp WITH STRTRAN(DscCamp, "-", "_")

        * Ordenar y limpiar el cursor
        SET ORDER TO NumCamp
        GO TOP
ENDFUNC
*---------------------------------------------------------------------*
*---------------------------------------------------------------------*
FUNCTION GenEstrucDbfIndices
    LPARAMETERS pTabla
    pTabla = STRTRAN(ALLTRIM(pTabla),"-","_")
    * Crear el cursor para almacenar la estructura
    CREATE CURSOR Cur_Estru_Index (NumIndex C(3), NomIndex C(10), DscIndex C(100) )
    INDEX ON NumIndex TAG NumIndex 
    INDEX ON ALLTRIM(NomIndex) TAG NomIndex
    SET ORDER TO

    * Verificar si la tabla existe
    IF !USED(pTabla)
        *MESSAGEBOX("La tabla " + pTabla + " no está abierta.", 16, "Error")
        VLc_DscErr = "ERROR EN LA FUNCION [GenEstrucDbfIndices] pTabla SE ENCUENTRA CERRADA!"
        VLc_DetErr = "NO SE PUDO OBTENER LA ESTRUCTURA DE LA TABLA "+ALLTRIM(pTabla)
        GuardarError(VLc_DscErr, VLc_DetErr, "", G_USERNAME )
        RETURN .F.
    ENDIF

    SELECT &pTabla

    IF TAGCOUNT() = 0
        && MESSAGEBOX("La tabla no tiene índices.", 64, "Información")
        RETURN
    ENDIF

    * Recorrer todos los índices de la tabla
    FOR i = 1 TO TAGCOUNT()
        * Obtener el nombre del índice
        M.NumIndex = TRANSFORM(i)
        * Obtener la expresión del índice
        M.NomIndex = TAG(i)
        * Verificar si el índice es único
        M.DscIndex = KEY(i) &&IIF(UNIQUE(i), "Único", "Regular")
        *
        INSERT INTO Cur_Estru_Index FROM MEMVAR
    ENDFOR
ENDFUNC
*---------------------------------------------------------------------*
*---------------------------------------------------------------------*
FUNCTION GenerarEstructuraMySQLServer
    LPARAMETERS pTabla
    mTabla = pTabla
    *-WAIT WINDOWS mTabla
    SELECT Cur_Estru
        GO TOP
        mStringMySQL = "CREATE TABLE "+STRTRAN(mTabla,"-","_")+" ("
        SCAN
            *-
            REPLACE DecCamp WITH ALLTRIM(STR(INT(VAL(DecCamp))))
            *-
            DO CASE
                CASE ALLTRIM(TipCamp) == "C"  && Character
                    REPLACE TipCamp WITH "VARCHAR"

                CASE ALLTRIM(TipCamp) == "N"  && Numeric
                    REPLACE TipCamp WITH "DECIMAL"

                CASE ALLTRIM(TipCamp) == "M"  && Memo
                    REPLACE TipCamp WITH "TEXT"

                CASE ALLTRIM(TipCamp) == "L"  && Logical
                    REPLACE TipCamp WITH "BIT"

                CASE ALLTRIM(TipCamp) == "D"  && Date
                    REPLACE TipCamp WITH "DATE"

                CASE ALLTRIM(TipCamp) == "T"  && DateTime
                    REPLACE TipCamp WITH "DATETIME"
                   
                CASE ALLTRIM(TipCamp) == "I"  && DateTime
                    REPLACE TipCamp WITH "Int"
                    
                CASE ALLTRIM(TipCamp) == "V"
                    REPLACE TipCamp WITH "VARCHAR"

                OTHERWISE
                    REPLACE TipCamp WITH UPPER(TipCamp)  && Otros tipos (si los hay)
            ENDCASE
            *-
            mDecimales = ""
            IF ALLTRIM(DecCamp) # "0"
                mDecimales = ", " + ALLTRIM(DecCamp)
            ENDIF
            *-
            IF ALLTRIM(TipCamp) = "DATE" .OR. ALLTRIM(TipCamp) = "DATETIME" .OR. ALLTRIM(TipCamp) = "TEXT" .OR. ALLTRIM(TipCamp) = "BIT"
                mLongitudCampo = ", "
                
            ELSE
                mLongitudCampo = " ("+ALLTRIM(STR(TamCamp+VAL(DecCamp)))+mDecimales+"), "
                
            ENDIF
                
            mStringMySQL = mStringMySQL +" "+ ALLTRIM(DscCamp) +" "+ ALLTRIM(TipCamp) + mLongitudCampo
            
        ENDSCAN
        *
        mStringMySQL = SUBSTR( mStringMySQL, 1, LEN(mStringMySQL)-2 )
        mStringMySQL = mStringMySQL +");"
        *
        SELECT Cur_Estru
            USE
        RETURN mStringMySQL
ENDFUNC
*---------------------------------------------------------------------*
*---------------------------------------------------------------------*
FUNCTION GenerarEstructuraMySQLServerIndices
    LPARAMETERS pTabla
    mTabla = STRTRAN(ALLTRIM(pTabla),"-","_")
    *
    SELECT Cur_Estru_Index
        *
        mStringMySQL = ""
        VLc_DscIndex = STRTRAN(ALLTRIM(DscIndex),"DTOS(","")
        VLc_DscIndex = STRTRAN(ALLTRIM(VLc_DscIndex),"TTOD(","")
        VLc_DscIndex = STRTRAN(ALLTRIM(VLc_DscIndex),"TTOC(","")
        VLc_DscIndex = STRTRAN(ALLTRIM(VLc_DscIndex),"DTOC(","")
        VLc_DscIndex = STRTRAN(ALLTRIM(VLc_DscIndex),"STR(","")
        VLc_DscIndex = STRTRAN(ALLTRIM(VLc_DscIndex),")","")
        VLc_DscIndex = STRTRAN(ALLTRIM(VLc_DscIndex),"+",",")
        IF OCCURS("RIGHT(", VLc_DscIndex) > 0
            mStringMySQL = ""
        ELSE
            mStringMySQL = mStringMySQL+" CREATE INDEX IDX_"+ALLTRIM(NomIndex)+" ON "+mTabla+" ("+VLc_DscIndex+");"
        ENDIF
        *
        RETURN mStringMySQL
ENDFUNC



FUNCTION ObtenerCamposMySQL
    PARAMETERS P_Tabla
        P_Tabla = STRTRAN(ALLTRIM(P_Tabla),"-","_")
        *
        CREATE CURSOR C_Columnas_MSQL (CdgCol N(3), DscCol C(100))
        SELECT C_Columnas_MSQL
            INDEX ON CdgCol TAG CdgCol
        *
        SET RELATION TO CdgCol INTO C_Columnas_DBF
        *   
        SELECT &P_Tabla
            M.CdgCol = 1
            * Recorre y muestra los nombres de las columnas
            FOR lnI = 1 TO FCOUNT()
                M.DscCol = FIELD(lnI)  && Muestra el nombre de la columna en la consola
                INSERT INTO C_Columnas_MSQL FROM MEMVAR
                M.CdgCol = M.CdgCol + 1
            NEXT
ENDFUNC


FUNCTION ObtenerCamposDBF
    PARAMETERS P_Tabla
    P_Tabla = STRTRAN(ALLTRIM(P_Tabla),"-","_")
    *
    CREATE CURSOR C_Columnas_DBF  (CdgCol N(3), DscCol C(100))
    SELECT C_Columnas_DBF
        INDEX ON CdgCol TAG CdgCol
    *
    SELECT &P_Tabla
        M.CdgCol = 1
        * Recorre y muestra los nombres de las columnas
        FOR lnI = 1 TO FCOUNT()
            M.DscCol = FIELD(lnI)  && Muestra el nombre de la columna en la consola
            INSERT INTO C_Columnas_DBF FROM MEMVAR
            M.CdgCol = M.CdgCol + 1
        NEXT

ENDFUNC 


FUNCTION VerificarExisteTablaMySQL
    PARAMETERS P_Tabla
    *
    STORE SQLSTRINGCONNECT(VLc_Conexion) TO MiConexion

    * Verificamos la conexión
    IF(MiConexion <= 0)
        *
        *MESSAGEBOX("Ocurrió un error al conectar con el servidor de MySql.",16)
        *
        VLc_DscErr = "ERROR EN LA FUNCION [VerificarExisteTablaMySQL]"
        VLc_DetErr = "ERROR AL INTENTAR CONECTAR CON LA BASE DE DATOS MYSQL"
        VLc_DetErr2 = ALLTRIM(VLc_Conexion)
        GuardarError(VLc_DscErr, VLc_DetErr, VLc_DetErr2, G_USERNAME )
        *---------------------------------------------------------------------*
        RETURN .F.
    ENDIF


    * Define la consulta SQL
    lcSQL = "SHOW TABLES LIKE '"+P_Tabla+"'"

    * Ejecuta la consulta y guarda los resultados en un cursor
    R = SQLEXEC(MiConexion, lcSQL, "C_Resultado")

    IF R < 0
        LOCAL ARRAY aErrorr[1]
        AERROR(aErrorr)

        *_cliptext = M_Script
        *MESSAGEBOX("Error al ejecutar el script: " + CHR(13) + ;
                   "Código de error: " + TRANSFORM(aErrorr[1]) + CHR(13) + ;
                   "Mensaje: " + aErrorr[2], 16, "Error")

        VLc_DetErr = "Código de error: " + TRANSFORM(aErrorr[1]) + CHR(13) + ;
                   "Mensaje: " + aErrorr[2]
        *
        GuardarError("ERROR AL EJECUTAR LA FUNCION [VerificarExisteTablaMySQL]", VLc_DetErr, lcSQL, G_USERNAME )
        *
    ENDIF


    * Desconecta la conexión al terminar
    SQLDISCONNECT(MiConexion)

    SELECT C_Resultado
        GO TOP
        IF !EOF()
            USE
            RETURN .T.
        ELSE
            USE
            RETURN .F.
        ENDIF
ENDFUNC

FUNCTION CrearTablaMySQL
    PARAMETERS P_Tabla_DBF, P_Tabla_MySQL
    *
    *-VGo_ObjConexion = SQLSTRINGCONNECT(VGc_StrConexion)
    STORE SQLSTRINGCONNECT(VLc_Conexion) to VGo_ObjConexion
    *
    *?VGo_ObjConexion
    *
    IF VGo_ObjConexion >= 1
        *?"Conectado a la base de datos "
    ELSE
        *
        VLc_DscErr = "ERROR EN LA FUNCION [CrearTablaMySQL]"
        VLc_DetErr = "ERROR AL INTENTAR CONECTAR CON LA BASE DE DATOS MYSQL"
        VLc_DetErr2 = ALLTRIM(VLc_Conexion)
        GuardarError(VLc_DscErr, VLc_DetErr, VLc_DetErr2, G_USERNAME )
        *---------------------------------------------------------------------*
        RETURN .F.
    ENDIF


    *
    *----------------------------------------------------------------*
    *----------------------------------------------------------------*
    *M_Tabla = ALLTR(P_Tabla)
    GenEstrucDbf(P_Tabla_DBF)
    M_Script = GenerarEstructuraMySQLServer(P_Tabla_MySQL)
    R=SQLEXEC(VGo_ObjConexion, M_Script)
    *
    IF R < 0.00
        *_cliptext = M_Script
        *MESSAGEBOX("Error al crear la tabla"+M_Tabla) 
        LOCAL ARRAY aErrorr[1]
        AERROR(aErrorr)
        *
        VLc_DetErr = "Código de error: " + TRANSFORM(aErrorr[1]) + CHR(13) + ;
                               "Mensaje: " + aErrorr[2]
        *
        GuardarError("ERROR AL CREAR UNA TABLA EN MYSQL", VLc_DetErr, M_Script, G_USERNAME )
    ENDIF
    *
    *----------------------------------------------------------------*
    *----------------------------------------------------------------*
    *M_Tabla = ALLTR(P_Tabla)
    GenEstrucDbfIndices(P_Tabla_DBF)
    SELECT Cur_Estru_Index
        GO TOP
        SCAN
            *
            IF !EMPTY(M_Script)
                M_Script = GenerarEstructuraMySQLServerIndices(P_Tabla_MySQL)
                R = SQLEXEC(VGo_ObjConexion, M_Script)

                IF R < 0
                    LOCAL ARRAY aErrorr[1]
                    AERROR(aErrorr)

                    *_cliptext = M_Script
                    *MESSAGEBOX("Error al ejecutar el script: " + CHR(13) + ;
                               "Código de error: " + TRANSFORM(aErrorr[1]) + CHR(13) + ;
                               "Mensaje: " + aErrorr[2], 16, "Error")

                    VLc_DetErr = "Código de error: " + TRANSFORM(aErrorr[1]) + CHR(13) + ;
                               "Mensaje: " + aErrorr[2]
                    *
                    GuardarError("ERROR AL CREAR LOS INDICES DE UNA TABLA EN MYSQL", VLc_DetErr, M_Script, G_USERNAME )
                    *
                ENDIF
            ENDIF
            SELECT Cur_Estru_Index
        ENDSCAN
        USE IN Cur_Estru_Index
    *
    *----------------------------------------------------------------*
    *----------------------------------------------------------------*
    *M_Tabla = ALLTRIM(P_Tabla)
    *GenEstrucDbf(M_Tabla)
    * Desconecta la conexión al terminar
    SQLDISCONNECT(VGo_ObjConexion)
    *
ENDFUNC



FUNCTION UnificarCampos
    *
    CREATE CURSOR C_Estructura    (CdgCol N(3), DscColMySQL C(100), DscColDBF C(100))
    *
    SELECT C_Columnas_DBF
    GO TOP
    SELECT C_Estructura
        GO TOP
    SELECT C_Columnas_MSQL
        GO TOP
        M.CdgCol = 1
        SCAN
            M.DscColMySQL = C_Columnas_MSQL.DscCol
            M.DscColDBF   = C_Columnas_DBF.DscCol
            INSERT INTO C_Estructura FROM MEMVAR
            SELECT C_Columnas_MSQL
            M.CdgCol = M.CdgCol + 1
        ENDSCAN
    *
    USE IN C_Columnas_DBF
    USE IN C_Columnas_MSQL
ENDFUNC


FUNCTION Enviar_Tabla_Completa_MySQL
    PARAMETERS P_Tabla_DBF, P_Tabla_MySQL
    P_Tabla_DBF   = STRTRAN(ALLTRIM(P_Tabla_DBF),"-","_")
    P_Tabla_MySQL = STRTRAN(ALLTRIM(P_Tabla_MySQL),"-","_")
    *
    SET DATE TO YMD
    *
    ObtenerCamposDBF(VLc_Tabla_DBF)
    ObtenerCamposMySQL(VLc_Tabla_DBF)  && VLc_Tabla_MySQL
    UnificarCampos()
    *
    SELECT C_Estructura
    GO TOP
    VLc_Campos_MySQL = ""
    VLc_Campos_DBF = ""

    SCAN
        IF !EMPTY(DscColMysql) .AND. !EMPTY(DscColDBF)
            VLc_Campos_MySQL = VLc_Campos_MySQL + ALLTRIM(DscColMysql) + ", "
            VLc_Campos_DBF   = VLc_Campos_DBF + "?SafeTrim(" + ALLTRIM(DscColDBF) + "), "
        ENDIF
    ENDSCAN

    * Remover la última coma y espacio
    VLc_Campos_MySQL = LEFT(VLc_Campos_MySQL, LEN(VLc_Campos_MySQL) - 2)
    VLc_Campos_DBF = LEFT(VLc_Campos_DBF, LEN(VLc_Campos_DBF) - 2)

    * Crear el script final
    VLc_Script = "INSERT INTO "+P_Tabla_MySQl+" (" + VLc_Campos_MySQL + ") VALUES (" + VLc_Campos_DBF + ")"
    *? VLc_Script

    STORE SQLSTRINGCONNECT(VLc_Conexion) to MiConexion

    SELECT &P_Tabla_DBF  && Tu tabla con los datos
        SCAN
            TEXT TO lcQuery TEXTMERGE NOSHOW
            INSERT INTO <<P_Tabla_MySQL>> (<<VLc_Campos_MySQL>>) VALUES (<<VLc_Campos_DBF>>)
            ENDTEXT

            * Ejecutar el script
            nResultado = SQLEXEC(MiConexion, lcQuery)
            
            * Verificar si ocurrió un error
            IF nResultado < 0
                AERROR(aErrorr)
                VLc_DetErr = "Código de error: " + TRANSFORM(aErrorr[1]) + CHR(13) + ;
                                   "Mensaje: " + aErrorr[2]
                *
                GuardarError("ERROR AL EJECUTAR UN INSERT INTO MYSQL", VLc_DetErr, lcQuery, G_USERNAME )

                * Mostrar información del error
                *MESSAGEBOX("Error al ejecutar SQL: " + aErrorr[2], 16, "Error SQL")
                *RETURN .F.  && Salir de la rutina o manejar el error según corresponda
            ENDIF
            
        ENDSCAN
    *
    * Desconecta la conexión al terminar
    SQLDISCONNECT(MiConexion)
    *
    SET DATE TO DMY
    USE IN C_Estructura

ENDFUNC



FUNCTION Modificar_Registro_MySQL
    PARAMETERS P_Tabla_DBF, P_Tabla_MySQL, P_Campos_Where
    P_Tabla_DBF   = STRTRAN(ALLTRIM(P_Tabla_DBF),"-","_")
    P_Tabla_MySQL = STRTRAN(ALLTRIM(P_Tabla_MySQL),"-","_")
    *
    SET DATE TO YMD
    *
    ObtenerCamposDBF(VLc_Tabla_DBF)
    ObtenerCamposMySQL(VLc_Tabla_DBF)  && VLc_Tabla_MySQL
    UnificarCampos()
    *
    SELECT C_Estructura
    GO TOP
    VLc_Campos_MySQL = ""
    *VLc_Campos_DBF = ""

    SCAN
        IF !EMPTY(DscColMysql) .AND. !EMPTY(DscColDBF)
            VLc_Campos_MySQL = VLc_Campos_MySQL + ALLTRIM(DscColMysql) +" = "+ "?SafeTrim(" + ALLTRIM(DscColDBF) + "), "
            *VLc_Campos_DBF   = VLc_Campos_DBF + "?" + ALLTRIM(DscColDBF) + ", "
        ENDIF
    ENDSCAN

    * Remover la última coma y espacio
    VLc_Campos_MySQL = LEFT(VLc_Campos_MySQL, LEN(VLc_Campos_MySQL) - 2)
    *VLc_Campos_DBF = LEFT(VLc_Campos_DBF, LEN(VLc_Campos_DBF) - 2)

    * Crear el script final
    VLc_Script = "UPDATE "+P_Tabla_MySQl+" SET " + VLc_Campos_MySQL
    

    IF !EMPTY(P_Campos_Where)
        * Crear un array a partir de la cadena, eliminando espacios
        DIMENSION aCampos[1]
        ALINES(aCampos, STRTRAN(P_Campos_Where, ",", CHR(13)), .T.)

        * Iterar sobre los elementos del array
        VLc_CamposWhere = ""
        FOR i = 1 TO ALEN(aCampos)
           *?"Campo: ", aCampos[i]
            VLc_CamposWhere = VLc_CamposWhere + aCampos[i] + " = ?SafeTrim("+aCampos[i] + ") AND "
        ENDFOR

        VLc_CamposWhere = LEFT(VLc_CamposWhere, LEN(VLc_CamposWhere) - 5)
    ELSE
        VLc_CamposWhere = "1 = 1"
    ENDIF


    *VLc_CamposWhere = "CdgArt = '001485'"
    *? VLc_Script

    STORE SQLSTRINGCONNECT(VLc_Conexion) to MiConexion

    SELECT &P_Tabla_DBF  && Tu tabla con los datos
        SCAN
            TEXT TO lcQuery TEXTMERGE NOSHOW
            UPDATE <<P_Tabla_MySQL>> SET <<VLc_Campos_MySQL>> WHERE (<<VLc_CamposWhere>>)
            ENDTEXT

            * Ejecutar el script
            nResultado = SQLEXEC(MiConexion, lcQuery)
            
            * Verificar si ocurrió un error
            IF nResultado < 0
                *AERROR(aErrorr)
                * Mostrar información del error
                *MESSAGEBOX("Error al ejecutar SQL: " + aErrorr[2], 16, "Error SQL")
                *RETURN .F.  && Salir de la rutina o manejar el error según corresponda
                AERROR(aErrorr)
                VLc_DetErr = "Código de error: " + TRANSFORM(aErrorr[1]) + CHR(13) + ;
                                   "Mensaje: " + aErrorr[2]
                *
                GuardarError("ERROR AL EJECUTAR UN UPDATE MYSQL", VLc_DetErr, lcQuery, G_USERNAME )
            ENDIF
            
        ENDSCAN
    *
    * Desconecta la conexión al terminar
    SQLDISCONNECT(MiConexion)
    *
    SET DATE TO DMY
    USE IN C_Estructura

ENDFUNC



FUNCTION Eliminar_Registro_MySQL
    PARAMETERS P_Tabla_DBF, P_Tabla_MySQL, P_Campos_Where
    P_Tabla_DBF   = STRTRAN(ALLTRIM(P_Tabla_DBF),"-","_")
    P_Tabla_MySQL = STRTRAN(ALLTRIM(P_Tabla_MySQL),"-","_")
    *
    SET DATE TO YMD
    *
    IF !EMPTY(P_Campos_Where)
        * Crear un array a partir de la cadena, eliminando espacios
        DIMENSION aCampos[1]
        ALINES(aCampos, STRTRAN(P_Campos_Where, ",", CHR(13)), .T.)

        * Iterar sobre los elementos del array
        VLc_CamposWhere = ""
        FOR i = 1 TO ALEN(aCampos)
           *?"Campo: ", aCampos[i]
            VLc_CamposWhere = VLc_CamposWhere + aCampos[i] + " = ?SafeTrim("+aCampos[i] + ") AND "
        ENDFOR

        VLc_CamposWhere = LEFT(VLc_CamposWhere, LEN(VLc_CamposWhere) - 5)
    ELSE
        VLc_CamposWhere = "1 = 1"
    ENDIF

    STORE SQLSTRINGCONNECT(VLc_Conexion) to MiConexion
    
    IF VLc_CamposWhere = "1 = 1"  && Borra toda la tabla 
        SELECT &P_Tabla_DBF  && Tu tabla con los datos
                TEXT TO lcQuery TEXTMERGE NOSHOW
                DELETE FROM <<P_Tabla_MySQL>> WHERE (<<VLc_CamposWhere>>)
                ENDTEXT

                * Ejecutar el script
                nResultado = SQLEXEC(MiConexion, lcQuery)
                
                * Verificar si ocurrió un error
                IF nResultado < 0
                    *AERROR(aErrorr)
                    * Mostrar información del error
                    *MESSAGEBOX("Error al ejecutar SQL: " + aErrorr[2], 16, "Error SQL")
                    *RETURN .F.  && Salir de la rutina o manejar el error según corresponda
                    AERROR(aErrorr)
                    VLc_DetErr = "Código de error: " + TRANSFORM(aErrorr[1]) + CHR(13) + ;
                                   "Mensaje: " + aErrorr[2]
                    *
                    GuardarError("ERROR AL EJECUTAR UN DELETE MYSQL", VLc_DetErr, lcQuery, G_USERNAME )
                ENDIF
                
    ELSE
        SELECT &P_Tabla_DBF  && Tu tabla con los datos
            SCAN
                TEXT TO lcQuery TEXTMERGE NOSHOW
                DELETE FROM <<P_Tabla_MySQL>> WHERE (<<VLc_CamposWhere>>)
                ENDTEXT

                * Ejecutar el script
                nResultado = SQLEXEC(MiConexion, lcQuery)
                
                * Verificar si ocurrió un error
                IF nResultado < 0
                    *AERROR(aErrorr)
                    * Mostrar información del error
                    *MESSAGEBOX("Error al ejecutar SQL: " + aErrorr[2], 16, "Error SQL")
                    *RETURN .F.  && Salir de la rutina o manejar el error según corresponda
                    AERROR(aErrorr)
                    VLc_DetErr = "Código de error: " + TRANSFORM(aErrorr[1]) + CHR(13) + ;
                                   "Mensaje: " + aErrorr[2]
                    *
                    GuardarError("ERROR AL EJECUTAR UN DELETE MYSQL", VLc_DetErr, lcQuery, G_USERNAME )
                ENDIF
                
            ENDSCAN
    ENDIF
    *
    * Desconecta la conexión al terminar
    SQLDISCONNECT(MiConexion)
    *
    SET DATE TO DMY
    *USE IN C_Estructura

ENDFUNC

FUNCTION SafeTrim
    LPARAMETERS vValue
    IF VARTYPE(vValue) = "C"
        RETURN ALLTRIM(vValue)
    ELSE
        RETURN vValue
    ENDIF
ENDFUNC

FUNCTION GuardarError
    LPARAMETERS P_DscErr, P_DetErr, P_DetErr2, P_CdgUsu
    IF !USED('F_Errores')
        lcDir = ObtenerDataDir()
        lcFile = ADDBS(lcDir) + "PMS_Errores.dbf"
        IF !FILE(lcFile) .AND. VARTYPE('CrearTablaErrores') = 'P'
            CrearTablaErrores(lcDir)
        ENDIF
        USE (lcFile) IN 0 ALIAS F_Errores ORDER CdgErr SHARED AGAIN
    ENDIF
    SELECT F_Errores
        GO BOTTOM
        IF !EMPTY(CdgErr)
            M.CdgErr = VAL(CdgErr)+1
        ELSE
            M.CdgErr = 1
        ENDIF
        
    M.CdgErr = PADL(ALLTRIM(TRANSFORM(M.CdgErr)),10,"0")
    M.DscErr = P_DscErr
    M.DetErr = P_DetErr
    M.DetErr2 = P_DetErr2
    M.CdgUsu = P_CdgUsu
    M.FecErr = DATETIME()
    M.Nom_PC = ALLTRIM(GETWORDNUM(SYS(0),1))
    INSERT INTO F_Errores FROM MEMVAR
ENDFUNC
*
