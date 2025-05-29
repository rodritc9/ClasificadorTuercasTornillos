=======================================================================================
Reporte de codigo DDL en bd

-Propietario  : PGT_PRG
-Nombre Objeto: PKG_TRADEUTILITY
-Tipo Objeto  : PACKAGE_BODY

Fecha Reporte: 20 mayo 2025 19:37
=======================================================================================

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PGT_PRG"."PKG_TRADEUTILITY" AS



/* *************************************************************************************/

/* PROJECT     :    Pkg_TradeUtility				   */

/* PROGRAM     :    Pkg_TradeUtility_body			   */

/* FILE        :    Pkg_TradeUtility_body.sql			       */

/*					       */

/* CREATE      :    25-02-2005		AUTOR  : <INORME SL>		   */

/* LAST. MOD.  :    29-06-2020		AUTOR  : <JROJAS>	       */

/*					       */

/* DESCRIPTION :    (17002.7) - Paquete con funcionalidades internas de GBO Trading.   */

/*					       */

/* MODIFIC.    :    GBO_9.2  05-05-2016  header - <RTEIJEIRO>  28846.7	Calypso    */

/*	    Collareral Interface - Add UPI Alias GBO mapping		   */

/* MODIFIC.    :    GBO_9.2  05-05-2016 - body - <RTEIJEIRO> - 28846.7 - Calypso      */

/*	    Collateral Interface - Add UPI Alias GBO mapping		   */

/* MODIFIC.    :    GBO_9.2  14-10-2016 - body/header - JROJAS - 29126.7 - Reports    */

/*	    Improvements: Add Accounting Center (Portfolio parameter)	       */

/* MODIFIC.    :    GBO_9.4  29-06-2020 - body - JROJAS - 32732.7 -	      */

/*	    [EMIR - DFA] 2020 Releases 9.4		       */

/* *************************************************************************************/



Cst_Package CONSTANT VARCHAR2(30) := 'Pkg_TradeUtility.';



/* ********************************************************************************/

/* <Function>	 f_GetIniRollover			  */

/* <Author>  INORME SL				  */

/* <Date>    25-02-2005 			  */

/* <Parameters>  Input: Event Pk ( Number )		      */

/* <Description> (17002.7) - Obtiene la Pk del Evento del Registry original que   */

/* interviene en un Rollover Netting. Relaciona los diferentes Rollover Registry  */

/* asociados a ese Evento.			      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

FUNCTION f_GetIniRollover( par_Event_Pk IN NUMBER ) RETURN NUMBER

IS



    num_PkInitial   NUMBER;



BEGIN



    BEGIN

    SELECT PK

    INTO   num_PKInitial

    FROM   "PGT_TRD".T_PGT_TRADE_EVENTS_S

    WHERE  FK_LINKEDEVENT IS NULL

    START WITH PK = par_Event_Pk

    CONNECT BY PRIOR FK_LINKEDEVENT = PK;

    EXCEPTION

    WHEN OTHERS THEN

	num_PKInitial := -1;

    END;



    RETURN num_PKInitial;



END f_GetIniRollover;



/* ********************************************************************************/

/* <Procedure>	 p_ChangeTradeStatus			      */

/* <Author>  INORME SL				  */

/* <Date>    18-08-2009 			  */

/* <Parameters>  Input: Event Pk (Number), Status (Number), RevText (Varchar)	  */

/* <Description> (17002.7) - Change the event status.		      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_ChangeTradeStatus( p_EventID IN NUMBER, p_Status IN NUMBER, p_RevText IN VARCHAR2 )

IS



    num_EventPK   Number;

    num_Status	  Number;

    num_RevCode   Number;



    str_Reason	  PGT_TRD.T_PGT_TRADE_EVENTS_S.REVTEXT%TYPE;



Begin



    num_EventPK   := p_EventID;

    num_Status	  := p_Status;

    str_Reason	  := p_RevText;



    "PGT_PRG".Pkg_Eventgeneral.p_SetVarLockEvent(0);



    IF ( num_Status = "PGT_PRG".Pkg_Pgtconst.CST_EV_STATUS_CAN )

    THEN



    IF RTRIM(str_Reason) IS NULL

    THEN

	Raise_Application_Error (-20001, 'Reversal Text must be filled');

    ELSE

	num_RevCode := "PGT_PRG".Pkg_Pgtconst.CST_REVREASON_OTHERS;

    END IF;



    UPDATE "PGT_TRD".T_PGT_TRADE_EVENTS_S

    SET    FK_REVREASON = num_RevCode,

	   REVTEXT	= str_Reason,

	   FK_STATUS	= num_Status

    WHERE  PK = num_EventPK;



    ELSE



    UPDATE "PGT_TRD".T_PGT_TRADE_EVENTS_S

    SET    FK_STATUS	= num_Status

    WHERE  PK = num_EventPK;



    END IF;



    "PGT_TRD".Pkg_Preeventprecommit.p_PreEventPreCommit (num_EventPK);



EXCEPTION

    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

     RAISE;



    WHEN "PGT_PRG".Pkg_PgtError.PACKAGE_DISCARDED THEN

     RAISE;



    WHEN OTHERS THEN

     RAISE_APPLICATION_ERROR(-20002, SQLERRM);



END p_ChangeTradeStatus;



/* ********************************************************************************/

/* <Procedure>	 p_GetCCSProductValue			      */

/* <Author>  JCASAS				  */

/* <Date>    30-07-2012 			  */

/* <Parameters>  Input: Header Pk (Number), Output: UPI Value (Varchar2)      */

/* <Description> (28846.7) - Calcutate the Product Value for Swap/CCS.	      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetCCSProductValue ( p_CoPk IN OUT NOCOPY VARCHAR2 )

IS

    Cst_Procedure   CONSTANT CHAR(30) := 'p_GetCCSProductValue';



    num_PkHeader NUMBER;

    num_SubType  NUMBER;



    str_Out  VARCHAR2(100);



BEGIN



    /*	SWAP:

	InterestRate:IRSwap:Basis  --> En GBO Patas Floating

	InterestRate:IRSwap:FixedFixed --> En GBO Patas Fixed

	InterestRate:IRSwap:FixedFloat	--> En GBO Patas Fixed Floating

	InterestRate:IRSwap:Inflation  --> En GBO Intrument Type Inflation independientemente de la patas.

    CCS:

	InterestRate:CrossCurrency:Basis  --> En GBO Patas Floating

	InterestRate:CrossCurrency:FixedFixed --> En GBO Patas Fixed

	InterestRate:CrossCurrency:FixedFloat  --> En GBO Patas Fixed Floating

    */



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Procedure, NULL, 'Start ' || Cst_Package || Cst_Procedure || ' Param - p_CoPk=' || p_CoPk);



    num_PkHeader := p_CoPk;



    -- GTR SubType

    "PGT_CFM".Pkg_EMIRGTRUtility.p_CalcGTRSubType( num_PkHeader, -- IN

			   num_SubType); -- OUT

    /* SWAP */

    IF num_SubType = Cst_GTRSwapType_FixFloat  THEN

    str_Out := 'InterestRate:IRSwap:FixedFloat';

    ELSIF num_SubType = Cst_GTRSwapType_OIS    THEN

    str_Out := 'InterestRate:IRSwap:OIS';

    ELSIF num_SubType = Cst_GTRSwapType_FixFix THEN

    str_Out := 'InterestRate:IRSwap:FixedFixed';

    ELSIF num_SubType = Cst_GTRSwapType_Basis  THEN

    str_Out := 'InterestRate:IRSwap:Basis';

    ELSIF num_SubType = Cst_GTRSwapType_InflSwap THEN

    str_Out := 'InterestRate:IRSwap:Inflation';

    /* CCS */

    ELSIF num_SubType = Cst_GTRCCSType_Basis  THEN

    str_Out := 'InterestRate:CrossCurrency:Basis';

    ELSIF num_SubType = Cst_GTRCCSType_FixFix	 THEN

    str_Out := 'InterestRate:CrossCurrency:FixedFixed';

    ELSIF num_SubType = Cst_GTRCCSType_FixFloat THEN

    str_Out := 'InterestRate:CrossCurrency:FixedFloat';

    END IF;



    p_CoPk := str_Out;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Procedure,NULL,'End ' || Cst_Package || Cst_Procedure|| ' Out - p_CoPk=' || p_CoPk);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    p_CoPk := NULL;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Procedure,NULL,'End ' || Cst_Package || Cst_Procedure|| ' (NoDataFound) Out - p_CoPk=' || p_CoPk);

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Procedure,NULL,' ERROR (' || Cst_Package||Cst_Procedure || ' ): ' || sqlerrm);

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Procedure, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetCCSProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_GetFRAProductValue			      */

/* <Author>  Stiwart Antunez (CORITEL)			  */

/* <Date>    03-09-2012 			  */

/* <Parameters>  Input: Event Pk (Number), Output: UPI Value (Varchar2)       */

/* <Description> (28846.7) - Calcutate the Product Value for FRA.	  */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetFRAProductValue ( p_CoPk IN OUT NOCOPY VARCHAR2 )

IS



    str_Out  VARCHAR2(100);

    num_PkHeader NUMBER;

    num_SubType  NUMBER;



    Cst_Module	 CONSTANT CHAR(50) := 'p_GetFRAProductValue';



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package|| Cst_Module || ' Param - p_CoPk=' || p_CoPk);



    str_Out := 'InterestRate:FRA';



    p_CoPk := str_Out;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package|| Cst_Module || ' Out - p_CoPk=' || p_CoPk);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    p_CoPk := NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,'Error: ' || SQLERRM);

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;



END p_GetFRAProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_GetCommCapProductValue		      */

/* <Author>  JCASAS				  */

/* <Date>    04-01-2013 			  */

/* <Parameters>  Input: Header Pk (Number), Output: UPI Value (Varchar2)      */

/* <Description> (28846.7) - Calcutate the Product Value for COMMODITY CAP&FLOOR. */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetCommCapProductValue ( p_CoPk IN OUT NOCOPY VARCHAR2 )

IS

    Cst_Module	    CONSTANT CHAR(50) := 'p_GetCommCapProductValue';



    num_PkHeader    NUMBER;



    rec_CapFloor    "PGT_TRD".T_PGT_CF_S%ROWTYPE;

    rec_QuoteRef    "PGT_CFM".Pkg_EMIRGTRUtility.tab_QuoteRef;

    rec_Sec	"PGT_CFM".Pkg_EMIRGTRUtility.tab_Security;

    rec_CommContract	"PGT_CFM".Pkg_EMIRGTRUtility.tab_CommContract;

    rec_Product     "PGT_CFM".Pkg_EMIRGTRUtility.tab_Product;



    num_QuoteType   NUMBER;

    num_QuoteRef    NUMBER;



    str_Out	VARCHAR2(100);



    str_ErrorText   VARCHAR2(200);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'Start:'||p_CoPk);



    --

    num_PkHeader := p_CoPk;



    -- Obtener los datos del CapFloor

    PGT_CFM.Pkg_EMIRGTRUtility.p_LoadCapFloor  (Cst_Ext_THeaderCapFloor,

			Cst_Owner_TradeHeader,

			num_PkHeader,

			Rec_CapFloor

			);



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'Cap='||rec_CapFloor.PK);





    num_QuoteRef := rec_CapFloor.FK_QUOTEREFERENCE;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW num_QuoteRef:'||num_QuoteRef);



    IF num_QuoteRef IS NOT NULL THEN

    --Obtener datos de la Quote Reference

    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadQuoteRef(num_QuoteRef,

			    rec_QuoteRef);



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW rec_QuoteRef:'||rec_QuoteRef.PK);



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW rec_QuoteRef.FK_QUOTETYPE:'||rec_QuoteRef.FK_QUOTETYPE);



    --Obtener datos de la Security

    IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities THEN --20761.4



	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW rec_QuoteRef.FK_QUOTETYPE:'||rec_QuoteRef.FK_QUOTETYPE);



	"PGT_CFM".Pkg_EMIRGTRUtility.p_LoadSecurity(rec_QuoteRef.FK_QUOTEINSTRUMENT,

			    rec_Sec);



	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW rec_Sec.PK:'||rec_Sec.PK);



    ELSE

	str_ErrorText := 'Error: Quote Reference is not a Security (Header: ' || num_PkHeader || ')';

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW str_ErrorText 2 '||str_ErrorText);

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, str_ErrorText );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END IF;



    END IF;



    --Datos del Producto de la Security (Commodity)

    IF rec_Sec.PK IS NOT NULL THEN



    IF rec_Sec.FK_SECTYPE = Cst_SecType_Commodity THEN --Commodity 25994.4

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 10');



	--Obtener el Commodity Contract de la Security

	"PGT_CFM".Pkg_EMIRGTRUtility.p_GetCommContract( rec_Sec.Pk, --IN

				rec_CommContract --OUT

			      );

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 20');

	--Obtener el Product del Commodity Contract

	"PGT_CFM".Pkg_EMIRGTRUtility.p_LoadCommodityProduct(rec_CommContract.FK_PRODUCT,

				rec_Product);

    ELSE

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 30');

	str_ErrorText := 'Error: Security is not a Commodity';

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, str_ErrorText );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END IF;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 50');

    END IF;



    IF rec_Product.Pk IS NOT NULL THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 60');

    IF rec_Product.FK_TYPE = Cst_CommProdType_MetalPrec THEN --Metals, Precious 45.4



	str_Out := 'Commodity:Metals:Precious:Option:Cash';

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 70');

    ELSIF rec_Product.FK_TYPE = Cst_CommProdType_MetalBase THEN --Metals, Base 44.4



	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 80');

	str_Out := 'Commodity:Metals:NonPrecious:Option:Cash';



    ELSIF rec_Product.FK_TYPE IN (Cst_CommProdType_Oil, --Oil 46.4

		      Cst_CommProdType_OilCrude, --Oil, Crude 47.4

		      Cst_CommProdType_OilRefFuel, --Oil, Ref, Fuel 48.4

		      Cst_CommProdType_OilRefGasoil, --Oil, Ref, Gasoil 49.4

		      Cst_CommProdType_GasolRBOB--Gasoline RBOB 43.4

		     ) THEN



	str_Out := 'Commodity:Energy:Oil:Option:Cash';



    ELSIF rec_Product.FK_TYPE = Cst_CommProdType_Gas THEN --Gas 26.4



	str_Out := 'Commodity:Energy:NatGas:Option:Cash';



    ELSIF rec_Product.FK_TYPE = Cst_CommProdType_Coal THEN --Coal 27.4



	str_Out := 'Commodity:Energy:Coal:Option:Cash';



    ELSIF rec_Product.FK_TYPE = Cst_CommProdType_Electricity THEN --Electricity 23.4



	str_Out := 'Commodity:Energy:Elec:Option:Cash';



    ELSIF rec_Product.FK_TYPE = Cst_CommProdType_Emissions THEN --Emissions 24.4



	str_Out := 'Commodity:Energy:InterEnergy:Option:Cash';



    END IF;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 100');

    END IF;



    p_CoPk := str_Out;



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    p_CoPk := NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 130');

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 120');

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'STW 110');

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;



END p_GetCommCapProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_GetCapProductValue			      */

/* <Author>  Stiwart Antunez (CORITEL)			  */

/* <Date>    03-09-2012 			  */

/* <Parameters>  Input: Event Pk (Number), Output: UPI Value (Varchar2)       */

/* <Description> (28846.7) - Calcutate the Product Value for CAP&FLOOR.       */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetCapProductValue ( p_CoPk IN OUT NOCOPY VARCHAR2 )

IS



    str_Out  VARCHAR2(100);

    num_PkHeader NUMBER;

    num_SubType  NUMBER;

    Cst_Module	 CONSTANT CHAR(30) := 'p_GetCapProductValue';



BEGIN





    str_Out := 'InterestRate:CapFloor';



    p_CoPk := str_Out;



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    p_CoPk := NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetCapProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_GetCFMProductValue			      */

/* <Author>  MCR				  */

/* <Date>    30-07-2012 			  */

/* <Parameters>  Input: Header Pk (Number), Output: UPI Value (Varchar2)      */

/* <Description> (28846.7) - Calcutate the Product Value for CASH FLOW MATCHING.  */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetCFMProductValue ( p_CoPk IN OUT NOCOPY VARCHAR2 )

IS

    Cst_Module	 CONSTANT CHAR(45) := 'p_GetCFMProductValue';



    num_PkHeader NUMBER;

    str_Out  VARCHAR2(100);



BEGIN



     "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package || Cst_Module || ' Param - p_CoPk=' || p_CoPk);







     str_Out := 'InterestRate:Exotic';



    p_CoPk := str_Out;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package || Cst_Module|| ' Out - p_CoPk=' || p_CoPk);



EXCEPTION



    WHEN NO_DATA_FOUND THEN

    p_CoPk := NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetCFMProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_LoadUPIConfigParam			      */

/* <Author>  JCASAS				  */

/* <Date>    05-12-2012 			  */

/* <Parameters>  Input: Credit PK, Output: UPI Config (Record)		  */

/* <Description> (28846.7) - Load parameters to search the UPI Config.	      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* <Mod> GBO2022 - 23-03-2022 - x231189 - 34895.7 - Added instrument type     */

/* ********************************************************************************/

PROCEDURE p_LoadUPIConfigParam ( p_PkCredit IN NUMBER,

		 o_rec_UPIConfig OUT "PGT_CFM".T_PGT_GTR_UPI_CFG_S%ROWTYPE )

IS

    Cst_Module	   CONSTANT CHAR(30) := 'p_LoadUPIConfigParam';



    num_PkCredit   NUMBER;



    num_PkEv	   NUMBER;

    num_PkHeader   NUMBER;

    num_CreditType NUMBER;

    num_DocClause  NUMBER;

    num_Basket	   NUMBER;

    str_DocClause  VARCHAR2(100);

    str_BasketType VARCHAR2(100);

    num_Issuer	   NUMBER;

    num_Strategy   NUMBER;

    num_BDESect    NUMBER;

    num_PkUnderlying NUMBER;

    str_UnderlyingCode VARCHAR2(60);

    num_EQCDOCLO   NUMBER;

    num_INSTRUMTYPE NUMBER; -- 23-03-2022 - x231189 - 34895.7



    rec_UPIConfig  "PGT_CFM".T_PGT_GTR_UPI_CFG_S%ROWTYPE;



    str_text_error VARCHAR2(200);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - p_PkCredit=' || p_PkCredit);



    --MNA(28/12/2012) Se inicializa con valor 0, si no, en cuanto no encuentre una configuracion, se queda con valor 1 para las siguientes

    num_Error := 0;



    num_PkCredit := p_PkCredit;



    -- Extraemos el tipo de Credito y en funcion del mismo cargamos los datos



    BEGIN

    SELECT CD.FK_CREDTYPE, CD.FK_DOCCLAUSE,

	   CD.FK_PARENT, CD.FK_BASKET,

	   CD.FK_ISSUER

    INTO num_CreditType, num_DocClause,

	 num_PkHeader, num_Basket,

	 num_Issuer

    FROM PGT_TRD.T_PGT_CD_S CD

    WHERE CD.PK = num_PkCredit;

    EXCEPTION

    WHEN NO_DATA_FOUND THEN

	/*str_text_error := 'Error - Loading Credit data: ' || 'No data found';

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

		    Cst_Module,

		    9,

		    Cst_General_ErrorType,

		    str_text_error

		    );

       RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;*/

       num_Error:= 1;/* STW 18-12-2012 */

    WHEN OTHERS THEN

	str_text_error := 'Error - Loading Credit data: ' || SQLERRM;

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;







    IF num_CreditType = Cst_CreditType_CreDefSwap THEN



    -- Obtener la estrategia

    BEGIN



	SELECT FK_STRATEGY, FK_INSTRUMTYPE

	INTO num_Strategy, num_INSTRUMTYPE --23-03-2022 - x231189 - 34895.7

	FROM "PGT_TRD".T_PGT_TRADE_HEADER_S

	WHERE PK = num_PkHeader;

    EXCEPTION

	WHEN NO_DATA_FOUND THEN

	/*str_text_error := 'Error loading header: ' || 'No data found';

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

		    Cst_Module,

		    9,

		    Cst_General_ErrorType,

		    str_text_error

		    );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;*/

	num_Error:= 1;/* STW 18-12-2012 */



	WHEN OTHERS THEN

	str_text_error := 'Error loading header Strategy or Instrument Type: ' || SQLERRM;

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;



    -- Obtener la BDESectorizacion del Issuer

    BEGIN

--	  SELECT FK_BDE_SECTORIZATION

--	INTO num_BDESect

--	FROM PGT_STC.V_PGT_CDISSLIST_S

--	   WHERE PK = num_Issuer;

	SELECT FK_BDE_SECTORIZATION

	INTO num_BDESect

	FROM PGT_STC.T_PGT_ENTITY_S

	WHERE PK = num_Issuer;

    EXCEPTION

	WHEN NO_DATA_FOUND THEN

	/*str_text_error := 'Error loading Issuer: ' || 'No data found';

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

		    Cst_Module,

		    9,

		    Cst_General_ErrorType,

		    str_text_error

		    );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

	*/

	 num_Error:= 1;/* STW 18-12-2012 */

	/* STW 18-12-2012 */

	WHEN OTHERS THEN

	str_text_error := 'Error loading BDESect: ' || SQLERRM;

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;



    -- Necesitamos el literal de la DocClause

    BEGIN

	SELECT CODE

	INTO str_DocClause

	FROM "PGT_STC".T_PGT_CD_DOCCLAUSE_S

	WHERE PK = num_DocClause;

    EXCEPTION

	WHEN NO_DATA_FOUND THEN

	/* str_text_error := 'Error load DocClause '||num_DocClause||': No found';

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

		    Cst_Module,

		    9,

		    Cst_General_ErrorType,

		    str_text_error

		    );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;  */

	num_Error:= 1;/* STW 18-12-2012 */

	/* STW 18-12-2012 */

	WHEN OTHERS THEN

	str_text_error := 'Error loading DocClause: ' || SQLERRM;

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;



    -- Parametros de la configuracion

    rec_UPIConfig.FK_INSTRUMENT := Cst_Instrument_CreDeriv;

    rec_UPIConfig.FK_CREDTYPE	:= num_CreditType;

    rec_UPIConfig.DOCCLAUSE	:= str_DocClause;

    rec_UPIConfig.FK_STRATEGY	:= num_Strategy;

    rec_UPIConfig.FK_BDE_SECTORIZATION := num_BDESect;

    rec_UPIConfig.FK_INSTRUMTYPE := num_INSTRUMTYPE;







    ELSIF num_CreditType = Cst_CreditType_CDSBasket THEN



    -- Buscar el BasketType (es el alias ISDA-418.4 de la Basket)

    -- Registry/ Credit/ Cred.Basket/ Basket/Alias /Output Alias ( Source: 418.4)

    --MNA(31/03/2014) Entities Stratification. Se busca el alias ISDA con el procedimiento de Estaticos

    BEGIN



	str_BasketType := "PGT_STI".Pkg_Entity.f_BasketlSDATaxonomy (num_Basket);



    EXCEPTION

	WHEN NO_DATA_FOUND THEN

	/*    str_text_error := 'Error load alias '||num_Basket||': No found';

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

		    Cst_Module,

		    9,

		    Cst_General_ErrorType,

		    str_text_error

		    );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg; */

	num_Error:= 1;/* STW 18-12-2012 */

	/* STW 18-12-2012 */

	WHEN OTHERS THEN

	str_text_error := 'Error loading BasketType: ' || SQLERRM;

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;



    -- Parametros de la configuracion

    rec_UPIConfig.FK_INSTRUMENT := Cst_Instrument_CreDeriv;

    rec_UPIConfig.FK_CREDTYPE	:= num_CreditType;

    rec_UPIConfig.BASKETTYPE	:= str_BasketType;





    ELSIF num_CreditType = Cst_CreditType_STCDO THEN



    -- -- JCASAS 04-01-2013: Eliminado



