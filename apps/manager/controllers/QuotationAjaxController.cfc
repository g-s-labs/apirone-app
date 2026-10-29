component extends="com.apirone.core.controller.AbsController" {

	function listCategories( event, rc, prc ){
		var data = [];

		var result = super.getResult();
		var params = super.paramsFromUrl();
		var mem    = super.getMementify();

		params[ "typeId" ] = rc.typeId;

		var rows = super.fire( "productCategory.list" );
		var data = mem.convertList( rows, "list" );

		result.setTotal( rows.len() );
		result.setCount( rows.len() );
		result.setData( data );

		event.setValue( "result", result );
	}

	function listLines( event, rc, prc ){
		var data = [];

		var result = super.getResult();
		var params = super.paramsFromUrl();
		var mem    = super.getMementify();

		params[ "catalogBundleCategoryId" ] = rc.categoryId;

		var rows = super.fire( "line.list", params );

		var data = mem.convertList( rows, "list" );

		result.setTotal( rows.len() );
		result.setCount( rows.len() );
		result.setData( data );

		event.setValue( "result", result );
	}

	function listModels( event, rc, prc ){
		var data = [];

		var result = super.getResult();
		var params = super.paramsFromUrl();
		var mem    = super.getMementify();

		param rc.catalogBundleCategoryId = "";

		params[ "catalogBundleLineId" ] = rc.lineId;

		if( Len( rc.catalogBundleCategoryId ) ){
			params[ "catalogBundleCategoryId" ] = rc.catalogBundleCategoryId;
		}

		// nei configuratori si propongono solo modelli con prodotti attivi: un bundle
		// vuoto ( es. CARBON / COMPOSIZIONE ) comparirebbe senza portare a nessuna finitura
		params[ "withActiveProducts" ] = true;
		params[ "includeProductId" ]   = super.service( "CatalogUsage" ).quotationItemProductId( rc.quotationItemId ?: "" );
		StructDelete( params, "quotationItemId" );

		var rows = super.fire( "model.list", params );

		var data = mem.convertList( rows, "list" );

		result.setTotal( rows.len() );
		result.setCount( rows.len() );
		result.setData( data );

		event.setValue( "result", result );
	}

	function listFinishes( event, rc, prc ){
		var data = [];

		var result = super.getResult();
		var params = super.paramsFromUrl();
		var mem    = super.getMementify();

		params[ "lineId" ]            = rc.lineId;
		params[ "productCategoryId" ] = rc.categoryId;

		// Con il modello si propongono solo le finiture che per quel modello hanno un
		// prodotto attivo: filtrando per sola linea comparivano finiture che per il
		// modello scelto non esistono ( la ricerca del prodotto poi non trovava nulla ).
		param rc.modelId = "";
		if ( Len( rc.modelId ) ) {
			params[ "modelId" ] = rc.modelId;
		}
		params[ "withActiveProducts" ] = true;
		// riga in modifica: il suo prodotto conta anche se eliminato dal catalogo
		params[ "includeProductId" ]   = super.service( "CatalogUsage" ).quotationItemProductId( rc.quotationItemId ?: "" );
		StructDelete( params, "quotationItemId" );

		var rows = super.fire( "finish.list", params );
		var data = mem.convertList( rows, "list" );

		result.setTotal( rows.len() );
		result.setCount( rows.len() );
		result.setData( data );

		event.setValue( "result", result );
	}

	function list( event, rc, prc ){
		var data = [];
		var result = super.getResult();
		var params = super.paramsFromUrl();
		var mem    = super.getMementify();
		var user = session.user;
		if (!isNull(user) && !isNull(user.getRole())) {
			if (user.getRole().getId() == 'CMJ') {
				params['ownerId'] = user.getId();
			}
			// Agente: solo i preventivi in cui è uno dei 5 agenti
			if (user.getRole().getId() == 'AGE') {
				params['agentAccountId'] = user.getAccount().getId();
			}
			if (user.getRole().getId() == 'PRO') {
				params['statusId'] = 'CON';
			}
		}
		var rows = super.fire( "quotation.search", params );
		var data = mem.convertList( rows.getData() );

		result.setTotal( rows.getTotal() );
		result.setCount( rows.getCount() );
		result.setData( data );

		event.setValue( "result", result );
	}

	function save( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		if ( super.rejectIfQuotationLocked( event, json.id ?: "" ) ) return;

		var thisId    = "";
		var messageId = "";
		var result    = super.getResult();

		var currency      = super.bean( "Currency" );
		var quotation     = super.bean( "Quotation" );
		var paymentMethod = super.bean( "PaymentMethod" );

		quotation.setId( json.id );
		quotation.setName( json.name );
		//quotation.setQuotationNumber( json.quotationNumber );
		quotation.setOwner( session.user );

		quotation.setValidityDate( IsDate( json?.validityDate ) ? json.validityDate : NullValue() );
		quotation.setQuotationDate( IsDate( json?.quotationDate ) ? json.quotationDate : NullValue() );
		quotation.setNote( json.note );

		quotation.setActive( true );
		quotation.setLang( super.fire( "lang.get", [ json.lang.id ] ) );


		if ( Val( json?.vatCode?.id ) ) {
			quotation.setVatCode( super.fire( "vatCode.get", [ json.vatCode.id ] ) );
		};

		if ( Len( json?.opportunity?.id ) ) {
			quotation.setOpportunity( super.fire( "opportunity.get", [ json.opportunity.id ] ) );
		};

		if ( Len( json?.lead?.id ) ) {
			quotation.setLead( super.fire( "lead.get", [ json.lead.id ] ) );
		};

		if ( Len( json?.customer?.id ) ) {
			quotation.setCustomer( super.fire( "customer.get", [ json.customer.id ] ) )
		}

		if ( Len( json?.salesAgent?.id ) ) {
			quotation.setSalesAgent( super.fire( "user.get", [ json.salesAgent.id ] ) )
		}

		if ( Len( json?.graphicTechnician?.id ) ) {
			quotation.setGraphicTechnician( super.fire( "user.get", [ json.graphicTechnician.id ] ) )
		}

		if ( Len( json?.shippingProfile?.id ) ) {
			quotation.setShippingProfile( super.bean("ShippingProfile").setId( json.shippingProfile.id ) );
		}

		quotation.setPaymentMethod( paymentMethod.setId( json.paymentMethod.id ) );
		quotation.setCurrency( currency.setId( json.currency.id ) );

		quotation.setNessunAgente( json.nessunAgente );

		var _ag1 = json.agente1;
		if ( !isNull(_ag1) ) {
			if ( isStruct(_ag1) && !isNull(_ag1.id) && len(_ag1.id) ) { quotation.setAgente1( _ag1.id ); }
			else if ( !isStruct(_ag1) && len(_ag1) ) { quotation.setAgente1( _ag1 ); }
		}
		var _ag2 = json.agente2;
		if ( !isNull(_ag2) ) {
			if ( isStruct(_ag2) && !isNull(_ag2.id) && len(_ag2.id) ) { quotation.setAgente2( _ag2.id ); }
			else if ( !isStruct(_ag2) && len(_ag2) ) { quotation.setAgente2( _ag2 ); }
		}
		var _ag3 = json.agente3;
		if ( !isNull(_ag3) ) {
			if ( isStruct(_ag3) && !isNull(_ag3.id) && len(_ag3.id) ) { quotation.setAgente3( _ag3.id ); }
			else if ( !isStruct(_ag3) && len(_ag3) ) { quotation.setAgente3( _ag3 ); }
		}
		var _ag4 = json.agente4;
		if ( !isNull(_ag4) ) {
			if ( isStruct(_ag4) && !isNull(_ag4.id) && len(_ag4.id) ) { quotation.setAgente4( _ag4.id ); }
			else if ( !isStruct(_ag4) && len(_ag4) ) { quotation.setAgente4( _ag4 ); }
		}
		var _ag5 = json.agente5;
		if ( !isNull(_ag5) ) {
			if ( isStruct(_ag5) && !isNull(_ag5.id) && len(_ag5.id) ) { quotation.setAgente5( _ag5.id ); }
			else if ( !isStruct(_ag5) && len(_ag5) ) { quotation.setAgente5( _ag5 ); }
		}

		if ( !isNull(json.commission1) && isNumeric(json.commission1) ) quotation.setCommission1( json.commission1 );
		if ( !isNull(json.commission2) && isNumeric(json.commission2) ) quotation.setCommission2( json.commission2 );
		if ( !isNull(json.commission3) && isNumeric(json.commission3) ) quotation.setCommission3( json.commission3 );
		if ( !isNull(json.commission4) && isNumeric(json.commission4) ) quotation.setCommission4( json.commission4 );
		if ( !isNull(json.commission5) && isNumeric(json.commission5) ) quotation.setCommission5( json.commission5 );
		if ( !isNull(json.referenteAmministrativo) ) quotation.setReferenteAmministrativo( json.referenteAmministrativo );
		if ( !isNull(json.referenteSpedizione) ) quotation.setReferenteSpedizione( json.referenteSpedizione );
		if ( !isNull(json.customerType) ) quotation.setCustomerType( json.customerType );
		if ( !isNull(json.industry) ) quotation.setIndustry( json.industry );
		if ( !isNull(json.rifLibero) ) quotation.setRifLibero( json.rifLibero );
		if ( !isNull(json.po) ) quotation.setPo( json.po );
		if ( !isNull(json.reclamoAnno) ) quotation.setReclamoAnno( Left( Trim( json.reclamoAnno ), 4 ) );
		if ( !isNull(json.reclamoNumero) && IsNumeric(json.reclamoNumero) ) quotation.setReclamoNumero( Int( json.reclamoNumero ) );
		if ( !isNull(json.reclamoAlfa) ) quotation.setReclamoAlfa( Left( Trim( json.reclamoAlfa ), 2 ) );
		// la modalità di pagamento vale solo con il pagamento 26 SCADENZE DA IMPUTARE
		if ( !isNull(json.customPaymentMethod) ) {
			quotation.setCustomPaymentMethod( quotation.getPaymentMethod().getId() == 26 ? Left( Trim( json.customPaymentMethod ), 255 ) : "" );
		}
		if ( structKeyExists(json, "dataEvasione") && !isNull(json.dataEvasione) && IsDate(json.dataEvasione) ) quotation.setDataEvasione( json.dataEvasione );
		if ( !isNull(json.codiceSdi) ) quotation.setCodiceSdi( json.codiceSdi );

		if ( !Len( json.id ) ) {

			thisId = super.fire( "quotation.create", [ quotation, session.user.getId() ] );
			messageId = "quotation.created";

		} else {
			thisId    = super.fire( "quotation.update", [ quotation ] )
			messageId = "quotation.updated";
		}

		var message = completeMessage( messageId );

		result.setData( { "message" = message, "payload" = { "id" = thisId }, "error" = {} } );
		event.setValue( "result", result );
	}

	function approveQuotation( event, rc, prc ) {
		var thisId = "";
		var message = "Preventivo approvato.";
		var result    = super.getResult();

		var isValid = true;
		var quotationId = rc.id

		try {
			transaction {
				var history = super.bean( "QuotationStatusHistory" );
				history.setQuotationId( quotationId );
				history.setUser( session.user );
				var quotation = super.fire( 'quotation.get', [ quotationId ] );
				var userRole = session.user.getRole().getId();

				// Blocca se il preventivo è già in stato "In approvazione".
				if ( !IsNull( quotation.getStatusHistory() ) && !IsNull( quotation.getStatusHistory().getStatus() ) && quotation.getStatusHistory().getStatus().getId() == 'PEN' ) {
					result.setData( { "message" = "Questo preventivo è già in attesa di approvazione.", "error" = {} } );
					result.setStatus( 'warning' );
					event.setValue( "result", result );
					return;
				}

				if ( !super.isQuotationApprover() ) {
					var totals = getTotals(quotationId).pricing
					var totalPrice = totals.total

					if (session.user.getRole().getQuotationMaxAmount() && session.user.getRole().getQuotationMaxAmount() > 0 && totalPrice > session.user.getRole().getQuotationMaxAmount()) {
						isValid = false;
						message = "Approvazione rimandata ad un superiore, il prezzo totale del preventivo è " & numberFormat( totalPrice, "999,999.00" ) & " €, ed è maggiore del tuo massimale: " & numberFormat( session.user.getRole().getQuotationMaxAmount(), "999,999.00" ) &  " €";

						history.setStatus( super.fire( 'status.get', [ 'PEN' ] ) );
						super.fire('QuotationStatusHistory.create', [ history ] );

						result.setData( { "message" = message, "error" = {} } );
						result.setStatus('warning')
						event.setValue( "result", result );
						return;
					}

					if (isValid) {
						var quotationDiscount1 = totals.discount1
						var quotationDiscount2 = totals.discount2

						var quotationItems = super.fire( 'QuotationItem.list', [ quotationId = quotationId ] )

						for (var quotationItem in quotationItems) {
							if (!isNull(quotationItem.getArticle())) {
								continue;
							}
							isValid = super.fire( 'QuotationItem.validateQuantity', [ quotation, quotationItem ])
							if (!IsValid) {
								var message = "C'è almeno un prodotto nel preventivo che sfora le quantità minima o massima. Approvazione rimandata ad un superiore.";

								history.setStatus( super.fire( 'status.get', [ 'PEN' ] ) );
								super.fire('QuotationStatusHistory.create', [ history ] );

								result.setData( { "message" = message, "error" = {} } );
								result.setStatus('warning')
								event.setValue( "result", result );
								return;
							}
							isValid = super.fire( 'QuotationItem.validateDiscounts', [
								session.user.getRole().getQuotationMaxDiscount(),
								quotationDiscount1,
								quotationDiscount2,
								quotationItem.getPrice().getDiscount1(),
								quotationItem.getPrice().getDiscount2()
							])

							if (!IsValid) {
								var message = "C'è almeno una riga del preventivo che supera il tuo massimale di sconto. Approvazione rimandata ad un superiore.";

								history.setStatus( super.fire( 'status.get', [ 'PEN' ] ) );
								super.fire('QuotationStatusHistory.create', [ history ] );

								result.setData( { "message" = message, "error" = {} } );
								result.setStatus('warning')
								event.setValue( "result", result );
								return;
							}
						}
					}
				}

				history.setStatus( super.fire( 'status.get', [ 'APR' ] ) );
				super.fire('QuotationStatusHistory.create', [ history ] );
			}
		} catch (e) {
			message = "Errore durante l'approvazione del preventivo: " & e.Message
			result.setData( { "message" = message, "error" = {} } );
			result.setStatus('error')
			event.setValue( "result", result );
		}


		result.setData( { "message" = message, "error" = { } } );
		event.setValue( "result", result );
	}

	function markAsSent( event, rc, prc ) {
		var result = super.getResult();
		try {
			var quotation = super.fire( 'quotation.get', [ rc.id ] );

			// Solo un preventivo approvato ( APR o stati successivi ) può andare al
			// cliente: in lavorazione o in attesa di approvazione no, nemmeno
			// chiamando l'endpoint direttamente.
			var approved = super.fire( 'status.get', [ 'APR' ] );
			if ( IsNull( quotation.getStatusHistory() ) || IsNull( quotation.getStatusHistory().getStatus() )
				|| quotation.getStatusHistory().getStatus().getOrderBy() < approved.getOrderBy() ) {
				result.setData( { "message" = "Il preventivo non è ancora approvato: non può essere contrassegnato come inviato al cliente.", "error" = {} } );
				result.setStatus( 'error' );
				event.setValue( "result", result );
				return;
			}

			quotation.setSentToClient( true );
			super.fire( 'quotation.update', [ quotation ] );
			result.setData( { "message" = "Preventivo contrassegnato come inviato al cliente.", "error" = {} } );
		} catch (e) {
			result.setData( { "message" = "Errore: " & e.Message, "error" = {} } );
			result.setStatus( 'error' );
		}
		event.setValue( "result", result );
	}

	function createRevision( event, rc, prc ) {
		var result = super.getResult();
		try {
			var quotation = super.fire( 'quotation.get', [ rc.id ] );
			var newId = super.fire( 'Quotation.createRevision', { 'quotation': quotation } );
			result.setData( { "message" = "Revisione creata.", "payload" = { "id" = newId }, "error" = {} } );
		} catch (e) {
			result.setData( { "message" = "Errore: " & e.Message, "error" = {} } );
			result.setStatus( 'error' );
		}
		event.setValue( "result", result );
	}

	/**
	 * Cosa non è più a catalogo nelle righe del preventivo: revisione e duplica
	 * non copiano quelle righe, l'utente va avvisato prima.
	 */
	function notInCatalog( event, rc, prc ) {
		var result = super.getResult();
		result.setData( { "labels" = super.service( "CatalogUsage" ).deletedInQuotation( rc.id ).labels } );
		event.setValue( "result", result );
	}

	function clone( event, rc, prc ) {
		var result = super.getResult();
		try {
			var quotation = super.fire( 'quotation.get', [ rc.id ] );
			var newId = super.fire( 'Quotation.clone', { 'quotation': quotation } );
			result.setData( { "message" = "Preventivo duplicato.", "payload" = { "id" = newId }, "error" = {} } );
		} catch (e) {
			result.setData( { "message" = "Errore: " & e.Message, "error" = {} } );
			result.setStatus( 'error' );
		}
		event.setValue( "result", result );
	}

	function setQuotationStatusHistory(json) {
		var quotationStatusHistories = super.fire( "QuotationStatusHistory.list", [ "quotationId" = json.id ] );
		//gli status history sono ordinati per data creazione decrescente, quindi cerco l'ultimo e verifico che lo status sia diverso. Se è diverso ne creo uno nuovo, altrimenti sono in modifica.
		if ( quotationStatusHistories.len() > 0 && quotationStatusHistories[1].getStatus().getId() == json.status.id ) {
			var quotationStatusHistory = quotationStatusHistories[1];
			thisId = quotationStatusHistory.getId();
		} else {
			var quotationStatusHistory = super.bean( "QuotationStatusHistory" );
			quotationStatusHistory.setQuotationId( json.id );
			quotationStatusHistory.setAccount( session.user.getAccount() );
			quotationStatusHistory.setStatus( super.service( "Status" ).get( json.status.id ) );
			messageId = "quotationStatusHistory.created";
			thisId    = super.fire( "quotationStatusHistory.create", [ quotationStatusHistory ] );
		}

		if ( StructKeyExists( json, "statusFile" ) AND json.status.id == 'CCN' ) {
			var tmpDir = getTempDir();
			var extension = super.fire( "File.getExtensionFromDataUrl", [ json.statusFile.file ] );
			if (IsNull(extension)) {
				return "Formato File non valido.";
			}
			fileName   = "quotation_status_history_" & json.id & "_" & json.status.id & "." & extension;
			filePath   = tmpDir & "/" & fileName;
			binaryData = ToBinary( json.statusFile.file );

			FileWrite( filePath, binaryData );

			var files = super.fire( "File.search", { quotationStatusHistoryId = thisId } );
			if ( Len( files.getData() ) ) {
				for ( var file in files.getData() ) {
					super.fire( "File.delete", { fileId = file.getId() } );
				}
			}

			var entity = super.bean( "Entity" );

			var kindId = "quotationStatusHistory";
			entity.setKey( "quotationStatusHistory.id" );
			entity.setValue( thisId );

			var fileId = super.fire(
				"file.create",
				{
					filePath = filePath,
					typeId   = "default",
					kindId   = kindId,
					entity   = entity
				}
			);
		}

		return null;
	}

	function delete( event, rc, prc ){
		var result    = super.getResult();
		var messageId = "quotation.deletedAllRecords";

		var errors  = [];
		var payload = "";

		var id = rc.id
		var outcome = super.fire( "quotation.delete", [ id ] );

		if ( outcome.getStatus() == "ERROR" ) {
			errors.add( { "message" = "Non sono riuscito a cancellare l'Id #id#" } )
		}

		if ( errors.len() ) {
			messageId = "quotation.deletedNotAllRecords"
			payload   = { "errors" = errors };
		}

		var message = super.completeMessage( messageId );

		result.setData( { "message" = message, "payload" = payload } );

		event.setValue( "result", result );
	}

	function crmCustomers( event, rc, prc ){
		param rc.str = "";

		var result = super.getResult();
		var mem    = super.getMementify();

		var rows = super.fire( "customer.search", [ rc.str ] );
		var data = mem.convertList( rows.getData() );

		result.setTotal( rows.getTotal() );
		result.setData( data );

		event.setValue( "result", result );
	}

	function crmOpportunities( event, rc, prc ){
		param rc.str = "";

		var result = super.getResult();
		var mem    = super.getMementify();

		var rows = super.fire( "opportunity.search", [ rc.str ] );
		var data = mem.convertList( rows.getData() );

		result.setTotal( rows.getTotal() );
		result.setData( data );

		event.setValue( "result", result );
	}

	function crmLeads( event, rc, prc ){
		param rc.str = "";

		var result = super.getResult();
		var memy   = super.getMementify();

		var rows = super.fire( "lead.search", [ rc.str ] );

		var data = memy.convertList( rows.getData() );

		result.setTotal( rows.getTotal() );
		result.setData( data );

		event.setValue( "result", result );
	}

	function get( event, rc, prc ){
		var result = super.getResult();
		var memy   = super.getMementify();

		var bean = super.fire( "Quotation.get", [ rc.id ] );
		var data = memy.convert( bean, "detail" );

		event.setValue( "result", data );
	}

	function updateTotals( event, rc, prc ){

		if ( super.rejectIfQuotationLocked( event, rc.id ) ) return;

		var json = DeserializeJSON( GetHTTPRequestData().content );

		var pricing = super.bean( "QuotationPrice" );
		var service = super.service( "QuotationPrice" );

		pricing.setQuotationId( rc.id );
		pricing.setDiscount1( Val( json?.discount1 ) ? json.discount1 : 0 );
		pricing.setDiscount2( Val( json?.discount2 ) ? json.discount2 : 0 );
		pricing.setFlatDiscount( Val( json?.flatDiscount ) ? json.flatDiscount : 0 );

		pricing.setShippingCost( Len( json?.shippingCost ) ? json.shippingCost : 0 );

		service.save( pricing );

		if ( StructKeyExists( json, "noteTrasporto" ) ) {
			super.service( "Quotation" ).updateNoteTrasporto( rc.id, json.noteTrasporto ?: "" );
		}

		var data = getTotals( rc.id );

		event.setValue( "result", data );

	}

	function totals( event, rc, prc ){

		var data = getTotals( rc.id );

		event.setValue( "result", data );

	}

	function export( event, rc, prc ){
		setting requestTimeout=300;
		var data = [];

		var result = super.getResult();
		var params = super.paramsFromUrl();

		params[ "id" ] = rc.id;

		// Solo un preventivo "Approvato" o "Confermato da cliente", anche
		// chiamando l'endpoint direttamente.
		var quotation = super.fire( "Quotation.get", [ rc.id ] );
		if ( !quotation.isExportable() ) {
			event.setValue( "result", {
				"success" = false,
				"error"   = "Si può esportare solo un preventivo in stato ""Approvato"" o ""Confermato da cliente""."
			} );
			return;
		}

		var quotationItems = super.fire( "QuotationItem.list", [ "quotationId" = rc.id ] );
		var result         = exportProductsAndQuotation( quotationItems );

		if (result.success) {
			quotation.setExported( true );
			quotation.setDataConfermaOrdine( Now() );
			super.fire( "quotation.update", [ quotation ] );

			var history = super.bean( "QuotationStatusHistory" );
			history.setQuotationId( quotation.getId() );
			history.setUser( session.user );
			history.setStatus( super.fire( 'status.get', [ 'CON' ] ) );
			super.fire( 'QuotationStatusHistory.create', [ history ] );
		}

		event.setValue( "result", result );
	}

	/**
	 * Esportazione unica verso Verticale: prima gli articoli ( il preventivo non
	 * si può scrivere finché i suoi articoli non hanno un codice esportato ), poi
	 * il preventivo. Il risultato del preventivo porta con sé quello degli
	 * articoli in "products", così la modale di riepilogo li mostra entrambi
	 * anche quando il secondo passo fallisce.
	 */
	private Struct function exportProductsAndQuotation( required Array quotationItems ){
		var productsResult = super.fire( "Quotation.exportProducts", [ arguments.quotationItems ] );

		if ( !productsResult.success || !IsNull( productsResult.error ) ) {
			return {
				"success"  = false,
				"error"    = productsResult.error ?: "Errore durante l'esportazione articoli.",
				"products" = productsResult
			};
		}

		var result = super.fire( "Quotation.export", [ arguments.quotationItems ] );
		result[ "products" ] = productsResult;

		return result;
	}


	/*
		private methods
	*/

	private Struct function getQuantities( quotationId ){

		var acc = super.service( "QuotationItem" ).list( quotationId = quotationId, typeId = "ACC" );
		var accQuantity = 0;
		var accessoriesTotalPrice = 0;
		for ( var item in acc ) {
			var zone = item.getQuotationZone()
			var originZone = zone.getOrigin()
			var zoneQuantity = zone.getQuantity();
			if (!isNull(originZone)) {
				zoneQuantity *= originZone.getQuantity()
			}
			accQuantity += item.getQuantity() * zoneQuantity;
			accessoriesTotalPrice += item.getQuantity() * zoneQuantity * item.getPrice().getTotal();
		}
		var pla = super.service( "QuotationItem" ).list( quotationId = quotationId, typeId = "PLA" );
		var plaQuantity = 0;
		var platesTotalPrice = 0;
		for ( var item in pla ) {
			var zone = item.getQuotationZone()
			var originZone = zone.getOrigin()
			var zoneQuantity = zone.getQuantity();
			if (!isNull(originZone)) {
				zoneQuantity *= originZone.getQuantity()
			}
			plaQuantity += item.getQuantity() * zoneQuantity;
			platesTotalPrice += item.getQuantity() * zoneQuantity * item.getPrice().getTotal();
		}
		var seg = super.service( "QuotationItem" ).list( quotationId = quotationId, typeId = "SEG" );
		var segQuantity = 0;
		var signagesTotalPrice = 0;
		for ( var item in seg ) {
			var zone = item.getQuotationZone()
			var originZone = zone.getOrigin()
			var zoneQuantity = zone.getQuantity();
			if (!isNull(originZone)) {
				zoneQuantity *= originZone.getQuantity()
			}
			segQuantity += item.getQuantity() * zoneQuantity;
			signagesTotalPrice += item.getQuantity() * zoneQuantity * item.getPrice().getTotal();
		}
		var art = super.service( "QuotationItem" ).list( quotationId = quotationId, typeId = "ART" );
		var artQuantity = 0;
		var articlesTotalPrice = 0;
		for ( var item in art ) {
			var zone = item.getQuotationZone()
			var originZone = zone.getOrigin()
			var zoneQuantity = zone.getQuantity();
			if (!isNull(originZone)) {
				zoneQuantity *= originZone.getQuantity()
			}
			artQuantity += item.getQuantity() * zoneQuantity;
			articlesTotalPrice += item.getQuantity() * zoneQuantity * item.getPrice().getTotal();
		}

		var data = {
			"accessories" = accQuantity,
			"accessoriesTotalPrice" = accessoriesTotalPrice,
			"plates" = plaQuantity,
			"platesTotalPrice" = platesTotalPrice,
			"signages" = segQuantity,
			"signagesTotalPrice" = signagesTotalPrice,
			"articles" = artQuantity,
			"articlesTotalPrice" = articlesTotalPrice,
		}

		return data;

	}

	function draftCount( event, rc, prc ){
		var result = super.getResult();
		var count  = super.fire( "QuotationItemDraft.countByQuotation", [ rc.id ] );
		result.setData( { "count" = count } );
		event.setValue( "result", result );
	}

	public Struct function getTotals( quotationId ){

		var service = super.service( "QuotationPrice" );

		service.ensure( quotationId );
		var result = service.calculate( quotationId );
		var counters = getQuantities( quotationId );

		var values = result.getCalculatedTotals();
		// non è un totale ma sta nel riquadro, accanto alle spese di trasporto
		values[ "noteTrasporto" ] = super.service( "Quotation" ).getNoteTrasporto( quotationId );

		var data = {
			"counters" = counters,
			"pricing" = values,
			"currency" = result.getCurrency()
		}

		return data;

	}

}
