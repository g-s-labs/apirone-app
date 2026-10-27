component extends="com.apirone.core.model.service.AbsService" accessors="true" {

	variables.verticaleUser = "apikey";
	variables.verticalePwd = "Gs16072001!";
	variables.verticaleSecret = ToBase64('#variables.verticaleUser#:#variables.verticalePwd#');

	// Sotto questa lunghezza la ricerca preventivi non interroga il CRM per il
	// nome del referente: vedi findReferentIds().
	variables.REFERENT_SEARCH_MIN_LENGTH = 3;

	// Codice export placche: prefisso dello slot orientamento nel codice variante ("HO" + HOR/VER)
	variables.PLATE_ORIENTATION_CODE = "HO";

	property name="dao" inject="QuotationDAO";

	//Ho ordinato i DAO in ordine di cancellazione, se elimino in questo ordine non dovrei avere problemi con la cancellazione a cascata
	property name="QuotationStatusHistoryService" inject="QuotationStatusHistoryService";
	property name="QuotationItemPriceLineService" inject="QuotationItemPriceLineService";
	property name="QuotationPriceService" inject="QuotationPriceService";
	property name="QuotationItemSignageRowService" inject="QuotationItemSignageRowService";
	property name="QuotationItemProductItemService" inject="QuotationItemProductItemService";
	property name="QuotationPriceLineService" inject="QuotationPriceLineService";
	property name="QuotationItemPriceService" inject="QuotationItemPriceService";
	property name="QuotationItemFruitPositionService" inject="QuotationItemFruitPositionService";
	property name="QuotationItemFruitService" inject="QuotationItemFruitService";
	property name="QuotationZonePositionService" inject="QuotationZonePositionService";
	property name="QuotationZoneService" inject="QuotationZoneService";
	property name="QuotationItemService" inject="QuotationItemService";
	property name="QuotationService" inject="QuotationService";
	property name="CatalogUsageService" inject="CatalogUsageService";
	property name="PlanningService" inject="PlanningService";


	// TODO capire se questo service esiste ancora dal momento che la tabella sul DB non c'e', viene usato nella clone
	property name="QuotationItemPositionService" inject="QuotationItemPositionService";

	property name="exportCodeService" inject="ExportCodeService";
	property name="rawValueService" inject="RawValueService";
	property name="attributeService" inject="AttributeService";
	property name="userService" inject="UserService";
	property name="profileService" inject="ProfileService";
	property name="langService" inject="LangService";
	property name="statusService" inject="StatusService";
	property name="signageConfigService" inject="signageConfigService";
	property name="SignageConfigItemService" inject="SignageConfigItemService";
	property name="pricelistService" inject="PricelistService";
	property name="paymentMethodService" inject="PaymentMethodService";
	property name="currencyService" inject="CurrencyService";
	property name="customerService" inject="CustomerService";
	property name="opportunityService" inject="OpportunityService";
	property name="leadService" inject="LeadService";
	property name="CrmApiService" inject="CrmApiService";
	property name="productService" inject="ProductService";
	property name="productCategoryService" inject="ProductCategoryService";
	property name="lineService" inject="LineService";
	property name="modelService" inject="ModelService";
	property name="finishService" inject="FinishService";
	property name="productItemService" inject="ProductItemService";
	property name="componentService" inject="ComponentService";
	property name="vatCodeService" inject="VatCodeService";
	property name="countryService" inject="CountryService";
	property name="fileService" inject="FileService";
	property name="ProductHashService" inject="ProductHashService";
	property name="accountService" inject="AccountService";

	public com.apirone.core.model.bean.Quotation function get( required String quotationId ){
		return build( arguments.quotationId );
	}

	public Number function getNextNumber(){

		return getDao().readNextNumber();

	}

	public Array function list(){
		arguments[ "limit" ] = -1;

		return search( argumentCollection = arguments ).getData();
	}

	public com.apirone.core.model.bean.Result function search(
		String str,
		required Numeric limit  = 15,
		required Numeric offset = 0,
		required Array orderBy  = [ { field = "quotation.createdAt", dir = "desc" } ]
	){
		var rows   = [];
		var result = super.getResult();

		arguments[ "orderby" ] = super.createOrderBy( arguments[ "orderby" ] );

		// Il nome del referente non è su quotations: sta sul CRM. Si chiede al
		// CRM quali referenti corrispondono al testo e si passano gli id al DAO,
		// che li mette in OR con la ricerca sulle colonne locali.
		var searchTerm = StructKeyExists( arguments, "str" ) ? arguments.str : "";
		StructAppend( arguments, findReferentIds( searchTerm ), true );

		// Primo passaggio: il find() restituisce solo gli ID (più il totale per paginazione)
		var records = getDao().find( argumentCollection = arguments );

		// Raccoglie tutti gli ID e carica i record in blocco con una sola query
		var ids = [];
		records.each( function( r ){
			ids.append( r.quotation_id );
		} );

		// Costruisce tutti i bean in batch con getMany() ottimizzato (evita N+1)
		var beanMap = ArrayLen( ids ) ? getMany( ids ) : {};

		// Ricostruisce le righe nell'ordine del find() originale
		records.each( function( record ){
			rows.add( beanMap[ record.quotation_id ] );
		} );

		result.setData( rows );
		result.setCount( Val( records.recordcount ) );
		result.setTotal( Val( records.total ) );

		return result;
	}

	/**
	 * Cerca sul CRM i referenti il cui nome corrisponde al testo e ne restituisce
	 * gli id, pronti per i filtri del DAO.
	 *
	 * Sotto la soglia di caratteri non interroga il CRM: l'endpoint /accounts
	 * ignora il parametro limit e restituisce l'intero insieme corrispondente
	 * (una ricerca di una lettera sola torna migliaia di record completi), quindi
	 * su stringhe cortissime il costo non è giustificato dal risultato.
	 *
	 * Un CRM irraggiungibile non deve far fallire l'elenco preventivi: in quel
	 * caso la ricerca degrada alle sole colonne locali e lo si annota nel log.
	 */
	private Struct function findReferentIds( required String str ){
		var ids = {};
		var term = Trim( arguments.str );

		if ( Len( term ) < variables.REFERENT_SEARCH_MIN_LENGTH ) {
			return ids;
		}

		var lookups = [
			{ key = "referentCustomerIds",    method = "searchCustomers" },
			{ key = "referentLeadIds",        method = "searchLeads" },
			{ key = "referentOpportunityIds", method = "searchOpportunities" }
		];

		for ( var lookup in lookups ) {
			try {
				var found = Invoke( getCrmApiService(), lookup.method, { str = term } );
				var list  = [];
				var rows  = [];

				// Niente operatori ?. e ?: qui dentro: su questo Lucee, dentro a un
				// ciclo, fanno fallire la compilazione dell'intero CFC con
				// "VerifyError: Expecting a stackmap frame" — e un CFC che non
				// compila viene saltato da mapDirectory, quindi il service sparisce
				// da WireBox e con lui l'elenco preventivi.
				if ( IsStruct( found ) && StructKeyExists( found, "data" ) && IsArray( found.data ) ) {
					rows = found.data;
				}

				for ( var row in rows ) {
					// Scarta id malformati: finiscono in un cast ::uuid[] lato
					// Postgres, dove un valore storto fa fallire tutta la query.
					// Il tipo va verificato come "guid" (8-4-4-4-12, il formato
					// del CRM e di Postgres): "uuid" in CFML è un formato diverso
					// (8-4-4-16) e scarterebbe ogni id.
					if ( StructKeyExists( row, "id" ) && IsValid( "guid", row.id ) ) {
						list.add( row.id );
					}
				}

				if ( list.len() ) {
					ids[ lookup.key ] = list;
				}
			} catch ( any e ) {
				getLogger().warn(
					"QuotationService.findReferentIds: #lookup.method# fallita per [#term#], "
					& "la ricerca prosegue senza referenti. #e.message#"
				);
			}
		}

		return ids;
	}

	public com.apirone.core.model.bean.Outcome function delete( required String quotationId ){
		var outcome = super.bean( "Outcome" );
		var obj     = get( arguments.quotationId );

		outcome.setData( { quotationId = arguments.quotationId } );

			try {
				transaction {
					quotationPrices = getQuotationPriceService().list( quotationId = arguments.quotationId );
					for ( var price in quotationPrices ) {
						getQuotationPriceLineService().deleteByQuotationPriceId( price.getId() );
						getQuotationPriceService().delete( price.getId() );
					}

					quotationItems = getQuotationItemService().list( quotationId = arguments.quotationId );
					for ( var item in quotationItems ) {
						//Elimino i quotation item price
						quotationItemPrices = getQuotationItemPriceService().list( quotationItemId = item.getId() );
						for ( var itemPrice in quotationItemPrices ) {
							getQuotationItemPriceService().delete( itemPrice.getId() );
						}

						//Elimino i quotation item fruit
						quotationItemFruits = getQuotationItemFruitService().list( quotationItemId = item.getId() );
						for ( var fruit in quotationItemFruits ) {
							//Elimino i quotation item fruit position
							quotationItemFruitPositions = getQuotationItemFruitPositionService().list( quotationItemFruit = fruit.getId() );
							for ( var fruitPosition in quotationItemFruitPositions ) {
								getQuotationItemFruitPositionService().delete( fruitPosition.getId() );
							}
							getQuotationItemFruitService().delete( fruit.getId() );
						}

						quotationItemSignageRows = getQuotationItemSignageRowService().list( quotationItemId = item.getId() );
						for ( var signageRow in quotationItemSignageRows ) {
							getQuotationItemSignageRowService().delete( signageRow.getId() );
						}

						quotationItemsProductItems = getQuotationItemProductItemService().list( quotationItemId = item.getId() );
						for ( var quotationItemProductItem in quotationItemsProductItems ) {
							getQuotationItemProductItemService().delete( quotationItemProductItem.getId() );
						}
						getQuotationItemService().delete( item.getId() );

					}

					var quotationZones = getQuotationZoneService().list( quotationId = arguments.quotationId );

					for ( var zone in quotationZones ) {
						// le posizioni della zona non si cancellano in cascata con lei ( FK senza ON DELETE )
						for ( var zonePosition in getQuotationZonePositionService().list( zoneId = zone.getId() ) ) {
							getQuotationZonePositionService().delete( zonePosition.getId() );
						}
						deleteQuotationZonesRecursive( zone.getId() );
					}

					// lo storico stati per ultimo: le letture dei preventivi ( QuotationDAO.readByIds ) fanno INNER JOIN
					// sullo stato corrente, e senza storico il preventivo non si trova più ( zone, righe ... )
					quotationStatusHistory = getQuotationStatusHistoryService().list( quotationId = arguments.quotationId );
					for ( var history in quotationStatusHistory ) {
						getQuotationStatusHistoryService().delete( history.getId() );
					}

					getDao().delete( arguments.quotationId );
				}
			} catch ( any error ) {
				transaction action="rollback";
				outcome.setError( error );
				outcome.setStatus( "ERROR" );
				outcome.setType( "ApirOne.CannotDeleteQuotation" );
				outcome.setMessage( "Cannot delete quotation [#arguments.quotationId#]" );
				rethrow
			}


		return outcome;
	}

	private void function deleteQuotationZonesRecursive(zoneId) {
		var quotationZones = getQuotationZoneService().list(originId = arguments.zoneId);
		for (var zone in quotationZones) {
			var quotationZonePositions = getQuotationZonePositionService().list(zoneId = zone.getId());
			for (var zonePosition in quotationZonePositions) {
					getQuotationZonePositionService().delete(zonePosition.getId());
			}
			deleteQuotationZonesRecursive(zone.getId());
			getQuotationZoneService().delete(zone.getId());
		}
	}

	// questa firma no è pulita ma è il miglior adattamento
	// questo metodo andrà usato anche da sistemi esterni e legarsi alla session non è consentito
	public String function create(
		required com.apirone.core.model.bean.Quotation quotation,
		required String userId,
		Boolean isClone = false,
		Boolean isPromoteStatus = false,
	){
		if (!isPromoteStatus) {
			arguments.quotation.setQuotationNumber( getNextNumber() );
			arguments.quotation.setVersionNumber( 1 );
		}

		transaction {

			var newId = getDao().insert( arguments.quotation );

			/*
				add first status to history
			*/
			var history = super.bean( "QuotationStatusHistory" );
			var status = getStatusService().get( "LAV" );

			history.setQuotationId( newId );
			history.setStatus( status );
			history.setUser( getUserService().get( arguments.userId ) );

			getQuotationStatusHistoryService().create( history );


			if (!isClone && !isPromoteStatus) {
				/*
					add first zone
				*/
				var zone = super.bean( "QuotationZone" );
				var newQuotation = super.bean( "Quotation" );
				newQuotation.setId( newId );

				zone.setQuotation( newQuotation );
				zone.setName( "Non assegnato" );
				zone.setQuantity(1);

				getQuotationZoneService().create( zone );
			}

		}

		return newId;

	}


	public String function update( required com.apirone.core.model.bean.Quotation quotation ){
		getDao().update( arguments.quotation );

		return arguments.quotation.getId();
	}

	/**
	 * Codice export di una voce di preventivo, calcolato senza scrivere nulla.
	 *
	 * Il codice è composto da 15 caratteri di articolo (categoria + linea +
	 * modello + finitura) e 10 di variante: i codici degli attributi
	 * "importanti" del prodotto, riempiti di zeri fino a 10 - anche per la
	 * segnaletica, il cui font e corpo NON occupano più caratteri del codice
	 * variante (restano solo in outcome.fontName/fontSize, per nota export e
	 * anteprima UI). Per le placche il codice variante inizia con l'orientamento
	 * ("HO" + HOR/VER, da quotationItemData.orientationId) seguito dagli
	 * attributi importanti (BORDO). È esattamente il valore che finisce in
	 * export_codes.export_code; il contatore (colCode) non c'entra ed è l'unica
	 * parte che richiede una scrittura, quindi resta fuori da qui.
	 *
	 * La usano sia exportProducts() sia le stampe: così il codice mostrato in
	 * stampa prima dell'esportazione è lo stesso che verrà poi scritto.
	 *
	 * Insieme al codice restituisce quello che l'esportazione ricava dalla
	 * stessa passata sugli attributi (id dei productItem, note descrittive,
	 * font) per non doverli rileggere una seconda volta.
	 *
	 * @quotationItemData  struct deserializzato da product_hashes.json_data
	 * @maps               mappe già caricate in batch dall'esportazione; se
	 *                     assenti si ricade sulle letture individuali
	 */
	public Struct function composeExportCode(
		required Struct quotationItemData,
		Struct maps = {}
	){
		var outcome = {
			"success"        = false,
			"error"          = "",
			"name"           = "",
			"articleCode"    = "",
			"variantCode"    = "",
			"productItemIds" = [],
			"attributeNotes" = [],
			"fontName"       = "",
			"fontSize"       = "",
			"variantParts"   = [],
			"importantAttributeIds" = []
		};

		var data = arguments.quotationItemData;

		var product  = exportEntity( arguments.maps, "productMap", data.productId );
		var category = exportEntity( arguments.maps, "categoryMap", data.categoryId );
		if ( IsNull( product ) || IsNull( category ) ) {
			outcome.error = "Prodotto o Categoria Prodotto non trovata.";
			return outcome;
		}

		var code = Trim( category.getCode() );

		var line = exportEntity( arguments.maps, "lineMap", data.lineId );
		if ( IsNull( line ) ) {
			outcome.error = "Linea prodotto non trovata.";
			return outcome;
		}
		code &= Trim( line.getCode() );

		var model = exportEntity( arguments.maps, "modelMap", data.modelId );
		if ( IsNull( model ) ) {
			outcome.error = "Modello prodotto non trovato.";
			return outcome;
		}
		code &= Trim( model.getCode() );

		var finish = exportEntity( arguments.maps, "finishMap", data.finishId );
		if ( IsNull( finish ) ) {
			outcome.error = "Finitura prodotto non trovata.";
			return outcome;
		}
		code &= Trim( finish.getCode() );
		outcome.articleCode = code; // valorizzato subito: utile all'anteprima anche quando la variante non si compone

		var varCode = "";

		// Segnaletica: font e corpo NON occupano più caratteri del codice
		// variante (solo outcome.fontName/fontSize, per nota export e anteprima
		// UI) - i 10 caratteri restano liberi per gli attributi "importanti",
		// esattamente come per gli altri tipi di prodotto.
		if ( StructKeyExists( data, "signageRows" ) ) {
			if ( !StructKeyExists( data, "signageConfigItemId" ) ) {
				outcome.error = "Configurazione segnaletica non trovata.";
				return outcome;
			}

			var signageConfigItem = exportEntity( arguments.maps, "signConfigItemMap", data.signageConfigItemId );
			if ( IsNull( signageConfigItem ) ) {
				outcome.error = "Configurazione segnaletica non trovata.";
				return outcome;
			}

			var signageConfig = exportEntity( arguments.maps, "signConfigMap", signageConfigItem.getSignageConfigId() );
			if ( IsNull( signageConfig ) ) {
				outcome.error = "Configurazione segnaletica non trovata.";
				return outcome;
			}

			outcome.fontSize = signageConfigItem.getSize().getName();
			outcome.fontName = signageConfig.getFont().getName();
		}

		// Placche: il codice variante inizia con l'orientamento ("HO" + HOR/VER),
		// seguito dagli attributi importanti (per le placche: BORDO). Le impronte
		// salvate prima dell'introduzione dell'orientamento non lo contengono:
		// meglio fermarsi che produrre un codice senza orientamento.
		var isPlate = !IsNull( category.getType() ) && category.getType().getId() == "PLA";
		if ( isPlate ) {
			var orientationId = Trim( data.orientationId ?: "" );
			if ( !Len( orientationId ) ) {
				outcome.error = "Orientamento della placca non disponibile: risalvare la placca (o usare ""Aggiorna tutti i prezzi"") per aggiornarne la configurazione.";
				return outcome;
			}
			varCode &= variables.PLATE_ORIENTATION_CODE & orientationId;
			ArrayAppend( outcome.variantParts, {
				"attributeId"   = "",
				"attributeCode" = variables.PLATE_ORIENTATION_CODE,
				"valueCode"     = orientationId
			} );
		}

		var importantAttributes = product.getImportantAttributes();
		if ( !IsNull( importantAttributes ) ) {
			for ( var importantAttribute in importantAttributes ) {
				ArrayAppend( outcome.importantAttributeIds, importantAttribute.getId() );
			}
		}

		if ( StructKeyExists( data, "productItems" ) ) {
			for ( var entry in data.productItems ) {
				var productItem = exportEntity( arguments.maps, "productItemMap", entry.productItemId );
				if ( IsNull( productItem ) ) {
					continue;
				}

				var attributeValue = productItem.getAttributeValue();
				// Lettura individuale: l'attributeId arriva dal ProductItem già
				// caricato, non è pre-raccoglibile in batch. Se il chiamante passa
				// maps.attributeMap la lettura si fa una volta sola per attributo.
				var attributeId = attributeValue.getAttributeId();
				var attribute   = NullValue();
				if ( StructKeyExists( arguments.maps, "attributeMap" ) && StructKeyExists( arguments.maps.attributeMap, attributeId ) ) {
					attribute = arguments.maps.attributeMap[ attributeId ];
				} else {
					attribute = getAttributeService().get( attributeId = attributeId );
					if ( StructKeyExists( arguments.maps, "attributeMap" ) && !IsNull( attribute ) ) {
						arguments.maps.attributeMap[ attributeId ] = attribute;
					}
				}
				if ( IsNull( attribute ) ) {
					outcome.error = "Attributo Prodotto non trovato.";
					return outcome;
				}

				var rawValue = attributeValue.getRawValue();

				ArrayAppend( outcome.productItemIds, productItem.getId() );
				ArrayAppend( outcome.attributeNotes, attribute.getName() & ": " & rawValue.getName() & "; " );

				var isImportant = false;
				if ( !IsNull( importantAttributes ) ) {
					for ( var importantAttribute in importantAttributes ) {
						if ( importantAttribute.getId() == attribute.getId() ) {
							isImportant = true;
						}
					}
				}

				if ( !isImportant ) {
					continue;
				}

				var slotCode = Trim( attribute.getCode() ) & Trim( rawValue.getCode() );
				if ( Len( varCode ) + Len( slotCode ) > 10 ) {
					outcome.error = 'Il codice variante supera i 10 caratteri: attributo "'
						& Trim( attribute.getCode() )
						& '" (valore "'
						& Trim( rawValue.getCode() )
						& '") non entra nel codice variante (già '
						& Len( varCode )
						& ' su 10 caratteri). Verificare i codici degli attributi importanti del prodotto.';
					outcome.variantCode = varCode;
					return outcome;
				}

				varCode &= slotCode;
				ArrayAppend( outcome.variantParts, {
					"attributeId"   = attribute.getId(),
					"attributeCode" = Trim( attribute.getCode() ),
					"valueCode"     = Trim( rawValue.getCode() )
				} );
			}
		}

		varCode &= RepeatString( "0", 10 - Len( varCode ) );

		outcome.success     = true;
		outcome.articleCode = code;
		outcome.variantCode = varCode;
		outcome.name        = code & varCode;

		return outcome;
	}

	/**
	 * Riga product_hashes dell'hash della voce. Se l'hash della voce è orfano ( nessuna
	 * riga: succedeva risalvando una placca con configurazione cambiata, bug corretto in
	 * QuotationItemService.update il 2026-10-09 ) lo rigenera dalla configurazione attuale
	 * della voce e lo riscrive, così export articoli ed export preventivo non si bloccano.
	 */
	private function resolveProductHash( required quotationItem ){
		var productHash = getProductHashService().getByHash( arguments.quotationItem.getHash() );
		if ( !IsNull( productHash ) ) {
			return productHash;
		}

		var hash = getProductHashService().createHash( arguments.quotationItem.getId() );
		if ( IsNull( hash ) || !Len( hash ) ) {
			return NullValue();
		}

		getQuotationItemService().updateHash( arguments.quotationItem.getId(), hash );
		arguments.quotationItem.setHash( hash );

		return getProductHashService().getByHash( hash );
	}

	/**
	 * Mappa hash della voce di preventivo -> codice export calcolato al volo,
	 * per le stampe di preventivi non ancora esportati. Non scrive nulla.
	 * Gli hash che non si riescono a comporre (configurazione incompleta)
	 * restano fuori dalla mappa: in stampa semplicemente non si vede il codice.
	 */
	public Struct function mapComputedExportCodesByHashes( required Array hashes ){
		var map = {};

		if ( !ArrayLen( arguments.hashes ) ) {
			return map;
		}

		var jsonDataMap = getProductHashService().mapJsonDataByHashes( arguments.hashes );

		// Le entità si caricano tutte insieme prima di comporre i codici: senza mappe
		// composeExportCode legge prodotto, categoria, linea, modello, finitura e
		// productItem con una get() a testa, per ogni voce (~10 s su 60 voci).
		var dataByHash = {};
		for ( var hash in jsonDataMap ) {
			try {
				dataByHash[ hash ] = DeserializeJson( jsonDataMap[ hash ] );
			} catch ( any error ) {
				// json non leggibile: la voce resta senza codice
			}
		}

		var maps = loadExportMaps( StructValueArray( dataByHash ) );

		for ( var hash in dataByHash ) {
			try {
				var outcome = composeExportCode( quotationItemData = dataByHash[ hash ], maps = maps );

				if ( outcome.success ) {
					map[ hash ] = outcome.name;
				}
			} catch ( any error ) {
				// Voce non componibile: la stampa prosegue senza codice.
			}
		}

		return map;
	}

	/**
	 * Mappe batch per composeExportCode, dai dati json delle voci: stesse entità e
	 * stessi getMany() della fase 2 di exportProducts. attributeMap parte vuota e
	 * la riempie composeExportCode man mano ( l'id attributo si conosce solo dopo
	 * aver letto il productItem ).
	 */
	private Struct function loadExportMaps( required Array dataList ){
		var ids = {
			"product"        = [],
			"category"       = [],
			"line"           = [],
			"model"          = [],
			"finish"         = [],
			"productItem"    = [],
			"signConfigItem" = []
		};

		for ( var data in arguments.dataList ) {
			if ( StructKeyExists( data, "productId" ) )  ArrayAppend( ids.product, data.productId );
			if ( StructKeyExists( data, "categoryId" ) ) ArrayAppend( ids.category, data.categoryId );
			if ( StructKeyExists( data, "lineId" ) )     ArrayAppend( ids.line, data.lineId );
			if ( StructKeyExists( data, "modelId" ) )    ArrayAppend( ids.model, data.modelId );
			if ( StructKeyExists( data, "finishId" ) )   ArrayAppend( ids.finish, data.finishId );

			if ( StructKeyExists( data, "productItems" ) ) {
				for ( var entry in data.productItems ) {
					ArrayAppend( ids.productItem, entry.productItemId );
				}
			}

			if ( StructKeyExists( data, "signageRows" ) && StructKeyExists( data, "signageConfigItemId" ) ) {
				ArrayAppend( ids.signConfigItem, data.signageConfigItemId );
			}
		}

		var maps = {
			"productMap"        = ArrayLen( ids.product )        ? getProductService().getMany( ids.product )                   : {},
			"categoryMap"       = ArrayLen( ids.category )       ? getProductCategoryService().getMany( ids.category )          : {},
			"lineMap"           = ArrayLen( ids.line )           ? getLineService().getMany( ids.line )                         : {},
			"modelMap"          = ArrayLen( ids.model )          ? getModelService().getMany( ids.model )                       : {},
			"finishMap"         = ArrayLen( ids.finish )         ? getFinishService().getMany( ids.finish )                     : {},
			"productItemMap"    = ArrayLen( ids.productItem )    ? getProductItemService().getMany( ids.productItem )           : {},
			"signConfigItemMap" = ArrayLen( ids.signConfigItem ) ? getSignageConfigItemService().getMany( ids.signConfigItem ) : {},
			"signConfigMap"     = {},
			"attributeMap"      = {}
		};

		var signConfigIds = [];
		for ( var signConfigItemId in maps.signConfigItemMap ) {
			ArrayAppend( signConfigIds, maps.signConfigItemMap[ signConfigItemId ].getSignageConfigId() );
		}
		if ( ArrayLen( signConfigIds ) ) {
			maps.signConfigMap = getSignageConfigService().getMany( signConfigIds );
		}

		return maps;
	}

	/**
	 * Lettura di un'entità usata nella composizione del codice export: prima
	 * dalla mappa batch dell'esportazione, altrimenti con la lettura singola.
	 */
	private any function exportEntity(
		required Struct maps,
		required String mapName,
		required any id
	){
		if ( StructKeyExists( arguments.maps, arguments.mapName ) ) {
			var map = arguments.maps[ arguments.mapName ];
			if ( StructKeyExists( map, arguments.id ) ) {
				return map[ arguments.id ];
			}
		}

		switch ( arguments.mapName ) {
			case "productMap":
				return getProductService().get( arguments.id );
			case "categoryMap":
				return getProductCategoryService().get( arguments.id );
			case "lineMap":
				return getLineService().get( arguments.id );
			case "modelMap":
				return getModelService().get( arguments.id );
			case "finishMap":
				return getFinishService().get( arguments.id );
			case "productItemMap":
				return getProductItemService().get( arguments.id );
			case "signConfigItemMap":
				return getSignageConfigItemService().get( arguments.id );
			case "signConfigMap":
				return getSignageConfigService().get( arguments.id );
		}

		return NullValue();
	}

	public Struct function exportProducts( required com.apirone.core.model.bean.QuotationItem[] quotationItems ){

		var result = {
			"success" = true,
			"error" = null,
			"exportedItems" = [],
			"skippedItems" = []
		};

		transaction {
			if ( arguments.quotationItems.len() ) {

				// --- Fase 1: pre-raccolta degli ID da tutti i quotationItem per il caricamento batch ---
				// Le tuple memorizzate verranno poi usate nella fase 2 per l'assemblaggio senza chiamate get() individuali.
				var exportTuples        = [];
				var allProductIds       = [];
				var allCategoryIds      = [];
				var allLineIds          = [];
				var allModelIds         = [];
				var allFinishIds        = [];
				var allProductItemIds   = [];
				var allFruitProductIds  = [];
				var allSignConfigItemIds = [];
				var allSignConfigIds    = [];

				for ( var quotationItem in arguments.quotationItems ) {
					// Gli articoli (servizi) non hanno dati prodotto - saltati nella pre-raccolta
					if ( !IsNull( quotationItem.getArticle() ) ) {
						continue;
					}

					if ( IsNull( quotationItem.getHash() ) || Trim( quotationItem.getHash() ) == "" ) {
						continue;
					}

					var productHash = resolveProductHash( quotationItem );
					if ( IsNull( productHash ) ) {
						continue;
					}

					var existingCode = exportCodeService.list( "productHashId" = productHash.getId() );
					if ( existingCode.len() > 0 ) {
						continue;
					}

					var quotationItemData = deserializeJson( productHash.getJsonData() );

					// Raccoglie tutti gli ID unici per il caricamento batch
					ArrayAppend( allProductIds, quotationItemData.productId );
					ArrayAppend( allCategoryIds, quotationItemData.categoryId );
					ArrayAppend( allLineIds, quotationItemData.lineId );
					ArrayAppend( allModelIds, quotationItemData.modelId );
					ArrayAppend( allFinishIds, quotationItemData.finishId );

					if ( StructKeyExists( quotationItemData, "productItems" ) ) {
						for ( var pi in quotationItemData.productItems ) {
							ArrayAppend( allProductItemIds, pi.productItemId );
						}
					}

					if ( StructKeyExists( quotationItemData, "signageRows" ) && StructKeyExists( quotationItemData, "signageConfigItemId" ) ) {
						ArrayAppend( allSignConfigItemIds, quotationItemData.signageConfigItemId );
					}

					if ( StructKeyExists( quotationItemData, "fruits" ) ) {
						for ( var fruit in quotationItemData.fruits ) {
							ArrayAppend( allFruitProductIds, fruit.product );
							if ( StructKeyExists( fruit, "productItems" ) ) {
								for ( var fi in fruit.productItems ) {
									ArrayAppend( allProductItemIds, fi.productItemId );
								}
							}
						}
					}

					// Memorizza la tupla per la fase 2: item originale, dati deserializzati e productHash
					ArrayAppend( exportTuples, {
						item = quotationItem,
						data = quotationItemData,
						hash = productHash
					} );
				}

				// --- Fase 2: caricamento batch di tutte le entity ---
				// Carica i Product con getMany() ottimizzato (incluse tutte le sub-entity: categorie, testi, prezzi, file, attributi)
				var productMap = {};
				if ( ArrayLen( allProductIds ) ) {
					productMap = getProductService().getMany( allProductIds );
				}

				// Carica ProductCategory, Line, Model, Finish con i rispettivi getMany()
				var categoryMap = {};
				if ( ArrayLen( allCategoryIds ) ) {
					categoryMap = getProductCategoryService().getMany( allCategoryIds );
				}

				var lineMap = {};
				if ( ArrayLen( allLineIds ) ) {
					lineMap = getLineService().getMany( allLineIds );
				}

				var modelMap = {};
				if ( ArrayLen( allModelIds ) ) {
					modelMap = getModelService().getMany( allModelIds );
				}

				var finishMap = {};
				if ( ArrayLen( allFinishIds ) ) {
					finishMap = getFinishService().getMany( allFinishIds );
				}

				var productItemMap = {};
				if ( ArrayLen( allProductItemIds ) ) {
					productItemMap = getProductItemService().getMany( allProductItemIds );
				}

				// Carica anche i fruit product (sono Product, ma con ID separato)
				var fruitProductMap = {};
				if ( ArrayLen( allFruitProductIds ) ) {
					fruitProductMap = getProductService().getMany( allFruitProductIds );
				}

				// Carica SignageConfigItem e SignageConfig in batch
				var signConfigItemMap = {};
				if ( ArrayLen( allSignConfigItemIds ) ) {
					signConfigItemMap = getSignageConfigItemService().getMany( allSignConfigItemIds );
				}

				// Raccoglie i signage_config_id dai SignageConfigItem caricati per il caricamento batch delle config
				for ( var scid in allSignConfigItemIds ) {
					if ( StructKeyExists( signConfigItemMap, scid ) ) {
						ArrayAppend( allSignConfigIds, signConfigItemMap[ scid ].getSignageConfigId() );
					}
				}
				var signConfigMap = {};
				if ( ArrayLen( allSignConfigIds ) ) {
					signConfigMap = getSignageConfigService().getMany( allSignConfigIds );
				}

				// --- Fase 3a: elaborazione degli articoli (servizi) ---
				for ( var quotationItem in arguments.quotationItems ) {
					if ( IsNull( quotationItem.getArticle() ) ) {
						continue;
					}

					var isSpeciale = quotationItem.getSpecial() ? "S" : "N";

					var dataExport = {
						"AR_CHIAVE" = quotationItem.getArticle().getCode() & RepeatString( "0", 31 - Len( quotationItem.getArticle().getCode() ) ),
						"ARCODART"  = quotationItem.getArticle().getCode() & RepeatString( "0", 15 - Len( quotationItem.getArticle().getCode() ) ),
						"ARDESART"  = quotationItem.getArticle().getDescription().subString( 0, Len( quotationItem.getArticle().getDescription() ) ) & RepeatString(
							"0",
							35 - Len( quotationItem.getArticle().getDescription().subString( 0, Len( quotationItem.getArticle().getDescription() ) ) )
						),
						"ARDESSUP"  = "",
						"ARDATCAR"  = Now(),
						"ARUNMIS1"  = "PZ",
						"VARCOD"    = "0000000000",
						"VARNOT"    = "",
						"CLCODICE"  = "000000",
						"CLANNOTA"  = quotationItem.getNote(),
						"ARIMG_64"  = "",
						"ARSPECIA"  = isSpeciale,
						"ARCODNOM"  = ""
					};

					// non abbiamo un prodotto legato a questa riga, quindi cerchiamo per codice e basta tra i codici gia esportati.
					var existingCodes = exportCodeService.list(
						str = quotationItem.getArticle().getCode() & RepeatString( "0", 25 - Len( quotationItem.getArticle().getCode() ) )
					);

					if ( existingCodes.len() > 0 ) {
						ArrayAppend( result.skippedItems, quotationItem.getArticle().getCode() );
						continue;
					}

					var exportCode = super.bean( "ExportCode" );
					exportCode.setName( quotationItem.getArticle().getCode() & RepeatString( "0", 25 - Len( quotationItem.getArticle().getCode() ) ) );
					exportCode.setCounter( "000000" );
					exportCodeService.create( "exportCode" = exportCode );
					result.success = getDao().exportProduct( dataExport );
					ArrayAppend( result.exportedItems, quotationItem.getArticle().getCode() );
				}

				// --- Fase 3b: elaborazione dei prodotti usando esclusivamente le mappe batch ---
				for ( var tuple in exportTuples ) {
					var quotationItem     = tuple.item;
					var quotationItemData = tuple.data;
					var productHash       = tuple.hash;

					var isSpeciale = quotationItem.getSpecial() ? "S" : "N";

					var hsCode = "";
					try {
						hsCode = quotationItem.getProduct().getLine().getHscode();
					} catch ( any e ) {
					}

					var quotationImageFile = quotationItem.getImage();
					var base64File         = "";

					try {
						var path = ExpandPath( "/../repository/public/media/quotation-items/500/" & quotationImageFile.getDirectory() & "/" & quotationImageFile.getName() );
						var file = FileReadBinary( path );
						if ( !IsNull( file ) ) {
							base64File = ToBase64( file );
						}
					} catch ( any e ) {
					}

					// Composizione del codice export: unica fonte, condivisa con le
					// stampe (composeExportCode()). Qui serve anche la parte
					// descrittiva (note, attributi risolti) che la funzione
					// restituisce insieme al codice per non rileggere gli attributi.
					var codeOutcome = composeExportCode(
						quotationItemData = quotationItemData,
						maps              = {
							"productMap"        = productMap,
							"categoryMap"       = categoryMap,
							"lineMap"           = lineMap,
							"modelMap"          = modelMap,
							"finishMap"         = finishMap,
							"productItemMap"    = productItemMap,
							"signConfigItemMap" = signConfigItemMap,
							"signConfigMap"     = signConfigMap
						}
					);

					if ( !codeOutcome.success ) {
						result.success = false;
						result.error   = codeOutcome.error;
						return result;
					}

					var code    = codeOutcome.articleCode;
					var varCode = codeOutcome.variantCode;

					var product = StructKeyExists( productMap, quotationItemData.productId )
						? productMap[ quotationItemData.productId ]
						: getProductService().get( quotationItemData.productId );

					var description = product.getDescription().left( 35 );

					var arKey           = code;
					var colCode         = "000000";
					var note            = "";
					var noteSegnaletica = '';

					// Segnaletica: font e corpo finiscono nella nota, le righe di
					// testo nella nota variante.
					if ( StructKeyExists( quotationItemData, "signageRows" ) ) {
						note &= "Font: " & codeOutcome.fontName & "; Font Size: " & codeOutcome.fontSize & "; ";
						var signageRowsCounter = 1;
						for ( var signageRow in quotationItemData.signageRows ) {
							noteSegnaletica &= 'riga ' & signageRowsCounter & ': Allineamento: ' & signageRow[ 'text-align' ] & ': Testo: "' & signageRow.content & '"";';
							signageRowsCounter++;
						}
					}

					var productItemIds = codeOutcome.productItemIds;

					for ( var attributeNote in codeOutcome.attributeNotes ) {
						note &= attributeNote;
					}

					var productComponents = getComponents( product.getId(), quotationItem, productItemIds );

					// Placca: recupera i fruit product e i productItem dalle mappe batch
					var fruitsComponents     = [];
					var fruitsProductItems   = {};
					var fruitsProductItemIds = {};
					if ( StructKeyExists( quotationItemData, "fruits" ) ) {
						var orientation = quotationItem.getFrame().getOrientation().getName();
						note &= "Orientamento: " & orientation & ";";

						var fruits = quotationItemData.fruits;
						if ( Len( fruits ) ) {
							note &= " Frutti: ";
						}
						var fruitsIndex = 1;
						for ( var fruit in fruits ) {
							var fruitBean = StructKeyExists( fruitProductMap, fruit.product )
								? fruitProductMap[ fruit.product ]
								: getProductService().get( fruit.product );
							note &= " " & fruitBean.getCode();
							var fruitItems = fruit.productItems;
							fruitsProductItems[ fruitsIndex ]     = [];
							fruitsProductItemIds[ fruitsIndex ]   = [];
							if ( Len( fruitItems ) ) {
								note &= ": ";
								for ( var fruitItem in fruitItems ) {
									var fruitItemBean = StructKeyExists( productItemMap, fruitItem.productItemId )
										? productItemMap[ fruitItem.productItemId ]
										: getProductItemService().get( fruitItem.productItemId );
									var attributeValue = fruitItemBean.getAttributeValue();
									var attribute      = attributeService.get( attributeId = attributeValue.getAttributeId() );

									if ( IsNull( attribute ) ) {
										result.success = false;
										result.error   = 'Attributo Frutto non trovato.';
										return result;
									}
									var rawValue = attributeValue.getRawValue();
									arrayAppend( fruitsProductItems[ fruitsIndex ], {
										"important"   = false,
										"rawValueId"  = rawValue.getId(),
										"attributeId" = attributeValue.getAttributeId()
									} );
									arrayAppend( fruitsProductItemIds[ fruitsIndex ], fruitItemBean.getId() );
									note &= attribute.getName() & ": " & rawValue.getName() & "; ";
									if ( fruitItem.note != "" ) {
										note &= " Note: " & fruitItem.note & "; ";
									}
								}
							}
							arrayAppend( fruitsComponents, getComponents( fruit.product, quotationItem, fruitsProductItemIds[ fruitsIndex ] ) );
							fruitsIndex++;
						}
					}

					var exportCode = super.bean( "ExportCode" );
					exportCode.setName( code & varCode );
					exportCode.setProductHashId( productHash.getId() );
					var maxCounter = exportCodeService.max( exportCode = code & varCode );
					if ( maxCounter > 0 ) {
						var newMaxCounter = NumberFormat( maxCounter + 1, "000000" );
						exportCode.setCounter( newMaxCounter );
						colCode = newMaxCounter;
					} else {
						exportCode.setCounter( "000001" );
						colCode = "000001";
					}
					exportCodeService.create( "exportCode" = exportCode );

					arKey = code & varCode & colCode;
					var dataExport = {
						"AR_CHIAVE" = arKey,
						"ARCODART"  = code & RepeatString( "0", 15 - Len( code ) ),
						"ARDESART"  = description,
						"ARDESSUP"  = quotationItemData.special == 'true' ? 'SÌ DWG' : 'NO DWG',
						"ARDATCAR"  = Now(),
						"ARUNMIS1"  = "PZ",
						"VARCOD"    = varCode,
						"VARNOT"    = noteSegnaletica,
						"CLCODICE"  = colCode,
						"CLANNOTA"  = note,
						"ARIMG_64"  = base64File,
						"ARSPECIA"  = isSpeciale,
						"ARCODNOM"  = hsCode
					};

					result.success = getDao().exportProduct( dataExport );
					ArrayAppend( result.exportedItems, description );

					var allComponents = [];
					for ( var productComponent in productComponents ) {
						productComponent.DS_CHIAVE = dataExport.AR_CHIAVE;
						productComponent.DSCODART  = dataExport.ARCODART;
						productComponent.DSCODVAR  = dataExport.VARCOD;
						productComponent.DSCODCOL  = dataExport.CLCODICE;
						ArrayAppend( allComponents, productComponent );
					}

					if ( StructKeyExists( quotationItemData, "fruits" ) ) {
						for ( var fruitComponents in fruitsComponents ) {
							for ( var fruitComponent in fruitComponents ) {
								fruitComponent.DS_CHIAVE = dataExport.AR_CHIAVE;
								fruitComponent.DSCODART  = dataExport.ARCODART;
								fruitComponent.DSCODVAR  = dataExport.VARCOD;
								fruitComponent.DSCODCOL  = dataExport.CLCODICE;
								ArrayAppend( allComponents, fruitComponent );
							}
						}
					}

					// materia prima non a pezzi ( né PA / EU / NR ): quantità +15% ( sfrido ), come nei costi. L'unità
					// si legge dalla stessa fonte del calcolo prezzi ( arunmis1 della materia prima )
					var wasteComponentSvc = getComponentService();
					for ( var row in allComponents ) {
						var rowUnit = ( !IsNull( row.DSCODMAT ) && Len( row.DSCODMAT ) )
							? wasteComponentSvc.getDao().getRawProductData( row.DSCODMAT ).raw_product_unit
							: "PZ";
						row.DSQTAMOV = Val( row.DSQTAMOV ) * wasteComponentSvc.quantityWasteFactor( rowUnit );
					}

					var grouped = {};
					for ( var row in allComponents ) {
						var key = row.DSCODMAT & "|" & row.DSVARMAT & "|" & row.DSCOLMAT;
						if ( !structKeyExists( grouped, key ) ) {
							grouped[ key ]             = duplicate( row );
							grouped[ key ].DSQTAMOV    = val( row.DSQTAMOV );
						} else {
							grouped[ key ].DSQTAMOV += val( row.DSQTAMOV );
						}
					}
					var parsedComponents = [];
					for ( var key in grouped ) {
						arrayAppend( parsedComponents, grouped[ key ] );
					}

					var counter = 0;
					for ( var row in parsedComponents ) {
						counter++;
						row.CPROWNUM = counter;
						row.CPROWORD = counter * 10;
						row.DSDATCRE = DateFormat( now(), "yyyy-mm-dd" );
						result.success = getDao().exportDiba( row );
					}
				}
			}
		}

		return result;
	}

	public Struct function export( required com.apirone.core.model.bean.QuotationItem[] quotationItems ){
		var result = {
			'success' = false,
			'error' = null,
			'header' = {},
			'rows' = []
		};

		transaction {
			if (quotationItems.len() > 0) {
				var quotation = quotationItems[1].getQuotation();

				getDao().deleteExport( quotationNumber = quotation.getQuotationNumber() );
				quotationDataResult = prepareExportData(quotation);
				if (!isNull(quotationDataResult.error)) {
					result.error = quotationDataResult.error;
					return result;
				}
				quotationDataHead = quotationDataResult.data;
				result.header = exportHeaderSummary( quotationDataHead );
			}

			quotationItemsToExport = [];
			if ( quotationItems.len() > 0 ) {
				var index = 1;
				for ( var quotationItem in arguments.quotationItems ) {
					var salesAgent = quotation.getSalesAgent();
					var graphicTechnician = quotation.getGraphicTechnician();
					var salesAgentId = 0;
					var graphicTechnicianId = 0;
					if (!isNull(salesAgent)) {
						salesAgentId = salesAgent.getAccount().getIdUtenteVerticale();
					}
					if (!isNull(graphicTechnician)) {
						graphicTechnicianId = graphicTechnician.getAccount().getIdUtenteVerticale();
					}

					var quotationData = {}
					quotationData.append(quotationDataHead);

					if (!isNull(quotationItem.getArticle())) {
						var product = null
						var code = quotationItem.getArticle().getCode() & RepeatString( "0", 15 - Len( quotationItem.getArticle().getCode() ) ) & "0000000000"
						var existingCodes = exportCodeService.list( str = code );
						if ( existingCodes.len() == 0 ) {
							result.error = 'Prima esporta gli articoli.';
							return result;
						}

						var data = {
							"AR_CHIAVE" = quotationItem.getArticle().getCode() & RepeatString( "0", 31 - Len( quotationItem.getArticle().getCode() ) ),
							"ARCODART"  = quotationItem.getArticle().getCode() & RepeatString( "0", 15 - Len( quotationItem.getArticle().getCode() ) ),
							"ARDESART"  = quotationItem.getArticle().getDescription().subString( 0, Len(quotationItem.getArticle().getDescription()) ) & RepeatString(
								"0",
								35 - Len( quotationItem.getArticle().getDescription().subString( 0, Len(quotationItem.getArticle().getDescription()) ) )
							),
							"ARDESSUP"  = "",
							"ARDATCAR"  = Now(),
							"ARUNMIS1"  = "PZ",
							"VARCOD"    = "0000000000",
							"CLCODICE"  = "000000",
							"CLANNOTA"  = quotationItem.getNote()
						}

						var quotationItemQuantity = quotationItem.getQuantity()
						if (!isNull(quotationItem.getQuotationZone())) {
							if (!isNull(quotationItem.getQuotationZone().getOrigin())) {
								quotationItemQuantity *= quotationItem.getQuotationZone().getOrigin().getQuantity()
							}
							quotationItemQuantity *= quotationItem.getQuotationZone().getQuantity()
						}
						quotationData["CPROWNUM"] = index;
						quotationData["CPROWORD"] = index * 10;
						quotationData["MMCODART"] = data["ARCODART"];
						quotationData["MMCODVAR"] = data["VARCOD"];
						quotationData["MMCODCOL"] = data["CLCODICE"];
						quotationData["ARUNMIS1"] = "PZ";
						quotationData["MMQTAMOV"] = quotationItemQuantity;
						quotationData["MMVALUNI"] = !isNull(quotationItem.getPrice()) ? quotationItem.getPrice().getAmount() : 0;
						quotationData["MMSCOAR1"] = !isNull(quotationItem.getPrice()) ? quotationItem.getPrice().getDiscount1() : 0;
						quotationData["MMSCOAR2"] = !isNull(quotationItem.getPrice()) ? quotationItem.getPrice().getDiscount2() : 0;
						quotationData["MMEVASIO"] = quotation.getValidityDate();
						quotationData["MM_STATO"] = "N";
						quotationData["MMUTECOM"] = salesAgentId;
						quotationData["MMUTETEC"] = graphicTechnicianId;
					} else {
						//in caso il prodotto non sia un servizio, ma un prodotto con hash, la gestione è più complessa
						if ( isNull(quotationItem.getHash()) || Trim( quotationItem.getHash() ) == "" ) {
							result.success = false;
							result.error = 'Hash riga preventivo non trovata.';
							return result;
						}
						var productHash = resolveProductHash( quotationItem );
						if ( isNull(productHash) ) {
							result.success = false;
							result.error = 'Hash prodotto non trovato.';
							return result;
						}
						//appurato che la riga di preventivo ha un hash associato e che l'hash corrisponda effettivamente ad un record sulla tabella degli hash
						//cerchiamo se l'hash è gia stato associato ad un codice esportato in verticale.
						var existingCode = exportCodeService.list( "productHashId" = productHash.getId() );
						if ( existingCode.len() > 0 ) {
							var code = existingCode[1].getName().left( 15 );
							var varCode = existingCode[1].getName().right( 10 );
							var colCode = existingCode[1].getCounter();

						} else {
							//se non esiste nemmeno il varCode negli exported vuol dire che non è sicuramente mai stato fatta la export articoli
							result.error = 'Prima esporta gli articoli.';
							return result;
						}

						var quotationItemQuantity = quotationItem.getQuantity()
						if (!isNull(quotationItem.getQuotationZone())) {
							if (!isNull(quotationItem.getQuotationZone().getOrigin())) {
								quotationItemQuantity *= quotationItem.getQuotationZone().getOrigin().getQuantity()
							}
							quotationItemQuantity *= quotationItem.getQuotationZone().getQuantity()
						}
						quotationData['CPROWNUM'] = index;
						quotationData['CPROWORD'] = index * 10;
						quotationData['MMCODART'] = code & RepeatString( "0", 15 - Len( code ) );
						quotationData['MMCODVAR'] = varCode;
						quotationData['MMCODCOL'] = colCode;
						quotationData['ARUNMIS1'] = "PZ";
						quotationData['MMQTAMOV'] = quotationItemQuantity;
						var price = 0
						var discount1 = 0
						var discount2 = 0
						if (!isNull(quotationItem.getPrice())) {
							// prezzo netto (sconti inclusi, anche a prezzo fisso): MMVALUNI lo riporta al lordo qui sotto
							price = quotationItem.getPrice().getTotal()
							if (quotationItem.getPrice().getDiscount1() > 0) {
								discount1 = !isNull(quotationItem.getPrice().getDiscount1()) ? quotationItem.getPrice().getDiscount1() : 0
							}
							if (quotationItem.getPrice().getDiscount2() > 0) {
								discount2 = !isNull(quotationItem.getPrice().getDiscount2()) ? quotationItem.getPrice().getDiscount2() : 0
							}
						}
						quotationData["MMVALUNI"] = (discount1 > 0 || discount2 > 0) ? getOriginalPrice( finalPrice = price, discount1 = discount1, discount2 = discount2 ) : price;
						quotationData['MMSCOAR1'] = discount1;
						quotationData['MMSCOAR2'] = discount2;
						quotationData['MMEVASIO'] = quotation.getValidityDate();
						quotationData['MM_STATO'] = 'N';
						quotationData["MMUTECOM"] = salesAgentId;
						quotationData["MMUTETEC"] = graphicTechnicianId;
					}
					// Nota della riga del preventivo (campo "Note"), sia per articoli che per prodotti
					quotationData["MMANNDET"] = quotationItem.getNote() ?: "";
					ArrayAppend( quotationItemsToExport, quotationData );
					index = index + 1;
				}

				for ( quotationItemToExport in quotationItemsToExport ) {
					getDao().export( quotationItemToExport );
					ArrayAppend( result.rows, exportRowSummary( quotationItemToExport ) );
				}

				var quotationPrice = getQuotationPriceService().calculate( quotation.getId() );
				if (!isNull(quotationPrice) && quotationPrice.getFlatDiscount() > 0) {
					var quotationPriceData = {}
					quotationPriceData.append(quotationDataHead);
					quotationPriceData['MMCODART'] = "000000000SCONTO";
					quotationPriceData['MMCODVAR'] = "0000000000";
					quotationPriceData['MMCODCOL'] = "00000";
					quotationPriceData['MMVALUNI'] = quotationPrice.getFlatDiscount();
					quotationPriceData['MMQTAMOV'] = 1;
					quotationPriceData["MMEVASIO"] = quotation.getValidityDate();
					quotationPriceData["MM_STATO"] = "N";
					quotationPriceData['CPROWNUM'] = index;
					quotationPriceData['CPROWORD'] = index * 10;
					quotationPriceData["MMUTECOM"] = salesAgentId;
					quotationPriceData["MMUTETEC"] = graphicTechnicianId;
					getDao().export( quotationPriceData );
					ArrayAppend( result.rows, exportRowSummary( quotationPriceData ) );
				}
			}
		}

		result.success = true;

		// notifyOrdersVerticale();

		return result;
	}

	/**
	 * Dati di testata scritti su ORDINI_APIR, da mostrare nel riepilogo
	 * dell'esportazione.
	 */
	private Struct function exportHeaderSummary( required Struct data ){
		return {
			"serial"           = arguments.data.MMSERIAL ?: "",
			"number"           = arguments.data.MMNUMDOC ?: "",
			"customerId"       = arguments.data.CF_IDCLI ?: "",
			"company"          = arguments.data.CFDESCR1 ?: "",
			"vatNumber"        = arguments.data.CFPARIVA ?: "",
			"billingAddress"   = Trim( ( arguments.data.CFINDIRI ?: "" ) & " " & ( arguments.data.CF___CAP ?: "" ) & " " & ( arguments.data.CFLOCALI ?: "" ) & " " & ( arguments.data.CFPROVIN ?: "" ) & " " & ( arguments.data.CFSTAISO ?: "" ) ),
			"shippingCompany"  = arguments.data.DEDESMER ?: "",
			"shippingAddress"  = Trim( ( arguments.data.DEINDMER ?: "" ) & " " & ( arguments.data.DECAPDES ?: "" ) & " " & ( arguments.data.DELOCMER ?: "" ) & " " & ( arguments.data.DEPROMER ?: "" ) & " " & ( arguments.data.DENAZMER ?: "" ) ),
			"shippingContact"  = arguments.data.MMRIFSPE ?: "",
			"reference"        = arguments.data.MMRIFORD ?: "",
			"po"               = arguments.data.MMRIF_PO ?: "",
			"claim"            = Trim( ( arguments.data.MMESEREC ?: "" ) & " " & ( Val( arguments.data.MMDOCREC ?: 0 ) ? arguments.data.MMDOCREC : "" ) & " " & ( arguments.data.MMALFREC ?: "" ) ),
			"agent"            = arguments.data.MMCODAGE ?: "",
			"paymentMethod"    = arguments.data.MMCODPAG ?: "",
			"vatCode"          = arguments.data.MMCODIVA ?: "",
			"deliveryDate"     = ( !IsNull( arguments.data.MMDATEVA ) && IsDate( arguments.data.MMDATEVA ) ) ? DateFormat( arguments.data.MMDATEVA, "dd/mm/yyyy" ) : "",
			"discount1"        = arguments.data.MMSCOCF1 ?: 0,
			"discount2"        = arguments.data.MMSCOCF2 ?: 0,
			"shippingCost"     = arguments.data.MMSPETRA ?: 0
		};
	}

	/**
	 * Riga scritta su ORDINI_APIR, da mostrare nel riepilogo dell'esportazione.
	 */
	private Struct function exportRowSummary( required Struct data ){
		return {
			"row"       = arguments.data.CPROWNUM ?: 0,
			"code"      = arguments.data.MMCODART ?: "",
			"variant"   = arguments.data.MMCODVAR ?: "",
			"color"     = arguments.data.MMCODCOL ?: "",
			"quantity"  = arguments.data.MMQTAMOV ?: 0,
			"price"     = arguments.data.MMVALUNI ?: 0,
			"discount1" = arguments.data.MMSCOAR1 ?: 0,
			"discount2" = arguments.data.MMSCOAR2 ?: 0,
			"note"      = arguments.data.MMANNDET ?: ""
		};
	}

	function getOriginalPrice(required numeric finalPrice, required numeric discount1, required numeric discount2) {
		var s1 = discount1 / 100;
		var s2 = discount2 / 100;

		var divisor = (1 - s1) * (1 - s2);

		if (divisor == 0) {
			throw(message = "Divisione per zero: controlla gli sconti");
		}

		return finalPrice / divisor;
	}

	public Array function getComponents(
		required String productId,
		required quotationItem,
		Array productItemIds = []
	){
		var quantity      = quotationItem.getQuantity() ? quotationItem.getQuantity() : 1;
		var allComponents = [];

		var productSvc   = getProductService();
		var componentSvc = getComponentService();

		var productId      = arguments.productId;
		var productItemIds = arguments.productItemIds;

		var product = productSvc.get( productId );
		if ( IsInstanceOf( product, "com.apirone.core.model.bean.ProductComplex" ) ) {

			var bundleComponents = componentSvc.list(
				lineId                         = product.getLine().getId(),
				modelId                        = product.getModel().getId(),
				includeBaseAttributeComponents = true
			);

			for ( var bundleComponent in bundleComponents ) {
				ArrayAppend( allComponents, parseComponent( bundleComponent ) );
			}

			if ( IsInstanceOf( quotationItem, "com.apirone.core.model.bean.QuotationItemSignage" ) ) {
				var signageConfigItemId = quotationItem.getSignageConfigItem().getId();

				// Come nel prezzo ( PriceCalculatorService.calculate ) questi componenti valgono
				// per singola lettera: la quantità in distinta è moltiplicata per le lettere
				// ( spazi esclusi ) e le materie prime con metadata KG-MMC / MQ diventano
				// peso / superficie della lettera per il coefficiente.
				var letters = 0;
				for ( var textRow in quotationItem.getSignageRows() ?: [] ) {
					letters += getQuotationItemService().signageLettersCount( {
						"charCount" = textRow.getCharCount(),
						"content"   = textRow.getContent() ?: ""
					} );
				}

				if ( letters > 0 ) {
					var calculator  = super.service( "PriceCalculator" );
					var letterSizes = calculator.signageLetterSizes( signageConfigItemId, product );

					if ( productItemIds.len() > 0 ) {
						var signagePiMap = getProductItemService().getMany( productItemIds );
						// un attributo alla volta: il coefficiente dipende dal suo raw value
						for ( var pid in productItemIds ) {
							var signageProductComps = componentSvc.listBySignageItemProductJoinIds(
								signageConfigItemId = signageConfigItemId,
								productItemIds      = [ pid ]
							);
							if ( !ArrayLen( signageProductComps ) ) {
								continue;
							}

							var measure = {};
							if ( StructKeyExists( signagePiMap, pid ) && !StructIsEmpty( letterSizes ) ) {
								measure = calculator.signageMaterialMeasure( signagePiMap[ pid ].getAttributeValue().getRawValue().getId() );
							}

							for ( var spc in signageProductComps ) {
								var signageComp = parseComponent( spc );
								var qtyPerLetter = Val( signageComp.DSQTAMOV );

								if ( !StructIsEmpty( measure ) && !IsNull( signageComp.DSCODMAT ) && Len( signageComp.DSCODMAT )
									&& componentSvc.getDao().getRawProductData( signageComp.DSCODMAT ).raw_product_processiong_type == "MP" ) {
									if ( measure.unit == "KG-MMC" ) {
										qtyPerLetter = letterSizes.volume * measure.coefficient;
									} else if ( measure.unit == "MQ" ) {
										qtyPerLetter = letterSizes.surfaceArea * measure.coefficient;
									}
								}

								signageComp.DSQTAMOV = qtyPerLetter * letters;
								if ( signageComp.DSQTAMOV > 0 ) {
									ArrayAppend( allComponents, signageComp );
								}
							}
						}
					}

					var signageComponents = componentSvc.list(
						signageConfigItemId            = signageConfigItemId,
						includeBaseAttributeComponents = true
					);
					for ( var signageComponent in signageComponents ) {
						var signageComp = parseComponent( signageComponent );
						signageComp.DSQTAMOV = Val( signageComp.DSQTAMOV ) * letters;
						if ( signageComp.DSQTAMOV > 0 ) {
							ArrayAppend( allComponents, signageComp );
						}
					}
				}
			}
		}

		var productComponents = componentSvc.list( productId = product.getId(), includeBaseAttributeComponents = true );

		for ( var productComponent in productComponents ) {
			ArrayAppend( allComponents, parseComponent( productComponent ) );
		}

		if ( productItemIds.len() > 0 ) {
			// Own components: batch con listByProductItemIds()
			var ownComponents = componentSvc.listByProductItemIds( productItemIds );
			for ( var oc in ownComponents ) {
				ArrayAppend( allComponents, parseComponent( oc ) );
			}

			// Base attribute components: corrisponde a includeBaseAttributeComponents=true
			// dell'originale searchByProductItemId() in ComponentService
			var compDao = componentSvc.getDao();
			var piMap   = getProductItemService().getMany( productItemIds );
			var attrValueIds = [];

			for ( var pid in productItemIds ) {
				if ( StructKeyExists( piMap, pid ) ) {
					var piBean  = piMap[ pid ];
					var attrVal = piBean.getAttributeValue();
					if ( !IsNull( attrVal ) && Len( attrVal.getId() ) ) {
						ArrayAppend( attrValueIds, attrVal.getId() );
					}
				}
			}

			if ( ArrayLen( attrValueIds ) ) {
				var attrRecords = compDao.readByAttributeValueIds( attrValueIds );

				// Raggruppa i componenti per attribute_raw_value_id
				var attrValueToCompIds = {};
				for ( var ar in attrRecords ) {
					if ( !StructKeyExists( attrValueToCompIds, ar.attribute_raw_value_id ) ) {
						attrValueToCompIds[ ar.attribute_raw_value_id ] = [];
					}
					ArrayAppend( attrValueToCompIds[ ar.attribute_raw_value_id ], ar.component_id );
				}

				// Raccoglie tutti i component ID e carica i bean con getMany()
				var allAttrCompIds = [];
				for ( var avid in attrValueToCompIds ) {
					for ( var cid in attrValueToCompIds[ avid ] ) {
						ArrayAppend( allAttrCompIds, cid );
					}
				}

				if ( ArrayLen( allAttrCompIds ) ) {
					var attrBeanMap = componentSvc.getMany( allAttrCompIds );

					for ( var pid in productItemIds ) {
						if ( !StructKeyExists( piMap, pid ) ) {
							continue;
						}
						var piBean  = piMap[ pid ];
						var attrVal = piBean.getAttributeValue();
						if ( IsNull( attrVal ) || !Len( attrVal.getId() ) ) {
							continue;
						}
						// Recupera solo i componenti dell'attributo di QUESTO specifico productItemId
						var myAttrCompIds = StructKeyExists( attrValueToCompIds, attrVal.getId() )
							? attrValueToCompIds[ attrVal.getId() ]
							: [];

						for ( var acid in myAttrCompIds ) {
							if ( !StructKeyExists( attrBeanMap, acid ) ) {
								continue;
							}
							var attrComp = attrBeanMap[ acid ];

							// Costruisce wrapper ComponentProductItem con type "base",
							// replicando la logica di searchByProductItemId() in ComponentService
							var baseBean = super.bean( "ComponentProductItem" );
							baseBean.setRawMemento( attrComp.getRawMemento() );
							baseBean.setProductItem( piBean );
							baseBean.setTypeId( "base" );

							var overrideSvc = componentSvc.getComponentOverrideService();
							var override    = overrideSvc.list( piBean.getId(), attrComp.getId() );
							if ( ArrayLen( override ) ) {
								baseBean.setOverride( override[ 1 ] );
							}

							ArrayAppend( allComponents, parseComponent( baseBean ) );
						}
					}
				}
			}
		}

		return allComponents;
	}

	public function parseComponent( com.apirone.core.model.bean.Component component ){
		var componente  = {
			"DS_CHIAVE" = "",
			"DSCODART"  = "",
			"DSCODVAR"  = "",
			"DSCODCOL"  = "",
			"DSCODMAT"  = component.getRawProduct()?.getId(),
			"DSVARMAT"  = component.getVariant().getId(),
			"DSCOLMAT"  = component.getColor().getId(),
			"DSQTAMOV"  = component.getQuantity(),
			"DSUNMIS1"  = component.getRawProduct()?.getMeasurementUnit()?.getId(),
			"CPROWNUM" = 0,
			"CPROWORD" = 0,
			"DSTIPRIG" = "R"
		};

		return componente;
	}

	private function prepareExportData( required com.apirone.core.model.bean.Quotation quotation ){
		var result = {
			"data" = {},
			"error" = null
		};
		var quotationPrice = getQuotationPriceService().calculate( quotation.getId() );
		var customer = quotation.getCustomer();

//		if (isNull(quotation.getShippingProfile())) {
//			result.error = "Dati spedizione non trovati."
//			return result;
//		}
		var quotationData = {
			"MMSERIAL" = quotation.getSerial(), // i need the same code
			"MM_IDRIF" = quotation.getQuotationNumber(), // i need the same code
			"MMNUMDOC" = quotation.getQuotationNumber() & "/" & quotation.getVersionNumber(),
			"MMDATDOC" = quotation.getCreatedAt(),
			"MMDATEVA" = !isNull(quotation.getDataEvasione()) ? quotation.getDataEvasione() : javaCast("null", ""),
			"MMEVASIO" = !isNull(quotation.getDataEvasione()) ? quotation.getDataEvasione() : javaCast("null", ""),
			"MMRIFORD" = quotation.getRifLibero() ?: "",
			"MMRIF_PO" = quotation.getPo() ?: "",
			"MMESEREC" = quotation.getReclamoAnno() ?: "", // reclamo: anno fattura
			"MMDOCREC" = quotation.getReclamoNumero() ?: 0, // reclamo: numero fattura
			"MMALFREC" = quotation.getReclamoAlfa() ?: "", // reclamo: alfa fattura
			"MMNUMLIS" = 1,
			"CFLINGUA" = !isNull(quotation.getLang()) ? UCase(quotation.getLang().getId()) : "IT",
			"MMCODAGE" = (!isNull(quotation.getAgente1()) && Len(quotation.getAgente1())) ? getAccountService().get(quotation.getAgente1()).getIdAgenteVerticale() : null,
			"MMCODAG2" = (!isNull(quotation.getAgente2()) && Len(quotation.getAgente2())) ? getAccountService().get(quotation.getAgente2()).getIdAgenteVerticale() : null,
			"MMCODAG3" = (!isNull(quotation.getAgente3()) && Len(quotation.getAgente3())) ? getAccountService().get(quotation.getAgente3()).getIdAgenteVerticale() : null,
			"MMCODAG4" = (!isNull(quotation.getAgente4()) && Len(quotation.getAgente4())) ? getAccountService().get(quotation.getAgente4()).getIdAgenteVerticale() : null,
			"MMCODAG5" = (!isNull(quotation.getAgente5()) && Len(quotation.getAgente5())) ? getAccountService().get(quotation.getAgente5()).getIdAgenteVerticale() : null,
			"MMPERPRO" = !isNull(quotation.getCommission1()) ? quotation.getCommission1() : 0,
			"MMPERPR2" = !isNull(quotation.getCommission2()) ? quotation.getCommission2() : 0,
			"MMPERPR3" = !isNull(quotation.getCommission3()) ? quotation.getCommission3() : 0,
			"MMPERPR4" = !isNull(quotation.getCommission4()) ? quotation.getCommission4() : 0,
			"MMPERPR5" = !isNull(quotation.getCommission5()) ? quotation.getCommission5() : 0,
			"MMCODPAG" = quotation.getPaymentMethod().getId(),
			"MMCODVAL" = quotation.getCurrency().getId(),
			"MMCODIVA" = !isNull( quotation.getVatCode() ) ? quotation.getVatCode().getId() : "", // aliquota IVA = ivacod di verticale_vat_codes.
			"CF_IDCLI" = customer.getId(),
			"CF___CAP" = customer.getPostalCode(),
			"CFDESCR1" = customer.getCompany(),
			"CFINDIRI" = customer.getStreet(),
			"CFLOCALI" = customer.getCity(),
			"CFPROVIN" = customer.getState(),
			"CFSTAISO" = customer.getCountry()?.getIsoCode(),
			"CFPARIVA" = customer.getVatNumber(),
			"CFTELEFO" = customer.getPhone(),
			"CFEMAIL"  = customer.getEmail() ?: "", // email del cliente dal CRM ( CrmMapper.extractEmail )
			"CFBLOCCO" = "N",
			"CFMOROSO" = "N",
			"CFREFAMM" = quotation.getReferenteAmministrativo() ?: "",
			"MMRIFSPE"  = quotation.getReferenteSpedizione() ?: "",
			"MMANNTES"  = quotation.getReferenteSpedizione() ?: "", // referente spedizione anche nelle annotazioni di testata
			"MMNOTPOS"  = quotation.getNote() ?: "",
			"CFTIPCLF" = (function(){
				var crmToErp = {
					"CAT" = "CA", "HOT" = "HO", "HO1" = "H1", "HO2" = "H2", "HO3" = "H3",
					"HO4" = "H4", "HO5" = "H5", "BEB" = "BB", "RIS" = "RI", "AGR" = "AG",
					"CAM" = "CM", "AGE" = "AE", "CLI" = "CL", "RES" = "RS", "UFF" = "UF",
					"ARC" = "AR", "CEN" = "CN", "CON" = "CO", "RIV" = "RV", "IMC" = "IC",
					"COl" = "CP", "AZI" = "AZ", "PRO" = "PR", "COS" = "CS", "ELE" = "EL",
					"ENT" = "EN", "NEG" = "NE", "AGA" = "AA", "CCR" = "CC", "PRI" = "PI",
					"Installatore Elettrico" = "IE", "Tour Operator" = "TO", "Other" = "OT"
				};
				var ct = quotation.getCustomerType() ?: "";
				return StructKeyExists( crmToErp, ct ) ? crmToErp[ ct ] : "";
			})(),
			"INDUSTRY" = quotation.getIndustry() ?: "",
			"MMORDFOR" = "",
			"CFCODDES" = quotation.getCodiceSdi() ?: "",
			"MMORDPRO" = "N",
			"MMSCOCF1" = quotationPrice.getDiscount1(),
			"MMSCOCF2" = quotationPrice.getDiscount2(),
			"MMSPETRA" = quotationPrice.getShippingCost(),
			"DECAPDOC" = customer.getPostalCode(),
			"DEDESDOD" = customer.getCompany(),
			"DEINDDOD" = customer.getStreet(),
			"DELOCDOD" = customer.getCity(),
			"DEPRODOD" = customer.getState(),
			"DENAZDOD" = customer.getCountry()?.getIsoCode(),
		};

		if (isNull(quotation.getShippingProfile())) {
			quotationData["DECAPDES"] = "";
			quotationData["DEIDDMER"] = "";
			quotationData["DEDESMER"] = "";
			quotationData["DEINDMER"] = "";
			quotationData["DELOCMER"] = "";
			quotationData["DEPROMER"] = "";
			quotationData["DENAZMER"] = "";
		} else {
			quotationData["DECAPDES"] = quotation.getShippingProfile().getPostalCode();
			quotationData["DEIDDMER"] = quotation.getShippingProfile().getId();
			quotationData["DEDESMER"] = quotation.getShippingProfile().getCompany();
			quotationData["DEINDMER"] = quotation.getShippingProfile().getStreet();
			quotationData["DELOCMER"] = quotation.getShippingProfile().getCity();
			quotationData["DEPROMER"] = quotation.getShippingProfile().getState();
			quotationData["DENAZMER"] = quotation.getShippingProfile().getCountry()?.getIsoCode();
		}


		result.data = quotationData;
		return result;
	}

	/**
	 * Le righe con elementi non più a catalogo non si copiano
	 * ( CatalogUsageService.deletedInQuotation ).
	 */
	public String function clone( required com.apirone.core.model.bean.Quotation quotation ){
		var originalQuotation = arguments.quotation;
		var clonedQuotation = Duplicate( originalQuotation );
		clonedQuotation.setId( "" );
		clonedQuotation.setNote( "Copia di " & originalQuotation.getQuotationNumber() & "/" & originalQuotation.getVersionNumber() );
		var clonedQuotationId = create( clonedQuotation, session.user.getId(), true );

		var quotationZones = getQuotationZoneService().list( quotationId = originalQuotation.getId() );
		var skipItemIds    = getCatalogUsageService().deletedInQuotation( originalQuotation.getId() ).itemIds;

		for ( var quotationZone in quotationZones ) {
			getQuotationZoneService().duplicate( zoneId = quotationZone.getId(), quotationId = clonedQuotationId, skipItemIds = skipItemIds )
		}

		getPlanningService().copyQuotationWorkHours( originalQuotation.getId(), clonedQuotationId );

		quotationService.update( originalQuotation );

		return clonedQuotationId;
	}

	/**
	 * Prossimo numero di versione di un preventivo ( max + 1 ), sotto lock per numero
	 * preventivo: va chiamato dentro la stessa transazione che inserisce la nuova
	 * versione, così il lock copre lettura e scrittura. Senza, due richieste
	 * ravvicinate leggevano lo stesso massimo e producevano due versioni uguali.
	 * Il vincolo UNIQUE ( quotation_number, version_number ) resta come ultima difesa.
	 */
	private Numeric function nextVersionNumber( required String quotationNumber ){
		getDao().lockVersionNumbering( arguments.quotationNumber );
		return getDao().readMaxVersionNumber( arguments.quotationNumber ) + 1;
	}

	public Void function markAsSent( required String quotationId ){
		getDao().markAsSent( arguments.quotationId );
	}

	/**
	 * Le righe con elementi non più a catalogo non si copiano
	 * ( CatalogUsageService.deletedInQuotation ).
	 */
	public String function createRevision( required com.apirone.core.model.bean.Quotation quotation ){
		var originalQuotation = arguments.quotation;
		var clonedQuotation   = Duplicate( originalQuotation );
		clonedQuotation.setId( "" );
		clonedQuotation.setActive( 1 );
		clonedQuotation.setSentToClient( false );
		clonedQuotation.setQuotationNumber( originalQuotation.getQuotationNumber() );

		transaction {
			clonedQuotation.setVersionNumber( nextVersionNumber( originalQuotation.getQuotationNumber() ) );
			var clonedQuotationId = create( clonedQuotation, session.user.getId(), false, true );
		}

		var quotationZones = getQuotationZoneService().list( quotationId = originalQuotation.getId() );
		var skipItemIds    = getCatalogUsageService().deletedInQuotation( originalQuotation.getId() ).itemIds;
		for ( var quotationZone in quotationZones ) {
			getQuotationZoneService().duplicate( zoneId = quotationZone.getId(), quotationId = clonedQuotationId, skipItemIds = skipItemIds );
		}

		getPlanningService().copyQuotationWorkHours( originalQuotation.getId(), clonedQuotationId );
		// la nuova versione resta nel progetto del Gantt della precedente
		getPlanningService().copyProjectLink( originalQuotation.getId(), clonedQuotationId );

		return clonedQuotationId;
	}

	/*
		private method
	*/

	private Void function notifyProductsVerticale(){

		cfhttp( url = "http://194.183.87.112:8080/verticale_web_data/servlet/api/v1/apir_update_articoli/ALL", method = "POST", result="result" ) {
			cfhttpparam( type = "header", name = "Content-Type", value = "application/json" );
			cfhttpparam( type = "header", name = "Authorization", value = "Basic #variables.verticaleSecret#" );
		}

		cffile( action="APPEND" file="#ExpandPath('/debug.log')#" output="#now()# notifyVerticale: apir_update_articoli: status: #result.status_code#");

	}

	private Void function notifyOrdersVerticale(){

		var user = "apikey";
		var pwd = "Gs16072001!";
		var secret = ToBase64('#user#:#pwd#');

		cfhttp( url = "http://194.183.87.112:8080/verticale_web_data/servlet/api/v1/apir_update_ordini/ALL", method = "POST", result="result" ) {
			cfhttpparam( type = "header", name = "Content-Type", value = "application/json" );
			cfhttpparam( type = "header", name = "Authorization", value = "Basic #variables.verticaleSecret#" );
		}

		cffile( action="APPEND" file="#ExpandPath('/debug.log')#" output="#now()# notifyVerticale: apir_update_ordini: status: #result.status_code#");

	}

	/**
	 * Recupera in batch più Quotation dato un array di ID.
	 * Restituisce uno Struct chiave = quotationId, valore = bean Quotation.
	 * precarica User e QuotationStatusHistory in batch per evitare il problema N+1.
	 *
	 * @ids Array di quotationId
	 * @return Struct mappato per quotationId -> Quotation
	 */
	public Struct function getMany( required Array ids ){
		var records = getDao().readByIds( ids = arguments.ids );
		var map     = {};

		// Raccoglie tutti gli user_id (owner, salesAgent, graphicTechnician)
		var allUserIds = [];
		for ( var r in records ) {
			if ( !IsNull( r.owner_id ) ) {
				allUserIds.append( r.owner_id );
			}
			if ( !IsNull( r.sales_agent_account_id ) ) {
				allUserIds.append( r.sales_agent_account_id );
			}
			if ( !IsNull( r.graphic_technician_account_id ) ) {
				allUserIds.append( r.graphic_technician_account_id );
			}
		}

		// Precarica gli User in batch (1 query per tutti e 3 i ruoli)
		var userMap = {};
		if ( ArrayLen( allUserIds ) ) {
			userMap = getUserService().getMany( allUserIds );
		}

		// Raccoglie i quotation_status_history_id
		var statusHistoryIds = [];
		for ( var r in records ) {
			if ( !IsNull( r.quotation_status_history_id ) ) {
				statusHistoryIds.append( r.quotation_status_history_id );
			}
		}

		// Precarica i QuotationStatusHistory in batch (1 query)
		var statusHistoryMap = {};
		if ( ArrayLen( statusHistoryIds ) ) {
			statusHistoryMap = getQuotationStatusHistoryService().getMany( statusHistoryIds );
		}

		// Precarica i totali calcolati in batch (1 query invece di N)
		var quotationIds = [];
		for ( var r in records ) {
			quotationIds.append( r.quotation_id );
		}
		var totalMap = getDao().getQuotationTotals( quotationIds );

		// Costruisce i bean Quotation con le mappe pre-caricate
		for ( var r in records ) {
			var bean = super.bean( "Quotation" );

			// Campi diretti dal record
			bean.setId( r.quotation_id.toString() );
			bean.setSerial( r.serial );
			bean.setName( r.quotation );
			bean.setQuotationNumber( r.quotation_number );
			bean.setVersionNumber( r.version_number );
			bean.setQuotationDate( r.quotation_date );
			bean.setCreatedAt( r.created_at );
			bean.setNote( r.note );
			bean.setValidityDate( r.validity_date );
			bean.setExported( r.exported );
			bean.setActive( r.active );

			// Lang, Currency, PaymentMethod: chiamate individuali (cache interna)
			bean.setLang( getLangService().get( r.lang_id ) );
			bean.setCurrency( getCurrencyService().get( r.currency_id ) );
			bean.setPaymentMethod( getPaymentMethodService().get( r.payment_method_id ) );

			// Owner, SalesAgent, GraphicTechnician: dalla mappa batch
			if ( !IsNull( r.owner_id ) && StructKeyExists( userMap, r.owner_id ) ) {
				bean.setOwner( userMap[ r.owner_id ] );
			} else if ( !IsNull( r.owner_id ) ) {
				bean.setOwner( getUserService().get( r.owner_id.toString() ) );
			}

			if ( !IsNull( r.sales_agent_account_id ) && StructKeyExists( userMap, r.sales_agent_account_id ) ) {
				bean.setSalesAgent( userMap[ r.sales_agent_account_id ] );
			} else if ( !IsNull( r.sales_agent_account_id ) ) {
				bean.setSalesAgent( getUserService().get( r.sales_agent_account_id.toString() ) );
			}

			if ( !IsNull( r.graphic_technician_account_id ) && StructKeyExists( userMap, r.graphic_technician_account_id ) ) {
				bean.setGraphicTechnician( userMap[ r.graphic_technician_account_id ] );
			} else if ( !IsNull( r.graphic_technician_account_id ) ) {
				bean.setGraphicTechnician( getUserService().get( r.graphic_technician_account_id.toString() ) );
			}

			// StatusHistory: dalla mappa batch
			if ( !IsNull( r.quotation_status_history_id ) && StructKeyExists( statusHistoryMap, r.quotation_status_history_id ) ) {
				bean.setStatusHistory( statusHistoryMap[ r.quotation_status_history_id ] );
			}

			// Agenti e commissioni (campi diretti)
			bean.setNessunAgente( r.nessun_agente );
			if ( !IsNull( r.agente1 ) && Len( r.agente1 ) ) bean.setAgente1( r.agente1.toString() );
			if ( !IsNull( r.agente2 ) && Len( r.agente2 ) ) bean.setAgente2( r.agente2.toString() );
			if ( !IsNull( r.agente3 ) && Len( r.agente3 ) ) bean.setAgente3( r.agente3.toString() );
			if ( !IsNull( r.agente4 ) && Len( r.agente4 ) ) bean.setAgente4( r.agente4.toString() );
			if ( !IsNull( r.agente5 ) && Len( r.agente5 ) ) bean.setAgente5( r.agente5.toString() );
			if ( !IsNull( r.commission1 ) ) bean.setCommission1( r.commission1 );
			if ( !IsNull( r.commission2 ) ) bean.setCommission2( r.commission2 );
			if ( !IsNull( r.commission3 ) ) bean.setCommission3( r.commission3 );
			if ( !IsNull( r.commission4 ) ) bean.setCommission4( r.commission4 );
			if ( !IsNull( r.commission5 ) ) bean.setCommission5( r.commission5 );
			if ( Len( r.referente_amministrativo ) ) bean.setReferenteAmministrativo( r.referente_amministrativo );
			if ( Len( r.referente_spedizione ) ) bean.setReferenteSpedizione( r.referente_spedizione );
			if ( Len( r.customer_type ) ) bean.setCustomerType( r.customer_type );
			if ( Len( r.industry ) ) bean.setIndustry( r.industry );
			if ( Len( r.rif_libero ) ) bean.setRifLibero( r.rif_libero );
			if ( Len( r.po ) ) bean.setPo( r.po );
			if ( Len( r.reclamo_anno ) ) bean.setReclamoAnno( r.reclamo_anno );
			if ( !IsNull( r.reclamo_numero ) ) bean.setReclamoNumero( r.reclamo_numero );
			if ( Len( r.reclamo_alfa ) ) bean.setReclamoAlfa( r.reclamo_alfa );
			if ( IsDate( r.data_evasione ) ) bean.setDataEvasione( r.data_evasione );
			if ( !IsNull( r.sent_to_client ) ) bean.setSentToClient( r.sent_to_client );
			if ( !IsNull( r.data_conferma_ordine ) && IsDate( r.data_conferma_ordine ) ) bean.setDataConfermaOrdine( r.data_conferma_ordine );
			if ( Len( r.codice_sdi ) ) bean.setCodiceSdi( r.codice_sdi );

			// Customer: chiamata individuale (CRM API, cache interna)
			if ( !IsNull( r.customer_id ) ) {
				var customer = getCustomerService().get( r.customer_id );
				bean.setCustomer( customer );

				if ( !IsNull( r.shipping_profile_id ) ) {
					for ( var thisAddress in customer.getShippingProfiles() ) {
						if ( thisAddress.getId() == r.shipping_profile_id ) {
							bean.setShippingProfile( thisAddress );
							break;
						}
					}
				}
			}

			// Opportunity, Lead, VatCode: chiamate individuali (CRM/verticale, cache interna)
			if ( !IsNull( r.opportunity_id ) ) {
				bean.setOpportunity( getOpportunityService().get( r.opportunity_id.toString() ) );
			}
			if ( !IsNull( r.lead_id ) ) {
				bean.setLead( getLeadService().get( r.lead_id ) );
			}
			if ( !IsNull( r.vat_code_id ) ) {
				bean.setVatCode( getVatCodeService().get( r.vat_code_id ) );
			}

			// Totale calcolato: dalla mappa batch
			bean.setCalculatedAmount(
				StructKeyExists( totalMap, r.quotation_id ) ? totalMap[ r.quotation_id ] : 0
			);

			map[ r.quotation_id ] = bean;
		}

		return map;
	}

	/**
	 * Costruisce un bean Quotation a partire dall'ID. Delega a buildFromRow() dopo la lettura del record.
	 */
	private com.apirone.core.model.bean.Quotation function build( required String quotationId ){
		var record = getDao().read( arguments.quotationId );

		if ( record.recordCount ) {
			return buildFromRow( record );
		}

		return NullValue();
	}

	/**
	 * Costruisce un bean Quotation a partire da una riga del query.
	 * Le sub-entity (Lang, Currency, Owner, PaymentMethod, StatusHistory, Customer, ecc.) sono caricate con chiamate individuali.
	 */
	private com.apirone.core.model.bean.Quotation function buildFromRow( required any record ){
		var bean = super.bean( "Quotation" );

		var calculatedAmount = 0;

		// Campi diretti dal record
		bean.setId( arguments.record.quotation_id.toString() );
		bean.setSerial( arguments.record.serial );
		bean.setName( arguments.record.quotation );
		bean.setQuotationNumber( arguments.record.quotation_number );
		bean.setVersionNumber( arguments.record.version_number );
		bean.setQuotationDate( arguments.record.quotation_date );
		bean.setCreatedAt( arguments.record.created_at );
		bean.setNote( arguments.record.note );
		bean.setValidityDate( arguments.record.validity_date );
		bean.setExported( arguments.record.exported );
		bean.setActive( arguments.record.active );
		bean.setLang( getLangService().get( arguments.record.lang_id ) );
		bean.setCurrency( getCurrencyService().get( arguments.record.currency_id ) );
		bean.setOwner( getUserService().get( arguments.record.owner_id.toString() ) );
		bean.setPaymentMethod( getPaymentMethodService().get( arguments.record.payment_method_id ) );

		bean.setNessunAgente( arguments.record.nessun_agente );
		if ( !IsNull( arguments.record.agente1 ) && Len( arguments.record.agente1 ) ) bean.setAgente1( arguments.record.agente1.toString() );
		if ( !IsNull( arguments.record.agente2 ) && Len( arguments.record.agente2 ) ) bean.setAgente2( arguments.record.agente2.toString() );
		if ( !IsNull( arguments.record.agente3 ) && Len( arguments.record.agente3 ) ) bean.setAgente3( arguments.record.agente3.toString() );
		if ( !IsNull( arguments.record.agente4 ) && Len( arguments.record.agente4 ) ) bean.setAgente4( arguments.record.agente4.toString() );
		if ( !IsNull( arguments.record.agente5 ) && Len( arguments.record.agente5 ) ) bean.setAgente5( arguments.record.agente5.toString() );
		if ( !IsNull( arguments.record.commission1 ) ) bean.setCommission1( arguments.record.commission1 );
		if ( !IsNull( arguments.record.commission2 ) ) bean.setCommission2( arguments.record.commission2 );
		if ( !IsNull( arguments.record.commission3 ) ) bean.setCommission3( arguments.record.commission3 );
		if ( !IsNull( arguments.record.commission4 ) ) bean.setCommission4( arguments.record.commission4 );
		if ( !IsNull( arguments.record.commission5 ) ) bean.setCommission5( arguments.record.commission5 );
		if ( Len( arguments.record.referente_amministrativo ) ) bean.setReferenteAmministrativo( arguments.record.referente_amministrativo );
		if ( Len( arguments.record.referente_spedizione ) ) bean.setReferenteSpedizione( arguments.record.referente_spedizione );
		if ( Len( arguments.record.customer_type ) ) bean.setCustomerType( arguments.record.customer_type );
		if ( Len( arguments.record.industry ) ) bean.setIndustry( arguments.record.industry );
		if ( Len( arguments.record.rif_libero ) ) bean.setRifLibero( arguments.record.rif_libero );
		if ( Len( arguments.record.po ) ) bean.setPo( arguments.record.po );
		if ( Len( arguments.record.reclamo_anno ) ) bean.setReclamoAnno( arguments.record.reclamo_anno );
		if ( !IsNull( arguments.record.reclamo_numero ) ) bean.setReclamoNumero( arguments.record.reclamo_numero );
		if ( Len( arguments.record.reclamo_alfa ) ) bean.setReclamoAlfa( arguments.record.reclamo_alfa );
		if ( IsDate( arguments.record.data_evasione ) ) bean.setDataEvasione( arguments.record.data_evasione );
		if ( !IsNull( arguments.record.sent_to_client ) ) bean.setSentToClient( arguments.record.sent_to_client );
		if ( !IsNull( arguments.record.data_conferma_ordine ) && IsDate( arguments.record.data_conferma_ordine ) ) bean.setDataConfermaOrdine( arguments.record.data_conferma_ordine );
		if ( Len( arguments.record.codice_sdi ) ) bean.setCodiceSdi( arguments.record.codice_sdi );

		//by a trigger from history
		//bean.setStatus( getStatusService().get( arguments.record.status_id ) );
		bean.setStatusHistory( getQuotationStatusHistoryService().get( arguments.record.quotation_status_history_id ) );

		if ( !IsNull( arguments.record.customer_id ) ) {

			var customer = getCustomerService().get( arguments.record.customer_id );
			bean.setCustomer( customer );

			// cerco l'indirizzo di spedizione tra gli indirizzi del customer
			if ( !IsNull( arguments.record.shipping_profile_id ) ) {
				for( var thisAddress in customer.getShippingProfiles() ) {
					if ( thisAddress.getId() == arguments.record.shipping_profile_id ) {
						bean.setShippingProfile( thisAddress );
						break;
					}
				}
			}

		}

		/*
		var quotationStatusHistories = getQuotationStatusHistoryService().list( quotationId = arguments.record.quotation_id, statusId = arguments.record.status_id );

		if ( quotationStatusHistories.len() > 0 && arguments.record.status_id == 'CCN' ) {
			var statusFiles = getFileService().list( quotationStatusHistoryId = quotationStatusHistories[1].getId() );
			if ( statusFiles.len() > 0 ) {
				bean.setStatusFile( statusFiles[1] )
			}
		}
		*/

		if ( !IsNull( arguments.record.opportunity_id ) ) {
			bean.setOpportunity( getOpportunityService().get( arguments.record.opportunity_id.toString() ) );
		}

		if ( !IsNull( arguments.record.lead_id ) ) {
			bean.setLead( getLeadService().get( arguments.record.lead_id ) );
		}

		if ( !IsNull( arguments.record.vat_code_id ) ) {
			bean.setVatCode( getVatCodeService().get( arguments.record.vat_code_id ) );
		}

		if ( !IsNull( arguments.record.sales_agent_account_id ) ) {
			bean.setSalesAgent( getUserService().get( arguments.record.sales_agent_account_id.toString() ) );
		}

		if ( !IsNull( arguments.record.graphic_technician_account_id ) ) {
			bean.setGraphicTechnician( getUserService().get( arguments.record.graphic_technician_account_id.toString() ) );
		}

		bean.setCalculatedAmount(
			getDao().getQuotationTotal( argumentCollection = { quotationId = bean.getId() } )
		);

		// bean.setPricelist( getPricelistService().get( arguments.record.pricelist_id ) );
		// bean.setBillingProfile( getProfileService().get( arguments.record.billing_profile_id ) );
		// bean.setgraphicTechnician( getAccountService().get( arguments.record.graphic_technician_account_id ) );

		return bean;
	}

}