--    -- Buscar el BasketType (es el alias ISDA-418.4 de la Basket)

--	-- Registry/ Credit/ Cred.Basket/ Basket/Alias /Output Alias ( Source: 418.4)

--    -- Buscar el Code del Underlying (Code de la Basket)

--    BEGIN

--	  SELECT OBJ.ALIASCODE, BI.CODE

--	   INTO str_BasketType, str_UnderlyingCode

--	   FROM "PGT_STD".T_MDR_BOI_MATURITIES_S    BM,

--	    "PGT_STD".T_MDR_BASKET_OF_ISSUERS_S BI,

--	    "PGT_STC".T_PGT_OBJSRC_OUTPUT_S OBJ

--	  WHERE BM.PK	     = num_Basket

--	AND BI.PK	 = BM.FK_PARENT

--	AND OBJ.FK_PARENT    = BI.PK

--	AND OBJ.FK_OWNER_OBJ = Cst_OWN_OBJ_Basket -- 16086.4

--	AND OBJ.FK_EXTENSION = Cst_Ext_Basket_SrcOutput -- 89432.4

--	AND OBJ.FK_SOURCE    = Cst_ISDASource;-- 418.4 (Alias ISDA)

--    EXCEPTION

--	  WHEN NO_DATA_FOUND THEN

--	  num_Error:= 1;/* STW 18-12-2012 */

--	  /* STW 18-12-2012 */

--	  WHEN OTHERS THEN

--	  str_text_error := 'Error loading str_BasketType, str_UnderlyingCode ';

--	  "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

--	  PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

--		      Cst_Module,

--		      9,

--		      Cst_General_ErrorType,

--		      str_text_error

--		      );

--	  RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

--    END;



--    -- Parametros de la configuracion

--    rec_UPIConfig.FK_INSTRUMENT := Cst_Instrument_CreDeriv;

--    rec_UPIConfig.FK_CREDTYPE   := num_CreditType;

--    rec_UPIConfig.BASKETTYPE	  := str_BasketType;

--    IF (str_UnderlyingCode like '%CDO%') OR

--	 (str_UnderlyingCode like '%CLO%')

--    THEN

--	  rec_UPIConfig.EQCDOCLO := 1;

--    ELSE

--	  rec_UPIConfig.EQCDOCLO := 0;

--    END IF;



    -- -- FIN JCASAS 04-01-2013: Eliminado



    -- -- JCASAS 04-01-2013: Primero ver si la cesta es CDO-CLO, y solo buscar el alias si NO lo es

	-- Buscar el Code del Underlying (Code de la Registry/ Credit/ Cred.Basket/ Basket)

    BEGIN

	SELECT BI.PK, BI.CODE

	INTO  num_PkUnderlying, str_UnderlyingCode

	FROM "PGT_STD".T_MDR_BOI_MATURITIES_S	 BM,

	 "PGT_STD".T_MDR_BASKET_OF_ISSUERS_S BI

	WHERE BM.PK	   = num_Basket

	AND BI.PK	 = BM.FK_PARENT;

    EXCEPTION

	WHEN NO_DATA_FOUND THEN

	str_text_error := 'Error loading Underlying (PkBasket='||num_Basket||'): '||'No data found';

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	num_Error:= 1;/* STW 18-12-2012 */

	/* STW 18-12-2012 */

	WHEN OTHERS THEN

	str_text_error := 'Error loading Underlying (PkBasket='||num_Basket||'): '||sqlerrm;

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;



    -- Ver si la cesta es CDO-CLO

    IF (str_UnderlyingCode like '%CDO%') OR

       (str_UnderlyingCode like '%CLO%') THEN

	num_EQCDOCLO := 1;

    ELSE

	num_EQCDOCLO := 0;

    END IF;



    -- Si NO es CDO-CLO => Buscar el alias: Registry/ Credit/ Cred.Basket/ Basket/Alias /Output Alias ( Source: 418.4)

    IF num_EQCDOCLO = 0 THEN



	--MNA(31/03/2014) Entities Stratification. Se busca el alias ISDA con el procedimiento de Estaticos

	BEGIN



	str_BasketType := "PGT_STI".Pkg_Entity.f_BasketlSDATaxonomy (num_Basket);



	EXCEPTION

	WHEN NO_DATA_FOUND THEN

	    num_Error:= 1;/* STW 18-12-2012 */

	/* STW 18-12-2012 */

	WHEN OTHERS THEN

	    str_text_error := 'Error loading str_BasketType, str_UnderlyingCode ';

	    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

	    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

	END;



    END IF;



    -- Parametros de la configuracion

    rec_UPIConfig.FK_INSTRUMENT := Cst_Instrument_CreDeriv;

    rec_UPIConfig.FK_CREDTYPE	:= num_CreditType;

    rec_UPIConfig.BASKETTYPE	:= str_BasketType;

    rec_UPIConfig.EQCDOCLO	:= num_EQCDOCLO;



    -- -- FIN JCASAS 04-01-2013





    ELSIF num_CreditType = Cst_CreditType_NthToDef THEN



    rec_UPIConfig.FK_INSTRUMENT := Cst_Instrument_CreDeriv;

    rec_UPIConfig.FK_CREDTYPE	:= num_CreditType;



    END IF;



    -- Salida

    o_rec_UPIConfig := rec_UPIConfig;





    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,' Out - o_rec_UPIConfig -->' );

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,

	'FK_INSTRUMENT='	||o_rec_UPIConfig.FK_INSTRUMENT ||';'||

	'FK_CREDTYPE='	    ||o_rec_UPIConfig.FK_CREDTYPE   ||';'||

	'DOCCLAUSE='	    ||o_rec_UPIConfig.DOCCLAUSE     ||';'||

	'BASKETTYPE='	    ||o_rec_UPIConfig.BASKETTYPE

	 );

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,

	'EQCDOCLO='	    ||o_rec_UPIConfig.EQCDOCLO	    ||';'||

	'FK_BDE_SECTORIZATION=' ||o_rec_UPIConfig.FK_BDE_SECTORIZATION||';'||

	'FK_STRATEGY='	    ||o_rec_UPIConfig.FK_STRATEGY

	);



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module);



EXCEPTION



    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;



    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;



    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN NO_DATA_FOUND THEN/* STW 18-12-2012 */

    num_Error:= 1;/* STW 18-12-2012 */

    WHEN OTHERS THEN

    str_text_error := 'Error: ' || SQLERRM;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;





END p_LoadUPIConfigParam;



/* ********************************************************************************/

/* <Procedure>	 p_GetUPIConfigFromParam		      */

/* <Author>  JCASAS				  */

/* <Date>    05-12-2012 			  */

/* <Parameters>  Input: UPI Config (Record), Output: UPI Config (Record)      */

/* <Description> (28846.7) - Return UPI Config based on the Credit Derivative	  */

/* operation data ( CreditType, DocClause, BasketType, Strategy, BDESectoriz,	  */

/* CDO / CLO ). 				  */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* <Mod> GBO2022 - 23-03-2022 - x231189 - 34895.7 - Added instrument type     */

/* ********************************************************************************/

PROCEDURE p_GetUPIConfigFromParam ( rec_UPIConfig IN OUT "PGT_CFM".T_PGT_GTR_UPI_CFG_S%ROWTYPE )

IS

    Cst_Module	   CONSTANT CHAR(30) := 'p_GetUPIConfigFromParam';



    rec_UPIConfigAux "PGT_CFM".T_PGT_GTR_UPI_CFG_S%ROWTYPE;

    boo_NoDataFound  BOOLEAN;

    num_CreditType   NUMBER;



    str_text_error   VARCHAR2(200);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param --> rec_UPIConfig:');



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,

	'FK_INSTRUMENT='	||rec_UPIConfig.FK_INSTRUMENT ||';'||

	'FK_CREDTYPE='	    ||rec_UPIConfig.FK_CREDTYPE   ||';'||

	'DOCCLAUSE='	    ||rec_UPIConfig.DOCCLAUSE	  ||';'||

	'BASKETTYPE='	    ||rec_UPIConfig.BASKETTYPE

	 );

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,

	'EQCDOCLO='	    ||rec_UPIConfig.EQCDOCLO	  ||';'||

	'FK_GTRCREDTYPE='	||rec_UPIConfig.FK_GTRCREDTYPE||';'||

	'FK_BDE_SECTORIZATION=' ||rec_UPIConfig.FK_BDE_SECTORIZATION||';'||

	'FK_STRATEGY='	    ||rec_UPIConfig.FK_STRATEGY||';'||
	'FK_INSTRUMTYPE='	||rec_UPIConfig.FK_INSTRUMTYPE

	);



    -- Buscar la configuracion

    BEGIN

    SELECT *

    INTO rec_UPIConfigAux

    FROM "PGT_CFM".T_PGT_GTR_UPI_CFG_S

    WHERE FK_INSTRUMENT = rec_UPIConfig.FK_INSTRUMENT

    AND FK_CREDTYPE   = rec_UPIConfig.FK_CREDTYPE

    AND NVL(DOCCLAUSE, 'ZZ')  = NVL(rec_UPIConfig.DOCCLAUSE , 'ZZ')

    AND NVL(BASKETTYPE, 'ZZ') = NVL(rec_UPIConfig.BASKETTYPE, 'ZZ')

    AND NVL(EQCDOCLO, -1)     = NVL(rec_UPIConfig.EQCDOCLO, -1)

    AND NVL(FK_STRATEGY, -1)  = NVL(rec_UPIConfig.FK_STRATEGY, -1)

    AND NVL(FK_BDE_SECTORIZATION, -1) = NVL(rec_UPIConfig.FK_BDE_SECTORIZATION, -1);



    boo_NoDataFound := FALSE; -- Configuracion encontrada

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'rec_UPIConfigAux.PK: '||rec_UPIConfigAux.PK);

    EXCEPTION

    WHEN NO_DATA_FOUND THEN

	boo_NoDataFound := TRUE; -- Indicamos que no se ha encontrado la configuracion

    WHEN TOO_MANY_ROWS THEN

	/*str_text_error := 'Error getting UPI config: ' || 'Too many rows';

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

		    Cst_Module,

		    9,

		    Cst_General_ErrorType,

		    str_text_error

		    );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;*/

	boo_NoDataFound := TRUE;/* STW 19-12-2012 */



    END;





    num_CreditType := rec_UPIConfig.FK_CREDTYPE;



    IF boo_NoDataFound THEN -- No se ha encontrado la configuracion => Hacemos una busqueda mejor





    IF num_CreditType = Cst_CreditType_CreDefSwap THEN


      IF rec_UPIConfig.FK_INSTRUMTYPE <> CST_CDS_CCDS_COVERAGE	THEN --24-03-2022 - x231189 - 34895.7 -
	-- Buscar solo por Strategy y BDESector

	BEGIN

	SELECT *

	INTO rec_UPIConfigAux

	FROM "PGT_CFM".T_PGT_GTR_UPI_CFG_S

	WHERE FK_INSTRUMENT = rec_UPIConfig.FK_INSTRUMENT

	AND FK_CREDTYPE   = rec_UPIConfig.FK_CREDTYPE

	AND NVL(FK_STRATEGY, -1)  = NVL(rec_UPIConfig.FK_STRATEGY, -1)

	AND NVL(FK_BDE_SECTORIZATION, -1) = NVL(rec_UPIConfig.FK_BDE_SECTORIZATION, -1)

	AND FK_INSTRUMTYPE IS NULL;


	boo_NoDataFound := FALSE; -- Configuracion encontrada



	EXCEPTION

	WHEN NO_DATA_FOUND THEN

	    boo_NoDataFound := TRUE; -- Indicamos que no se ha encontrado la configuracion

	WHEN TOO_MANY_ROWS THEN

	    /*str_text_error := 'Error getting UPI config: ' || 'Too many rows';

	    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

			Cst_Module,

			9,

			Cst_General_ErrorType,

			str_text_error

			);

	    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;*/

	    boo_NoDataFound := TRUE;/* STW 19-12-2012 */



	END;





	IF boo_NoDataFound THEN -- No se ha encontrado la configuracion => Hacemos una busqueda mejor



	-- Buscar solo por DocClause

	BEGIN

	    SELECT *

	    INTO rec_UPIConfigAux

	    FROM "PGT_CFM".T_PGT_GTR_UPI_CFG_S

	    WHERE FK_INSTRUMENT = rec_UPIConfig.FK_INSTRUMENT

	    AND FK_CREDTYPE   = rec_UPIConfig.FK_CREDTYPE

	    AND NVL(DOCCLAUSE, 'ZZ')  = NVL(rec_UPIConfig.DOCCLAUSE , 'ZZ')

	    AND FK_INSTRUMTYPE IS NULL;

	    boo_NoDataFound := FALSE; -- Configuracion encontrada



	EXCEPTION

	    WHEN NO_DATA_FOUND THEN

	    boo_NoDataFound := TRUE; -- Indicamos que no se ha encontrado la configuracion

	    WHEN TOO_MANY_ROWS THEN

	    /*str_text_error := 'Error getting UPI config: ' || 'Too many rows';

	    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

			Cst_Module,

			9,

			Cst_General_ErrorType,

			str_text_error

			);

	    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;*/

	    boo_NoDataFound := TRUE;/* STW 19-12-2012 */



	END;



	END IF;

	--START - 24-03-2022 - x231189 - 34895.7 -
      ELSIF rec_UPIConfig.FK_INSTRUMTYPE = CST_CDS_CCDS_COVERAGE THEN

       BEGIN

	SELECT *

	INTO rec_UPIConfigAux

	FROM "PGT_CFM".T_PGT_GTR_UPI_CFG_S

	WHERE FK_INSTRUMENT = rec_UPIConfig.FK_INSTRUMENT

	AND FK_CREDTYPE   = rec_UPIConfig.FK_CREDTYPE

	AND NVL(DOCCLAUSE, 'ZZ')  = NVL(rec_UPIConfig.DOCCLAUSE , 'ZZ')

	AND NVL(BASKETTYPE, 'ZZ') = NVL(rec_UPIConfig.BASKETTYPE, 'ZZ')

	AND NVL(EQCDOCLO, -1)	  = NVL(rec_UPIConfig.EQCDOCLO, -1)


	AND NVL(FK_INSTRUMTYPE, -1) = NVL(rec_UPIConfig.FK_INSTRUMTYPE, -1);



	boo_NoDataFound := FALSE; -- Configuracion encontrada

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'rec_UPIConfigAux.PK: '||rec_UPIConfigAux.PK);

	EXCEPTION

	WHEN NO_DATA_FOUND THEN

	    boo_NoDataFound := TRUE; -- Indicamos que no se ha encontrado la configuracion

	WHEN TOO_MANY_ROWS THEN



	    boo_NoDataFound := TRUE;/* STW 19-12-2012 */



	END;

      END IF;
      --END - 24-03-2022 - x231189 - 34895.7 -


    ELSIF num_CreditType = Cst_CreditType_CDSBasket THEN



	-- Buscar solo por BasketType

	BEGIN

	SELECT *

	INTO rec_UPIConfigAux

	FROM "PGT_CFM".T_PGT_GTR_UPI_CFG_S

	WHERE FK_INSTRUMENT = rec_UPIConfig.FK_INSTRUMENT

	AND FK_CREDTYPE   = rec_UPIConfig.FK_CREDTYPE

	AND NVL(BASKETTYPE, 'ZZ') = NVL(rec_UPIConfig.BASKETTYPE, 'ZZ');



	boo_NoDataFound := FALSE; -- Configuracion encontrada



	EXCEPTION

	WHEN NO_DATA_FOUND THEN

	    boo_NoDataFound := TRUE; -- Indicamos que no se ha encontrado la configuracion

	WHEN TOO_MANY_ROWS THEN

	    /*str_text_error := 'Error getting UPI config: ' || 'Too many rows';

	    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

			Cst_Module,

			9,

			Cst_General_ErrorType,

			str_text_error

			);

	    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;*/

	    boo_NoDataFound := TRUE;/* STW 19-12-2012 */



	END;





    ELSIF num_CreditType = Cst_CreditType_STCDO THEN



	-- Buscar solo por BasketType y CDO/CLO

	BEGIN

	SELECT *

	INTO rec_UPIConfigAux

	FROM "PGT_CFM".T_PGT_GTR_UPI_CFG_S

	WHERE FK_INSTRUMENT = rec_UPIConfig.FK_INSTRUMENT

	AND FK_CREDTYPE   = rec_UPIConfig.FK_CREDTYPE

	AND NVL(BASKETTYPE, 'ZZ') = NVL(rec_UPIConfig.BASKETTYPE, 'ZZ')

	AND NVL(EQCDOCLO, -1)	  = NVL(rec_UPIConfig.EQCDOCLO, -1);



	boo_NoDataFound := FALSE; -- Configuracion encontrada



	EXCEPTION

	WHEN NO_DATA_FOUND THEN

	    boo_NoDataFound := TRUE; -- Indicamos que no se ha encontrado la configuracion

	WHEN TOO_MANY_ROWS THEN

	    str_text_error := 'Error getting UPI config: ' || 'Too many rows';

	    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

	    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

	    --boo_NoDataFound := TRUE;/* STW 19-12-2012 */



	END;



	IF boo_NoDataFound THEN -- No se ha encontrado la configuracion => Hacemos una busqueda mejor



	-- Buscar solo por CDO/CLO

	BEGIN

	    SELECT *

	    INTO rec_UPIConfigAux

	    FROM "PGT_CFM".T_PGT_GTR_UPI_CFG_S

	    WHERE FK_INSTRUMENT = rec_UPIConfig.FK_INSTRUMENT

	    AND FK_CREDTYPE   = rec_UPIConfig.FK_CREDTYPE

	    AND NVL(EQCDOCLO, -1)     = NVL(rec_UPIConfig.EQCDOCLO, -1);



	    boo_NoDataFound := FALSE; -- Configuracion encontrada



	EXCEPTION

	    WHEN NO_DATA_FOUND THEN

	    boo_NoDataFound := TRUE; -- Indicamos que no se ha encontrado la configuracion

	    WHEN TOO_MANY_ROWS THEN

	    /*str_text_error := 'Error getting UPI config: ' || 'Too many rows';

	    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

			Cst_Module,

			9,

			Cst_General_ErrorType,

			str_text_error

			);

	    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;*/

	    boo_NoDataFound := TRUE;/* STW 19-12-2012 */



	END;



	END IF;





    ELSIF num_CreditType = Cst_CreditType_NthToDef THEN



	-- Buscar solo por CreditType

	BEGIN

	SELECT *

	INTO rec_UPIConfigAux

	FROM "PGT_CFM".T_PGT_GTR_UPI_CFG_S

	WHERE FK_INSTRUMENT = rec_UPIConfig.FK_INSTRUMENT

	AND FK_CREDTYPE   = rec_UPIConfig.FK_CREDTYPE;



	boo_NoDataFound := FALSE; -- Configuracion encontrada



	EXCEPTION

	WHEN NO_DATA_FOUND THEN

	    boo_NoDataFound := TRUE; -- Indicamos que no se ha encontrado la configuracion

	WHEN TOO_MANY_ROWS THEN

	    /*str_text_error := 'Error getting UPI config: ' || 'Too many rows';

	    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

	    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

			Cst_Module,

			9,

			Cst_General_ErrorType,

			str_text_error

			);

	    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;*/

	    boo_NoDataFound := TRUE;/* STW 19-12-2012 */



	END;



    END IF;



    END IF;



    -- Ver si hay error

    IF boo_NoDataFound THEN -- No se ha encontrado ninguna configuracion => Error



--    str_text_error := 'Error getting UPI config: ' || 'UPI Config not found';

--    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

--    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,

--		  Cst_Module,

--		  9,

--		  Cst_General_ErrorType,

--		  str_text_error

--		  );

--    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    rec_UPIConfigAux := NULL;



    END IF;



    -- Salida

    rec_UPIConfig := rec_UPIConfigAux;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - UPIConfig.PK='||rec_UPIConfig.PK);



EXCEPTION



    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;



    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;



    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;



    WHEN  NO_DATA_FOUND THEN

    rec_UPIConfig := NULL;/* STW 18-12-2012 */

    WHEN OTHERS THEN

    str_text_error := 'Error: ' || SQLERRM;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;



END p_GetUPIConfigFromParam;



/* ********************************************************************************/

/* <Procedure>	 p_GetUPIConfig 			  */

/* <Author>  JCASAS				  */

/* <Date>    05-12-2012 			  */

/* <Parameters>  Input: Credit Pk (Number), Output: UPI Config (Record)       */

/* <Description> (28846.7) - Return the UPI Config for CREDIT DERIVATIVES.    */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetUPIConfig ( p_PkCredit IN NUMBER,

	       o_rec_UPIConfig OUT "PGT_CFM".T_PGT_GTR_UPI_CFG_S%ROWTYPE )

IS

    Cst_Module	   CONSTANT CHAR(30) := 'p_GetUPIConfig';



    num_PkCredit   NUMBER;



    rec_UPIConfig  "PGT_CFM".T_PGT_GTR_UPI_CFG_S%ROWTYPE;



    str_text_error VARCHAR2(200);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - p_PkCredit=' || p_PkCredit);



    num_PkCredit := p_PkCredit;



    -- Cargar los datos de busqueda para la Configuracion del UPI

    p_LoadUPIConfigParam (num_PkCredit, -- IN

	      rec_UPIConfig); -- OUT





    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'num_error '||num_error);

    /* STW 19-12-2012 */

    /* Si no hay error */

    IF num_error <> 1 THEN

    -- Obtener la Configuracion del UPI para los parametros introducidos

    p_GetUPIConfigFromParam (rec_UPIConfig); -- IN OUT



    ELSE

    rec_UPIConfig := NULL;

    END IF;



    -- Salida

    o_rec_UPIConfig := rec_UPIConfig;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - UPIConfig.PK='||o_rec_UPIConfig.PK);



EXCEPTION

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;



    WHEN "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;



    WHEN "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN NO_DATA_FOUND THEN /* STW 18-12-2012 */

    o_rec_UPIConfig := NULL;

    WHEN OTHERS THEN

    str_text_error := 'Error: ' || SQLERRM;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module, NULL,str_text_error);

    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,str_text_error);

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;





END p_GetUPIConfig;



/* ********************************************************************************/

/* <Procedure>	 p_GetCreditProductValue		      */

/* <Author>  JCASAS				  */

/* <Date>    19-09-2012 			  */

/* <Parameters>  Input: Credit Pk (Number), Output: UPI Value (Varchar2)      */

/* <Description> (28846.7) - Calcutate the Product Value for CREDIT DERIVATIVES.  */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetCreditProductValue ( num_PK IN OUT NOCOPY VARCHAR2 )

IS

    Cst_Module	   CONSTANT CHAR(30) := 'p_GetCreditProductValue';



    num_PkCredit   NUMBER;



    rec_UPIConfig  "PGT_CFM".T_PGT_GTR_UPI_CFG_S%ROWTYPE;



    str_Out    VARCHAR2(100);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - num_PK=' || num_PK);



    num_PkCredit := TO_NUMBER(num_PK);



    p_GetUPIConfig( num_PkCredit, -- IN

	    rec_UPIConfig); -- OUT



    --

    str_Out := rec_UPIConfig.UPI;



    -- Variable de salida

    num_PK := str_Out;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - num_PK=' || num_PK);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    num_PK := NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,'Error: ' || SQLERRM);

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetCreditProductValue;



