component extends="com.apirone.core.controller.AbsController" {

	function list( event, rc, prc ){
		prc.title = "Preventivi";

		prc.statuses = super.fire( "status.list", [ "QUOTATION" ] );
		param rc.statusId = "";
		prc.filterStatusId = rc.statusId;

		prc.jsFiles.add( "app-quotation-list" );

		event.setView( "quotation/list" );
	}

	function plantPositions( event, rc, prc ){
		var quotation = super.fire( "Quotation.get", [ rc.id ] );
		var settings = new config.Settings();

		var baseUrl = "#settings.get( "site.repository" )#";

		prc.title = "Posizioni in pianta - Preventivo < " & quotation.getName() & " >";

		prc.baseUrl = baseUrl;
		prc.quotation = quotation;

		prc.page = getData( quotation.getVatCode()?.getId() ?: "" ).page;
		prc.page[ "quotation" ] = { "id" = quotation.getId() };
		prc.page[ "canEdit" ]   = true;
		prc.page[ "canSee" ]    = false;
		prc.page[ "canRevise" ] = false;

		prc.cssFiles.add( "quotation" );
		prc.jsFiles.add( "app-quotation-plant-positions" );
		prc.jsFiles.add( "app-quotation-export-code" );
		prc.jsFiles.add( "app-quotation-pricing" );
		prc.jsFiles.add( "app-quotation-plate-designer" );
		prc.jsFiles.add( "app-quotation-plate-vue" );
		prc.jsFiles.add( "app-quotation-signage" );
		prc.jsFiles.add( "app-quotation-accessory" );

		event.setView( "quotation/plant-positions" );
	}

	function new( event, rc, prc ){
		prc.isEditing = false;

		prc.title = "Nuovo preventivo";
		rc.id     = 0;

		prc.page = getData().page;

		prc.jsFiles.add( "app-quotation-header" );
		prc.cssFiles.add( "quotation" );

		event.setView( "quotation/new" );
	}

	function edit( event, rc, prc ){
		param prc.id = "___invalid___";

		var memy = super.getMementify();

		prc.isEditing = true;

		var quotation = super.fire( "Quotation.get", [ rc.id ] );

		var user = session.user;
		if (!isNull(user) && !isNull(user.getRole()) && user.getRole().getId() == 'CMJ' && quotation.getOwner().getId() != user.getId()) {
        	relocate( uri="/manager/dashboard", postProcessExempt=false, addToken=false );
			return;
		}
		// Agente: solo i preventivi in cui è uno dei 5 agenti
		if (!isNull(user) && !isNull(user.getRole()) && user.getRole().getId() == 'AGE' && !quotation.hasAgent( user.getAccount().getId() )) {
        	relocate( uri="/manager/dashboard", postProcessExempt=false, addToken=false );
			return;
		}
		if (!isNull(user) && !isNull(user.getRole()) && user.getRole().getId() == 'PRO' && quotation.getStatusHistory().getStatus().getId() != 'CON') {
        	relocate( uri="/manager/dashboard", postProcessExempt=false, addToken=false );
			return;
		}

		prc.title     = "Modifica preventivo < #quotation.getQuotationNumber()# / #quotation.getVersionNumber()# > ";

		prc.quotation = quotation;

		prc.page = getData( quotation.getVatCode()?.getId() ?: "" ).page;
		prc.page[ "quotation" ]["id"] = quotation.getId();
		prc.page[ "quotation" ]["exported"] = quotation.getExported();
		prc.page[ "quotation" ]["sentToClient"] = quotation.getSentToClient() ?: false;

		// I totali si calcolano da subito ( QuotationPriceService.ensure ), senza
		// aspettare il primo "Salva".
		super.service( "QuotationPrice" ).ensure( quotation.getId() );

		// Finché il preventivo non è stato calcolato non esiste un QuotationPrice:
		// le stampe che riportano prezzi e totali non hanno i dati per esistere.
		// Il modale di stampa usa questo flag per lasciare disponibile la sola
		// stampa foto (vedi app-quotation-detail.js).
		prc.page[ "quotation" ]["priceCalculated"] = !IsNull(
			super.fire( "QuotationPrice.getByQuotationId", [ quotation.getId() ] )
		);

		var baseCanEdit = (
			ArrayContains(['ADM', 'CMA', 'TCD', 'TCS', 'TCJ'], user.getRole().getId()) ||
			(
				( quotation.getOwner().getId() == user.getId() || quotation.getSalesAgent().getId() == user.getId() ) &&
				quotation.getStatusHistory().getStatus().getOrderBy() < 20
			)
		);
		// Inviato al cliente o convertito in ordine: non si modifica più,
		// si crea una revisione ( Quotation.lockReason ). La revisione si può creare
		// in qualunque stato, anche dal proprietario / commerciale, che a stato
		// avanzato perde baseCanEdit.
		var isLocked = quotation.isLocked();
		var isOwnerOrAgent = quotation.getOwner().getId() == user.getId()
			|| ( !IsNull( quotation.getSalesAgent() ) && quotation.getSalesAgent().getId() == user.getId() );
		prc.page[ "canEdit" ] = baseCanEdit && !isLocked;
		prc.page[ "canRevise" ] = (
			ArrayContains(['ADM', 'CMA', 'TCD', 'TCS', 'TCJ'], user.getRole().getId()) || isOwnerOrAgent
		);
		prc.page[ "lockReason" ] = quotation.lockReason();
		// Si esporta solo un preventivo concluso: "Approvato" o "Confermato da
		// cliente" ( Quotation.isExportable ). Non dipende dal blocco: un preventivo
		// inviato al cliente si esporta lo stesso. Esportato, diventa "Convertito in ordine".
		prc.page[ "canExport" ] = quotation.isExportable() && (
			ArrayContains(['ADM', 'CMA', 'TCD', 'TCS', 'TCJ'], user.getRole().getId()) || isOwnerOrAgent
		);
		prc.page[ "canSee" ] = user.getRole().getId() == 'CMS' || prc.page[ "canEdit" ] == false || user.getRole().getId() == 'PRO';

		prc.jsFiles.add( "app-quotation-header" );
		prc.jsFiles.add( "app-quotation-status" );
		prc.jsFiles.add( "app-quotation-detail" );
		prc.jsFiles.add( "app-quotation-export-code" );
		prc.jsFiles.add( "app-quotation-pricing" );

		prc.jsFiles.add( "app-quotation-plate-designer" );
		prc.jsFiles.add( "app-quotation-plate-vue" );
		prc.jsFiles.add( "app-quotation-signage" );
		prc.jsFiles.add( "app-quotation-accessory" );
		prc.jsFiles.add( "app-quotation-article" );
		prc.jsFiles.add( "app-quotation-documents" );
		prc.jsFiles.add( "app-file" );

		prc.cssFiles.add( "quotation" );

		// event.setView( "quotation/header" );
		event.setView( "quotation/detail" );
	}


	/*
		private methods
	*/

	// vatCodeId: il codice IVA del preventivo aperto, che resta nella tendina anche se non più attivo
	private function getData( String vatCodeId = "" ){
		var page = {};
		var memy = super.getMementify();

		page[ "userRole"]        = [ "id": session.user.getRole().getId(), "quotationMaxAmount": session.user.getRole().getQuotationMaxAmount(), "quotationMaxDiscount": session.user.getRole().getQuotationMaxDiscount() ];
		page[ "statuses" ]       = memy.convertList( super.fire( "status.list", [ "QUOTATION" ] ) );
		page[ "itemStatuses" ]   = memy.convertList( super.fire( "status.list", [ "QUOTATION_ITEM" ] ) );
		page[ "languages" ]      = memy.convertList( super.fire( "lang.list" ) );
		page[ "paymentMethods" ] = memy.convertList( super.fire( "paymentMethod.list" ) );
		page[ "currencies" ]     = memy.convertList( super.fire( "currency.list" ) );
		page[ "frames" ]         = memy.convertList( super.fire( "frame.list" ), "minimal" );
		page[ "vatCodes" ]       = memy.convertList( super.fire( "vatCode.list", { activeOnly = true, includeId = arguments.vatCodeId } ) );
		page[ "techUsers" ]      = memy.convertList( super.fire( "user.list", { roleTypeId="TEC", hasUtenteVerticale=true } ) );
		page[ "saleUsers" ]      = memy.convertList( super.fire( "user.list", { roleTypeId="COM", hasUtenteVerticale=true } ) );

		return { "page" = page }

	}

}