/* *********************************************************************************/

/* <Procedure>	 p_GetCommEQSwapProductValue			   */

/* <Author>  JCASAS				   */

/* <Date>    08-06-2015 			   */

/* <Parameters>  Input: Header Pk (Number), Output: UPI Value (Varchar2)       */

/* <Description> (28846.7) - Calcutate the Product Value for COMMODITY EQUITY SWAP.*/

/* ------------------------------------------------------------------------------- */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	    */

/* *********************************************************************************/

PROCEDURE p_GetCommEQSwapProductValue ( p_CoPk IN OUT NOCOPY VARCHAR2 )

IS

    Cst_Procedure  CONSTANT VARCHAR2(50) := 'p_GetCommEQSwapProductValue';



    num_PkHeader    NUMBER;



    rec_EqSwp	    "PGT_TRD".T_PGT_EQSWP_S%ROWTYPE;

    rec_QuoteRef    "PGT_CFM".Pkg_EMIRGTRUtility.tab_QuoteRef;

    rec_Sec	"PGT_CFM".Pkg_EMIRGTRUtility.tab_Security;

    rec_CommContract	"PGT_CFM".Pkg_EMIRGTRUtility.tab_CommContract;

    rec_Product     "PGT_CFM".Pkg_EMIRGTRUtility.tab_Product;



    num_QuoteType   NUMBER;

    num_QuoteRef    NUMBER;



    str_Out	VARCHAR2(100);



BEGIN



    -- Iniciamos las trazas

    "PGT_SYS".Pkg_ApplicationInfo.p_Process (Cst_Procedure , NULL, 'Start ' || Cst_Procedure || ' Param - ' || ' p_CoPk: ' || p_CoPk);





    num_PkHeader := p_CoPk;



    --Obtener datos del Equity Swap

    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadEqSwpFromHd(num_PkHeader,

			   rec_EqSwp);

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Procedure,NULL,'EQSWP='||rec_EqSwp.PK);

    IF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Loan THEN --183.4 - Loan

    num_QuoteType   := rec_EqSwp.FK_QUOTETYPE_A;

    num_QuoteRef    := rec_EqSwp.FK_QUOTEREFERENCE_A;



    ELSIF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Borrower THEN --184.4 - Borrower

    num_QuoteType   := rec_EqSwp.FK_QUOTETYPE_L;

    num_QuoteRef    := rec_EqSwp.FK_QUOTEREFERENCE_L;



    ELSIF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Both THEN --25703.4 - Both

    --Si las dos son del mismo tipo -> coger los datos de la pata Asset (criterio inventado a falta de confirmacion)

    --Si una de las dos es una security -> tomar datos de la Security (criterio inventado a falta de confirmacion)

    IF rec_EqSwp.FK_QUOTETYPE_A = rec_EqSwp.FK_QUOTETYPE_L THEN

	num_QuoteType	:= rec_EqSwp.FK_QUOTETYPE_A;

	num_QuoteRef	:= rec_EqSwp.FK_QUOTEREFERENCE_A;

    ELSE

	IF rec_EqSwp.FK_QUOTETYPE_A = Cst_QuoteType_Securities THEN --20761.4

	num_QuoteType	:= rec_EqSwp.FK_QUOTETYPE_A;

	num_QuoteRef	:= rec_EqSwp.FK_QUOTEREFERENCE_A;

	ELSIF rec_EqSwp.FK_QUOTETYPE_L = Cst_QuoteType_Securities THEN --20761.4

	num_QuoteType	:= rec_EqSwp.FK_QUOTETYPE_L;

	num_QuoteRef	:= rec_EqSwp.FK_QUOTEREFERENCE_L;

	END IF;

    END IF;



    END IF;



    IF num_QuoteRef IS NOT NULL THEN

    --Obtener datos de la Quote Reference

    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadQuoteRef(num_QuoteRef,

			    rec_QuoteRef);

    --Obtener datos de la Security

    IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities THEN --20761.4

	"PGT_CFM".Pkg_EMIRGTRUtility.p_LoadSecurity(rec_QuoteRef.FK_QUOTEINSTRUMENT,

			    rec_Sec);

    ELSE

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Procedure, 9, Cst_General_ErrorType, 'Error: Quote Reference is not a Security');

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;



    END IF;



    END IF;



    --Datos del Producto de la Security (Commodity)

    IF rec_Sec.PK IS NOT NULL THEN



    IF rec_Sec.FK_SECTYPE = Cst_SecType_Commodity THEN --Commodity 25994.4

	--Obtener el Commodity Contract de la Security

	"PGT_CFM".Pkg_EMIRGTRUtility.p_GetCommContract( rec_Sec.Pk, --IN

				rec_CommContract --OUT

			      );

	--Obtener el Product del Commodity Contract

	"PGT_CFM".Pkg_EMIRGTRUtility.p_LoadCommodityProduct(rec_CommContract.FK_PRODUCT,

				rec_Product);

    ELSE

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Procedure, 9, Cst_General_ErrorType, 'Error: Security is not a Commodity' );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;



    END IF;



    END IF;



    IF rec_Product.Pk IS NOT NULL THEN



    IF rec_Product.FK_TYPE = Cst_CommProdType_MetalPrec THEN --Metals, Precious 45.4

	str_Out := 'Commodity:Metals:Precious:Swap:Cash';

    ELSIF rec_Product.FK_TYPE = Cst_CommProdType_MetalBase THEN --Metals, Base 44.4

	str_Out := 'Commodity:Metals:NonPrecious:Swap:Cash';

    ELSIF rec_Product.FK_TYPE IN (Cst_CommProdType_Oil, --Oil 46.4

		      Cst_CommProdType_OilCrude, --Oil, Crude 47.4

		      Cst_CommProdType_OilRefFuel, --Oil, Ref, Fuel 48.4

		      Cst_CommProdType_OilRefGasoil, --Oil, Ref, Gasoil 49.4

		      Cst_CommProdType_GasolRBOB--Gasoline RBOB 43.4

		     ) THEN

	str_Out := 'Commodity:Energy:Oil:Swap:Cash';

    ELSIF rec_Product.FK_TYPE = Cst_CommProdType_Gas THEN --Gas 26.4

	str_Out := 'Commodity:Energy:NatGas:Swap:Cash';

    ELSIF rec_Product.FK_TYPE = Cst_CommProdType_Coal THEN --Coal 27.4

	str_Out := 'Commodity:Energy:Coal:Swap:Cash';

    ELSIF rec_Product.FK_TYPE = Cst_CommProdType_Electricity THEN --Electricity 23.4

	str_Out := 'Commodity:Energy:Elec:Swap:Cash';

    ELSIF rec_Product.FK_TYPE = Cst_CommProdType_Emissions THEN --Emissions 24.4

	str_Out := 'Commodity:Energy:InterEnergy:Swap:Cash';

    END IF;



    END IF;



    p_CoPk := str_Out;



    -- Cerramos las trazas

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Procedure,NULL,'End ' || Cst_Procedure || '-> Out='||p_CoPk);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    p_CoPk := NULL;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Procedure,NULL,'End ' || Cst_Package||Cst_Procedure || ' (NoDataFound) Out - p_CoPk=' || p_CoPk);

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Procedure,NULL,' ERROR (' || Cst_Package||Cst_Procedure || ' ): ' || sqlerrm);

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Procedure, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetCommEQSwapProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_GetFirstIntSchd			  */

/* <Author>  MCASAS				  */

/* <Date>    19-12-2012 			  */

/* <Parameters>  Input: Int Rate Pk (Number), Output: First Int Schedule (Record) */

/* <Description> (28846.7) - Procedure that returns the First Int Schedule of the */

/*^		 Int Rate passed as parameter		  */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetFirstIntSchd ( p_num_IR	    IN	  NUMBER,

		  p_rec_IntSchd IN OUT "PGT_TRD".T_PGT_INTRATE_SCHEDULE_S%ROWTYPE )

IS

    Cst_Module	CONSTANT CHAR(30) := 'p_GetFirstIntSchd';



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - p_num_IR=' || p_num_IR);



    IF NOT "PGT_CFM".Pkg_EMIRGTRUtility.f_LoadFirstSchd( p_num_IR,

			     p_rec_IntSchd) -- OUT

    THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'ERROR loading first IR Schd: '||': '||SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END IF;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - p_rec_IntSchd.PK=' || p_rec_IntSchd.PK);



EXCEPTION

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetFirstIntSchd;



/* ********************************************************************************/

/* <Function>	 f_IsBasketSecurity			  */

/* <Author>  MCASAS				  */

/* <Date>    19-12-2012 			  */

/* <Parameters>  Input: Security Type (Number), Output: TRUE / FALSE (Boolean)	  */

/* <Description> (28846.7) - Returns TRUE if the security is Basket and FALSE if  */

/*		 it is not.			  */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

FUNCTION f_IsBasketSecurity ( p_num_SecType IN NUMBER ) RETURN BOOLEAN

IS



    Cst_Module	CONSTANT CHAR(30) := 'f_IsBasketSecurity';



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - p_num_SecType=' || p_num_SecType);



    IF p_num_SecType IN ( Cst_SecType_BasketCurrencyPair,

	      Cst_SecType_BasketEquity,

	      Cst_SecType_BasketFixedIncome,

	      Cst_SecType_BasketIndexEquity,

	      Cst_SecType_BasketIdxFixIncome ) THEN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' RETURN TRUE - Out -> p_num_SecType=' || p_num_SecType);

    RETURN TRUE; --la Security es Basket



    ELSE



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' RETURN TRUE - Out -> p_num_SecType=' || p_num_SecType);

    RETURN FALSE; --la Security no es Basket



    END IF;



END f_IsBasketSecurity;



/* ********************************************************************************/

/* <Procedure>	 p_GetEquityStrProductValue		      */

/* <Author>  MNA				  */

/* <Date>    07-05-2013 			  */

/* <Parameters>  Input: Event Pk (Number), Output: UPI Value (Varchar2)       */

/* <Description> (28846.7) - Calcutate the Product Value for EQUITY STRUCTURED.   */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* <Mod> 9.4  29-06-2020 - JROJAS  32732.70  New logic for equity iption       */

/* <Mod> 9.4  17-07-2020 - JROJAS  32732.70  New logic for equity iption,      */

/*  otceq no longer structured				  */

/* ********************************************************************************/

PROCEDURE p_GetEquityStrProductValue ( p_CoPk IN OUT NOCOPY VARCHAR2 )

IS

    Cst_Module	    CONSTANT CHAR(30) := 'p_GetEquityStrProductValue';



    num_PkHeader    NUMBER;

    num_PKEvent     NUMBER;



    num_Instrument  NUMBER;

    num_InstrumType NUMBER;

    num_StructInd   NUMBER;

    num_IsOTCEQ     NUMBER;



    rec_OTC	"PGT_TRD".T_PGT_OTC_OPTION_S%ROWTYPE;

    rec_EqSwp	    "PGT_CFM".Pkg_EMIRGTREquityProc.Tab_EqSwp;

    rec_QuoteRef    "PGT_CFM".Pkg_EMIRGTRUtility.Tab_QuoteRef;

    rec_Sec	"PGT_CFM".Pkg_EMIRGTRUtility.Tab_Security;

    rec_IntRate     "PGT_TRD".T_PGT_INTRATE_S%ROWTYPE;

    rec_IntSchd     "PGT_TRD".T_PGT_INTRATE_SCHEDULE_S%ROWTYPE;



    num_QuoteType   NUMBER;

    num_QuoteRef    NUMBER;



    num_ExtensionIR NUMBER;



    boo_NominalInterest BOOLEAN;

    boo_BasketSecurity	BOOLEAN;

    boo_IsVarianceSwap	BOOLEAN;



    str_Out	VARCHAR2(100);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - p_CoPk=' || p_CoPk);



    num_PKEvent := p_CoPk;



    --Obtenemos el Instrument

    BEGIN

    SELECT EV.FK_INSTRUMENT, NVL (EV.FK_SOURCEEVENT, EV.PK)

      INTO num_Instrument, num_PKEvent

      FROM "PGT_TRD".T_PGT_TRADE_EVENTS_S EV

     WHERE EV.PK = num_PkEvent;



    EXCEPTION

    WHEN NO_DATA_FOUND THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'Error loading Event Data: No data found' );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    WHEN OTHERS THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'Error loading Event Data: ' || SQLERRM );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;



    -- Obtener los datos del Header

    BEGIN

    SELECT HE.PK, HE.FK_INSTRUMTYPE, HE.STRUCTIND

      INTO num_PKHeader, num_InstrumType, num_StructInd

      FROM "PGT_TRD".T_PGT_TRADE_HEADER_S HE

     WHERE HE.FK_OWNER_OBJ = CST_EVENT_OW_HEADER

       AND HE.FK_EXTENSION = CST_EVENT_EX_HEADER

       AND HE.FK_PARENT = num_PKEvent;



    EXCEPTION

    WHEN NO_DATA_FOUND THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'Error loading Header Data: No data found' );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    WHEN OTHERS THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'Error loading Header Data: ' || SQLERRM );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;



    IF num_Instrument = Cst_Instrument_EQSWP THEN --20334.4



    -- Obtener los datos del Equity Swap

    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadEqSwpFromHd( num_PkHeader, --IN

			    rec_EqSwp); -- OUT



    /**************************************/

    /* NOMINAL, INTERES CALCULADO	  */

    /**************************************/

    --Comparar el Nominal y los intereses del primer flujo de intereses:

	-- Si Direccion=Borrower => datos de la pata Asset.

	-- Si Direccion=Loan => datos de la pata Liab.

	-- Si Direccion=Both => no esta definido (asi que cojo la pata Asset).

    boo_NominalInterest := FALSE;

    IF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Borrower THEN --184.4 - Borrower

	--Datos de la pata Asset

	num_ExtensionIR := Cst_Ext_EqSwp_AssetIR;

    ELSIF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Loan THEN --183.4 - Loan

	--Datos de la pata Liab

	num_ExtensionIR := Cst_Ext_EqSwp_LiabIR;

    ELSIF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Both THEN --25703.4 - Both

	--Datos de la pata Asset

	num_ExtensionIR := Cst_Ext_EqSwp_AssetEquity;

    END IF;

    --Obtener el IR

    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadIntrate ( num_ExtensionIR, --FK_EXTENSION

			     Cst_Obj_EquitySwap, --FK_OWNER_OBJ

			     rec_EqSwp.PK, --FK_PARENT

			     rec_IntRate --OUT

			   );

    --Obtener los datos del primer flujo del IR

    p_GetFirstIntSchd( rec_IntRate.PK,

	       rec_IntSchd); -- OUT



    IF NVL(rec_IntSchd.NOMINAL,0) = NVL(rec_IntSchd.INTCALCAMOUNT,0) THEN

	boo_NominalInterest := TRUE; --el nominal es igual a los intereses calculados

    ELSE

	boo_NominalInterest := FALSE; --el nominal es distinto de los intereses calculados

    END IF;



    /**************************************/

    /* QUOTE REFERENCE Y SECURITY	  */

    /**************************************/

    IF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Loan THEN --183.4 - Loan

	num_QuoteType	:= rec_EqSwp.FK_QUOTETYPE_A;

	num_QuoteRef	:= rec_EqSwp.FK_QUOTEREFERENCE_A;



    ELSIF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Borrower THEN --184.4 - Borrower

	num_QuoteType	:= rec_EqSwp.FK_QUOTETYPE_L;

	num_QuoteRef	:= rec_EqSwp.FK_QUOTEREFERENCE_L;



    ELSIF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Both THEN --25703.4 - Both

	--Si las dos son del mismo tipo -> coger los datos de la pata Asset (criterio inventado a falta de confirmacion)

	--Si una de las dos es una security -> tomar datos de la Security (criterio inventado a falta de confirmacion)

	IF rec_EqSwp.FK_QUOTETYPE_A = rec_EqSwp.FK_QUOTETYPE_L THEN

	num_QuoteType	:= rec_EqSwp.FK_QUOTETYPE_A;

	num_QuoteRef	:= rec_EqSwp.FK_QUOTEREFERENCE_A;

	ELSE

	IF rec_EqSwp.FK_QUOTETYPE_A = Cst_QuoteType_Securities THEN --20761.4

	    num_QuoteType   := rec_EqSwp.FK_QUOTETYPE_A;

	    num_QuoteRef    := rec_EqSwp.FK_QUOTEREFERENCE_A;

	ELSIF rec_EqSwp.FK_QUOTETYPE_L = Cst_QuoteType_Securities THEN --20761.4

	    num_QuoteType   := rec_EqSwp.FK_QUOTETYPE_L;

	    num_QuoteRef    := rec_EqSwp.FK_QUOTEREFERENCE_L;

	END IF;

	END IF;



    END IF;



    IF num_QuoteRef IS NOT NULL THEN

	--Obtener datos de la Quote Reference

	"PGT_CFM".Pkg_EMIRGTRUtility.p_LoadQuoteRef(   num_QuoteRef, --IN

			       rec_QuoteRef); --OUT



	IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities THEN --20761.4

	"PGT_CFM".Pkg_EMIRGTRUtility.p_LoadSecurity(rec_QuoteRef.FK_QUOTEINSTRUMENT, --IN

				rec_Sec); --OUT



	END IF;



    END IF;





    /****************************************/

    /* BASKET SECURITY		*/

    /****************************************/

    boo_BasketSecurity	:= FALSE;

    boo_BasketSecurity	:= f_IsBasketSecurity(rec_Sec.FK_SECTYPE);



    /****************************************/

    /* PRODUCT VALUE		*/

    /****************************************/

    IF num_InstrumType = Cst_InstType_EqSwp_Standard AND

       rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

       boo_BasketSecurity AND

       num_StructInd = Cst_No AND

       boo_NominalInterest  THEN



	str_Out := 'Equity:Swap:ParameterReturnDividend:Basket';



    --MNA(28/05/2013)

    ELSIF num_InstrumType = Cst_InstType_EqSwp_Standard AND

       num_StructInd = Cst_Yes THEN



	str_Out := 'Equity:Other';



    --El resto de casos son Instrument Type que no son Structured Product Template

    ELSE



       str_Out := NULL;



    END IF;



    ELSIF num_Instrument = Cst_Instrument_OTC THEN --20111.4



    -- Obtener los datos de la OTC

    BEGIN

	SELECT OTC.*

	  INTO rec_OTC

	  FROM "PGT_TRD".T_PGT_OTC_OPTION_S OTC

	 WHERE OTC.FK_PARENT	= num_PkHeader

	   AND OTC.FK_OWNER_OBJ = Cst_Owner_OTC --1476.4

	   AND OTC.FK_EXTENSION = Cst_Ext_THeaderOTC; --32361.4



    EXCEPTION

	WHEN NO_DATA_FOUND THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'Error loading OTC: No data found' );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

	WHEN OTHERS THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'Error loading OTC: ' || SQLERRM );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;



    --Se comprueba si la OTC es de tipo Equity

    IF rec_OTC.FK_UNDERLYINGTYPE = Cst_UnderLyingType_Market THEN --22991.4



	IF rec_OTC.FK_QUOTETYPE = Cst_QuoteType_Indexes THEN --20762.4



	num_IsOTCEQ := Cst_Yes; --1



	ELSIF rec_OTC.FK_QUOTETYPE = Cst_QuoteType_Securities THEN --20761.4



	IF rec_OTC.FK_QUOTEREFERENCE IS NOT NULL THEN

	    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadQuoteRef(rec_OTC.FK_QUOTEREFERENCE, --IN

				   rec_QuoteRef); --OUT

	    --Recuperar datos de la Security

	    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadSecurity(rec_QuoteRef.FK_QUOTEINSTRUMENT, --IN

				   rec_Sec);--OUT

	    IF rec_Sec.FK_SECTYPE IN (Cst_SecType_Equity, --30.4

			  Cst_SecType_BasketEquity, --20558.4

			  Cst_SecType_BasketIndexEquity --25378.4

			  ) THEN

	    num_IsOTCEQ := Cst_Yes; --1



	    END IF;



	   END IF;



	END IF;



    END IF;



    IF num_IsOTCEQ = Cst_Yes THEN --1







	--Ver si la OTC tiene FlexType=VarianceSwap (Pdte de definir de forma exacta)

	boo_IsVarianceSwap  := FALSE;

	IF rec_OTC.FK_OPTIONTYPE = Cst_OptionType_Flex AND --22417.4

	   rec_OTC.FLEXOPTIONTYPE IN ('Variance Swap', 'VarianceSwap') THEN

	boo_IsVarianceSwap  := TRUE;

	END IF;



	--Obtener datos de la Quote Reference

	boo_BasketSecurity := FALSE;

	"PGT_CFM".Pkg_EMIRGTRUtility.p_LoadQuoteRef(   rec_OTC.FK_QUOTEREFERENCE, --IN

			       rec_QuoteRef); --OUT



	IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities THEN --20761.4

	--Cargar datos de la Security

	"PGT_CFM".Pkg_EMIRGTRUtility.p_LoadSecurity(rec_QuoteRef.FK_QUOTEINSTRUMENT, --IN

				rec_Sec); --OUT

	--Ver si la Security es de tipo Basket

	boo_BasketSecurity := f_IsBasketSecurity(rec_Sec.FK_SECTYPE);



	END IF;

	 --START - 23-07-2020 - JROJAS - 32732.70

	 str_Out := 'Equity:Option:'; -- always if it is an equity option



	IF boo_IsVarianceSwap THEN



	str_Out := str_out||'ParameterReturnVariance:'; --always if it is variance swap



	IF rec_QuoteRef.FK_QUOTETYPE = "PGT_CFM".Pkg_DTCCGTRConstant.Cst_QuoteType_Securities AND

	    boo_BasketSecurity THEN



	      str_Out := str_out||'Basket';



	ELSIF rec_QuoteRef.FK_QUOTETYPE = "PGT_CFM".Pkg_DTCCGTRConstant.Cst_QuoteType_Securities AND

	  NOT  boo_BasketSecurity THEN



	      str_Out := str_out||'SingleName';



	ELSIF rec_QuoteRef.FK_QUOTETYPE = "PGT_CFM".Pkg_DTCCGTRConstant.Cst_QuoteType_Indexes THEN



	     str_Out := str_out||'SingleIndex';



	ELSE



	     str_Out := '';



	END IF;

	ELSE --not variance

	  str_Out := str_out||'PriceReturnBasicPerformance:';



	   IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

	   boo_BasketSecurity THEN



	      str_Out := str_out||'Basket';

	   ELSE



	   str_Out := '';



	   END IF;



	END IF;

	 --END - 23-07-2020 - JROJAS - 32732.70



      /*

	IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

	boo_BasketSecurity AND

	rec_OTC.FK_OPTIONTYPE = Cst_OptionType_PlainVanilla THEN



	str_Out := 'Equity:Option:PriceReturnBasicPerformance:Basket';



	ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

	NOT boo_BasketSecurity AND

	boo_IsVarianceSwap THEN



	str_Out := 'Equity:Option:ParameterReturnVariance:SingleName';



	ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Indexes AND

	boo_IsVarianceSwap THEN



	str_Out := 'Equity:Option:ParameterReturnVariance:SingleIndex';



	ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

	boo_BasketSecurity AND

	boo_IsVarianceSwap THEN



	str_Out := 'Equity:Option:ParameterReturnVariance:Basket';



	--GBO_8.5 TASK 24945.7	-- triple condicion (HDECAMPOS)

	ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

	rec_Sec.FK_SECTYPE =Cst_SecType_Equity AND

	num_StructInd = Cst_YES THEN



	str_Out := 'Equity:Other';



	--GBO_8.5 TASK 24945.7	-- condicion para los indices(HDECAMPOS)

	ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Indexes AND

	num_StructInd = Cst_YES THEN



	str_Out := 'Equity:Other';



	--MNA(28/05/2013)

	ELSIF rec_OTC.FK_OPTIONTYPE = Cst_OptionType_Flex AND NOT boo_IsVarianceSwap

	   OR rec_OTC.FK_OPTIONTYPE IN (Cst_OptionType_Asian, --22413.4

			Cst_OptionType_Barrier, --22412.4

			Cst_OptionType_Ladder, --22416.4

			Cst_OptionType_LookBack, --22415.4

			Cst_OptionType_Ratchet) THEN --22414.4



	str_Out := 'Equity:Other';



	ELSE



	str_Out := NULL;



	END IF;

    */



    ELSE



	str_Out := NULL;



    END IF; --Is EQOTC



    ELSE



    str_Out := NULL;



    END IF; --INSTRUMENT



    p_CoPk := str_Out;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - p_CoPk=' || p_CoPk);



    EXCEPTION

    WHEN NO_DATA_FOUND THEN

	p_CoPk := NULL;

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - p_CoPk=' || p_CoPk);



    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

	RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

	RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

	RAISE;

    WHEN OTHERS THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetEquityStrProductValue;



/* **********************************************************************************/

/* <Procedure>	 p_IsEqStrProdTemp			    */

/* <Author>  MNA				    */

/* <Date>    07-05-2013 			    */

/* <Parameters>  Input: Event Pk (Number), Output: 1 - Equity Structured Product    */

/*			       Template (Number)	*/

/*			   0 - Not Equity Structured Product*/

/*			       Template (Number)	*/

/* <Description> (28846.7) - Check if the registry event is an Equity Structured    */

/*		 Product Template.			*/

/* -------------------------------------------------------------------------------- */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	     */

/* **********************************************************************************/

PROCEDURE p_IsEqStrProdTemp ( par_PK	       IN NUMBER,

		  par_OperType	   IN NUMBER,

		  par_ConfigDealPK IN NUMBER,

		  par_result	   OUT NUMBER )

IS



    Cst_Module	    CONSTANT CHAR(17) := 'p_IsEqStrProdTemp';



    num_PkEvent     NUMBER;



    str_InOut	    VARCHAR2(200);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - par_PK=' || par_PK ||';'||

						  'par_OperType='||par_OperType||';'||

						  'par_ConfigDealPK='||par_ConfigDealPK

						);



    par_result	   := 0;



    num_PkEvent := par_PK;



    str_InOut	:= num_PkEvent;



    --Comprobar si esta operacion corresponde a algun ProductValue de Equities Structured Product Template.

    p_GetEquityStrProductValue (str_InOut);



    --Si la operacion corresponde a algun ProductValue de Equities Structured Product Template => Devuelve 1

    IF str_InOut IS NOT NULL THEN

    par_result	:= 1;

    END IF;



    num_GlobalExclude := par_result; /* STW 12-12-2012 */



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - par_result=' || par_result);



EXCEPTION

    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

     RAISE;

    WHEN "PGT_PRG".Pkg_PgtError.PACKAGE_DISCARDED THEN

     RAISE;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

     RAISE;

    WHEN OTHERS THEN

     "PGT_PRG".PKG_PGTERROR.p_PutErrorParcial ( Cst_Error_Others, Cst_Module, 9, 'Error p_IsEqStrProdTemp: '||SQLERRM);

     "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,' ERROR (' || Cst_Package||Cst_Module || ' ): ' || sqlerrm);

     RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_IsEqStrProdTemp;



/* ********************************************************************************/

/* <Procedure>	 p_GetEQSwapProductValue		      */

/* <Author>  MCASAS				  */

/* <Date>    10-12-2012 			  */

/* <Parameters>  Input: Header Pk (Number), Output: UPI Value (Varchar2)      */

/* <Description> (28846.7) - Calcutate the Product Value for EQUITY SWAP.     */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetEQSwapProductValue ( p_CoPk IN OUT NOCOPY VARCHAR2 )

IS

    Cst_Module	    CONSTANT CHAR(30) := 'p_GetEQSwapProductValue';



    num_PkHeader    NUMBER;



    num_InstrumType NUMBER;

    num_StructInd   NUMBER;



    rec_EqSwp	    "PGT_CFM".Pkg_EMIRGTREquityProc.Tab_EqSwp;

    rec_QuoteRef    "PGT_CFM".Pkg_EMIRGTRUtility.Tab_QuoteRef;

    rec_Sec	"PGT_CFM".Pkg_EMIRGTRUtility.Tab_Security;

    rec_IntRate     "PGT_TRD".T_PGT_INTRATE_S%ROWTYPE;

    rec_IntSchd     "PGT_TRD".T_PGT_INTRATE_SCHEDULE_S%ROWTYPE;



    num_QuoteType   NUMBER;

    num_QuoteRef    NUMBER;



    num_ExtensionIR NUMBER;



    boo_NominalInterest BOOLEAN;

    boo_BasketSecurity	BOOLEAN;



    str_Out	VARCHAR2(100);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - p_CoPk=' || p_CoPk);



    num_PkHeader := p_CoPk;



    -- Obtener los datos del Header

    BEGIN

    SELECT HE.FK_INSTRUMTYPE, HE.STRUCTIND

      INTO num_InstrumType, num_StructInd

      FROM "PGT_TRD".T_PGT_TRADE_HEADER_S HE

     WHERE HE.PK    = num_PkHeader;



    EXCEPTION

    WHEN NO_DATA_FOUND THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'Error loading Header Data: No data found' );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    WHEN OTHERS THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'Error loading Header Data: ' || SQLERRM );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;



    -- Obtener los datos del Equity Swap

    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadEqSwpFromHd( num_PkHeader, --IN

			    rec_EqSwp); -- OUT



    /**************************************/

    /* NOMINAL, INTERES CALCULADO     */

    /**************************************/

    --Comparar el Nominal y los intereses del primer flujo de intereses:

    -- Si Direccion=Borrower => datos de la pata Asset.

    -- Si Direccion=Loan => datos de la pata Liab.

    -- Si Direccion=Both => no esta definido (asi que cojo la pata Asset).

    boo_NominalInterest := FALSE;

    IF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Borrower THEN --184.4 - Borrower

    --Datos de la pata Asset

    num_ExtensionIR := Cst_Ext_EqSwp_AssetIR;

    ELSIF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Loan THEN --183.4 - Loan

    --Datos de la pata Liab

    num_ExtensionIR := Cst_Ext_EqSwp_LiabIR;

    ELSIF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Both THEN --25703.4 - Both

    --Datos de la pata Asset

    num_ExtensionIR := Cst_Ext_EqSwp_AssetEquity;

    END IF;

    --Obtener el IR

    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadIntrate ( num_ExtensionIR, --FK_EXTENSION

			 Cst_Obj_EquitySwap, --FK_OWNER_OBJ

			 rec_EqSwp.PK, --FK_PARENT

			 rec_IntRate --OUT

			   );

    --Obtener los datos del primer flujo del IR

    p_GetFirstIntSchd( rec_IntRate.PK,

	       rec_IntSchd); -- OUT



    IF NVL(rec_IntSchd.NOMINAL,0) = NVL(rec_IntSchd.INTCALCAMOUNT,0) THEN

    boo_NominalInterest := TRUE; --el nominal es igual a los intereses calculados

    ELSE

    boo_NominalInterest := FALSE; --el nominal es distinto de los intereses calculados

    END IF;



    /**************************************/

    /* QUOTE REFERENCE Y SECURITY     */

    /**************************************/

    IF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Loan THEN --183.4 - Loan

    num_QuoteType   := rec_EqSwp.FK_QUOTETYPE_A;

    num_QuoteRef    := rec_EqSwp.FK_QUOTEREFERENCE_A;



    ELSIF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Borrower THEN --184.4 - Borrower

    num_QuoteType   := rec_EqSwp.FK_QUOTETYPE_L;

    num_QuoteRef    := rec_EqSwp.FK_QUOTEREFERENCE_L;



    ELSIF rec_EqSwp.FK_EQUITYDIR = Cst_Direction_Both THEN --25703.4 - Both

    --Si las dos son del mismo tipo -> coger los datos de la pata Asset (criterio inventado a falta de confirmacion)

    --Si una de las dos es una security -> tomar datos de la Security (criterio inventado a falta de confirmacion)

    IF rec_EqSwp.FK_QUOTETYPE_A = rec_EqSwp.FK_QUOTETYPE_L THEN

	num_QuoteType	:= rec_EqSwp.FK_QUOTETYPE_A;

	num_QuoteRef	:= rec_EqSwp.FK_QUOTEREFERENCE_A;

    ELSE

	IF rec_EqSwp.FK_QUOTETYPE_A = Cst_QuoteType_Securities THEN --20761.4

	num_QuoteType	:= rec_EqSwp.FK_QUOTETYPE_A;

	num_QuoteRef	:= rec_EqSwp.FK_QUOTEREFERENCE_A;

	ELSIF rec_EqSwp.FK_QUOTETYPE_L = Cst_QuoteType_Securities THEN --20761.4

	num_QuoteType	:= rec_EqSwp.FK_QUOTETYPE_L;

	num_QuoteRef	:= rec_EqSwp.FK_QUOTEREFERENCE_L;

	END IF;

    END IF;



    END IF;



    IF num_QuoteRef IS NOT NULL THEN

    --Obtener datos de la Quote Reference

    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadQuoteRef(   num_QuoteRef, --IN

			       rec_QuoteRef); --OUT



    IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities THEN --20761.4

	"PGT_CFM".Pkg_EMIRGTRUtility.p_LoadSecurity(rec_QuoteRef.FK_QUOTEINSTRUMENT, --IN

			    rec_Sec); --OUT



    END IF;



    END IF;





    /****************************************/

    /* BASKET SECURITY		    */

    /****************************************/

    boo_BasketSecurity	:= FALSE;

    boo_BasketSecurity	:= f_IsBasketSecurity(rec_Sec.FK_SECTYPE);



    /****************************************/

    /* PRODUCT VALUE		    */

    /****************************************/

    IF num_InstrumType = Cst_InstType_EqSwp_Standard AND

       rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

       NOT boo_BasketSecurity AND

       num_StructInd = Cst_No AND

       NOT boo_NominalInterest	THEN



    str_Out := 'Equity:Swap:PriceReturnBasicPerformance:SingleName';



    ELSIF num_InstrumType = Cst_InstType_EqSwp_Standard AND

       rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Indexes AND

       num_StructInd = Cst_No AND

       NOT boo_NominalInterest	THEN



    str_Out := 'Equity:Swap:PriceReturnBasicPerformance:SingleIndex';



    ELSIF num_InstrumType = Cst_InstType_EqSwp_Standard AND

       rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

       boo_BasketSecurity AND

       num_StructInd = Cst_No AND

       NOT boo_NominalInterest	THEN



    str_Out := 'Equity:Swap:PriceReturnBasicPerformance:Basket';



    ELSIF num_InstrumType = Cst_InstType_EqSwp_Standard AND

       rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

       NOT boo_BasketSecurity AND

       num_StructInd = Cst_No AND

       boo_NominalInterest  THEN



    str_Out := 'Equity:Swap:ParameterReturnDividend:SingleName';



    ELSIF num_InstrumType = Cst_InstType_EqSwp_Standard AND

       rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Indexes AND

       num_StructInd = Cst_No AND

       boo_NominalInterest  THEN



    str_Out := 'Equity:Swap:ParameterReturnDividend:SingleIndex';



    ELSIF num_InstrumType = Cst_InstType_EqSwp_Standard AND

       rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

       boo_BasketSecurity AND

       num_StructInd = Cst_No AND

       boo_NominalInterest  THEN



    str_Out := 'Equity:Swap:ParameterReturnDividend:Basket';



    ELSIF num_InstrumType = Cst_InstType_EqSwp_Standard AND

       num_StructInd = Cst_Yes THEN



    str_Out := 'Equity:Other';



    --el resto de casos son Instrument Type que no existen en Global



    END IF;



    p_CoPk := str_Out;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - p_CoPk=' || p_CoPk);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    p_CoPk := NULL;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - p_CoPk=' || p_CoPk);



    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetEQSwapProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_IsOTCSWAPTION			  */

/* <Author>  MCASAS				  */

/* <Date>    11-12-2012 			  */

/* <Parameters>  Input: Event Pk (Number), Output: 1 - OTC Swaption (Number)	  */

/*			   0 - Not OTC Swaption (Number)  */

/* <Description> (28846.7) - Check if the registry event is an OTC Swaption.	  */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_IsOTCSWAPTION ( par_PK	 IN NUMBER,

		par_OperType	 IN NUMBER,

		par_ConfigDealPK IN NUMBER,

		par_result	 OUT NUMBER )

IS



    CST_MODULE	      CONSTANT CHAR(15) := 'p_IsOTCSWAPTION';

    num_FinUnderInstrum   NUMBER;

    num_OTCUnderly    NUMBER;



    num_PkRegistry    NUMBER;



    num_PkEvent       NUMBER;



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - par_PK=' || par_PK ||';'||

						  'par_OperType='||par_OperType||';'||

						  'par_ConfigDealPK='||par_ConfigDealPK

						);



    par_result	   := 0;



    num_PkEvent := par_PK;



    /* Obtenemos la pk del registry */

    num_PkRegistry := PGT_PRG.Pkg_Pgtutility.f_GetEventRegPK (num_PkEvent);



    BEGIN



       SELECT OTC.FK_UNDERLYINGTYPE, OTC.FK_FINUNDERINSTRUM

     INTO num_OTCUnderly, num_FinUnderInstrum

     FROM "PGT_TRD".T_PGT_TRADE_HEADER_S HDR,

	  "PGT_TRD".T_PGT_OTC_OPTION_S OTC

    WHERE HDR.PK	= num_PkRegistry

      AND HDR.FK_OWNER_OBJ  = Cst_Event_Ow_Header

      AND HDR.FK_EXTENSION  = Cst_Event_Ex_Header

      AND HDR.PK	= OTC.FK_PARENT

      AND OTC.FK_OWNER_OBJ  = Cst_Owner_OTC

      AND OTC.FK_EXTENSION  = Cst_Ext_THeaderOTC;



       --"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'  OTC_Underly: '||TO_CHAR(num_OTCUnderly));

       --"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'  Fin_Under_Instrum: '||TO_CHAR(num_FinUnderInstrum));



    EXCEPTION



    WHEN NO_DATA_FOUND THEN

	par_result     := 0;



    WHEN TOO_MANY_ROWS THEN

	RAISE;



    WHEN OTHERS THEN

	RAISE;



    END;



    IF ((num_OTCUnderly = Cst_UnderLyingType_Financial) AND

    (num_FinUnderInstrum = Cst_Instrument_Swap) )THEN



       --"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,' -- Es OTC Swap --');

       par_result     := 1;



    END IF;



    num_GlobalExclude := par_result; /* STW 12-12-2012 */



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - par_result=' || par_result);



EXCEPTION

    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

     RAISE;

    WHEN "PGT_PRG".Pkg_PgtError.PACKAGE_DISCARDED THEN

     RAISE;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

     RAISE;

    WHEN OTHERS THEN

     "PGT_PRG".PKG_PGTERROR.p_PutErrorParcial ( Cst_Error_Others, Cst_Module, 9, 'Error p_IsOTCSwaption: '||SQLERRM);

     "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,' ERROR (' || Cst_Package||Cst_Module || ' ): ' || sqlerrm);

     RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_IsOTCSWAPTION;



/* ********************************************************************************/

/* <Procedure>	 p_IsBondOption 			  */

/* <Author>  MNA				  */

/* <Date>    18-09-2013 			  */

/* <Parameters>  Input: Event Pk (Number), Output: 1 - Bond Option (Number)   */

/*			   0 - Not Bond Option (Number)   */

/* <Description> (28846.7) - Check if the registry event is a Bond Option.    */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_IsBondOption ( par_PK	IN NUMBER,

	       par_OperType	IN NUMBER,

	       par_ConfigDealPK IN NUMBER,

	       par_result	OUT NUMBER )

IS



    CST_MODULE	    CONSTANT CHAR(15) := 'p_IsBondOption';



    num_PkEvent     NUMBER;

    num_PkRegistry  NUMBER;

    num_GTRSubType  NUMBER;



    str_InOut	    VARCHAR2(200);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - par_PK=' || par_PK ||';'||

						  'par_OperType='||par_OperType||';'||

						  'par_ConfigDealPK='||par_ConfigDealPK

						);



    par_result := 0;



    num_PkEvent := par_PK;



    --Obtenemos la pk del registry

    num_PkRegistry := "PGT_PRG".Pkg_Pgtutility.f_GetEventRegPK (num_PkEvent);



    --LLamamos al procedimiento que calcula el Subtipo. Si el subtipo es 'Bond Option' se devuelve 1, si no, 0.

    "PGT_CFM".Pkg_DTCCGTRUtility.p_CalcGTRSubType (num_PkRegistry, num_GTRSubType);



    IF num_GTRSubType = Cst_GTROTCType_Bond THEN --30



    par_result	:= 1;



    END IF;



    num_GlobalExclude := par_result; /* STW 12-12-2012 */



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - par_result=' || par_result);



EXCEPTION

    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

     RAISE;

    WHEN "PGT_PRG".Pkg_PgtError.PACKAGE_DISCARDED THEN

     RAISE;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

     RAISE;

    WHEN OTHERS THEN

     "PGT_PRG".PKG_PGTERROR.p_PutErrorParcial ( Cst_Error_Others, Cst_Module, 9, 'Error p_IsEqSwpBase: '||SQLERRM);

     "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,' ERROR (' || Cst_Package||Cst_Module || ' ): ' || sqlerrm);

     RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_IsBondOption;



/* ********************************************************************************/

/* <Procedure>	 p_IsFXOption				  */

/* <Author>  MNA				  */

/* <Date>    03-04-2013 			  */

/* <Parameters>  Input: Event Pk (Number), Output: 1 - FX Option (Number)     */

/*			   0 - Not FX Option (Number)	  */

/* <Description> (28846.7) - Check if the registry event is a FX Option.      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_IsFXOption ( par_PK       IN NUMBER,

	     par_OperType     IN NUMBER,

	     par_ConfigDealPK IN NUMBER,

	     par_result   OUT NUMBER )

IS



    CST_MODULE	    CONSTANT CHAR(15) := 'p_IsFXOption';



    num_PkEvent     NUMBER;

    rec_Event	    "PGT_TRD".T_PGT_TRADE_EVENTS_S%ROWTYPE;



    str_InOut	    VARCHAR2(200);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - par_PK=' || par_PK ||';'||

						  'par_OperType='||par_OperType||';'||

						  'par_ConfigDealPK='||par_ConfigDealPK

						);



    par_result	   := 0;



    num_PkEvent := par_PK;



    -- Cargamos los datos del evento

    "PGT_PRG".pkg_eventgeneral.p_loadevent (num_PkEvent, Rec_Event);



    str_InOut	:= NVL(Rec_Event.FK_SOURCEEVENT, Rec_Event.PK);



    --Comprobar si esta operacion corresponde a algun ProductValue de FX.

    p_GetFXProductValue (str_InOut);

    --Si la operacion corresponde a algun ProductValue de Equities => es una Equity.

    IF str_InOut IS NOT NULL THEN

    par_result	:= 1;

    END IF;



    num_GlobalExclude := par_result; /* STW 12-12-2012 */



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - par_result=' || par_result);



EXCEPTION

    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

     RAISE;

    WHEN "PGT_PRG".Pkg_PgtError.PACKAGE_DISCARDED THEN

     RAISE;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

     RAISE;

    WHEN OTHERS THEN

     "PGT_PRG".PKG_PGTERROR.p_PutErrorParcial ( Cst_Error_Others, Cst_Module, 9, 'Error p_IsOTCEquity: '||SQLERRM);

     "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,' ERROR (' || Cst_Package||Cst_Module || ' ): ' || sqlerrm);

     RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_IsFXOption;



/* ********************************************************************************/

/* <Procedure>	 p_IsOTCEquity				  */

/* <Author>  MCASAS				  */

/* <Date>    14-12-2012 			  */

/* <Parameters>  Input: Event Pk (Number), Output: 1 - OTC Equity (Number)    */

/*			   0 - Not OTC Equity (Number)	  */

/* <Description> (28846.7) - Check if the registry event is an OTC Equity.    */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_IsOTCEquity ( par_PK       IN NUMBER,

	      par_OperType     IN NUMBER,

	      par_ConfigDealPK IN NUMBER,

	      par_result       OUT NUMBER )

IS



    CST_MODULE	      CONSTANT CHAR(15) := 'p_IsOTCEquity';



    num_QuoteType     NUMBER;

    num_UnderlyingType	  NUMBER;

    num_QuoteRef      NUMBER;

    num_OptionType    NUMBER;



    num_PkEvent       NUMBER;

    num_PkRegistry    NUMBER;



    rec_QuoteRef      "PGT_MRK".T_PGT_QUOTE_REFERENCE_S%ROWTYPE;

    rec_Security      "PGT_STC".PGT_SECURITY%ROWTYPE;



BEGIN



    -- Una OTC Equity es una OTC con:

    --	  Underl Class=Market Underlying y

    --	      Underl Type=Indexes o

    --	      Underl Type=Securities y Underlying/Security/Security Type=Equity,Basket-Equity,Basket-Index(Equity).



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - par_PK=' || par_PK ||';'||

						  'par_OperType='||par_OperType||';'||

						  'par_ConfigDealPK='||par_ConfigDealPK

						);



    par_result	   := 0;



    num_PkEvent := par_PK;



    /* Obtenemos la pk del registry */

    num_PkRegistry := PGT_PRG.Pkg_Pgtutility.f_GetEventRegPK (num_PkEvent);



    BEGIN



       SELECT OTC.FK_UNDERLYINGTYPE, OTC.FK_QUOTETYPE,

	  OTC.FK_QUOTEREFERENCE, OTC.FK_OPTIONTYPE

     INTO num_UnderlyingType, num_QuoteType,

	  num_QuoteRef, num_OptionType

     FROM "PGT_TRD".T_PGT_TRADE_HEADER_S HDR,

	  "PGT_TRD".T_PGT_OTC_OPTION_S OTC

    WHERE HDR.PK	= num_PkRegistry

      AND HDR.FK_OWNER_OBJ  = Cst_Event_Ow_Header

      AND HDR.FK_EXTENSION  = Cst_Event_Ex_Header

      AND HDR.PK	= OTC.FK_PARENT

      AND OTC.FK_OWNER_OBJ  = Cst_Owner_OTC

      AND OTC.FK_EXTENSION  = Cst_Ext_THeaderOTC;



       --"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'  OTC_Underly: '||TO_CHAR(num_OTCUnderly));

       --"PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_module,NULL,'  Fin_Under_Instrum: '||TO_CHAR(num_FinUnderInstrum));



    EXCEPTION



    WHEN NO_DATA_FOUND THEN

	par_result     := 0;



    WHEN TOO_MANY_ROWS THEN

	RAISE;



    WHEN OTHERS THEN

	RAISE;



    END;



    IF num_UnderlyingType = Cst_UnderLyingType_Market THEN



    IF num_QuoteType = Cst_QuoteType_Indexes THEN

	par_result     := 1;



    ELSIF num_QuoteType = Cst_QuoteType_Securities THEN



	IF num_QuoteRef IS NOT NULL THEN

	"PGT_CFM".Pkg_DTCCGTRUtility.p_LoadQuoteRef(num_QuoteRef, --IN

			       rec_QuoteRef); --OUT

	--Recuperar datos de la Security

	"PGT_CFM".Pkg_DTCCGTRUtility.p_LoadSecurity(rec_QuoteRef.FK_QUOTEINSTRUMENT, --IN

			       rec_Security);--OUT

	IF rec_Security.FK_SECTYPE IN (Cst_SecType_Equity,

			   Cst_SecType_BasketEquity,

			   Cst_SecType_BasketIndexEquity

			  ) THEN

	    par_result	   := 1;

	END IF;



       END IF;



    END IF;



    END IF;



    num_GlobalExclude := par_result; /* STW 12-12-2012 */



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - par_result=' || par_result);



EXCEPTION

    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

     RAISE;

    WHEN "PGT_PRG".Pkg_PgtError.PACKAGE_DISCARDED THEN

     RAISE;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

     RAISE;

    WHEN OTHERS THEN

     "PGT_PRG".PKG_PGTERROR.p_PutErrorParcial ( Cst_Error_Others, Cst_Module, 9, 'Error p_IsOTCEquity: '||SQLERRM);

     "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,' ERROR (' || Cst_Package||Cst_Module || ' ): ' || sqlerrm);

     RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_IsOTCEquity;



/* ********************************************************************************/

/* <Procedure>	 p_GetLiveExercise			  */

/* <Author>  MNA				  */

/* <Date>    27-11-2012 			  */

/* <Parameters>  Input: OTC Option Pk (Number), Output: Live Exercise (Record)	  */

/* <Description> (28846.7) - Procedure that returns the Live Exercise of an OTC   */

/*		 Option.			   */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetLiveExercise ( p_PKOTC IN NUMBER, p_RecOTCSchd OUT "PGT_TRD".T_PGT_OTC_SCHEDULE_S%ROWTYPE )

IS



    Cst_Module	     VARCHAR2(17) := 'p_GetLiveExercise';

    dte_Reference    DATE;



    dat_Mat	 DATE;



    dat_Min	 DATE;

    dat_Max	 DATE;



    boo_OTCSchd_NotFound BOOLEAN := FALSE;



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package || Cst_Module || ' Param - p_PKOTC=' || p_PKOTC);



    dte_Reference   := TRUNC(SYSDATE);



--    BEGIN

--    SELECT SCHD.*

--	INTO p_RecOTCSchd

--	FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

--     WHERE SCHD.FK_PARENT	  = p_PKOTC

--	 AND SCHD.FK_OWNER_OBJ	  = Cst_Owner_OTCSchd -- 12188.4

--	 AND SCHD.FK_EXTENSION	  = Cst_Ext_OTC_OTCSchd -- 32384.4

--	 AND SCHD.FK_REVREASON IS NULL;

--    EXCEPTION

--    WHEN TOO_MANY_ROWS THEN

--

--	  BEGIN

--

--	  SELECT SCHD.*

--	INTO p_RecOTCSchd

--	FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

--	   WHERE SCHD.FK_PARENT   = p_PKOTC

--	 AND SCHD.FK_OWNER_OBJ	  = Cst_Owner_OTCSchd -- 12188.4

--	 AND SCHD.FK_EXTENSION	  = Cst_Ext_OTC_OTCSchd -- 32384.4

--	 AND SCHD.STARTDATE < dte_Reference

--	 AND SCHD.ENDDATE  >= dte_Reference

--	 AND SCHD.FK_REVREASON IS NULL;

--

--	  EXCEPTION --MNA(10/04/2013)

--	      WHEN NO_DATA_FOUND THEN

--	      BEGIN

--		  SELECT SCHD.*

--		INTO p_RecOTCSchd

--		FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

--		   WHERE SCHD.FK_PARENT   = p_PKOTC

--		 AND SCHD.FK_OWNER_OBJ	  = Cst_Owner_OTCSchd -- 12188.4

--		 AND SCHD.FK_EXTENSION	  = Cst_Ext_OTC_OTCSchd -- 32384.4

--		 AND SCHD.STARTDATE <= dte_Reference

--		 AND SCHD.ENDDATE  > dte_Reference

--		 AND SCHD.FK_REVREASON IS NULL;

--	      -- JCASAS (19/12/2013): Para fechas posteriores a MatDate => Coger el ultimo Exercise

--	      EXCEPTION

--		  WHEN NO_DATA_FOUND THEN

--		  -- Obtener la MatDate

--		  SELECT MATURITY

--		    INTO dat_Mat

--		    FROM PGT_TRD.T_PGT_OTC_OPTION_S

--		   WHERE PK = p_PKOTC;

--		  IF dte_Reference > dat_Mat THEN

--		      -- El ultimo exercise es el vivo a MaturityDate

--		      SELECT SCHD.*

--		    INTO p_RecOTCSchd

--		    FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

--		       WHERE SCHD.FK_PARENT   = p_PKOTC

--		     AND SCHD.FK_OWNER_OBJ    = Cst_Owner_OTCSchd -- 12188.4

--		     AND SCHD.FK_EXTENSION    = Cst_Ext_OTC_OTCSchd -- 32384.4

--		     AND SCHD.STARTDATE < dat_Mat

--		     AND SCHD.ENDDATE  >= dat_Mat

--		     AND SCHD.FK_REVREASON IS NULL;

--		  END IF;

--	      END;

--	      -- Fin JCASAS (19/12/2013)

--	  END;

--

--    END;



    /**********************************************************************************/

    /* GMC: 05/06/2014 --> Nuevo tratamiendo para el Calculo del Flujo Vivo de un OTC */

    /*		   Lo hacemos igual que Pkg_EMIRGTROTCEqProc.p_GetLiveOTCSchd */

    /**********************************************************************************/

    BEGIN



    SELECT SCHD.*

      INTO p_RecOTCSchd

      FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

     WHERE SCHD.FK_PARENT	= p_PKOTC

       AND SCHD.FK_OWNER_OBJ	= Cst_Owner_OTCSchd -- 12188.4

       AND SCHD.FK_EXTENSION	= Cst_Ext_OTC_OTCSchd -- 32384.4

       AND SCHD.FK_REVREASON IS NULL;



    EXCEPTION

    WHEN TOO_MANY_ROWS THEN



	BEGIN

	-- Buscar el flujo vivo

	SELECT SCHD.*

	  INTO p_RecOTCSchd

	  FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

	 WHERE SCHD.FK_PARENT	    = p_PKOTC

	   AND SCHD.FK_OWNER_OBJ    = Cst_Owner_OTCSchd -- 12188.4

	   AND SCHD.FK_EXTENSION    = Cst_Ext_OTC_OTCSchd -- 32384.4

	   AND SCHD.STARTDATE <= dte_Reference

	   AND SCHD.ENDDATE  >= dte_Reference

	   AND SCHD.FK_REVREASON IS NULL;

	EXCEPTION

	WHEN NO_DATA_FOUND THEN

	    boo_OTCSchd_NotFound := TRUE;



	-- Si hay varios, coger el de mayor secuencia entre ellos

	WHEN TOO_MANY_ROWS THEN



	    SELECT SCHD.*

	      INTO p_RecOTCSchd

	      FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

	     WHERE SCHD.FK_PARENT   = p_PKOTC

	       AND SCHD.FK_OWNER_OBJ	= Cst_Owner_OTCSchd -- 12188.4

	       AND SCHD.FK_EXTENSION	= Cst_Ext_OTC_OTCSchd -- 32384.4

	       AND SCHD.FK_REVREASON IS NULL

	       AND SCHD.SEQUENCE = (SELECT MAX(SCHD.SEQUENCE)

			  FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

			 WHERE SCHD.FK_PARENT	= p_PKOTC

			   AND SCHD.FK_OWNER_OBJ    = Cst_Owner_OTCSchd -- 12188.4

			   AND SCHD.FK_EXTENSION    = Cst_Ext_OTC_OTCSchd -- 32384.4

			   AND SCHD.STARTDATE <= dte_Reference

			   AND SCHD.ENDDATE  >= dte_Reference

			   AND SCHD.FK_REVREASON IS NULL);

	END;



    END;



    IF boo_OTCSchd_NotFound THEN -- No se ha encontrado ningun flujo vivo



    -- Miramos en que fechas empieza y termina el schedule

    SELECT MIN(SCHD.STARTDATE), MAX(SCHD.ENDDATE)

      INTO dat_Min, dat_Max

      FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

     WHERE SCHD.FK_PARENT	= p_PKOTC

       AND SCHD.FK_OWNER_OBJ	= Cst_Owner_OTCSchd -- 12188.4

       AND SCHD.FK_EXTENSION	= Cst_Ext_OTC_OTCSchd -- 32384.4

       AND SCHD.FK_REVREASON IS NULL;



    IF dte_Reference > dat_Max THEN



	-- Tomamos como flujo vivo el ultimo

	SELECT SCHD.*

	  INTO p_RecOTCSchd

	  FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

	 WHERE SCHD.FK_PARENT	= p_PKOTC

	   AND SCHD.FK_OWNER_OBJ    = Cst_Owner_OTCSchd -- 12188.4

	   AND SCHD.FK_EXTENSION    = Cst_Ext_OTC_OTCSchd -- 32384.4

	   AND SCHD.FK_REVREASON IS NULL

	   AND SCHD.SEQUENCE = (SELECT MAX(SCHD.SEQUENCE)

		      FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

		     WHERE SCHD.FK_PARENT   = p_PKOTC

		       AND SCHD.FK_OWNER_OBJ	= Cst_Owner_OTCSchd -- 12188.4

		       AND SCHD.FK_EXTENSION	= Cst_Ext_OTC_OTCSchd -- 32384.4

		       AND SCHD.FK_REVREASON IS NULL);



    ELSIF dte_Reference < dat_Min THEN



	-- Tomamos como flujo vivo el primero

	SELECT SCHD.*

	  INTO p_RecOTCSchd

	  FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

	 WHERE SCHD.FK_PARENT	= p_PKOTC

	   AND SCHD.FK_OWNER_OBJ    = Cst_Owner_OTCSchd -- 12188.4

	   AND SCHD.FK_EXTENSION    = Cst_Ext_OTC_OTCSchd -- 32384.4

	   AND SCHD.FK_REVREASON IS NULL

	   AND SCHD.SEQUENCE = (SELECT MIN(SCHD.SEQUENCE)

		      FROM "PGT_TRD".T_PGT_OTC_SCHEDULE_S SCHD

		     WHERE SCHD.FK_PARENT   = p_PKOTC

		       AND SCHD.FK_OWNER_OBJ	= Cst_Owner_OTCSchd -- 12188.4

		       AND SCHD.FK_EXTENSION	= Cst_Ext_OTC_OTCSchd -- 32384.4

		       AND SCHD.FK_REVREASON IS NULL);



    END IF;



    END IF;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package || Cst_Module|| ' Out - p_RecOTCSchd.PK=' || p_RecOTCSchd.PK);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetLiveExercise;



/* ********************************************************************************/

/* <Procedure>	 p_GetFXProductValue			      */

/* <Author>  MNA				  */

/* <Date>    26-11-2012 			  */

/* <Parameters>  Input: Event Pk (Number), Output: UPI Value (Varchar2)       */

/* <Description> (28846.7) - Calcutate the Product Value for FX FORWARD, FX NDF,  */

/* FX SPOT, FX NDS and FX OPTION.			  */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetFXProductValue ( p_CoPk IN OUT NOCOPY VARCHAR2 )

IS



    str_Out  VARCHAR2(100);

    Rec_Event	 "PGT_TRD".T_PGT_TRADE_EVENTS_S%ROWTYPE;

    Rec_OTC  "PGT_TRD".T_PGT_OTC_OPTION_S%ROWTYPE;     /* Registro de OTC */

    Rec_OTCSchd  "PGT_TRD".T_PGT_OTC_SCHEDULE_S%ROWTYPE;   /* Registro de OTC Schedule */

    num_PkEvent  NUMBER;

    num_SubType  NUMBER;

    Cst_Module	 CONSTANT CHAR(30) := 'p_GetFXProductValue';



    -- BEGIN ADECASO - 15/10/2014 - FX NDF como Spot

    num_spotpur  NUMBER;

    num_spotsale NUMBER;

    num_spot	 NUMBER;

    -- END ADECASO



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package || Cst_Module || ' Param - p_CoPk=' || p_CoPk);



    num_PkEvent := p_CoPk;



    -- Cargamos los datos del evento

    "PGT_PRG".pkg_eventgeneral.p_loadevent (num_PkEvent, Rec_Event);



    IF Rec_Event.FK_INSTRUMENT = Cst_Instrument_FXFwd THEN --11.4



    str_Out := 'ForeignExchange:Forward';



    ELSIF Rec_Event.FK_INSTRUMENT = Cst_Instrument_FXNDF THEN --13.4



    -- BEGIN ADECASO - 15/10/2014 - FX NDF como Spot

    -- Calculamos los dias Spot para la compra como la venta

    SELECT  pgt_prg.pkg_calendar.f_getworkdays(CURPUR.FK_CALENDAR, HDR.TRADEDATE, NDF.SETTLEDATE) as spotpur,

	pgt_prg.pkg_calendar.f_getworkdays(CURSAL.FK_CALENDAR, HDR.TRADEDATE, NDF.SETTLEDATE) as spotsal

    INTO    num_spotpur, num_spotsale

    FROM    PGT_TRD.T_PGT_TRADE_EVENTS_S EVT,

	PGT_TRD.T_PGT_TRADE_HEADER_S HDR,

	PGT_TRD.T_PGT_NDF_S NDF,

	PGT_TRD.T_PGT_FWDSTARTING_S SETT,

	PGT_STC.T_PGT_CURRENCY_S CURPUR,

	PGT_STC.T_PGT_CURRENCY_S CURSAL

    WHERE   HDR.FK_PARENT = EVT.PK

    AND NDF.FK_PARENT = HDR.PK

    AND SETT.FK_PARENT = NDF.PK

    AND NDF.FK_PURCCURR = CURPUR.PK

    AND NDF.FK_SALECURR = CURSAL.PK

    AND NDF.FK_OWNER_OBJ = Cst_Owner_OTC -- 1476.4

    AND NDF.FK_EXTENSION = Cst_Ext_FXNDF -- 14905.4

    AND SETT.FK_OWNER_OBJ = Cst_Obj_FXNonDeliverable -- 1505.4

    AND EVT.PK = num_PkEvent;



    -- Nos quedamos con el menor de los dos spot

    IF num_spotpur > num_spotsale THEN

	num_spot := num_spotsale;

    ELSE

	num_spot := num_spotpur;

    END IF;



    -- Si el spot es menor o igual que 2, entonces el UPI es Spot.

    IF num_spot <= 2 THEN

	str_Out := 'ForeignExchange:Spot';



    -- En otro caso, se queda como NDF.

    ELSE

	str_Out := 'ForeignExchange:NDF';

    END IF;

    -- END ADECASO



    ELSIF Rec_Event.FK_INSTRUMENT = Cst_Instrument_FXDelSpot THEN --8.4



    str_Out := 'ForeignExchange:Spot';



    ELSIF Rec_Event.FK_INSTRUMENT = Cst_Instrument_FXNDS THEN --20134.4



    str_Out := 'ForeignExchange:Spot';



    ELSIF Rec_Event.FK_INSTRUMENT = Cst_Instrument_OTC THEN --20111.4



    --Obtener los datos de la OTC a partir de la Pk del Evento

    "PGT_CFM".Pkg_EMIRGTRSwaptionProc.p_LoadOTCFromEv(num_PkEvent, Rec_OTC);



    IF Rec_OTC.FK_UNDERLYINGTYPE = Cst_UndCl_MarketUnderlying THEN --22991.4



	IF Rec_OTC.FK_QUOTETYPE = Cst_UndType_FX THEN --20760.4



	--Se busca el Exercise vivo

	p_GetLiveExercise (Rec_OTC.PK, Rec_OTCSchd);



	IF Rec_OTC.FK_OPTIONTYPE = Cst_OptionType_PlainVanilla THEN --22411.4



	    --MCR Cambio para los exoticos de emir porque se generaba de forma incorrecta los exotic digital 12/12/2013



	    IF Rec_OTCSchd.FK_EXOTICSETTLE = Cst_SettleExotic_Digital then --21302.4



	    str_Out := 'ForeignExchange:SimpleExotic:Digital';



	    ELSIF NVL (Rec_OTCSchd.DELIVERYIND, 0) = Cst_DeliveryInd_No THEN--0



	    str_Out := 'ForeignExchange:NDO';



	    ELSE



	    str_Out := 'ForeignExchange:VanillaOption';



	    END IF;


	ELSIF Rec_OTC.FK_OPTIONTYPE = Cst_OptionType_Flex  and	Rec_OTC.FLEXOPTIONTYPE	LIKE  '%AmerFwd%' then

	    str_Out := 'ForeignExchange:Forward';

	  ELSIF Rec_OTC.FK_OPTIONTYPE = Cst_OptionType_Flex  and  Rec_OTC.FLEXOPTIONTYPE  IN ('AmBarrier', 'EuroBarr') then

	str_Out := 'ForeignExchange:ComplexExotic';


	 ELSIF Rec_OTC.FK_OPTIONTYPE = Cst_OptionType_Barrier --22412.4
	 THEN --22417.4



	    str_Out := 'ForeignExchange:SimpleExotic:Barrier';



	ELSIF Rec_OTC.FK_OPTIONTYPE = Cst_OptionType_Asian --22413.4

	OR (Rec_OTC.FK_OPTIONTYPE = Cst_OptionType_Flex AND (Rec_OTC.FLEXOPTIONTYPE NOT IN ('AmBarrier', 'EuroBarr') or Rec_OTC.FLEXOPTIONTYPE IS NULL)) THEN --22417.4



	    str_Out := 'ForeignExchange:ComplexExotic';









	END IF;



	END IF;





    END IF;



    END IF;



    p_CoPk := str_Out;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package || Cst_Module|| ' Out - p_CoPk=' || p_CoPk);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    p_CoPk := NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    PGT_PRG.Pkg_PgtError.p_PutError(Cst_Error_ConfOthers,Cst_Module,9,Cst_General_ErrorType,'Error: ' || SQLERRM);

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetFXProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_GetFX			      */

/* <Author>  MNA				  */

/* <Date>    27-11-2012 			  */

/* <Parameters>  Input: FX Pk (Number), Output: FX (Record)	      */

/* <Description> (28846.7) - Get the record of FX table from a given PK.      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetFX ( p_PKFX IN NUMBER,

	    Rec_FX OUT "PGT_TRD".T_PGT_FX_S%ROWTYPE )

IS



    Cst_Module	    CONSTANT CHAR(7) := 'p_GetFX';



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package || Cst_Module || ' Param - p_PKFX=' || p_PKFX);



    -- Obtenemos el Registro de la tabla FX

    SELECT  FX.*

    INTO    Rec_FX

    FROM    PGT_TRD.T_PGT_FX_S	FX

    WHERE   FX.PK = p_PKFX;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'End ' || Cst_Package || Cst_Module || ' Out - Rec_FX.PK=' || Rec_FX.PK);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    Rec_FX := NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetFX;



/* ********************************************************************************/

/* <Procedure>	 p_GetNDF			      */

/* <Author>  MNA				  */

/* <Date>    29-11-2012 			  */

/* <Parameters>  Input: NDF Pk (Number), Output: NDF (Record)		  */

/* <Description> (28846.7) - Get the record of NDF table from a given PK.     */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetNDF ( p_PKNDF IN NUMBER,

	     Rec_NDF OUT "PGT_TRD".T_PGT_NDF_S%ROWTYPE )

IS



    Cst_Module	    CONSTANT CHAR(8) := 'p_GetNDF';



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package || Cst_Module || ' Param - p_PKNDF=' || p_PKNDF);



    -- Obtenemos el Registro de la tabla NDF

    SELECT  NDF.*

    INTO    Rec_NDF

    FROM    PGT_TRD.T_PGT_NDF_S  NDF

    WHERE   NDF.PK = p_PKNDF;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'End ' || Cst_Package || Cst_Module || ' Out - Rec_NDF.PK=' || Rec_NDF.PK);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    Rec_NDF := NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetNDF;



/* ********************************************************************************/

/* <Procedure>	 p_GetFXSwDProductValue 		      */

/* <Author>  MNA				  */

/* <Date>    14-12-2012 			  */

/* <Parameters>  Input: FX Pk (Number), Output: UPI Value (Varchar2)	      */

/* <Description> (28846.7) - Calcutate the Product Value for FX SWAP.	      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetFXSwDProductValue ( p_PKFX IN OUT NOCOPY VARCHAR2 )

IS

    Cst_Module	   CONSTANT CHAR(22) := 'p_GetFXSwDProductValue';



    num_FX     NUMBER;

    rec_FX     "PGT_TRD".T_PGT_FX_S%ROWTYPE;

    str_Out    VARCHAR2(50);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package || Cst_Module || ' Param - p_PKFX=' || p_PKFX);



    num_FX := p_PKFX;



    p_GetFX (num_FX, rec_FX);



    IF rec_FX.FK_EXTENSION IN (Cst_Ext_Delv_NearSpot, Cst_Ext_Delv_FarSpot) THEN --15061.4,39869.4



    str_Out :='ForeignExchange:Spot';



    ELSIF rec_FX.FK_EXTENSION IN (Cst_Ext_Delv_FarFwd, Cst_Ext_Delv_NearFwd) THEN --27404.4,15060.4



    str_Out := 'ForeignExchange:Forward';



    END IF;



    p_PKFX := str_Out;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process ( Cst_Module, NULL, 'End ' || Cst_Package || Cst_Module || ' Out - p_PKFX=' || p_PKFX );



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    p_PKFX := NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetFXSwDProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_GetFXSwNDProductValue		      */

/* <Author>  MNA				  */

/* <Date>    14-12-2012 			  */

/* <Parameters>  Input: NDF Pk (Number), Output: UPI Value (Varchar2)	      */

/* <Description> (28846.7) - Calcutate the Product Value for FX SWAP ND.      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetFXSwNDProductValue ( p_PKNDF IN OUT NOCOPY VARCHAR2 )

IS

    Cst_Module	   CONSTANT CHAR(23) := 'p_GetFXSwNDProductValue';



    num_NDF    NUMBER;

    rec_NDF    "PGT_TRD".T_PGT_NDF_S%ROWTYPE;

    str_Out    VARCHAR2(50);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package || Cst_Module || ' Param - p_PKNDF=' || p_PKNDF);



    num_NDF := p_PKNDF;



    p_GetNDF (num_NDF, rec_NDF);



    IF rec_NDF.FK_EXTENSION IN (Cst_Ext_NonDelv_NearSpot, Cst_Ext_NonDelv_FarSpot) THEN --39821.4,39870.4



    str_Out :='ForeignExchange:Spot';



    ELSIF rec_NDF.FK_EXTENSION IN (Cst_Ext_NonDelv_NearFwd, Cst_Ext_NonDelv_FarFwd) THEN --39820.4,39822.4



    -- JCASAS (07/01/2014)

    --str_Out := 'ForeignExchange:Forward';

    str_Out := 'ForeignExchange:NDF';

    -- Fin JCASAS (07/01/2014)



    END IF;



    p_PKNDF := str_Out;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process ( Cst_Module, NULL, 'End ' || Cst_Package || Cst_Module || ' Out - p_PKNDF=' || p_PKNDF );



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    p_PKNDF := NULL;

    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetFXSwNDProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_GetOTCEqProductValue 		      */

/* <Author>  MCASAS				  */

/* <Date>    17-12-2012 			  */

/* <Parameters>  Input: Header Pk (Number), Output: UPI Value (Varchar2)      */

/* <Description> (28846.7) - Calcutate the Product Value for OTC EQUITY.      */

/* Note: if you change something in this procedure, also review the procedure	  */

/* p_GetNonStandardFlag.			      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* <Mod> 9.4  29-06-2020 - JROJAS  32732.70  New logic for equity iption       */

/* ********************************************************************************/

PROCEDURE p_GetOTCEqProductValue ( p_CoPk IN OUT NOCOPY VARCHAR2 )

IS

    Cst_Module	    CONSTANT CHAR(30) := 'p_GetOTCEqProductValue';



    num_PkHeader    NUMBER;



    rec_OTC	"PGT_TRD".T_PGT_OTC_OPTION_S%ROWTYPE;

    rec_QuoteRef    "PGT_CFM".Pkg_EMIRGTRUtility.Tab_QuoteRef;

    rec_Sec	"PGT_CFM".Pkg_EMIRGTRUtility.Tab_Security;



    boo_IsVarianceSwap	BOOLEAN;

    boo_IsBasketSec BOOLEAN;



    str_Out	VARCHAR2(100);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module, NULL, 'Start ' || Cst_Package||Cst_Module || ' Param - p_CoPk=' || p_CoPk);



    num_PkHeader := p_CoPk;



    -- Obtener los datos de la OTC

    BEGIN

    SELECT OTC.*

      INTO rec_OTC

      FROM "PGT_TRD".T_PGT_OTC_OPTION_S OTC

     WHERE OTC.FK_PARENT    = num_PkHeader

       AND OTC.FK_OWNER_OBJ = Cst_Owner_OTC --1476.4

       AND OTC.FK_EXTENSION = Cst_Ext_THeaderOTC; --32361.4



    EXCEPTION

    WHEN NO_DATA_FOUND THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'Error loading OTC: No data found' );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    WHEN OTHERS THEN

	"PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9,  Cst_General_ErrorType, 'Error loading OTC: ' || SQLERRM );

	RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

    END;



    --Ver si la OTC tiene FlexType=VarianceSwap (Pdte de definir de forma exacta)

    boo_IsVarianceSwap	:= FALSE;

    IF rec_OTC.FK_OPTIONTYPE = Cst_OptionType_Flex AND --22417.4

       rec_OTC.FLEXOPTIONTYPE  IN ('Variance Swap', 'VarianceSwap') THEN --MNA(29/05/2013) Se anade 'VarianceSwap'

    boo_IsVarianceSwap	:= TRUE;

    END IF;



    --Obtener datos de la Quote Reference

    boo_IsBasketSec := FALSE;

    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadQuoteRef(   rec_OTC.FK_QUOTEREFERENCE, --IN

			   rec_QuoteRef); --OUT



    IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities THEN --20761.4

    --Cargar datos de la Security

    "PGT_CFM".Pkg_EMIRGTRUtility.p_LoadSecurity(rec_QuoteRef.FK_QUOTEINSTRUMENT, --IN

			    rec_Sec); --OUT

    --Ver si la Security es de tipo Basket

    boo_IsBasketSec := f_IsBasketSecurity(rec_Sec.FK_SECTYPE);



    END IF;



    --START - 29-06-2020 - JROJAS - 32732.70

	str_Out := 'Equity:Option:'; -- always if it is an equity option



	IF boo_IsVarianceSwap THEN



	str_Out := str_out||'ParameterReturnVariance:'; --always if it is variance swap



	IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

	   boo_IsBasketSec THEN



	      str_Out := str_out||'Basket';



	ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

	  NOT boo_IsBasketSec THEN



	      str_Out := str_out||'SingleName';



	ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Indexes THEN



	     str_Out := str_out||'SingleIndex';



	ELSE



	     str_Out := '';



	END IF;

	ELSE --not variance



	   str_Out := str_out||'PriceReturnBasicPerformance:';



	   IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

	   boo_IsBasketSec THEN



	      str_Out := str_out||'Basket';



	ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

	  NOT boo_IsBasketSec THEN



	      str_Out := str_out||'SingleName';



	ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Indexes THEN



	     str_Out := str_out||'SingleIndex';



	ELSE



	     str_Out := '';



	END IF;





	END IF;

     --END - 29-06-2020 - JROJAS - 32732.70





    /*

    --El Product Value no esta bien definido todavia. De momento los ponemos asi:

    IF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

       NOT boo_IsBasketSec AND

       rec_OTC.FK_OPTIONTYPE = Cst_OptionType_PlainVanilla THEN



    str_Out := 'Equity:Option:PriceReturnBasicPerformance:SingleName';



    ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Indexes AND

       rec_OTC.FK_OPTIONTYPE = Cst_OptionType_PlainVanilla THEN



    str_Out := 'Equity:Option:PriceReturnBasicPerformance:SingleIndex';



    ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

       boo_IsBasketSec AND

       rec_OTC.FK_OPTIONTYPE = Cst_OptionType_PlainVanilla THEN



    str_Out := 'Equity:Option:PriceReturnBasicPerformance:Basket';



    ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

       NOT boo_IsBasketSec AND

       boo_IsVarianceSwap THEN



    str_Out := 'Equity:Option:ParameterReturnVariance:SingleName';



    ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Indexes AND

       boo_IsVarianceSwap THEN



    str_Out := 'Equity:Option:ParameterReturnVariance:SingleIndex';



    ELSIF rec_QuoteRef.FK_QUOTETYPE = Cst_QuoteType_Securities AND

       boo_IsBasketSec AND

       boo_IsVarianceSwap THEN



    str_Out := 'Equity:Option:ParameterReturnVariance:Basket';



    --MNA(29/05/2013)

    ELSIF rec_OTC.FK_OPTIONTYPE = Cst_OptionType_Flex AND NOT boo_IsVarianceSwap

       OR rec_OTC.FK_OPTIONTYPE IN (Cst_OptionType_Asian, --22413.4

		    Cst_OptionType_Barrier, --22412.4

		    Cst_OptionType_Ladder, --22416.4

		    Cst_OptionType_LookBack, --22415.4

		    Cst_OptionType_Ratchet) THEN --22414.4



    str_Out := 'Equity:Other';



    ELSE



    str_Out := NULL;



    END IF;

    */



    p_CoPk := str_Out;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - p_CoPk=' || p_CoPk);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    p_CoPk := NULL;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(Cst_Module,NULL,'End ' || Cst_Package||Cst_Module || ' Out - p_CoPk=' || p_CoPk);



    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;

    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;

    WHEN OTHERS THEN

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, Cst_Module, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;

END p_GetOTCEqProductValue;



/* ********************************************************************************/

/* <Procedure>	 p_CalcUPIValue 			  */

/* <Author>  RTEIJEIRO				  */

/* <Date>    05-05-2016 			  */

/* <Parameters>  Input: Event Pk (Number), Output: UPI Value (Varchar2)       */

/* <Description> (28846.7) - Calcutate the UPI value at trade level.	      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_CalcUPIValue( par_Event_PK IN NUMBER, str_LegInd IN VARCHAR2 DEFAULT NULL, str_UPI_Value OUT VARCHAR2 )

IS



    Rec_Event	    "PGT_TRD".T_PGT_TRADE_EVENTS_S%ROWTYPE;

    Rec_CD	"PGT_TRD".T_PGT_CD_S%ROWTYPE;	      /* Registro de Credit Derivatives */



    num_PkEvent     NUMBER;

    num_PkHeader    NUMBER;

    num_PkFX	    NUMBER;

    num_PkNDF	    NUMBER;

    num_OTCType     NUMBER;

    num_EquityStruct	NUMBER;

    str_ProductValue	VARCHAR2(100);

    str_Proc	    VARCHAR2(14) := 'p_CalcUPIValue';



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(str_Proc, NULL, 'Start ' || Cst_Package || str_Proc || ' Param - par_Event_PK=' || par_Event_PK);



    -- Initialize variables

    num_PkEvent := par_Event_PK;

    str_ProductValue := NULL;



    -- Load Event data

    "PGT_PRG".pkg_eventgeneral.p_loadevent (num_PkEvent, Rec_Event);



    -- Get Registry PK

    num_PkHeader := "PGT_PRG".Pkg_PgtUtility.f_GetRegistryPK( Rec_Event.PK );



    -- Calculate the UPI (Unique Product Identifier) value depending on the event instrument



    -- SWAP & CROSS CURRENCY SWAP

    IF Rec_Event.FK_INSTRUMENT IN( "PGT_PRG".Pkg_PGTConst.CST_INST_CCS, "PGT_PRG".Pkg_PGTConst.CST_INST_SWAP ) THEN

    str_ProductValue := num_PkHeader;

    p_GetCCSProductValue (str_ProductValue);



    -- FORWARD RATE AGREEMENT

    ELSIF Rec_Event.FK_INSTRUMENT = "PGT_PRG".Pkg_PGTConst.CST_INST_FRA THEN

    str_ProductValue := num_PkEvent;

    p_GetFRAProductValue (str_ProductValue);



    -- CAP&FLOOR

    ELSIF Rec_Event.FK_INSTRUMENT = "PGT_PRG".Pkg_PGTConst.CST_INST_CAPFLOOR THEN

    IF NOT "PGT_PRG".Pkg_Tradeheadergeneral.f_LoadTrdHdrByPkNoErrs( num_PkHeader ) THEN

	str_ProductValue := NULL;

    ELSE

	-- COMMODITY CAP&FLOOR

	IF "PGT_PRG".Pkg_Tradeheadergeneral.rHeader.FK_INSTRUMTYPE = "PGT_PRG".Pkg_PGTConst.CST_INSTTYPE_CAPFLOOR_C0MMCF THEN

	str_ProductValue := num_PkHeader;

	p_GetCommCapProductValue (str_ProductValue);

	ELSE

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(str_Proc, NULL, 'Start ' || Cst_Package || str_Proc || ' Antes de p_GetCapProductValue =' || str_UPI_Value);

	str_ProductValue := num_PkEvent;

	p_GetCapProductValue (str_ProductValue);

	"PGT_SYS".Pkg_ApplicationInfo.p_Process(str_Proc, NULL, 'Start ' || Cst_Package || str_Proc || ' Despues de p_GetCapProductValue =' || str_ProductValue);

	END IF;

    END IF;



    -- CASH FLOW MATCHING

    ELSIF Rec_Event.FK_INSTRUMENT = "PGT_PRG".Pkg_CFMConstant.CST_CFM_INSTRUMENT THEN

    str_ProductValue := num_PkHeader;

    p_GetCFMProductValue (str_ProductValue);



    -- CREDIT DERIVATIVES

    ELSIF Rec_Event.FK_INSTRUMENT = "PGT_PRG".pkg_creditconstant.cst_cd_instrument THEN

    "PGT_PRG".Pkg_Creditauxiliar.p_LoadCredit (num_PkEvent, Rec_CD);

    str_ProductValue := Rec_CD.PK;

    p_GetCreditProductValue (str_ProductValue);



    -- EQUITY SWAP

    ELSIF Rec_Event.FK_INSTRUMENT = "PGT_PRG".Pkg_PGTConst.CST_INST_EQSWAP THEN

    IF NOT "PGT_PRG".Pkg_Tradeheadergeneral.f_LoadTrdHdrByPkNoErrs( num_PkHeader ) THEN

	str_ProductValue := NULL;

    ELSE

	-- COMMODITY EQUITY SWAP

	IF "PGT_PRG".Pkg_Tradeheadergeneral.rHeader.FK_INSTRUMTYPE = "PGT_PRG".Pkg_PGTConst.CST_INSTTYPE_EQSWAP_COMMEQSW THEN

	str_ProductValue := num_PkHeader;

	p_GetCommEQSwapProductValue (str_ProductValue);

	ELSE

	p_IsEqStrProdTemp (num_PkEvent, NULL, NULL, num_EquityStruct);

	IF num_EquityStruct = 1 THEN -- Equity Structured = Yes

	    str_ProductValue := num_PkEvent;

	    p_GetEquityStrProductValue (str_ProductValue);

	ELSE -- Equity Structured = No

	    str_ProductValue := num_PkHeader;

	    p_GetEQSwapProductValue (str_ProductValue);

	END IF;

	END IF;

    END IF;



    -- OTC OPTION

    ELSIF Rec_Event.FK_INSTRUMENT = "PGT_PRG".Pkg_Otcconst.CST_OTC_INSTRUMOTC THEN

    -- Check OTC Type

    p_IsOTCSWAPTION (num_PkEvent, NULL, NULL, num_OTCType);

    IF num_OTCType = 1 THEN -- OTC SWAPTION

	str_ProductValue := 'InterestRate:Option:Swaption';

    ELSE

	p_IsBondOption (num_PkEvent, NULL, NULL, num_OTCType);

	IF num_OTCType = 1 THEN -- BOND OPTION

	str_ProductValue := 'InterestRate:Option:DebtOption';

	ELSE

	p_IsFXOption (num_PkEvent, NULL, NULL, num_OTCType);

	IF num_OTCType = 1 THEN -- FX OPTION

	    str_ProductValue := num_PkEvent;

	    p_GetFXProductValue (str_ProductValue);

	ELSE

	    p_IsOTCEquity (num_PkEvent, NULL, NULL, num_OTCType);

	    IF num_OTCType = 1 THEN -- OTC EQUITY

	    p_IsEqStrProdTemp (num_PkEvent, NULL, NULL, num_EquityStruct);

	    IF num_EquityStruct = 1 THEN -- Equity Structured = Yes

		str_ProductValue := num_PkEvent;

		p_GetEquityStrProductValue (str_ProductValue);

	    ELSE -- Equity Structured = No

		str_ProductValue := num_PkHeader;

		p_GetOTCEqProductValue (str_ProductValue);

	    END IF;

	    END IF;

	END IF;

	END IF;

    END IF;



    -- FX SPOT, FX NDS, FX FORWARD & FX NDF

    ELSIF Rec_Event.FK_INSTRUMENT IN( "PGT_PRG".Pkg_Fxconstant.CST_INST_FXSPOT,

		      "PGT_PRG".Pkg_Fxconstant.CST_INST_FXNDS,

		      "PGT_PRG".Pkg_Fxconstant.CST_INST_FXFWD,

		      "PGT_PRG".Pkg_Fxconstant.CST_INST_FXNDF ) THEN

    str_ProductValue := num_PkEvent;

    p_GetFXProductValue (str_ProductValue);





    -- FX SWAP

    ELSIF Rec_Event.FK_INSTRUMENT = "PGT_PRG".Pkg_Fxconstant.CST_INST_FXSWAP THEN

    IF str_LegInd IS NOT NULL THEN

	IF str_LegInd = 'N' THEN -- Pata Near

	BEGIN

	    SELECT  FX.PK

	    INTO    num_PkFX

	    FROM    "PGT_TRD".T_PGT_FX_S FX,

		"PGT_TRD".T_PGT_FX_SWAP_S SWAP

	    WHERE   FX.FK_OWNER_OBJ = Cst_Obj_FXSwapDeliv --1761.4

	    AND     FX.FK_EXTENSION IN ( Cst_Ext_Delv_NearSpot, --15061.4

			 Cst_Ext_Delv_NearFwd ) --15060.4

	    AND     FX.FK_PARENT = SWAP.PK

	    AND     SWAP.FK_OWNER_OBJ = Cst_Owner_TradeHeader--1476.4

	    AND     SWAP.FK_EXTENSION = Cst_Ext_Header_FxSwap--15063.4

	    AND     SWAP.FK_PARENT = num_PkHeader;

	EXCEPTION

	    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

	    RAISE;

	    WHEN NO_DATA_FOUND THEN

	    num_PkFX := NULL;

	    WHEN OTHERS THEN

	    RAISE;

	END;

	ELSE -- IF str_LegInd = 'F' THEN -- Pata Far

	BEGIN

	    SELECT  FX.PK

	    INTO    num_PkFX

	    FROM    "PGT_TRD".T_PGT_FX_S FX,

		"PGT_TRD".T_PGT_FX_SWAP_S SWAP

	    WHERE   FX.FK_OWNER_OBJ = Cst_Obj_FXSwapDeliv --1761.4

	    AND     FX.FK_EXTENSION IN ( Cst_Ext_Delv_FarFwd, --27404.4

			 Cst_Ext_Delv_FarSpot ) --39869.4

	    AND     FX.FK_PARENT = SWAP.PK

	    AND     SWAP.FK_OWNER_OBJ = Cst_Owner_TradeHeader--1476.4

	    AND     SWAP.FK_EXTENSION = Cst_Ext_Header_FxSwap--15063.4

	    AND     SWAP.FK_PARENT = num_PkHeader;

	EXCEPTION

	    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

	    RAISE;

	    WHEN NO_DATA_FOUND THEN

	    num_PkFX := NULL;

	    WHEN OTHERS THEN

	    RAISE;

	END;

	END IF;



	str_ProductValue := num_PkFX;

	p_GetFXSwDProductValue (str_ProductValue);



    ELSE

	str_ProductValue := NULL;

    END IF;



    -- FX SWAP ND

    ELSIF Rec_Event.FK_INSTRUMENT = "PGT_PRG".Pkg_Fxconstant.CST_INST_FXSWAPND THEN

    IF str_LegInd IS NOT NULL THEN

	IF str_LegInd = 'N' THEN -- Pata Near

	BEGIN

	    SELECT  NDF.PK

	    INTO    num_PkNDF

	    FROM    "PGT_TRD".T_PGT_NDF_S NDF,

		"PGT_TRD".T_PGT_FX_SWAP_S SWAP

	    WHERE   NDF.FK_OWNER_OBJ = Cst_Obj_FXSwapNonDeliv --12754.4

	    AND     NDF.FK_EXTENSION IN ( Cst_Ext_NonDelv_NearSpot, --39821.4

			  Cst_Ext_NonDelv_NearFwd ) --39820.4

	    AND     NDF.FK_PARENT = SWAP.PK

	    AND     SWAP.FK_OWNER_OBJ = Cst_Owner_TradeHeader--1476.4

	    AND     SWAP.FK_EXTENSION = Cst_Ext_Header_FxSwapND--39812.4

	    AND     SWAP.FK_PARENT = num_PkHeader;

	EXCEPTION

	    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

	    RAISE;

	    WHEN NO_DATA_FOUND THEN

	    num_PkNDF := NULL;

	    WHEN OTHERS THEN

	    RAISE;

	END;

	ELSE -- IF str_LegInd = 'F' THEN -- Pata Far

	BEGIN

	    SELECT  NDF.PK

	    INTO    num_PkNDF

	    FROM    "PGT_TRD".T_PGT_NDF_S NDF,

		"PGT_TRD".T_PGT_FX_SWAP_S SWAP

	    WHERE   NDF.FK_OWNER_OBJ = Cst_Obj_FXSwapNonDeliv --12754.4

	    AND     NDF.FK_EXTENSION IN ( Cst_Ext_NonDelv_FarFwd, --39822.4

			  Cst_Ext_NonDelv_FarSpot ) --39870.4

	    AND     NDF.FK_PARENT = SWAP.PK

	    AND     SWAP.FK_OWNER_OBJ = Cst_Owner_TradeHeader--1476.4

	    AND     SWAP.FK_EXTENSION = Cst_Ext_Header_FxSwapND--39812.4

	    AND     SWAP.FK_PARENT = num_PkHeader;

	EXCEPTION

	    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

	    RAISE;

	    WHEN NO_DATA_FOUND THEN

	    num_PkNDF := NULL;

	    WHEN OTHERS THEN

	    RAISE;

	END;

	END IF;



	str_ProductValue := num_PkNDF;

	p_GetFXSwNDProductValue (str_ProductValue);



    ELSE

	str_ProductValue := NULL;

    END IF;



    END IF;



    str_UPI_Value := str_ProductValue;



EXCEPTION

    WHEN "PGT_PRG".Pkg_PgtError.NOT_FIND_PROGRAM THEN

    RAISE;



    WHEN "PGT_PRG".Pkg_PgtError.PACKAGE_DISCARDED THEN

    RAISE;



    WHEN NO_DATA_FOUND THEN

    str_UPI_Value := NULL;



    WHEN OTHERS THEN

    str_UPI_Value := NULL;



END p_CalcUPIValue;



/* ********************************************************************************/

/* <Procedure>	 p_GetAliasUPI				  */

/* <Author>  JCASAS				  */

/* <Date>    19-09-2012 			  */

/* <Parameters>  Input: Parent PK (Number), Owner Obj (Number), Extension (Number)*/

/*	 Output: UPI Alias Code (Varchar2)		  */

/* <Description> (28846.7) - Procedure that returns UPI Alias Code.	  */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetAliasUPI( p_Parent    IN NUMBER,

	     p_Owner_Obj IN NUMBER,

	     p_Extension IN NUMBER,

	     o_AliasCode OUT VARCHAR2 )

IS

    str_Proc	VARCHAR2(100) := 'p_GetAliasUPI';

    str_Param	VARCHAR2(300);



BEGIN



    -- Iniciamos las trazas

    str_Param :=  'p_Parent='	||p_Parent  ||';'||

	  'p_Owner_Obj='||p_Owner_Obj	||';'||

	  'p_Extension='||p_Extension;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process (str_Proc, NULL, 'Start ' || Cst_Package || str_Proc || ' Param - ' || str_Param);



    -- Extraemos el alias code de UPI

    SELECT ALIASCODE

    INTO o_AliasCode

    FROM "PGT_TRD".T_PGT_EVENT_ALTER_ID_S

    WHERE FK_PARENT    = p_Parent

    AND FK_OWNER_OBJ	   = p_Owner_Obj

    AND FK_EXTENSION	   = p_Extension

    AND FK_SOURCE      = Cst_UPISource

    AND FK_EQUIVALENCETYPE = Cst_EquivTypeUPI;



    -- JCASAS 31-10-2012: Quitar los saltos de linea del alias code

    o_AliasCode := replace(o_AliasCode,chr(10),'');

    o_AliasCode := replace(o_AliasCode,chr(13),'');



    "PGT_SYS".Pkg_ApplicationInfo.p_Process (str_Proc, NULL, 'End ' || Cst_Package || str_Proc || ' Out - o_AliasCode=' || o_AliasCode);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    o_AliasCode := NULL;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process (str_Proc, NULL, 'End ' || Cst_Package || str_Proc || ' (NoDataFound) Out - o_AliasCode=' || o_AliasCode);



    WHEN "PGT_PRG".Pkg_PgtError.e_stop_prg THEN

    RAISE;



    WHEN  "PGT_PRG".PKG_PGTERROR.NOT_FIND_PROGRAM THEN

    RAISE;



    WHEN  "PGT_PRG".PKG_PGTERROR.PACKAGE_DISCARDED THEN

    RAISE;



    WHEN OTHERS THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(str_Proc,NULL,' ERROR (' || Cst_Package||str_Proc || ' ): ' || sqlerrm);

    "PGT_PRG".Pkg_PgtError.p_PutError( Cst_Error_ConfOthers, str_Proc, 9, Cst_General_ErrorType, 'Error: ' || SQLERRM );

    RAISE "PGT_PRG".Pkg_PgtError.e_stop_prg;



END p_GetAliasUPI;



/* ********************************************************************************/

/* <Procedure>	 p_InsAlterAliasSource			      */

/* <Author>  MCASAS (AXPE)			      */

/* <Date>    06-02-2014 			  */

/* <Parameters>  Input: Alternate Alias (Record), Output: Alternate Alias (Record)*/

/* <Description> (28846.7) - Inserts a record in Alias Alternate table of a   */

/*	 registry trade (Table "PGT_TRD".T_PGT_EVENT_ALTER_ID_S).     */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_InsAlterAliasSource( rec_EventAlterId  IN OUT  "PGT_TRD".T_PGT_EVENT_ALTER_ID_S%ROWTYPE )

IS



    /* **************************************** */

    /* Variables		*/

    /* **************************************** */



    str_Proc	      VARCHAR2(100) := 'p_InsAlterAliasSource';

    str_Param	      VARCHAR2(400);



BEGIN



    -- Iniciamos las variables

    rec_EventAlterId.PK := NULL;



    -- Iniciamos las trazas

    str_Param :=  'rec_EventAlterId-->'||

	  'FK_PARENT='	       ||rec_EventAlterId.FK_PARENT	||';'||

	  'FK_OWNER_OBJ='      ||rec_EventAlterId.FK_OWNER_OBJ	    ||';'||

	  'FK_EXTENSION='      ||rec_EventAlterId.FK_EXTENSION;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process (str_Proc, NULL, 'Start ' || Cst_Package || str_Proc || ' Param 1 - ' || str_Param);



    str_Param :=  'rec_EventAlterId-->'||

	  'FK_EQUIVALENCETYPE='||rec_EventAlterId.FK_EQUIVALENCETYPE||';'||

	  'FK_SOURCE='	       ||rec_EventAlterId.FK_SOURCE	||';'||

	  'ALIASCODE='	       ||rec_EventAlterId.ALIASCODE;

    "PGT_SYS".Pkg_ApplicationInfo.p_Process (str_Proc, NULL, 'Start ' || Cst_Package || str_Proc || ' Param 2 - ' || str_Param);



    "PGT_TRD".PKG_SIGOM_COV.P_SETHEADER ('T_PGT_EVENT_ALTER_ID_S', rec_EventAlterId.PK, rec_EventAlterId.FK_OWNER_OBJ);



    "PGT_SYS".Pkg_ApplicationInfo.p_Process (str_Proc, NULL, 'Start ' || Cst_Package || str_Proc || ' Param 2 - ' || str_Param);



    INSERT INTO "PGT_TRD".T_PGT_EVENT_ALTER_ID_S

    (	PK,

	FK_OWNER_OBJ,

	FK_PARENT,

	FK_EXTENSION,

	FK_EQUIVALENCETYPE,

	FK_SOURCE,

	ALIASCODE

    )

    VALUES

    (	rec_EventAlterId.PK,

	rec_EventAlterId.FK_OWNER_OBJ,

	rec_EventAlterId.FK_PARENT,

	rec_EventAlterId.FK_EXTENSION,

	rec_EventAlterId.FK_EQUIVALENCETYPE,

	rec_EventAlterId.FK_SOURCE,

	rec_EventAlterId.ALIASCODE



    );



    "PGT_SYS".Pkg_ApplicationInfo.p_Process (str_Proc, NULL, 'End ' || Cst_Package || str_Proc || ' INSERTED row T_PGT_EVENT_ALTER_ID_S.PK=' || rec_EventAlterId.PK);



EXCEPTION

    WHEN OTHERS THEN

    NULL;

--    num_ErrCode := SQLCODE;

--    str_ErrText := SUBSTR(SQLERRM,1,200);

--    STR_GENEERR := 'p_InsAlterAliasSource - INSERTING  IN "PGT_TRD".T_PGT_EVENT_ALTER_ID_S TABLE.';

--    str_TextErr := num_ErrCode||'. '||str_GeneErr||' !.'||str_ErrText;

--    /* ********************************************************************	 */

--    /* Generamos el error ... 	   */

--    /* ********************************************************************	 */

--    Pkg_PgtError.P_RaiseError (1.4, str_TextErr);

END p_InsAlterAliasSource;



/* ********************************************************************************/

/* <Procedure>	 p_UpdateAlterAliasSource		      */

/* <Author>  RTEIJEIRO				  */

/* <Date>    20-05-2016 			  */

/* <Parameters>  Input: Parent PK (Number), Owner Obj (Number), Extension (Number)*/

/*	 Equivalence Type (Number), Source (Number), Alias Code (Varchar2)*/

/*	 Output: Alias Code (Varchar2)			  */

/* <Description> (28846.7) - Updates a record in Alias Alternate table of a   */

/*	 registry trade (Table "PGT_TRD".T_PGT_EVENT_ALTER_ID_S).     */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_UpdateAlterAliasSource( num_Parent		IN NUMBER,

		    num_Owner_Obj	IN NUMBER,

		    num_Extension	IN NUMBER,

		    num_EquivalenceType     IN NUMBER,

		    num_Source		IN NUMBER,

		    str_Alias		IN OUT VARCHAR2 )

IS



    /* **************************************** */

    /* Variables		*/

    /* **************************************** */



    str_Proc	    VARCHAR2(100);



BEGIN



    str_Proc	:= 'p_UpdateAlterAliasSource';



    "PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, 'START', NULL, "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );



    UPDATE  "PGT_TRD".T_PGT_EVENT_ALTER_ID_S

    SET     ALIASCODE	    = str_Alias

    WHERE   FK_PARENT	    = num_Parent

    AND     FK_OWNER_OBJ    = num_Owner_Obj

    AND     FK_EXTENSION    = num_Extension

    AND     FK_EQUIVALENCETYPE	= num_EquivalenceType

    AND     FK_SOURCE	    = num_Source;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, 'END', NULL, "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );



END p_UpdateAlterAliasSource;



/* ********************************************************************************/

/* <Procedure>	 p_InsertUPIAlias			  */

/* <Author>  RTEIJEIRO				  */

/* <Date>    20-05-2016 			  */

/* <Description> (28846.7) - Procedure that generates and inserts UPI Alias Code  */

/*	 as an Alternate Alias in registry event	      */

/*	 (Table "PGT_TRD".T_PGT_EVENT_ALTER_ID_S).	      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_InsertUPIAlias

IS



    /* **************************************** */

    /* Variables		*/

    /* **************************************** */



    rec_Event	    "PGT_TRD".T_PGT_TRADE_EVENTS_S%ROWTYPE;



    rec_EventAlterId	"PGT_TRD".T_PGT_EVENT_ALTER_ID_S%ROWTYPE;



    str_Alias_Aux   VARCHAR2(100) := NULL;

    str_UPI	VARCHAR2(100) := NULL;	-- UPI Alias Code



    str_Proc	    VARCHAR2(100);

    str_Comments    VARCHAR2(500);

    str_Module	    VARCHAR2(50) := 'INSERT UPI ALIAS CODE';



    num_EventType   NUMBER;



BEGIN



    /* ********************************************************************************* */

    /* Initialize variables				 */

    /* ********************************************************************************* */

    str_Proc := 'p_InsertUPIAlias';



    /* ********************************************************************************* */

    /* Initialize trace 				 */

    /* ********************************************************************************* */

    "PGT_SYS".Pkg_ApplicationInfo.p_StartModule( str_Module, NULL, 'Start ' || Cst_Package || str_Proc ||

			 ' Param - Pkg_Eventdispatcher.rec_Event.PK = ' || "PGT_PRG".Pkg_Eventdispatcher.rec_Event.PK,

			 "PGT_PRG".Pkg_Eventdispatcher.rec_Event.PK

			);



    /* ********************************************************************************* */

    /* Load Event data					 */

    /* ********************************************************************************* */

    rec_Event	:= "PGT_PRG".Pkg_Eventdispatcher.rec_Event;



    num_EventType := "PGT_PRG".Pkg_PGTUtility.f_GetEventType( rec_Event.PK );



    IF num_EventType <> "PGT_PRG".Pkg_PGTConst.CST_EV_TYPE_REGISTRY THEN -- 126.4



    NULL;



    ELSE -- Es un registry => Insertar o actualizar (si ya existe) el UPI.



    -- Calculamos el valor del UPI a insertar/actualizar a partir de los datos del evento Registry

    BEGIN

	"PGT_PRG".Pkg_TradeUtility.p_CalcUPIValue( par_Event_PK => rec_Event.PK,

			       str_UPI_Value => str_UPI );

    EXCEPTION

	WHEN OTHERS THEN

	str_UPI := NULL;

    END;



    -- Comprobamos si ya existe o no el UPI

    str_Alias_Aux := "PGT_PRG".Pkg_Pgtutility.f_GetAlterAliasSource( Cst_EquivTypeUPI, Cst_UPISource, rec_Event.PK, Cst_Event_Ow_Header, 0 );



    -- Si la funcion anterior nos devuelve un '<NOT FOUND>' (no existe el UPI) lo transformamos a NULL.

    IF str_Alias_Aux = '<NOT FOUND>' THEN

	str_Alias_Aux := NULL;

    END IF;



    -- Si no existe, entonces insertamos el UPI calculado anteriormente.

    IF str_Alias_Aux IS NULL THEN



	IF str_UPI IS NOT NULL THEN

	"PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, NULL, 'Insert UPI Alias Code', "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );

	rec_EventAlterId.FK_OWNER_OBJ	    := Cst_Event_Ow_Header; --1546.4

	rec_EventAlterId.FK_PARENT	:= rec_Event.PK;

	rec_EventAlterId.FK_EXTENSION	    := Cst_Ext_Event_Alter_Alias; --25684.4

	rec_EventAlterId.FK_EQUIVALENCETYPE := Cst_EquivTypeUPI; --26263.4

	rec_EventAlterId.FK_SOURCE	:= Cst_UPISource; --399.4

	rec_EventAlterId.ALIASCODE	:= str_UPI;

	p_InsAlterAliasSource( rec_EventAlterId );

	END IF;



    ELSE -- Si ya existe, entonces actualizamos con el UPI calculado anteriormente.



	IF str_UPI IS NOT NULL THEN

	"PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, NULL, 'Update UPI Alias Code', "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );

	p_UpdateAlterAliasSource( rec_Event.PK, Cst_Event_Ow_Header, Cst_Ext_Event_Alter_Alias, Cst_EquivTypeUPI, Cst_UPISource, str_UPI );

	END IF;



    END IF;



    END IF;



    /* ********************************************************************************* */

    /* Cargamos los datos globales			     */

    /* ********************************************************************************* */



    "PGT_PRG".Pkg_Eventdispatcher.rec_Event	:= rec_Event;



    "PGT_SYS".Pkg_ApplicationInfo.p_EndModule( 'End ' || Cst_Package || str_Proc );



EXCEPTION



    WHEN "PGT_PRG".Pkg_Pgterror.NOT_FIND_PROGRAM THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, 'ERROR', SUBSTR(SQLERRM, 1, 100 ) );

    RAISE;



    WHEN "PGT_PRG".Pkg_Pgterror.PACKAGE_DISCARDED THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, 'ERROR', SUBSTR('PACKAGE DISCARDED', 1, 100 ) );

    RAISE;



    WHEN OTHERS THEN

    str_Comments    := SUBSTR( 'Error in UPI Alter Alias. SQLERR: ' || SQLERRM,1,500 );

    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, ' ERROR (' || Cst_Package || str_Proc || ' ): ' || SQLERRM );

    "PGT_PRG".Pkg_Pgterror.p_PutError( "PGT_PRG".Pkg_Genconst.CST_ERR_OTHERS, Cst_Package || str_Proc, NULL, "PGT_PRG".Pkg_Pgtconst.Cst_Error, str_Comments );

    RAISE;



END p_InsertUPIAlias;



/* ********************************************************************************/

/* <Procedure>	 p_GetPkNearFarDelByEvent		      */

/* <Author>  RTEIJEIRO				  */

/* <Date>    23-05-2016 			  */

/* <Description> (28846.7) - Procedure that gets NEAR and FAR legs data for an	  */

/*	 FX Swap - Deliverable from Event PK.		      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetPkNearFarDelByEvent( p_num_Event     IN	NUMBER,

		    p_rec_FxNear    OUT PGT_TRD.T_PGT_FX_S%ROWTYPE,

		    p_rec_FxFar     OUT PGT_TRD.T_PGT_FX_S%ROWTYPE )

IS



    num_FxSwap	    NUMBER;

    num_DealType    NUMBER;



    num_ExtensionNear	NUMBER;

    num_ExtensionFar	NUMBER;



    num_Error	    NUMBER;



    str_Proc	    VARCHAR2(100)   := 'p_GetPkNearFarDelByEvent';

    str_Comments    VARCHAR2(350);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, 'Start ' || Cst_Package || str_Proc || ' Param - p_num_Event= ' || p_num_Event );



    -- Gets Fx Swap data

    num_Error	:= 1;



    SELECT  FXSWAP.PK,

	FXSWAP.FK_DEALTYPE

    INTO    num_FxSwap,

	num_DealType

    FROM    "PGT_TRD".T_PGT_TRADE_HEADER_S  HEADER,

	"PGT_TRD".T_PGT_FX_SWAP_S	FXSWAP

    WHERE   HEADER.FK_PARENT	  = p_num_Event

    AND     HEADER.FK_OWNER_OBJ   = Cst_Event_Ow_Header --1546.4

    AND     HEADER.FK_EXTENSION   = Cst_Event_Ex_Header --11867.4

    AND     FXSWAP.FK_PARENT	  = HEADER.PK

    AND     FXSWAP.FK_OWNER_OBJ   = Cst_Owner_TradeHeader --1476.4

    AND     FXSWAP.FK_EXTENSION   = Cst_Ext_Header_FxSwap; --15063.4



    IF num_DealType = Cst_DealType_SpotSpot THEN --Spot/Spot 22591.4

    num_ExtensionNear	:= Cst_Ext_Delv_NearSpot; --15061.4

    num_ExtensionFar	:= Cst_Ext_Delv_FarSpot; --39869.4



    ELSIF num_DealType = Cst_DealType_SpotForward THEN --Spot/Forward 22592.4

    num_ExtensionNear	:= Cst_Ext_Delv_NearSpot; --15061.4

    num_ExtensionFar	:= Cst_Ext_Delv_FarFwd; --27404.4



    ELSIF num_DealType = Cst_DealType_ForwardForward THEN --Forward/Forward 22593.4

    num_ExtensionNear	:= Cst_Ext_Delv_NearFwd; --15060.4

    num_ExtensionFar	:= Cst_Ext_Delv_FarFwd; --27404.4

    END IF;



    -- Gets Near leg data

    num_Error	:= 2;



    SELECT  FX.*

    INTO    p_rec_FxNear

    FROM    "PGT_TRD".T_PGT_FX_S    FX

    WHERE   FX.FK_PARENT    = num_FxSwap

    AND     FX.FK_OWNER_OBJ = Cst_Obj_FXSwapDeliv --1761.4

    AND     FX.FK_EXTENSION = num_ExtensionNear;



    -- Gets Far leg data

    num_Error	:= 3;



    SELECT  FX.*

    INTO    p_rec_FxFar

    FROM    "PGT_TRD".T_PGT_FX_S    FX

    WHERE   FX.FK_PARENT    = num_FxSwap

    AND     FX.FK_OWNER_OBJ = Cst_Obj_FXSwapDeliv --1761.4

    AND     FX.FK_EXTENSION = num_ExtensionFar;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, 'End ' || Cst_Package || str_Proc || ' Out - p_rec_FxNear.PK= ' || p_rec_FxNear.PK ||';'||

						     'p_rec_FxFar.PK= ' || p_rec_FxFar.PK );



EXCEPTION



    WHEN NO_DATA_FOUND THEN

    IF num_Error = 1 THEN

	str_Comments	:= 'No Data Found getting FxSwap data: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap;

    ELSIF num_Error = 2 THEN

	str_Comments	:= 'No Data Found getting Near Leg: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap;

    ELSIF num_Error = 3 THEN

	str_Comments	:= 'No Data Found getting Far Leg: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap;

    END IF;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, ' ERROR (' || Cst_Package || str_Proc || ' ): ' || str_Comments );

    "PGT_PRG".Pkg_Pgterror.p_PutErrorParcial ( Cst_Error_NoDataFound, Cst_Package || str_Proc, 1, str_Comments );

    RAISE;



    WHEN OTHERS THEN

    IF num_Error = 1 THEN

	str_Comments	:= SUBSTR(  'No Data Found getting FxSwap data: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap || '->' || SQLERRM, 1, 350 );

    ELSIF num_Error = 2 THEN

	str_Comments	:= SUBSTR(  'No Data Found getting Near Leg: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap || '->' || SQLERRM, 1, 350 );

    ELSIF num_Error = 3 THEN

	str_Comments	:= SUBSTR(  'No Data Found getting Far Leg: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap || '->' || SQLERRM, 1, 350 );

    END IF;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, ' ERROR (' || Cst_Package || str_Proc || ' ): ' || str_Comments );

    "PGT_PRG".Pkg_Pgterror.p_PutErrorParcial (	Cst_Error_Others, Cst_Package || str_Proc, 9, str_Comments );

    RAISE;



END p_GetPkNearFarDelByEvent;



/* ********************************************************************************/

/* <Procedure>	 p_InsertNearFarDelUPIAlias		      */

/* <Author>  RTEIJEIRO				  */

/* <Date>    23-05-2016 			  */

/* <Description> (28846.7) - Procedure that generates and inserts UPI Alias Code  */

/*	 as an Alternate Alias in FX Swap - Deliverable Near/Far legs	  */

/*	 (Table "PGT_TRD".T_PGT_EVENT_ALTER_ID_S).	      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_InsertNearFarDelUPIAlias

IS



    /* **************************************** */

    /* Variables		*/

    /* **************************************** */



    rec_Event	    "PGT_TRD".T_PGT_TRADE_EVENTS_S%ROWTYPE;



    rec_FxNear	    "PGT_TRD".T_PGT_FX_S%ROWTYPE;

    rec_FxFar	    "PGT_TRD".T_PGT_FX_S%ROWTYPE;



    rec_EventAlterId	"PGT_TRD".T_PGT_EVENT_ALTER_ID_S%ROWTYPE;



    str_NearAlias_Aux	VARCHAR2(100) := NULL;

    str_FarAlias_Aux	VARCHAR2(100) := NULL;

    str_NearUPI     VARCHAR2(100) := NULL;  -- UPI Alias Code for Near leg

    str_FarUPI	    VARCHAR2(100) := NULL;  -- UPI Alias Code for Far leg



    str_Proc	    VARCHAR2(100);

    str_Comments    VARCHAR2(500);

    str_Module	    VARCHAR2(50) := 'INSERT UPI ALIAS FX SWAP LEGS';



    num_EventType   NUMBER;



BEGIN



    /* ********************************************************************************* */

    /* Initialize variables				 */

    /* ********************************************************************************* */

    str_Proc := 'p_InsertNearFarDelUPIAlias';



    /* ********************************************************************************* */

    /* Initialize trace 				 */

    /* ********************************************************************************* */

    "PGT_SYS".Pkg_ApplicationInfo.p_StartModule( str_Module, NULL, 'Start ' || Cst_Package || str_Proc ||

			 ' Param - Pkg_Eventdispatcher.rec_Event.PK = ' || "PGT_PRG".Pkg_Eventdispatcher.rec_Event.PK,

			 "PGT_PRG".Pkg_Eventdispatcher.rec_Event.PK

			);



    /* ********************************************************************************* */

    /* Load Event data					 */

    /* ********************************************************************************* */

    rec_Event	:= "PGT_PRG".Pkg_Eventdispatcher.rec_Event;



    num_EventType := "PGT_PRG".Pkg_PGTUtility.f_GetEventType( rec_Event.PK );



    /* ********************************************************************************* */

    /* Load NEAR and FAR legs data			     */

    /* ********************************************************************************  */

    p_GetPkNearFarDelByEvent( rec_Event.PK, rec_FxNear, rec_FxFar );



    IF num_EventType <> "PGT_PRG".Pkg_PGTConst.CST_EV_TYPE_REGISTRY THEN -- 126.4



    NULL;



    ELSE -- Es un registry => Insertar o actualizar (si ya existe) el UPI de las patas Near y Far.



    /* ************************************************ */

    /* NEAR LEG 		    */

    /* ************************************************ */



    -- Calculamos el valor del UPI a insertar/actualizar para la pata Near

    BEGIN

	"PGT_PRG".Pkg_TradeUtility.p_CalcUPIValue( par_Event_PK => rec_Event.PK,

			       str_LegInd => 'N', -- Pata Near

			       str_UPI_Value => str_NearUPI );

    EXCEPTION

	WHEN OTHERS THEN

	str_NearUPI := NULL;

    END;



    -- Comprobamos si ya existe o no el UPI en la pata Near

    str_NearAlias_Aux := "PGT_PRG".Pkg_Pgtutility.f_GetAlterAliasSource( Cst_EquivTypeUPI, Cst_UPISource, rec_FxNear.PK, Cst_Obj_FXDeliverable, 0 );



    -- Si la funcion anterior nos devuelve un '<NOT FOUND>' (no existe el UPI) lo transformamos a NULL.

    IF str_NearAlias_Aux = '<NOT FOUND>' THEN

	str_NearAlias_Aux := NULL;

    END IF;



    -- Si no existe, entonces insertamos el UPI calculado anteriormente.

    IF str_NearAlias_Aux IS NULL THEN



	IF str_NearUPI IS NOT NULL THEN

	"PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, NULL, 'Insert FX Near UPI Alias Code', "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );

	rec_EventAlterId.FK_OWNER_OBJ	    := Cst_Obj_FXDeliverable; --1688.4

	rec_EventAlterId.FK_PARENT	:= rec_FxNear.PK; --PK del FX de la pata Near

	rec_EventAlterId.FK_EXTENSION	    := Cst_Ext_FxDel_Alter_Alias; --110030.4

	rec_EventAlterId.FK_EQUIVALENCETYPE := Cst_EquivTypeUPI; --26263.4

	rec_EventAlterId.FK_SOURCE	:= Cst_UPISource; --399.4

	rec_EventAlterId.ALIASCODE	:= str_NearUPI;

	p_InsAlterAliasSource( rec_EventAlterId );

	END IF;



    ELSE -- Si ya existe, entonces actualizamos con el UPI calculado anteriormente.



	IF str_NearUPI IS NOT NULL THEN

	"PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, NULL, 'Update FX Near UPI Alias Code', "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );

	p_UpdateAlterAliasSource( rec_FxNear.PK, Cst_Obj_FXDeliverable, Cst_Ext_FxDel_Alter_Alias, Cst_EquivTypeUPI, Cst_UPISource, str_NearUPI );

	END IF;



    END IF;



    /* ************************************************ */

    /* FAR LEG			    */

    /* ************************************************ */



    -- Calculamos el valor del UPI a insertar/actualizar para la pata Far

    BEGIN

	"PGT_PRG".Pkg_TradeUtility.p_CalcUPIValue( par_Event_PK => rec_Event.PK,

			       str_LegInd => 'F', -- Pata Far

			       str_UPI_Value => str_FarUPI );

    EXCEPTION

	WHEN OTHERS THEN

	str_FarUPI := NULL;

    END;



    -- Comprobamos si ya existe o no el UPI en la pata Far

    str_FarAlias_Aux := "PGT_PRG".Pkg_Pgtutility.f_GetAlterAliasSource( Cst_EquivTypeUPI, Cst_UPISource, rec_FxFar.PK, Cst_Obj_FXDeliverable, 0 );



    -- Si la funcion anterior nos devuelve un '<NOT FOUND>' (no existe el UPI) lo transformamos a NULL.

    IF str_FarAlias_Aux = '<NOT FOUND>' THEN

	str_FarAlias_Aux := NULL;

    END IF;



    -- Si no existe, entonces insertamos el UPI calculado anteriormente.

    IF str_FarAlias_Aux IS NULL THEN



	IF str_FarUPI IS NOT NULL THEN

	"PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, NULL, 'Insert FX Far UPI Alias Code', "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );

	rec_EventAlterId.FK_OWNER_OBJ	    := Cst_Obj_FXDeliverable; --1688.4

	rec_EventAlterId.FK_PARENT	:= rec_FxFar.PK; --PK del FX de la pata Far

	rec_EventAlterId.FK_EXTENSION	    := Cst_Ext_FxDel_Alter_Alias; --110030.4

	rec_EventAlterId.FK_EQUIVALENCETYPE := Cst_EquivTypeUPI; --26263.4

	rec_EventAlterId.FK_SOURCE	:= Cst_UPISource; --399.4

	rec_EventAlterId.ALIASCODE	:= str_FarUPI;

	p_InsAlterAliasSource( rec_EventAlterId );

	END IF;



    ELSE -- Si ya existe, entonces actualizamos con el UPI calculado anteriormente.



	IF str_FarUPI IS NOT NULL THEN

	"PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, NULL, 'Update FX Far UPI Alias Code', "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );

	p_UpdateAlterAliasSource( rec_FxFar.PK, Cst_Obj_FXDeliverable, Cst_Ext_FxDel_Alter_Alias, Cst_EquivTypeUPI, Cst_UPISource, str_FarUPI );

	END IF;



    END IF;



    END IF;



    /* ********************************************************************************* */

    /* Cargamos los datos globales			     */

    /* ********************************************************************************* */



    "PGT_PRG".Pkg_Eventdispatcher.rec_Event	:= rec_Event;



    "PGT_SYS".Pkg_ApplicationInfo.p_EndModule( 'End ' || Cst_Package || str_Proc );



EXCEPTION



    WHEN "PGT_PRG".Pkg_Pgterror.NOT_FIND_PROGRAM THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, 'ERROR', SUBSTR(SQLERRM, 1, 100 ) );

    "PGT_SYS".Pkg_ApplicationInfo.p_EndModule( 'End ' || Cst_Package || str_Proc );

    RAISE;



    WHEN "PGT_PRG".Pkg_Pgterror.PACKAGE_DISCARDED THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, 'ERROR', SUBSTR('PACKAGE DISCARDED', 1, 100 ) );

    "PGT_SYS".Pkg_ApplicationInfo.p_EndModule( 'End ' || Cst_Package || str_Proc );

    RAISE;



    WHEN OTHERS THEN

    str_Comments    := SUBSTR( 'Error in UPI Alter Alias. SQLERR: ' || SQLERRM,1,500 );

    "PGT_PRG".Pkg_Pgterror.p_PutError( "PGT_PRG".Pkg_Genconst.CST_ERR_OTHERS, Cst_Package || str_Proc, NULL, "PGT_PRG".Pkg_Pgtconst.CST_Error, str_Comments );

    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, ' ERROR (' || Cst_Package || str_Proc || ' ): ' || SQLERRM );

    "PGT_SYS".Pkg_ApplicationInfo.p_EndModule( 'End ' || Cst_Package || str_Proc );

    RAISE;



END p_InsertNearFarDelUPIAlias;



/* ********************************************************************************/

/* <Procedure>	 p_GetPkNearFarNonDelByEvent			  */

/* <Author>  RTEIJEIRO				  */

/* <Date>    23-05-2016 			  */

/* <Description> (28846.7) - Procedure that gets NEAR and FAR legs data for an	  */

/*	 FX Swap - Non Deliverable from Event PK.	      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_GetPkNearFarNonDelByEvent( p_num_Event     IN  NUMBER,

		       p_rec_FxNear    OUT PGT_TRD.T_PGT_NDF_S%ROWTYPE,

		       p_rec_FxFar     OUT PGT_TRD.T_PGT_NDF_S%ROWTYPE )

IS



    num_FxSwap	    NUMBER;

    num_DealType    NUMBER;



    num_ExtensionNear	NUMBER;

    num_ExtensionFar	NUMBER;



    num_Error	    NUMBER;



    str_Proc	    VARCHAR2(100)   := 'p_GetPkNearFarNonDelByEvent';

    str_Comments    VARCHAR2(350);



BEGIN



    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, 'Start ' || Cst_Package || str_Proc || ' Param - p_num_Event= ' || p_num_Event );



    -- Gets Fx Swap ND data

    num_Error	:= 1;



    SELECT  FXSWAP.PK,

	FXSWAP.FK_DEALTYPE

    INTO    num_FxSwap,

	num_DealType

    FROM    "PGT_TRD".T_PGT_TRADE_HEADER_S  HEADER,

	"PGT_TRD".T_PGT_FX_SWAP_S	FXSWAP

    WHERE   HEADER.FK_PARENT	    = p_num_Event

    AND     HEADER.FK_OWNER_OBJ     = Cst_Event_Ow_Header --1546.4

    AND     HEADER.FK_EXTENSION     = Cst_Event_Ex_Header --11867.4

    AND     FXSWAP.FK_PARENT	    = HEADER.PK

    AND     FXSWAP.FK_OWNER_OBJ     = Cst_Owner_TradeHeader --1476.4

    AND     FXSWAP.FK_EXTENSION     = Cst_Ext_Header_FxSwapND; --39812.4



    IF num_DealType = Cst_DealType_SpotSpot THEN --Spot/Spot 22591.4

    num_ExtensionNear	:= Cst_Ext_NonDelv_NearSpot; --39821.4

    num_ExtensionFar	:= Cst_Ext_NonDelv_FarSpot; --39870.4



    ELSIF num_DealType = Cst_DealType_SpotForward THEN --Spot/Forward 22592.4

    num_ExtensionNear	:= Cst_Ext_NonDelv_NearSpot; --39821.4

    num_ExtensionFar	:= Cst_Ext_NonDelv_FarFwd; --39822.4



    ELSIF num_DealType = Cst_DealType_ForwardForward THEN --Forward/Forward 22593.4

    num_ExtensionNear	:= Cst_Ext_NonDelv_NearFwd; --39820.4

    num_ExtensionFar	:= Cst_Ext_NonDelv_FarFwd; --39822.4

    END IF;



    -- Gets Near leg data

    num_Error	:= 2;



    SELECT  NDF.*

    INTO    p_rec_FxNear

    FROM    "PGT_TRD".T_PGT_NDF_S   NDF

    WHERE   NDF.FK_PARENT   = num_FxSwap

    AND     NDF.FK_OWNER_OBJ	= Cst_Obj_FXSwapNonDeliv --12754.4

    AND     NDF.FK_EXTENSION	= num_ExtensionNear;



    -- Gets Far leg data

    num_Error	:= 3;



    SELECT  NDF.*

    INTO    p_rec_FxFar

    FROM    "PGT_TRD".T_PGT_NDF_S   NDF

    WHERE   NDF.FK_PARENT   = num_FxSwap

    AND     NDF.FK_OWNER_OBJ	= Cst_Obj_FXSwapNonDeliv --12754.4

    AND     NDF.FK_EXTENSION	= num_ExtensionFar;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, 'End ' || Cst_Package || str_Proc || ' Out - p_rec_FxNear.PK= ' || p_rec_FxNear.PK ||';'||

						     'p_rec_FxFar.PK= ' || p_rec_FxFar.PK );



EXCEPTION



    WHEN NO_DATA_FOUND THEN

    IF num_Error = 1 THEN

	str_Comments	:= 'No Data Found getting FxSwapND data: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap;

    ELSIF num_Error = 2 THEN

	str_Comments	:= 'No Data Found getting Near ND Leg: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap;

    ELSIF num_Error = 3 THEN

	str_Comments	:= 'No Data Found getting Far ND Leg: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap;

    END IF;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, ' ERROR (' || Cst_Package || str_Proc || ' ): ' || str_Comments );

    "PGT_PRG".Pkg_Pgterror.p_PutErrorParcial ( Cst_Error_NoDataFound, Cst_Package || str_Proc, 1, str_Comments );

    RAISE;



    WHEN OTHERS THEN

    IF num_Error = 1 THEN

	str_Comments	:= SUBSTR(  'No Data Found getting FxSwapND data: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap || '->' || SQLERRM, 1, 350 );

    ELSIF num_Error = 2 THEN

	str_Comments	:= SUBSTR(  'No Data Found getting Near ND Leg: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap || '->' || SQLERRM, 1, 350 );

    ELSIF num_Error = 3 THEN

	str_Comments	:= SUBSTR(  'No Data Found getting Far ND Leg: Event= ' || p_num_Event || '; FxSwap= ' || num_FxSwap || '->' || SQLERRM, 1, 350 );

    END IF;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, ' ERROR (' || Cst_Package || str_Proc || ' ): ' || str_Comments );

    "PGT_PRG".Pkg_Pgterror.p_PutErrorParcial (	Cst_Error_Others, Cst_Package || str_Proc, 9, str_Comments );

    RAISE;



END p_GetPkNearFarNonDelByEvent;



/* ********************************************************************************/

/* <Procedure>	 p_InsertNearFarNonDelUPIAlias			  */

/* <Author>  RTEIJEIRO				  */

/* <Date>    23-05-2016 			  */

/* <Description> (28846.7) - Procedure that generates and inserts UPI Alias Code  */

/*	 as an Alternate Alias in FX Swap - Non Deliverable Near/Far legs */

/*	 (Table "PGT_TRD".T_PGT_EVENT_ALTER_ID_S).	      */

/* ------------------------------------------------------------------------------ */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	       */

/* ********************************************************************************/

PROCEDURE p_InsertNearFarNonDelUPIAlias

IS



    /* **************************************** */

    /* Variables		*/

    /* **************************************** */



    rec_Event	    "PGT_TRD".T_PGT_TRADE_EVENTS_S%ROWTYPE;



    rec_NDFNear     "PGT_TRD".T_PGT_NDF_S%ROWTYPE;

    rec_NDFFar	    "PGT_TRD".T_PGT_NDF_S%ROWTYPE;



    rec_EventAlterId	"PGT_TRD".T_PGT_EVENT_ALTER_ID_S%ROWTYPE;



    str_NearAlias_Aux	VARCHAR2(100) := NULL;

    str_FarAlias_Aux	VARCHAR2(100) := NULL;

    str_NearUPI     VARCHAR2(100) := NULL;  -- UPI Alias Code for Near leg

    str_FarUPI	    VARCHAR2(100) := NULL;  -- UPI Alias Code for Far leg



    str_Proc	    VARCHAR2(100);

    str_Comments    VARCHAR2(500);

    str_Module	    VARCHAR2(50) := 'INSERT UPI ALIAS FX SWAP ND LEGS';



    num_EventType   NUMBER;



BEGIN



    /* ********************************************************************************* */

    /* Initialize variables				 */

    /* ********************************************************************************* */

    str_Proc := 'p_InsertNearFarNonDelUPIAlias';



    /* ********************************************************************************* */

    /* Initialize trace 				 */

    /* ********************************************************************************* */

    "PGT_SYS".Pkg_ApplicationInfo.p_StartModule( str_Module, NULL, 'Start ' || Cst_Package || str_Proc ||

			 ' Param - Pkg_Eventdispatcher.rec_Event.PK = ' || "PGT_PRG".Pkg_Eventdispatcher.rec_Event.PK,

			 "PGT_PRG".Pkg_Eventdispatcher.rec_Event.PK

			);



    /* ********************************************************************************* */

    /* Load Event data					 */

    /* ********************************************************************************* */

    rec_Event	:= "PGT_PRG".Pkg_Eventdispatcher.rec_Event;



    num_EventType := "PGT_PRG".Pkg_PGTUtility.f_GetEventType( rec_Event.PK );



    /* ********************************************************************************* */

    /* Load NEAR and FAR legs data			     */

    /* ********************************************************************************  */

    p_GetPkNearFarNonDelByEvent( rec_Event.PK, rec_NDFNear, rec_NDFFar );



    IF num_EventType <> "PGT_PRG".Pkg_PGTConst.CST_EV_TYPE_REGISTRY THEN -- 126.4



    NULL;



    ELSE -- Es un registry => Insertar o actualizar (si ya existe) el UPI de las patas Near y Far.



    /* ************************************************ */

    /* NEAR LEG 		    */

    /* ************************************************ */



    -- Calculamos el valor del UPI a insertar/actualizar para la pata Near

    BEGIN

	"PGT_PRG".Pkg_TradeUtility.p_CalcUPIValue( par_Event_PK => rec_Event.PK,

			       str_LegInd => 'N', -- Pata Near

			       str_UPI_Value => str_NearUPI );

    EXCEPTION

	WHEN OTHERS THEN

	str_NearUPI := NULL;

    END;



    -- Comprobamos si ya existe o no el UPI en la pata Near

    str_NearAlias_Aux := "PGT_PRG".Pkg_Pgtutility.f_GetAlterAliasSource( Cst_EquivTypeUPI, Cst_UPISource, rec_NDFNear.PK, Cst_Obj_FXNonDeliverable, 0 );



    -- Si la funcion anterior nos devuelve un '<NOT FOUND>' (no existe el UPI) lo transformamos a NULL.

    IF str_NearAlias_Aux = '<NOT FOUND>' THEN

	str_NearAlias_Aux := NULL;

    END IF;



    -- Si no existe, entonces insertamos el UPI calculado anteriormente.

    IF str_NearAlias_Aux IS NULL THEN



	IF str_NearUPI IS NOT NULL THEN

	"PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, NULL, 'Insert NDF Near UPI Alias Code', "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );

	rec_EventAlterId.FK_OWNER_OBJ	    := Cst_Obj_FXNonDeliverable; --1505.4

	rec_EventAlterId.FK_PARENT	:= rec_NDFNear.PK; --PK del NDF de la pata Near

	rec_EventAlterId.FK_EXTENSION	    := Cst_Ext_FxNonDel_Alter_Alias; --110031.4

	rec_EventAlterId.FK_EQUIVALENCETYPE := Cst_EquivTypeUPI; --26263.4

	rec_EventAlterId.FK_SOURCE	:= Cst_UPISource; --399.4

	rec_EventAlterId.ALIASCODE	:= str_NearUPI;

	p_InsAlterAliasSource( rec_EventAlterId );

	END IF;



    ELSE -- Si ya existe, entonces actualizamos con el UPI calculado anteriormente.



	IF str_NearUPI IS NOT NULL THEN

	"PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, NULL, 'Update NDF Near UPI Alias Code', "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );

	p_UpdateAlterAliasSource( rec_NDFNear.PK, Cst_Obj_FXNonDeliverable, Cst_Ext_FxNonDel_Alter_Alias, Cst_EquivTypeUPI, Cst_UPISource, str_NearUPI );

	END IF;



    END IF;



    /* ************************************************ */

    /* FAR LEG			    */

    /* ************************************************ */



    -- Calculamos el valor del UPI a insertar/actualizar para la pata Far

    BEGIN

	"PGT_PRG".Pkg_TradeUtility.p_CalcUPIValue( par_Event_PK => rec_Event.PK,

			       str_LegInd => 'F', -- Pata Far

			       str_UPI_Value => str_FarUPI );

    EXCEPTION

	WHEN OTHERS THEN

	str_FarUPI := NULL;

    END;



    -- Comprobamos si ya existe o no el UPI en la pata Far

    str_FarAlias_Aux := "PGT_PRG".Pkg_Pgtutility.f_GetAlterAliasSource( Cst_EquivTypeUPI, Cst_UPISource, rec_NDFFar.PK, Cst_Obj_FXNonDeliverable, 0 );



    -- Si la funcion anterior nos devuelve un '<NOT FOUND>' (no existe el UPI) lo transformamos a NULL.

    IF str_FarAlias_Aux = '<NOT FOUND>' THEN

	str_FarAlias_Aux := NULL;

    END IF;



    -- Si no existe, entonces insertamos el UPI calculado anteriormente.

    IF str_FarAlias_Aux IS NULL THEN



	IF str_FarUPI IS NOT NULL THEN

	"PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, NULL, 'Insert NDF Far UPI Alias Code', "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );

	rec_EventAlterId.FK_OWNER_OBJ	    := Cst_Obj_FXNonDeliverable; --1505.4

	rec_EventAlterId.FK_PARENT	:= rec_NDFFar.PK; --PK del NDF de la pata Far

	rec_EventAlterId.FK_EXTENSION	    := Cst_Ext_FxNonDel_Alter_Alias; --110031.4

	rec_EventAlterId.FK_EQUIVALENCETYPE := Cst_EquivTypeUPI; --26263.4

	rec_EventAlterId.FK_SOURCE	:= Cst_UPISource; --399.4

	rec_EventAlterId.ALIASCODE	:= str_FarUPI;

	p_InsAlterAliasSource( rec_EventAlterId );

	END IF;



    ELSE -- Si ya existe, entonces actualizamos con el UPI calculado anteriormente.



	IF str_FarUPI IS NOT NULL THEN

	"PGT_SYS".Pkg_ApplicationInfo.p_Process( Cst_Package || str_Proc, NULL, 'Update NDF Far UPI Alias Code', "PGT_PRG".Pkg_Genconst.CST_HIGH_LEVEL );

	p_UpdateAlterAliasSource( rec_NDFFar.PK, Cst_Obj_FXNonDeliverable, Cst_Ext_FxNonDel_Alter_Alias, Cst_EquivTypeUPI, Cst_UPISource, str_FarUPI );

	END IF;



    END IF;



    END IF;



    /* ********************************************************************************* */

    /* Cargamos los datos globales			     */

    /* ********************************************************************************* */



    "PGT_PRG".Pkg_Eventdispatcher.rec_Event	:= rec_Event;



    "PGT_SYS".Pkg_ApplicationInfo.p_EndModule( 'End ' || Cst_Package || str_Proc );



EXCEPTION



    WHEN "PGT_PRG".Pkg_Pgterror.NOT_FIND_PROGRAM THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, 'ERROR', SUBSTR(SQLERRM, 1, 100 ) );

    "PGT_SYS".Pkg_ApplicationInfo.p_EndModule( 'End ' || Cst_Package || str_Proc );

    RAISE;



    WHEN "PGT_PRG".Pkg_Pgterror.PACKAGE_DISCARDED THEN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, 'ERROR', SUBSTR('PACKAGE DISCARDED', 1, 100 ) );

    "PGT_SYS".Pkg_ApplicationInfo.p_EndModule( 'End ' || Cst_Package || str_Proc );

    RAISE;



    WHEN OTHERS THEN

    str_Comments    := SUBSTR( 'Error in UPI Alter Alias. SQLERR: ' || SQLERRM,1,500 );

    "PGT_PRG".Pkg_Pgterror.p_PutError( "PGT_PRG".Pkg_Genconst.CST_ERR_OTHERS, Cst_Package || str_Proc, NULL, "PGT_PRG".Pkg_Pgtconst.CST_Error, str_Comments );

    "PGT_SYS".Pkg_ApplicationInfo.p_Process( str_Proc, NULL, ' ERROR (' || Cst_Package || str_Proc || ' ): ' || SQLERRM );

    "PGT_SYS".Pkg_ApplicationInfo.p_EndModule( 'End ' || Cst_Package || str_Proc );

    RAISE;



END p_InsertNearFarNonDelUPIAlias;



/* ******************************************************************************* */

/* <FUNCTION>	 F_Get_Parameter_noerr			       */

/* <Author>  JROJAS				   */

/* <Date>    14-10-2016 			   */

/* <Description> Gets parameter for the type (29126.7)		       */

/* ------------------------------------------------------------------------------- */

/* <Mod> versionGBO  dd-mm-yyyy - usr  idTarea	descripcion	    */

/* ******************************************************************************* */

FUNCTION F_Get_Parameter_noerr (P_Object IN NUMBER,

		P_Parent IN NUMBER,

		P_Type IN NUMBER) RETURN VARCHAR2 IS

Parameter VARCHAR2(100);



BEGIN



    SELECT PARAMETERVALUE

    INTO   Parameter

    FROM   PGT_STC.T_PGT_PARAMETER_S T1

    WHERE  T1.FK_OWNER_OBJ = P_Object

       AND T1.FK_PARENT = P_Parent

       AND T1.FK_PARAMETERTYPE = P_Type;



      RETURN(Parameter);



EXCEPTION

    WHEN NO_DATA_FOUND THEN

    RETURN NULL;

    WHEN TOO_MANY_ROWS THEN

      RETURN NULL;

    WHEN OTHERS THEN

	  RETURN NULL;



END F_Get_Parameter_noerr;



-- INICIO ELAB TECNILOGICA - SwapAgent STM - 28/06/21

/**************************************************************************************************/

/* Procedure:	P_UpdInsertAliasObjSource			      */

/* Description: Updates alias and in case alias doesn't exist it is inserted		  */

/* Parameters: Columns to insert/update in table			  */

/**************************************************************************************************/

PROCEDURE P_UpdInsertAliasObjSource(P_FK_OWNER_OBJ IN NUMBER,

		    P_FK_PARENT    IN NUMBER,

		    P_FK_EXTENSION IN NUMBER,

		    P_ALIASCODE    IN VARCHAR2,

		    P_FK_SOURCE    IN NUMBER)

IS

  num_PkSource NUMBER;

  num_FkOwner  NUMBER := P_FK_OWNER_OBJ;

BEGIN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  '***** BEGIN *****',

			  '',

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;

  BEGIN

    "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  'Checks the num_PkSource',

			  '',

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;

    SELECT PK

      INTO num_PkSource

      FROM PGT_TRD.T_PGT_OBJ_SOURCE_S

     WHERE FK_OWNER_OBJ = P_FK_OWNER_OBJ

       AND FK_PARENT	= P_FK_PARENT

       AND FK_EXTENSION = P_FK_EXTENSION

       AND FK_SOURCE	= P_FK_SOURCE;



     "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  'Gets the num_PkSource',

			  'num_PkSource: ' || num_PkSource,

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;

  EXCEPTION

    WHEN NO_DATA_FOUND THEN

      num_PkSource := 0;

  END;



  "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  'Before IF condition',

			  'num_PkSource: ' || num_PkSource,

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;



  IF num_PkSource = 0 THEN -- If it doesn't exist, inserts the aliascode

    num_PkSource := NULL;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  'Alias not exist',

			  'Before calling proc P_SetHeader',

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;



    PGT_TRD.Pkg_Sigom_Cov.P_SetHeader ('T_PGT_OBJ_SOURCE_S',

		       num_PkSource,

		       num_FkOwner);



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  'Alias not exist',

			  'After calling proc P_SetHeader',

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  'Alias not exist',

			  'Before insert',

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;

    INSERT INTO PGT_TRD.T_PGT_OBJ_SOURCE_S

	   (PK,

	FK_OWNER_OBJ,

	FK_PARENT,

	FK_EXTENSION,

	ALIASCODE,

	FK_SOURCE

	   )

    VALUES

	   (num_PkSource,

	P_FK_OWNER_OBJ,

	P_FK_PARENT,

	P_FK_EXTENSION,

	P_ALIASCODE,

	P_FK_SOURCE

	   );



    "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  'Alias dont exist',

			  'After insert',

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;

  ELSE -- In case it exists, the procedure updates aliascode

      "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			      'Alias exists',

			      'Before update',

			      "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;

    UPDATE PGT_TRD.T_PGT_OBJ_SOURCE_S

       SET ALIASCODE = P_ALIASCODE

     WHERE PK = num_PkSource

       AND ALIASCODE <> P_ALIASCODE;



     "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  'Alias exists',

			  'After update',

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;

  END IF;



  "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  'After IF condition',

			  '',

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;



  "PGT_SYS".Pkg_ApplicationInfo.p_Process(SUBSTR('Pkg_TradeUtility.P_UpdInsertAliasObjSource', 1, 50),

			  '***** END *****',

			  '',

			  "PGT_SYS".Pkg_ApplicationInfo.CST_DEBUG_TRACE_LEVEL) ;

EXCEPTION

  WHEN OTHERS THEN

    DBMS_OUTPUT.PUT_LINE( SQLCODE||' - '||SQLERRM);

    RAISE;

END P_UpdInsertAliasObjSource;

-- FIN ELAB TECNILOGICA - SwapAgent STM - 28/06/21



END Pkg_TradeUtility;
/
