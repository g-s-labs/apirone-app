component extends="com.apirone.core.model.service.AbsService" accessors="true" {

	property name="dao" inject="QuotationItemDAO";
	property name="quotationItemFruitService" inject="QuotationItemFruitService";
	property name="quotationItemPriceService" inject="QuotationItemPriceService";
	property name="quotationItemPriceLineService" inject="QuotationItemPriceLineService";
	property name="QuotationService" inject="QuotationService";
	property name="QuotationZoneService" inject="QuotationZoneService";
	property name="QuotationItemProductItemService" inject="QuotationItemProductItemService";
	property name="ProductService" inject="ProductService";
	property name="ComponentService" inject="ComponentService";
	property name="StatusService" inject="StatusService";
	property name="ArticleService" inject="ArticleService";
	property name="ProductHashService" inject="ProductHashService";
	property name="SignageConfigItemService" inject="SignageConfigItemService";
	property name="FileService" inject="FileService";
	property name="QuotationItemSignageRowService" inject="QuotationItemSignageRowService";
	property name="QuotationZonePositionService" inject="QuotationZonePositionService";
	property name="QuotationItemPositionService" inject="QuotationItemPositionService";
	property name="LookupService" inject="LookupService";
	property name="CatalogBundleService" inject="CatalogBundleService";
	property name="TextService" inject="TextService";
	property name="PriceService" inject="PriceService";
	property name="ProductItemService" inject="ProductItemService";

	// Costanti prodotto dei tappi: "tappo" = tappo intero, "mezzotappo" = mezzo tappo.
	variables.plugProductIds = {
		"tappo"      = "5f4ec169-c445-40a0-8c94-1dc22c21be79",
		"mezzotappo" = "452e03e4-ddf4-4042-ac87-b0f17489c4e1"
	};
	variables.plugProductIdList = [ variables.plugProductIds.tappo, variables.plugProductIds.mezzotappo ];

	public com.apirone.core.model.bean.QuotationItem function get( required String quotationItemId ){
		return build( arguments.quotationItemId );
	}

	public Array function list(){
		arguments[ "limit" ] = -1;
		return search( argumentCollection = arguments ).getData();
	}

	public com.apirone.core.model.bean.Result function search(
		String str,
		String mode,
		required Numeric limit  = 15,
		required Numeric offset = 0,
		required Array orderBy  = [ { field = "quotation.id" } ]
	){
		arguments[ "orderby" ] = super.createOrderBy( arguments[ "orderby" ] );

		var rows    = [];
		var result  = super.getResult();

		// Primo passaggio: il find() restituisce solo gli ID (più il totale per paginazione)
		var records = getDao().find( argumentCollection = arguments );

		// Raccoglie tutti gli ID e carica i record in blocco con una sola query
		var ids = [];
		records.each( function( r ){
			ids.append( r.quotation_item_id );
		} );

		// Costruisce tutti i bean in batch con getMany() ottimizzato (evita N+1)
		var beanMap = ArrayLen( ids ) ? getMany( ids ) : {};

		// Ricostruisce le righe nell'ordine del find() originale, applicando il filtro mode
		records.each( function( record ) {
			var quotationItem = beanMap[ record.quotation_item_id ];
			if ( IsNull( mode ) ) {
				rows.add( quotationItem );
			} else {
				if ( mode == "plate" ) {
					if ( IsInstanceOf( quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" ) ) {
						rows.add( quotationItem );
					}
				} else {
					if ( !IsInstanceOf( quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" ) ) {
						rows.add( quotationItem );
					}
				}
			}
		} );

		result.setData( rows );
		result.setCount( Val( records.recordcount ) );
		result.setTotal( Val( records.total ) );

		return result;
	}

	public void function reorder( required Array ids ){
		var ordinamento = 10;
		for ( var id in arguments.ids ) {
			getDao().updateOrdinamento( id, ordinamento );
			ordinamento += 10;
		}
	}

	public Query function listForZoneDeletion( required String quotationZoneId ){
		return getDao().listForZoneDeletion( arguments.quotationZoneId );
	}

	/**
	 * Cancella tutte le righe di una zona con una sola DELETE e poi ricalcola i
	 * prezzi delle righe rimaste che condividevano costi fissi con quelle
	 * cancellate, una volta per gruppo: stesso effetto della cancellazione riga
	 * per riga ( QuotationItemAjaxController.delete ) senza caricare i bean.
	 * Va chiamato dentro la transazione del chiamante.
	 *
	 * @return numero di righe cancellate
	 */
	public Numeric function deleteByZone( required String quotationZoneId ){
		var rows       = getDao().listForZoneDeletion( arguments.quotationZoneId );
		var repricings = {};

		for ( var row in rows ) {
			if ( Len( row.article_id ) || !Len( row.product_id ) ) continue;

			if ( row.is_plate || row.is_signage ) {
				// senza linea o finitura non c'è un gruppo di costi fissi da ricalcolare
				if ( !Len( row.line_id ) || !Len( row.finish_id ) ) continue;
				var key = "lfm|" & row.line_id & "|" & row.finish_id & "|" & row.model_id;
				repricings[ key ] = {
					"lfm"  = true,
					"args" = {
						"quotationId"     = row.quotation_id,
						"quotationItemId" = row.quotation_item_id,
						"lineId"          = row.line_id,
						"finishId"        = row.finish_id,
						"modelId"         = row.model_id
					}
				};
			} else {
				repricings[ "p|" & row.product_id ] = {
					"lfm"  = false,
					"args" = {
						"quotationId"     = row.quotation_id,
						"quotationItemId" = row.quotation_item_id,
						"productId"       = row.product_id
					}
				};
			}
		}

		var deleted = getDao().deleteByZone( arguments.quotationZoneId );

		for ( var key in repricings ) {
			if ( repricings[ key ].lfm ) {
				aggiornaPrezzoAltriArticoliByQuotationIdLineIdFinishId( argumentCollection = repricings[ key ].args );
			} else {
				aggiornaPrezzoAltriArticoliByQuotationIdAndProductId( argumentCollection = repricings[ key ].args );
			}
		}

		return deleted;
	}

	public com.apirone.core.model.bean.Outcome function delete( required String quotationItemId ){
		var outcome = super.bean( "Outcome" );

		outcome.setData( { quotationItemId = arguments.quotationItemId } );

		transaction {
			try {
				getDao().delete( arguments.quotationItemId );
			} catch ( any error ) {
				outcome.setError( error );
				outcome.setStatus( "ERROR" );
				outcome.setType( "ApirOne.CannotDeleteQuotationItem" );
				outcome.setMessage( "Cannot delete quotation item [#arguments.quotationItemId#]" );
			}
		}

		return outcome;
	}

	public String function create( required com.apirone.core.model.bean.QuotationItem quotationItem ){

		transaction {

			arguments.quotationItem = ensurePosition( arguments.quotationItem );

			if ( !IsNumeric( arguments.quotationItem.getOrdinamento() ) || arguments.quotationItem.getOrdinamento() == 0 ) {
				if ( !isNull( arguments.quotationItem.getArticle() ) ) {
					var typeId = "ART";
				} else if ( IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" ) ) {
					var typeId = "PLA";
				} else if ( IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemSignage" ) ) {
					var typeId = "SEG";
				} else {
					var typeId = "ACC";
				}
				var maxOrd = getDao().getMaxOrdinamento( arguments.quotationItem.getQuotation().getId(), typeId );
				arguments.quotationItem.setOrdinamento( maxOrd + 10 );
			}

			var newId = getDao().insert( arguments.quotationItem );

			if ( IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" ) ) {
				for ( var thisFruit in arguments.quotationItem.getFruits() ) {
					thisFruit.setQuotationItemId( newId );
					thisFruit.setId(null)
					getQuotationItemFruitService().create( thisFruit );
				}
			}

			var price = arguments.quotationItem.getPrice();
			price.setQuotationItemId( newId );
			getQuotationItemPriceService().create( price );

			if ( isNull( arguments.quotationItem.getArticle() ) ) {
				var hash = getProductHashService().createHash( newId );
				if ( !IsNull( hash ) ) {
					updateHash( newId, hash );
				}
			}

			if (isNull(quotationItem.getArticle())) {
				var quotationItemQuantity = arguments.quotationItem.getQuantity();
				if (quotationItemQuantity > 0) {
					for (var i = 1; i <= quotationItemQuantity; i++) {
						var position = super.bean("QuotationItemPosition");
						position.setQuotationItemId(newId);
						getQuotationItemPositionService().create(position);
					}
				}
			}

		}

		return newId;
	}

	public String function update( required com.apirone.core.model.bean.QuotationItem quotationItem ){
		// Se l'impronta dell'item (calcolata sui dati in memoria) coincide con quella salvata
		// nel bean (hash letta dal DB durante il build), la configurazione non è cambiata:
		// l'hash esclude prezzo e quantità ma include frutti, posizioni, note e tappi
		// ricalcolati, quindi salta la riscrittura completa di frutti/posizioni/product item
		// e anche la riscrittura dell'hash stessa (la riga su product_hashes esiste già ed è
		// già collegata: risparmia ricerca, lettura e UPDATE per ogni item gemello).
		// Il confronto usa computeOnly: l'MD5 è calcolato solo in memoria, senza query.
		// Tipico dell'aggiornaPrezzo dei gemelli, che cambia solo il prezzo.
		// Il confronto fra i frutti serve solo per gli ID: legge gli id esistenti
		// con una sola query invece di ricaricare e ricostruire l'intero item con
		// getMany() (cascata N+1 di build completi)
		// Se l'hash salvato non esiste (item nuovo o mai persistito) il confronto non scatta
		// e la riscrittura completa dei frutti avviene come prima.
		var oldFruitIds = [];
		var fruitIdsToDeleted = [];
		var doSkipFruits = false;
		var newHash = NullValue();
		if ( IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" ) ) {
			newHash = getProductHashService().createHash( arguments.quotationItem.getId(), arguments.quotationItem, true );
			var storedHash = arguments.quotationItem.getHash();
			doSkipFruits = !IsNull( storedHash ) && !IsNull( newHash ) && storedHash == newHash;
		}
		if ( IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" ) && !doSkipFruits ) {
			var fruitRows = getQuotationItemFruitService().getDao().findByQuotationItemIds( [ arguments.quotationItem.getId() ] );
			for ( var fruitRow in fruitRows ) {
				oldFruitIds.append( fruitRow.quotation_item_fruit_id );
			}
		}

		if ( IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" ) && !doSkipFruits ) {

			// Raccoglie gli id dei frutti nuovi valorizzati
			// (i tappi ricalcolati hanno id vuoto)
			var newFruitIds = [];
			for ( var thisFruit in arguments.quotationItem.getFruits() ) {
				if ( !IsNull( thisFruit.getId() ) && thisFruit.getId() != "" ) {
					newFruitIds.append( thisFruit.getId() );
				}
			}

			// Un frutto esistente assente fra i nuovi va eliminato
			// (stessa semantica del vecchio confronto)
			for ( var oldFruitId in oldFruitIds ) {
				var found = false;
				for ( var newFruitId in newFruitIds ) {
					if ( newFruitId == oldFruitId ) {
						found = true;
						break;
					}
				}
				if ( !found ) {
					fruitIdsToDeleted.add( oldFruitId );
				}
			}
		}

		transaction {

			arguments.quotationItem = ensurePosition( arguments.quotationItem );

			getDao().update( arguments.quotationItem );

			if ( IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" ) && !doSkipFruits ) {
				for( var thisFruitId in fruitIdsToDeleted ) {
					getQuotationItemFruitService().delete( thisFruitId );
				}

				for ( var thisFruit in arguments.quotationItem.getFruits() ) {
					if ( IsNull( thisFruit.getId() ) || thisFruit.getId() == "" ) {
						thisFruit.setQuotationItemId( arguments.quotationItem.getId() );
						getQuotationItemFruitService().create( thisFruit );
					} else {
						getQuotationItemFruitService().update( thisFruit );
					}
				}
			}

			if ( !IsNull( arguments.quotationItem.getPrice() ) ) {

				// Il prezzo ricalcolato è un bean nuovo: se l'id della riga su DB è già noto
				// (succede con i gemelli, il cui bean è stato caricato in batch con il prezzo
				// esistente) si riusa quello e si salta la ricerca del prezzo corrente, che oggi
				// costa 3 query a giro (find + lettura prezzo + lettura righe) solo per avere l'id.
				// Se l'id non è noto (nel salvataggio normale il prezzo arriva dal client senza id)
				// si fa la ricerca come prima.
				if ( IsNull( arguments.quotationItem.getPrice().getId() ) || !Len( arguments.quotationItem.getPrice().getId() ) ) {
					var current = getQuotationItemPriceService().getByQuotationItemId( arguments.quotationItem.getId() );
					arguments.quotationItem.getPrice().setId( current.getId() );
				}
				arguments.quotationItem.getPrice().setQuotationItemId( arguments.quotationItem.getId() );

				var price = arguments.quotationItem.getPrice();
				getQuotationItemPriceService().update( price );
			}

			if ( isNull( arguments.quotationItem.getArticle() ) ) {
				// Passa il bean già caricato: l'hash non contiene id di riga, quindi il
				// bean in memoria (già sincronizzato con i frutti ricomputati) produce
				// lo stesso hash di un reload completo.
				// Con doSkipFruits l'impronta salvata coincide già (configurazione invariata):
				// niente UPDATE dell'hash, il valore su DB è già quello giusto.
				// newHash ( computeOnly ) è solo l'MD5 per il confronto: non crea la riga su
				// product_hashes, quindi a configurazione cambiata serve la createHash vera,
				// altrimenti l'item resta con un hash orfano e l'export verso Verticale fallisce
				// ( "Hash prodotto non trovato" ).
				if ( !doSkipFruits ) {
					var hash = getProductHashService().createHash( arguments.quotationItem.getId(), arguments.quotationItem );
					if ( !IsNull( hash ) ) {
						updateHash( arguments.quotationItem.getId(), hash );
					}
				}

				var quotationItemQuantity = arguments.quotationItem.getQuantity();
				var countItemPositions = arguments.quotationItem.getPositions();
				if (isNull(countItemPositions)) {
					countItemPositions = 0;
				} else {
					countItemPositions = countItemPositions.len();
				}

				if (quotationItemQuantity > countItemPositions) {
					for (var i = countItemPositions + 1; i <= quotationItemQuantity; i++) {
						var position = super.bean("QuotationItemPosition");
						position.setQuotationItemId(arguments.quotationItem.getId());
						getQuotationItemPositionService().create(position);
					}
				}
				// Logica cancellata provvisoriamente, ora se riduco quantita lo gestisco lato controller, sara possibile eliminare (ridurre qta) solo dalla mappa.
				// else if (quotationItemQuantity < maxSequenceQuotationItemPosition) {
				// 	for (var i = quotationItemQuantity + 1; i <= maxSequenceQuotationItemPosition; i++) {
				// 		var positionToDelete = getQuotationItemPositionService().list( quotationItemId = arguments.quotationItem.getId(), sequence = i );
				// 		if (Len(positionToDelete) > 0) {
				// 			getQuotationItemPositionService().delete(positionToDelete[1].getId());
				// 		}
				// 	}
				// }
			}

		}

		return arguments.quotationItem.getId();
	}


	public Boolean function updateHash( required String quotationItemId, required String hash ){
		getDao().updateHash( quotationItemId, hash );
		return true;
	}

	/**
	 * Clona un QuotationItem. Se asInstance=true genera un instance_group_id condiviso
	 * tra l'originale e il clone, in modo da sincronizzarli ad ogni modifica futura.
	 * Restituisce l'ID del nuovo item.
	 */
	public String function clone( required String quotationItemId, Boolean asInstance = false ){
		var original = get( arguments.quotationItemId );

		if ( IsNull( original ) ) {
			throw( message = "QuotationItem non trovato: #arguments.quotationItemId#" );
		}

		// Prepara il clone cancellando l'ID e azzerando l'ordinamento (verrà ricalcolato)
		var cloneBean = duplicate( original );
		cloneBean.setId( "" );
		cloneBean.setOrdinamento( 0 );

		var newInstanceGroupId = "";
		if ( arguments.asInstance ) {
			newInstanceGroupId = lcase( createUUID() );
			cloneBean.setInstanceGroupId( newInstanceGroupId );
		} else {
			cloneBean.setInstanceGroupId( "" );
		}

		// Azzera le posizioni: il clone parte senza posizioni pianta
		cloneBean.setPositions( [] );

		// Copia (non istanza): se l'originale ha la posizione compilata, la copia
		// nasce con "<codice>-BIS" così si distingue subito dall'originale. Bean
		// nuovo senza id: ensurePosition() in create() la registra nella zona.
		if ( !arguments.asInstance && !IsNull( original.getPosition() ) && Len( Trim( original.getPosition().getCode() ?: "" ) ) ) {
			var bisPosition = super.bean( "QuotationZonePosition" );
			bisPosition.setCode( Trim( original.getPosition().getCode() ) & "-BIS" );
			cloneBean.setPosition( bisPosition );
		}

		var newId = "";
		transaction {
			newId = create( cloneBean );

			// Copia: ordinamento dell'originale + 5, cioè a metà fra l'originale e la
			// riga successiva (l'elenco usa passi di 10), così la copia sta subito dopo
			// di lui (A01, A01-BIS, A02) invece che in fondo con il max+10 di create().
			// Scritto dopo create() perché con ordinamento 0 (righe storiche mai
			// riordinate) create() lo sostituirebbe comunque con max+10.
			if ( !arguments.asInstance ) {
				getDao().updateOrdinamento( newId, Val( original.getOrdinamento() ) + 5 );
			}

			// Se istanza: aggiorna anche l'originale con lo stesso instance_group_id
			if ( arguments.asInstance ) {
				getDao().updateInstanceGroupId( arguments.quotationItemId, newInstanceGroupId );
			}

			// Immagini della riga (anteprima e immagine custom): copiate con file fisici
			// propri, così la copia ha subito la foto invece di restare vuota fino al
			// primo salvataggio dalla modale.
			var sourceFiles = getFileService().list( quotationItemId = arguments.quotationItemId );
			for ( var sourceFile in sourceFiles ) {
				getFileService().duplicateForQuotationItem( sourceFile.getId(), newId );
			}

			// Copia le signage rows se presenti
			if ( IsInstanceOf( cloneBean, "com.apirone.core.model.bean.QuotationItemSignage" ) ) {
				var originalRows = getQuotationItemSignageRowService().list( quotationItemId = arguments.quotationItemId );
				for ( var row in originalRows ) {
					var rowClone = duplicate( row );
					rowClone.setId( "" );
					rowClone.setQuotationItemId( newId );
					getQuotationItemSignageRowService().create( rowClone );
				}
			}
		}

		return newId;
	}

	/**
	 * Sincronizza tutti i QuotationItem con lo stesso instance_group_id di quello dato.
	 * Copia i campi "configurazione articolo" (zona, prodotto, quantità, note, special, bozza, prezzo).
	 * NON copia le posizioni pianta (sono specifiche per ogni istanza).
	 */
	public void function syncInstanceGroup( required String quotationItemId ){
		var source = get( arguments.quotationItemId );
		if ( IsNull( source ) || IsNull( source.getInstanceGroupId() ) || !Len( source.getInstanceGroupId() ) ) return;

		var siblings = getDao().findByInstanceGroupId( source.getInstanceGroupId() );
		for ( var row in siblings ) {
			if ( row.quotation_item_id == arguments.quotationItemId ) continue;
			var sibling = get( row.quotation_item_id );
			if ( IsNull( sibling ) ) continue;

			// Copia i campi di configurazione (NO posizioni, NO zona)
			sibling.setQuantity( source.getQuantity() );
			sibling.setNote( source.getNote() );
			sibling.setSpecial( source.getSpecial() );
			sibling.setCustomImage( source.getCustomImage() );
			sibling.setBozza( source.getBozza() );
			if ( !IsNull( source.getProduct() ) ) sibling.setProduct( source.getProduct() );
			if ( !IsNull( source.getPrice() ) )   sibling.setPrice( source.getPrice() );

			update( sibling );
		}
	}

	/**
	 * Ensure quotation item position is created and linked when needed.
	 */
	private com.apirone.core.model.bean.QuotationItem function ensurePosition( required com.apirone.core.model.bean.QuotationItem quotationItem ){

		if ( !IsNull( arguments.quotationItem.getPosition() ) ) {
			if ( Len( arguments.quotationItem.getPosition().getCode() ) ) {

				var position = arguments.quotationItem.getPosition();

				if ( IsNull( position.getId() ) OR !Len( position.getId() ) ) {

					position.setZoneId( arguments.quotationItem.getQuotationZone().getId() );
					var newPositionId = getQuotationZonePositionService().create( position );
					arguments.quotationItem.getPosition().setId( newPositionId );
				}
			}
		}

		return arguments.quotationItem;
	}

	/**
	 * Recupera in batch più QuotationItem dato un array di ID.
	 * Restituisce uno Struct chiave = quotationItemId, valore = bean QuotationItem.
	 * precarica tutte le FK correlate (Quotation, Product, Article, Zone, SignageConfigItem,
	 * Fruits, Prices, Files, ProductItems, SignageRows, Positions) in batch per evitare
	 * il problema N+1, il più pesante di tutta l'applicazione.
	 *
	 * @ids Array di quotationItemId
	 * @return Struct mappato per quotationItemId -> QuotationItem
	 */
	public Struct function getMany( required Array ids ){
		var records = getDao().readByIds( ids = arguments.ids );
		var map     = {};

		// --- Fase 1: raccoglie gli ID delle FK dai record ---
		var quotationIds    = [];
		var productIds      = [];
		var articleIds      = [];
		var zoneIds         = [];
		var signageConfigItemIds = [];
		var zonePositionIds = [];

		for ( var r in records ) {
			if ( !IsNull( r.quotation_id ) ) {
				quotationIds.append( r.quotation_id );
			}
			if ( Len( r.product_id ) ) {
				productIds.append( r.product_id );
			}
			if ( Len( r.article_id ) ) {
				articleIds.append( r.article_id );
			}
			if ( !IsNull( r.quotation_zone_id ) ) {
				zoneIds.append( r.quotation_zone_id );
			}
			if ( Len( r.signage_config_item_id ) ) {
				signageConfigItemIds.append( r.signage_config_item_id );
			}
			if ( Len( r.quotation_zone_position_id ) ) {
				zonePositionIds.append( r.quotation_zone_position_id );
			}
		}

		// --- Fase 2: precarica tutte le entity in batch ---

		// Quotation (getMany() ora esiste e batch-carica Owner, StatusHistory)
		var quotationMap = {};
		if ( ArrayLen( quotationIds ) ) {
			quotationMap = getQuotationService().getMany( quotationIds );
		}

		// Product: precarica in batch con getMany() ottimizzato di ProductService
		var productMap = {};
		if ( ArrayLen( productIds ) ) {
			productMap = getProductService().getMany( productIds );
		}

		// Article
		var articleMap = {};
		if ( ArrayLen( articleIds ) ) {
			articleMap = getArticleService().getMany( articleIds );
		}

		// QuotationZone
		var zoneMap = {};
		if ( ArrayLen( zoneIds ) ) {
			zoneMap = getQuotationZoneService().getMany( zoneIds );
		}

		// SignageConfigItem
		var signageConfigItemMap = {};
		if ( ArrayLen( signageConfigItemIds ) ) {
			signageConfigItemMap = getSignageConfigItemService().getMany( signageConfigItemIds );
		}

		// Fruits: legge i record via DAO, raccoglie i PK, carica con getMany()
		var fruitMap = {};
		if ( ArrayLen( arguments.ids ) ) {
			var fruitRecords = getQuotationItemFruitService().getDao().findByQuotationItemIds( arguments.ids );
			var fruitIds = [];
			var fruitGroup = {};
			for ( var fr in fruitRecords ) {
				fruitIds.append( fr.quotation_item_fruit_id );
				if ( !StructKeyExists( fruitGroup, fr.quotation_item_id ) ) {
					fruitGroup[ fr.quotation_item_id ] = [];
				}
				fruitGroup[ fr.quotation_item_id ].append( fr.quotation_item_fruit_id );
			}
			// Carica i bean completi con getMany() ottimizzato
			if ( ArrayLen( fruitIds ) ) {
				var fruitBeanMap = getQuotationItemFruitService().getMany( fruitIds );
				for ( var qid in fruitGroup ) {
					fruitMap[ qid ] = [];
					for ( var fid in fruitGroup[ qid ] ) {
						if ( StructKeyExists( fruitBeanMap, fid ) ) {
							fruitMap[ qid ].append( fruitBeanMap[ fid ] );
						}
					}
				}
			}
		}

		// Prices (batch via nuovo readByQuotationItemIds)
		var priceMap      = {};
		var priceBeanById = {};
		if ( ArrayLen( arguments.ids ) ) {
			var priceRecords = getQuotationItemPriceService().getDao().readByQuotationItemIds( arguments.ids );
			var priceIds     = [];
			for ( var prr in priceRecords ) {
				var priceBean = super.bean( "QuotationItemPrice" );
				var methodBean = super.bean( "PriceMethod" );
				priceBean.setId( prr.quotation_item_price_id );
				priceBean.setDiscount1( prr.discount1 );
				priceBean.setDiscount2( prr.discount2 );
				priceBean.setAmount( prr.amount );
				priceBean.setMissingPrice( prr.missing_price );
				priceBean.setMethod( methodBean.setId( prr.price_method_id ) );
				// Mappa sia per quotation_item_id (lookup dal bean) che per price_id (aggiornamento linee)
				priceMap[ prr.quotation_item_id ]             = priceBean;
				priceBeanById[ prr.quotation_item_price_id ]  = priceBean;
				priceIds.append( prr.quotation_item_price_id );
			}

			// Precarica le linee di prezzo in batch (necessarie per getTotal()
			// che somma i line.amount per calcolare il totale)
			if ( ArrayLen( priceIds ) ) {
				var priceLineDao  = getQuotationItemPriceLineService().getDao();
				var priceLineRecs = priceLineDao.readByQuotationItemPriceIds( priceIds );
				for ( var plr in priceLineRecs ) {
					var lineBean = super.bean( "QuotationItemPriceLine" );
					lineBean.setName( plr.name );
					lineBean.setAmount( plr.amount );
					lineBean.setCost( plr.cost );
					if ( StructKeyExists( priceBeanById, plr.quotation_item_price_id ) ) {
						var targetPrice = priceBeanById[ plr.quotation_item_price_id ];
						if ( IsNull( targetPrice.getLines() ) || !ArrayLen( targetPrice.getLines() ) ) {
							targetPrice.setLines( [ lineBean ] );
						} else {
							var existingLines = targetPrice.getLines();
							existingLines.append( lineBean );
							targetPrice.setLines( existingLines );
						}
					}
				}
			}
		}

		// Files (listByEntityIds)
		var fileMap = getFileService().listByEntityIds( "quotationItem.id", arguments.ids );

		// ProductItems (batch via DAO, raggruppati per quotationItemId)
		var productItemMap = {};
		if ( ArrayLen( arguments.ids ) ) {
			var idsList = ArrayToList( arguments.ids );
			var qipiRecords = getQuotationItemProductItemService().getDao().readByQuotationItemIds( arguments.ids );

			// Raccoglie i product_item_id e origin_id per precaricamento batch
			var qipiProductItemIds = [];
			var qipiOriginIds      = [];
			for ( var qr in qipiRecords ) {
				if ( !IsNull( qr.product_item_id ) ) {
					qipiProductItemIds.append( qr.product_item_id );
				}
				if ( !IsNull( qr.origin_id ) ) {
					qipiOriginIds.append( qr.origin_id );
				}
			}

			// Precarica i ProductItem in batch con getMany() ottimizzato
			var qipiProductItemMap = {};
			if ( ArrayLen( qipiProductItemIds ) ) {
				qipiProductItemMap = getProductItemService().getMany( qipiProductItemIds );
			}
			// Aggiunge anche gli origin_id alla mappa se non già presenti
			if ( ArrayLen( qipiOriginIds ) ) {
				var missingOriginIds = [];
				for ( var oid in qipiOriginIds ) {
					if ( !StructKeyExists( qipiProductItemMap, oid ) ) {
						missingOriginIds.append( oid );
					}
				}
				if ( ArrayLen( missingOriginIds ) ) {
					var extraOriginMap = getProductItemService().getMany( missingOriginIds );
					for ( var key in extraOriginMap ) {
						qipiProductItemMap[ key ] = extraOriginMap[ key ];
					}
				}
			}

			for ( var qr in qipiRecords ) {
				if ( !StructKeyExists( productItemMap, qr.quotation_item_id ) ) {
					productItemMap[ qr.quotation_item_id ] = [];
				}
				var qipiBean = super.bean( "QuotationItemProductItem" );
				qipiBean.setId( qr.quotation_item_product_item_id );
				qipiBean.setQuotationItemId( qr.quotation_item_id );
				qipiBean.setLevel( qr.level );
				qipiBean.setNote( qr.note );
				if ( !IsNull( qr.engraving_marker_id ) ) qipiBean.setEngravingMarkerId( qr.engraving_marker_id );
				if ( !IsNull( qr.engraving_x_px ) ) qipiBean.setEngravingXPx( qr.engraving_x_px );
				if ( !IsNull( qr.engraving_y_px ) ) qipiBean.setEngravingYPx( qr.engraving_y_px );
				if ( !IsNull( qr.engraving_x_mm ) ) qipiBean.setEngravingXMm( qr.engraving_x_mm );
				if ( !IsNull( qr.engraving_y_mm ) ) qipiBean.setEngravingYMm( qr.engraving_y_mm );
				// ProductItem: dalla mappa pre-caricata
				if ( !IsNull( qr.product_item_id ) && StructKeyExists( qipiProductItemMap, qr.product_item_id ) ) {
					qipiBean.setProductItem( qipiProductItemMap[ qr.product_item_id ] );
				}
				// Origin: dalla mappa pre-caricata (usa gli stessi ProductItem già caricati)
				if ( !IsNull( qr.origin_id ) && StructKeyExists( qipiProductItemMap, qr.origin_id ) ) {
					qipiBean.setOrigin( qipiProductItemMap[ qr.origin_id ] );
				}
				productItemMap[ qr.quotation_item_id ].append( qipiBean );
			}
		}

		// SignageRows (batch via nuovo readByQuotationItemIds)
		var signageRowMap = {};
		if ( ArrayLen( arguments.ids ) ) {
			var rowRecords = getQuotationItemSignageRowService().getDao().readByQuotationItemIds( arguments.ids );
			for ( var srr in rowRecords ) {
				if ( !StructKeyExists( signageRowMap, srr.quotation_item_id ) ) {
					signageRowMap[ srr.quotation_item_id ] = [];
				}
				var rowBean = super.bean( "QuotationItemSignageRow" );
				rowBean.setId( srr.quotation_item_signage_row_id.toString() );
				rowBean.setQuotationItemId( srr.quotation_item_id.toString() );
				rowBean.setTextAlign( srr.text_align );
				rowBean.setContent( srr.content );
				rowBean.setCharCount( srr.char_count );
				rowBean.setOrderBy( srr.orderby );
				signageRowMap[ srr.quotation_item_id ].append( rowBean );
			}
		}

		// Positions (batch via nuovo readByQuotationItemIds)
		var positionMap = {};
		if ( ArrayLen( arguments.ids ) ) {
			var posRecords = getQuotationItemPositionService().getDao().readByQuotationItemIds( arguments.ids );
			for ( var por in posRecords ) {
				if ( !StructKeyExists( positionMap, por.quotation_item_id ) ) {
					positionMap[ por.quotation_item_id ] = [];
				}
				var posBean = super.bean( "QuotationItemPosition" );
				posBean.setId( por.quotation_item_position_id.toString() );
				posBean.setQuotationItemId( por.quotation_item_id.toString() );
				posBean.setCoordinateX( por.coordinate_x );
				posBean.setCoordinateY( por.coordinate_y );
				posBean.setVisible( por.visible );
				posBean.setAngle( por.angle );
				if ( !IsNull( por.size_multiplier ) ) posBean.setSizeMultiplier( por.size_multiplier );
				positionMap[ por.quotation_item_id ].append( posBean );
			}
		}

		// QuotationZonePosition: una sola query in batch per tutte le posizioni del
		// batch (prima una chiamata individuale per riga: centinaia di round trip
		// quando il batch contiene molte placche, ognuna con la sua posizione)
		var zonePositionMap = {};
		if ( ArrayLen( zonePositionIds ) ) {
			zonePositionMap = getQuotationZonePositionService().getMany( zonePositionIds );
		}

		// --- Fase 3: costruisce i bean QuotationItem ---
		for ( var r in records ) {
			// Determina il tipo (Plate, Signage, o base)
			var fruits = [];
			if ( StructKeyExists( fruitMap, r.quotation_item_id ) ) {
				fruits = fruitMap[ r.quotation_item_id ];
				ArraySort( fruits, function( a, b ){
					return a.getPositions()[ 1 ].order - b.getPositions()[ 1 ].order;
				} );
			}

			if ( ArrayLen( fruits ) || isPlateCategory( r.product_category_type_id ) ) {
				var bean = super.bean( "QuotationItemPlate" );

				bean.setFruits( fruits );

				var frame = super.bean( "Frame" );
				frame.setOrientation( getLookupService().get( "orientation", r.orientation_id ) );
				bean.setFrame( frame );

				// Block orientations dalla colonna del record
				if ( !IsNull( r.block_orientations ) && Len( r.block_orientations ) ) {
					bean.setBlockOrientations( r.block_orientations );
				}
			} else {
				if ( Len( r.signage_config_item_id ) ) {
					var bean = super.bean( "QuotationItemSignage" );
				} else {
					var bean = super.bean( "QuotationItem" );
				}
			}

			// Pricing: dalla mappa batch (bean costruito inline)
			if ( StructKeyExists( priceMap, r.quotation_item_id ) ) {
				bean.setPrice( priceMap[ r.quotation_item_id ] );
			}

			// Campi diretti
			bean.setId( r.quotation_item_id );
			bean.setQuantity( r.quantity );
			bean.setCreatedAt( r.created_at );
			bean.setNote( r.note );
			bean.setHash( r.hash );
			if ( !IsNull( r.ordinamento ) ) bean.setOrdinamento( r.ordinamento );
			bean.setSpecial( BooleanFormat( Val( r.special ) ) );
			bean.setCustomImage( BooleanFormat( Val( r.custom_image ) ) );
			bean.setBozza( BooleanFormat( Val( r.bozza ) ) );

			// Quotation: dalla mappa batch
			if ( Len( r.quotation_id ) && StructKeyExists( quotationMap, r.quotation_id ) ) {
				bean.setQuotation( quotationMap[ r.quotation_id ] );
			}

			// Product: dalla mappa batch
			if ( Len( r.product_id ) && StructKeyExists( productMap, r.product_id ) ) {
				bean.setProduct( productMap[ r.product_id ] );
			}

			// Status (cached)
			if ( Len( r.status_id ) ) {
				bean.setStatus( getStatusService().get( r.status_id ) );
			}

			// Article: dalla mappa batch
			if ( Len( r.article_id ) && StructKeyExists( articleMap, r.article_id ) ) {
				bean.setArticle( articleMap[ r.article_id ] );
			}

			// QuotationZone: dalla mappa batch
			if ( !IsNull( r.quotation_zone_id ) && StructKeyExists( zoneMap, r.quotation_zone_id ) ) {
				bean.setQuotationZone( zoneMap[ r.quotation_zone_id ] );
			}

			// SignageConfigItem: dalla mappa batch
			if ( Len( r.signage_config_item_id ) && StructKeyExists( signageConfigItemMap, r.signage_config_item_id ) ) {
				bean.setSignageConfigItem( signageConfigItemMap[ r.signage_config_item_id ] );

				if ( r.char_count ) {
					bean.getSignageConfigItem().setCharCount( r.char_count );
				}
				if ( r.height_in_pixel ) {
					bean.getSignageConfigItem().setHeightInPixel( r.height_in_pixel );
				}
				if ( r.row_count ) {
					bean.getSignageConfigItem().setRowCount( r.row_count );
				}
			}

			// SignageRows: dalla mappa batch (solo per QuotationItemSignage)
			if ( Len( r.signage_config_item_id ) ) {
				bean.setSignageRows( StructKeyExists( signageRowMap, r.quotation_item_id ) ? signageRowMap[ r.quotation_item_id ] : [] );
			}

			// File/image: dalla mappa batch
			if ( StructKeyExists( fileMap, r.quotation_item_id ) && Len( fileMap[ r.quotation_item_id ] ) ) {
				bean.setImage( fileMap[ r.quotation_item_id ][ 1 ] );
			}

			// ProductItems: dalla mappa batch, riordinati secondo la gerarchia dell'albero
			// attributi (il DB li restituisce nell'ordine, sostanzialmente casuale, della
			// UUID di quotation_item_product_items - vedi sortItemsByTree).
			if ( StructKeyExists( productItemMap, r.quotation_item_id ) ) {
				bean.setItems( getProductHashService().sortItemsByTree( productItemMap[ r.quotation_item_id ] ) );
			}

			// QuotationZonePosition: dalla mappa batch
			if ( Len( r.quotation_zone_position_id ) && StructKeyExists( zonePositionMap, r.quotation_zone_position_id ) ) {
				bean.setPosition( zonePositionMap[ r.quotation_zone_position_id ] );
			}

			// Positions: dalla mappa batch
			if ( StructKeyExists( positionMap, r.quotation_item_id ) ) {
				bean.setPositions( positionMap[ r.quotation_item_id ] );
			}

			// InstanceGroup
			if ( !IsNull( r.instance_group_id ) && Len( r.instance_group_id ) ) {
				bean.setInstanceGroupId( r.instance_group_id );
				bean.setInstanceGroupCount( getDao().countByInstanceGroupId( r.instance_group_id ) );
			}

			map[ r.quotation_item_id ] = bean;
		}

		return map;
	}

	/**
	 * Una riga è una placca per categoria prodotto (tipo "PLA", letto dalla join in
	 * QuotationItemDAO.read/readByIds), non perché ha dei frutti: una placca salvata
	 * senza frutti deve comunque diventare un QuotationItemPlate (frame, blockOrientations),
	 * altrimenti il memento editPlate fallisce su getFrame().
	 */
	private Boolean function isPlateCategory( any productCategoryTypeId ){
		return !IsNull( arguments.productCategoryTypeId )
			&& Len( arguments.productCategoryTypeId )
			&& UCase( arguments.productCategoryTypeId ) == "PLA";
	}

	private com.apirone.core.model.bean.QuotationItem function build( required String quotationItemId ){
		var record = getDao().read( arguments.quotationItemId );

		if ( record.recordCount ) {
			return buildFromRow( record );
		}

		return NullValue();
	}

	/**
	 * Costruisce un bean QuotationItem a partire da una riga del query.
	 * Le sub-entity (Fruits, Prices, Quotation, Product, Status, Article, Zone, SignageConfigItem, Files, ProductItems, Positions) sono caricate con chiamate individuali.
	 */
	private com.apirone.core.model.bean.QuotationItem function buildFromRow( required any record ){
		var fruits = getQuotationItemFruitService().list( quotationItemId = arguments.record.quotation_item_id );

		if ( fruits.len() > 0 || isPlateCategory( arguments.record.product_category_type_id ) ) {
			arraySort( fruits, function( a, b ){
				return a.getPositions()[ 1 ].order - b.getPositions()[ 1 ].order;
			} );
			var bean = super.bean( "QuotationItemPlate" );
			var frame = super.bean( "Frame" );

			bean.setFruits( fruits );

			frame.setOrientation( getLookupService().get( "orientation", arguments.record.orientation_id ) );
			bean.setFrame( frame );

			if ( !IsNull( arguments.record.block_orientations ) && Len( arguments.record.block_orientations ) ) {
				bean.setBlockOrientations( arguments.record.block_orientations );
			}
		} else {
			if ( Len( arguments.record.signage_config_item_id ) ) {
				var bean = super.bean( "QuotationItemSignage" );
			} else {
				var bean = super.bean( "QuotationItem" );
			}
		}

		var pricing = getQuotationItemPriceService().getByQuotationItemId( quotationItemId = arguments.record.quotation_item_id );
		bean.setPrice( pricing );

		bean.setId( arguments.record.quotation_item_id );
		bean.setQuantity( arguments.record.quantity );
		bean.setCreatedAt( arguments.record.created_at );

		bean.setQuotation( getQuotationService().get( arguments.record.quotation_id ) );
		//bean.setPrice( pricing );

		if ( Len( arguments.record.product_id ) ) {
			bean.setProduct( getProductService().get( arguments.record.product_id ) );
		}

		if ( Len( arguments.record.status_id ) ) {
			bean.setStatus( getStatusService().get( arguments.record.status_id ) );
		}

		if ( Len( arguments.record.article_id ) ) {
			bean.setArticle( getArticleService().get( arguments.record.article_id ) );
		}

		bean.setQuotationZone(
			IsNull( arguments.record.quotation_zone_id ) ? NullValue() : getQuotationZoneService().get(
				arguments.record.quotation_zone_id
			)
		);

		if ( Len( arguments.record.signage_config_item_id ) ) {
			bean.setSignageConfigItem( getSignageConfigItemService().get( arguments.record.signage_config_item_id ) );

			if ( arguments.record.char_count ) {
				bean.getSignageConfigItem().setCharCount( arguments.record.char_count );
			}
			if ( arguments.record.height_in_pixel ) {
				bean.getSignageConfigItem().setHeightInPixel( arguments.record.height_in_pixel );
			}
			if ( arguments.record.row_count ) {
				bean.getSignageConfigItem().setRowCount( arguments.record.row_count );
			}

			var signageRows = getQuotationItemSignageRowService().list( quotationItemId = arguments.record.quotation_item_id );
			bean.setSignageRows( signageRows );
		}

		var images = getFileService().list( quotationItemId = arguments.record.quotation_item_id );

		if ( Len( images ) ) {
			bean.setImage( images[ 1 ] );
		}

		var items = getQuotationItemProductItemService().list( quotationItemId = arguments.record.quotation_item_id );

		if ( Len( items ) ) {
			bean.setItems( getProductHashService().sortItemsByTree( items ) );
		}

		bean.setNote( arguments.record.note );
		bean.setHash( arguments.record.hash );
		if ( !isNull( arguments.record.ordinamento ) ) bean.setOrdinamento( arguments.record.ordinamento );
		bean.setSpecial( BooleanFormat( Val( arguments.record.special ) ) );
		bean.setCustomImage( BooleanFormat( Val( arguments.record.custom_image ) ) );
		bean.setBozza( BooleanFormat( Val( arguments.record.bozza ) ) );

		if( Len( arguments.record.quotation_zone_position_id ) ) {
			bean.setPosition( getQuotationZonePositionService().get( arguments.record.quotation_zone_position_id ) );
		}
		var quotationItemPositions = getQuotationItemPositionService().list( quotationItemId = arguments.record.quotation_item_id );
		if ( Len( quotationItemPositions ) ) {
			bean.setPositions( quotationItemPositions );
		}

		if ( !IsNull( arguments.record.instance_group_id ) && Len( arguments.record.instance_group_id ) ) {
			bean.setInstanceGroupId( arguments.record.instance_group_id );
			bean.setInstanceGroupCount( getDao().countByInstanceGroupId( arguments.record.instance_group_id ) );
		}

		return bean;
	}

	/*
		Recupera il pricing di una placca.
		I parametri opzionali preloadedQuotation e preloadedQuotationItem permettono
		al chiamante (es. aggiornaPrezzo nel ciclo sulle altre righe) di passare i
		bean già caricati, evitando di ricostruire la stessa Quotation per ogni item (N+1).
	*/
	public com.apirone.core.model.bean.QuotationItemPrice function getPlatePricing(
		required Struct data,
		preloadedQuotation = javacast( "null", "" ),
		preloadedQuotationItem = javacast( "null", "" ),
		skipPrewarm = javacast( "null", "" )
	){

		var json = arguments.data;

		// Lettura difensiva di skipPrewarm: quando il chiamante non lo passa, Lucee NON binda
		// un argomento posizionale con valore null (la chiave resterebbe numerica nell'arguments
		// scope) e un accesso diretto lancerebbe "key doesn't exist". Da qui in poi viaggia
		// solo un booleano, che si binda sempre.
		var doSkipPrewarm = StructKeyExists( arguments, "skipPrewarm" ) && !IsNull( arguments.skipPrewarm ) && arguments.skipPrewarm;

		var pricing = super.bean( "QuotationItemPrice" );
		var method  = super.bean( "PriceMethod" );

		var calculator = super.service( "PriceCalculator" );

		var lines = [];

		pricing.setQuantity( StructKeyExists( json.price, "quantity" ) && Val( json.price.quantity ) ? json.item.quantity : 1 );
		pricing.setDiscount1( Val( json.price.discount1 ) ? json.price.discount1 : 0 );
		pricing.setDiscount2( Val( json.price.discount2 ) ? json.price.discount2 : 0 );

		pricing.setMethod( method.setId( json.price.method.id ) );

        if ( pricing.isFixed() ) {
			pricing.setAmount( Val( json.price.total ) ? json.price.total : 0 );
		} else {
			pricing.setAmount( 0 );
		}

		/*
			plate price
		*/

		var productItemsIds = [];

		var product = json.item.product;

		var productItemsData = isArray( product.items ) ? product.items : product.items._data;
		for ( var item in productItemsData ) {
			for ( var value in item.values ) {
				if ( value.selected ) {
					productItemsIds.add( value.productItemId );
				}
			}
		}

		//TODO debuggare qui per capire cosa fare per il discorso "ok placca senza frutti e aggiunta tappi"
		// QuotationItem: se il chiamante l'ha già caricato viene riusato,
		// altrimenti caricamento singolo originale
		var quotationItem = arguments.preloadedQuotationItem;
		if ( IsNull( quotationItem ) && json.item.id != "" ) {
			var qiMap = getMany( [ json.item.id ] );
			quotationItem = StructKeyExists( qiMap, json.item.id )
				? qiMap[ json.item.id ]
				: null;
		}

		// Quotation: se il chiamante l'ha già caricata viene riusata, altrimenti
		// caricamento singolo originale
		var quotation = arguments.preloadedQuotation;
		if ( IsNull( quotation ) && json.quotationId != "" ) {
			var qMap = getQuotationService().getMany( [ json.quotationId ] );
			quotation = StructKeyExists( qMap, json.quotationId )
				? qMap[ json.quotationId ]
				: null;
		}

		// Precarica in batch tutti i prodotti coinvolti (placca, frutti, tappi)
		// per evitare il rebuild completo del prodotto per ogni calcolo (N+1).
		var productIdsToPreload = [ product.id ];

		for ( var fruit in json.item.fruits._data ) {
			ArrayAppend( productIdsToPreload, fruit.fruit.id );
		}

		if ( isVitiAVistaNo( json ) ) {
			ArrayAppend( productIdsToPreload, variables.plugProductIdList, true );
		}

		// Memo per request: gli stessi prodotti (placca + frutti + tappi) tornano in tutti gli
		// articoli gemelli; i bean prodotto sono usati in sola lettura nel pricing
		var pmpKey = ArrayToList( productIdsToPreload );
		if ( !StructKeyExists( request, "_pricingProductMapMemo" ) ) {
			request._pricingProductMapMemo = {};
		}
		var productMap = NullValue();
		if ( ArrayLen( productIdsToPreload ) && StructKeyExists( request._pricingProductMapMemo, pmpKey ) ) {
			productMap = request._pricingProductMapMemo[ pmpKey ];
		} else if ( ArrayLen( productIdsToPreload ) ) {
			productMap = getProductService().getMany( productIdsToPreload );
			request._pricingProductMapMemo[ pmpKey ] = productMap;
		} else {
			productMap = {};
		}

		// Prewarm verticale: una sola coppia di query listin/artico per TUTTA la placca
		// (componenti degli item selezionati di placca e frutti + componenti dei prodotti
		// placca/frutti/tappi). I prewarm interni dei calcoli per frutto non fanno più round trip.
		var allProductItemIds = duplicate( productItemsIds );
		for ( var fruitItem in json.item.fruits._data ) {
			for ( var fruitItemValue in fruitItem.items._data ) {
				for ( var value in fruitItemValue.values ) {
					if ( value.selected ) {
						allProductItemIds.add( value.productItemId );
					}
				}
			}
		}

		// skipPrewarm arriva solo dal ricalcolo a catena dei prezzi (l'aggregatore degli
		// articoli gemelli, vedi aggiornaPrezzoAltriArticoliByQuotationIdLineIdFinishId, che
		// esegue UNO sweep verticale per tutte le placche prima del loop). In quel contesto
		// le memo ERP contengono già i costi di tutti i componenti: il prewarm locale sarebbe
		// uno spreco (diverse letture apirone per niente). Dal salvataggio normale (client)
		// il flag non arriva e il prewarm locale gira come sempre.
		if ( !doSkipPrewarm ) {
			getComponentService().prewarmPricingComponents(
				productItemIds = allProductItemIds,
				productIds     = productIdsToPreload,
				lineId         = productMap[ product.id ].getLine().getId(),
				modelId        = productMap[ product.id ].getModel().getId()
			);
		}

		var platePrice = calculator.calculate(
			product.id,
			json.item.quantity,
			json.item.quotationZone.id,
			productItemsIds,
			0,
			0,
			quotation,
			quotationItem,
			StructKeyExists( productMap, product.id ) ? productMap[ product.id ] : NullValue(),
			doSkipPrewarm
		);

		var line = super.bean( "QuotationItemPriceLine" );

		if ( platePrice.missingPrice ) pricing.setMissingPrice( true );
		line.setName( "Prezzo placca" );
		line.setAmount( platePrice.finalPrice );
		line.setCost( platePrice.totalCost );
		lines.add( line );


		/*
			fruits price
		*/

		for ( var fruit in json.item.fruits._data ) {
			var fruitItemsIds = [];

			var line = super.bean( "QuotationItemPriceLine" );

			for ( var item in fruit.items._data ) {
				for ( var value in item.values ) {
					if ( value.selected ) {
						fruitItemsIds.add( value.productItemId );
					}
				}
			}

			var fruitPrice = calculator.calculate(
				fruit.fruit.id,
				1,
				json.item.quotationZone.id,
				fruitItemsIds,
				0,
				0,
				quotation,
				quotationItem,
				StructKeyExists( productMap, fruit.fruit.id ) ? productMap[ fruit.fruit.id ] : NullValue(),
				doSkipPrewarm
			);

			if ( fruitPrice.missingPrice ) pricing.setMissingPrice( true );
			line.setName( "#fruit.fruit?.name#" );
			line.setAmount( fruitPrice.finalPrice );
			line.setCost( fruitPrice.totalCost );
			lines.add( line );
		}

		if ( isVitiAVistaNo( json ) ) {
			for ( var plug in computePlugRuns( json ) ) {
				var plugProductId = variables.plugProductIds[ plug.type ];
				var plugProduct = StructKeyExists( productMap, plugProductId )
					? productMap[ plugProductId ]
					: NullValue();
				if ( IsNull( plugProduct ) ) continue;
				var plugPrice = calculator.calculate(
					plugProductId,
					1,
					json.item.quotationZone.id,
					[],
					0,
					0,
					quotation,
					quotationItem,
					plugProduct,
					doSkipPrewarm
				);
				if ( plugPrice.missingPrice ) pricing.setMissingPrice( true );
				var plugLine = super.bean( "QuotationItemPriceLine" );
				plugLine.setName( plug.type == "tappo" ? "Tappo" : "Mezzo tappo" );
				plugLine.setAmount( plugPrice.finalPrice );
				plugLine.setCost( plugPrice.totalCost );
				lines.add( plugLine );
			}
		}

		pricing.setLines( lines );
		// A prezzo fisso il prezzo lo decide l'utente: nessun avviso di prezzo mancante
		if ( pricing.isFixed() ) pricing.setMissingPrice( false );

		return pricing;
	}

	private Boolean function isVitiAVistaNo( required Struct json ) {
		if ( !StructKeyExists( json, "item" )
			|| !StructKeyExists( json.item, "product" )
			|| !StructKeyExists( json.item.product, "items" )
			|| !StructKeyExists( json.item.product.items, "_data" ) ) {
			return false;
		}
		for ( var item in json.item.product.items._data ) {
			if ( StructKeyExists( item, "attributeName" ) && item.attributeName == "VITI A VISTA" ) {
				for ( var val in item.values ) {
					if ( StructKeyExists( val, "selected" ) && val.selected
						&& StructKeyExists( val, "attributeValue" )
						&& StructKeyExists( val.attributeValue, "rawValue" )
						&& val.attributeValue.rawValue.name == "NO" ) {
						return true;
					}
				}
			}
		}
		return false;
	}

	/**
	 * Wrapper con memoization request-scoped di computePlugRunsInternal().
	 * Evita di ricalcolare due volte la lista dei tappi durante aggiornaPrezzo()
	 * (che chiama buildPlugFruitBeans() e poi getPlatePricing() con lo stesso json).
	 */
	private Array function computePlugRuns( required Struct json ) {
		// Chiave di memoization: id del quotation item + fingerprint degli input
		// (positions, frame, orientation) così che lo stesso item con dati diversi
		// non restituisca un risultato stale nella stessa request.
		var memoKey = "";
		if ( StructKeyExists( json, "item" ) && StructKeyExists( json.item, "id" ) && Len( json.item.id ) ) {
			var fingerprintInput = {
				"positions"   = StructKeyExists( json, "positions" ) ? json.positions : {},
				"frame"       = StructKeyExists( json.item, "product" ) && StructKeyExists( json.item.product, "frame" ) ? json.item.product.frame : {},
				"orientation" = StructKeyExists( json.item, "product" ) && StructKeyExists( json.item.product, "orientation" ) ? json.item.product.orientation : {}
			};
			memoKey = "_plugRuns_" & json.item.id & "_" & Hash( SerializeJSON( fingerprintInput ) );
			if ( StructKeyExists( request, memoKey ) ) {
				return request[ memoKey ];
			}
		}

		var result = computePlugRunsInternal( json );

		if ( Len( memoKey ) ) {
			request[ memoKey ] = result;
		}

		return result;
	}

	private Array function computePlugRunsInternal( required Struct json ) {
		var result = [];
		if ( !StructKeyExists( json, "positions" )
			|| !StructKeyExists( json, "item" )
			|| !StructKeyExists( json.item, "product" )
			|| !StructKeyExists( json.item.product, "frame" )
			|| !StructKeyExists( json.item.product, "orientation" )
			|| !Len( json.item.product.orientation.id ) ) {
			return result;
		}
		// frame.code usato direttamente (path aggiornaPrezzo); frame.id come fallback (path save da client)
		var frameCode = "";
		var frame = "";
		if ( StructKeyExists( json.item.product.frame, "id" ) && Len( json.item.product.frame.id ) ) {
			frame = super.service( "Frame" ).get( json.item.product.frame.id );
		} else if ( StructKeyExists( json.item.product.frame, "code" ) && Len( json.item.product.frame.code ) ) {
			frame = super.service( "Frame" ).getByCode( json.item.product.frame.code );
		}
		if ( !IsNull( frame ) && !IsSimpleValue( frame ) ) frameCode = frame.getCode();
		if ( !Len( frameCode ) && StructKeyExists( json.item.product.frame, "code" ) ) frameCode = json.item.product.frame.code;
		if ( !Len( frameCode ) ) return result;

		var allPositions = [];

		if ( !IsNull( frame ) && !IsSimpleValue( frame ) && !IsNull( frame.getBlocks() ) && ArrayLen( frame.getBlocks() ) ) {
			// placca a blocchi: slot numerati 1..N, indipendenti dall'orientamento.
			// Il blocco serve per non far "cavallottare" un tappo doppio fra due blocchi.
			var slotCounter = 0;
			var blockIndex = 0;
			for ( var block in frame.getBlocks() ) {
				blockIndex++;
				for ( var i = 1; i <= block.getSlotCount(); i++ ) {
					slotCounter++;
					allPositions.add( { id: slotCounter, order: slotCounter - 1, block: blockIndex } );
				}
			}
		} else {
			// placca legacy su file
			var gridFile = ExpandPath( "/config/data/plates/grid_#frameCode#.json.cfm" );
			if ( !FileExists( gridFile ) ) return result;
			var gridConfig = DeserializeJSON( FileRead( gridFile ) );
			var orientationId = json.item.product.orientation.id;
			if ( !StructKeyExists( gridConfig.frame.orientations, orientationId ) ) return result;
			var gridRows = gridConfig.frame.orientations[ orientationId ].grid;
			for ( var gridRow in gridRows ) {
				for ( var cell in gridRow ) {
					if ( cell.type != "0" ) {
						allPositions.add( { id: cell.id, order: cell.order, block: 0 } );
					}
				}
			}
		}

		ArraySort( allPositions, function( a, b ) {
			if ( a.order < b.order ) return -1;
			if ( a.order > b.order ) return 1;
			return 0;
		} );
		var occupiedIds = {};
		for ( var fId in json.positions ) {
			for ( var pos in json.positions[ fId ] ) {
				// posizioni da client: {id: uuid, order: N}; da DB: {position: uuid, order: N}
				var posId = StructKeyExists( pos, "id" ) ? pos.id : ( StructKeyExists( pos, "position" ) ? pos.position : "" );
				if ( Len( posId ) ) occupiedIds[ posId ] = true;
			}
		}
		var emptyPositions = [];
		for ( var pos in allPositions ) {
			if ( !StructKeyExists( occupiedIds, pos.id ) ) {
				emptyPositions.add( pos );
			}
		}
		var idx = 1;
		while ( idx <= ArrayLen( emptyPositions ) ) {
			var isDouble = idx < ArrayLen( emptyPositions )
				&& emptyPositions[ idx + 1 ].order == emptyPositions[ idx ].order + 1
				&& emptyPositions[ idx + 1 ].block == emptyPositions[ idx ].block;
			if ( isDouble ) {
				result.add( { type: "tappo", positionIds: [ emptyPositions[ idx ], emptyPositions[ idx + 1 ] ] } );
				idx += 2;
			} else {
				result.add( { type: "mezzotappo", positionIds: [ emptyPositions[ idx ] ] } );
				idx += 1;
			}
		}
		return result;
	}

	public Array function buildPlugFruitBeans( required Struct data ) {
		var json = arguments.data;
		var result = [];
		if ( !isVitiAVistaNo( json ) ) return result;

		// Precarica in batch i due prodotti tappo per evitare get() singolo per ogni plug
		var plugProductMap = getProductService().getMany( variables.plugProductIdList );

		for ( var plug in computePlugRuns( json ) ) {
			var plugProductId = variables.plugProductIds[ plug.type ];
			var plugProduct = StructKeyExists( plugProductMap, plugProductId )
				? plugProductMap[ plugProductId ]
				: NullValue();
			if ( IsNull( plugProduct ) ) continue;
			var fruitBean = super.bean( "QuotationItemFruit" );
			fruitBean.setFruit( plugProduct );
			fruitBean.setPositions( plug.positionIds );
			fruitBean.setItems( [] );
			result.add( fruitBean );
		}
		return result;
	}

	/*
		Lettere di una riga segnaletica ai fini del prezzo: charCount ( pittogramma = 1 )
		meno gli spazi del contenuto, che occupano posto nella riga ma non sono lettere.
		Senza content ( vecchi chiamanti ) resta il charCount.
	*/
	public Numeric function signageLettersCount( required Struct signageRow ){
		var letters = Val( arguments.signageRow.charCount ?: 0 );
		if ( !IsNull( arguments.signageRow.content ) && IsSimpleValue( arguments.signageRow.content ) ) {
			letters -= Len( REReplace( arguments.signageRow.content, "[^\s]", "", "all" ) );
		}
		return Max( letters, 0 );
	}

	/*
		Recupera il pricing di un item signage. I parametri opzionali
		preloadedQuotation e preloadedQuotationItem permettono al chiamante di
		passare i bean già caricati, evitando un refetch per item (N+1).
	*/
	public com.apirone.core.model.bean.QuotationItemPrice function getSignagePricing(
		required Struct data,
		preloadedQuotation = javacast( "null", "" ),
		preloadedQuotationItem = javacast( "null", "" )
	){
		var json = arguments.data;

		var pricing = super.bean( "QuotationItemPrice" );
		var method  = super.bean( "PriceMethod" );

		var calculator = super.service( "PriceCalculator" );

		var lines = [];

		pricing.setQuotationItemId( json.quotationItem.id );
		pricing.setId( Val( json.quotationItem.price.id ) ? json.quotationItem.price.id : null );
		pricing.setQuantity( Val( json.quotationItem.quantity ) ? json.quotationItem.quantity : 1 );
		pricing.setDiscount1( Val( json.quotationItem.price.discount1 ) ? json.quotationItem.price.discount1 : 0 );
		pricing.setDiscount2( Val( json.quotationItem.price.discount2 ) ? json.quotationItem.price.discount2 : 0 );

		pricing.setMethod( method.setId( json.quotationItem.price.method.id ) );

        if ( json.quotationItem.price.method.id EQ 'F' ) {
			pricing.setAmount( Val( json.quotationItem.price.total ) ? json.quotationItem.price.total : 0 );
		} else {
			pricing.setAmount( 0 );
		}

		/*
			signage price
		*/
		var productItemsIds = [];

		var product = json.quotationItem.product;

		if ( product.keyExists( "items" ) ) {
			var productItemsData = isArray( product.items ) ? product.items : product.items._data;
			for ( var item in productItemsData ) {
				for ( var value in item.values ) {
					if ( value.selected ) {
						productItemsIds.add( value.product_item_id );
					}
				}
			}
		}

		var lettersQuantity = 0;
		for ( var signageRow in json.quotationItem.signageRows._data ) {
			lettersQuantity += signageLettersCount( signageRow );
		}

		// Quotation: se il chiamante l'ha già caricata viene riusata, altrimenti
		// caricamento singolo originale
		var quotation = arguments.preloadedQuotation;
		if ( IsNull( quotation ) ) {
			var qMap = getQuotationService().getMany( [ json.quotationId ] );
			quotation = StructKeyExists( qMap, json.quotationId )
				? qMap[ json.quotationId ]
				: null;
		}

		// QuotationItem: se il chiamante l'ha già caricato viene riusato,
		// altrimenti caricamento singolo originale
		var quotationItem = arguments.preloadedQuotationItem;
		if ( IsNull( quotationItem ) && !isNull( json.quotationItem.id ) && json.quotationItem.id != '' ) {
			var qiMap = getMany( [ json.quotationItem.id ] );
			quotationItem = StructKeyExists( qiMap, json.quotationItem.id )
				? qiMap[ json.quotationItem.id ]
				: null;
		}

		var signagePrice = calculator.calculate(
			product.id,
			json.quotationItem.quantity,
			json.quotationItem.quotationZone.id,
			productItemsIds,
			lettersQuantity,
			json.quotationItem.signageConfigItem.id,
			quotation,
			quotationItem,
			NullValue()
		);
		var line = super.bean( "QuotationItemPriceLine" );

		line.setName( "Prezzo segnaletica" );
		line.setAmount( signagePrice.finalPrice );
		line.setCost( signagePrice.totalCost );

		lines.add( line );

		pricing.setLines( lines );
		// Prodotto senza prezzo: riga a 0 marcata (a prezzo fisso decide l'utente, nessun avviso)
		pricing.setMissingPrice( signagePrice.missingPrice && !pricing.isFixed() );

		return pricing;
	}

	/*
		Recupera il pricing di un item semplice (non placca/signage).
		I parametri opzionali preloadedQuotation e preloadedQuotationItem permettono
		al chiamante di passare i bean già caricati, evitando un refetch per item (N+1).
	*/
	public com.apirone.core.model.bean.QuotationItemPrice function getPricing(
		required Struct data,
		preloadedQuotation = javacast( "null", "" ),
		preloadedQuotationItem = javacast( "null", "" )
	){
		var json = arguments.data;

		var pricing = super.bean( "QuotationItemPrice" );
		var method  = super.bean( "PriceMethod" );

		var calculator = super.service( "PriceCalculator" );

		var lines = [];

		pricing.setQuotationItemId( json.quotationItem.id );
		pricing.setId( Val( json.quotationItem.price.id ) ? json.quotationItem.price.id : null );
		pricing.setQuantity( Val( json.quotationItem.quantity ) ? json.quotationItem.quantity : 1 );
		pricing.setDiscount1( Val( json.quotationItem.price.discount1 ) ? json.quotationItem.price.discount1 : 0 );
		pricing.setDiscount2( Val( json.quotationItem.price.discount2 ) ? json.quotationItem.price.discount2 : 0 );

		pricing.setMethod( method.setId( json.quotationItem.price.method.id ) );

        if ( json.quotationItem.price.method.id EQ 'F' ) {
			pricing.setAmount( Val( json.quotationItem.price.total ) ? json.quotationItem.price.total : 0 );
		} else {
			pricing.setAmount( 0 );
		}

		/*
			price
		*/

		var productItemsIds = [];

		var product = json.quotationItem.product;

		// Combinazione categoria/linea/modello/finitura senza prodotto: il client
		// manda product.id vuoto (o assente). Errore tipizzato, che i controller
		// traducono in una risposta INVALID leggibile invece di un 500.
		if ( IsNull( product ) || !StructKeyExists( product, "id" ) || !Len( Trim( product.id ) ) ) {
			Throw(
				type    = "ApirOne.ProductNotFound",
				message = "Nessun prodotto configurato per la combinazione categoria, linea, modello e finitura scelta: cambia finitura o modello."
			);
		}

		if ( product.keyExists( "items" ) ) {
			var productItemsData = isArray( product.items ) ? product.items : product.items._data;
			for ( var item in productItemsData ) {
				for ( var value in item.values ) {
					if ( value.selected ) {
						productItemsIds.add( value.product_item_id );
					}
				}
			}
		}

		// Quotation: se il chiamante l'ha già caricata viene riusata, altrimenti
		// caricamento singolo originale
		var quotation = arguments.preloadedQuotation;
		if ( IsNull( quotation ) ) {
			var qMap = getQuotationService().getMany( [ json.quotationId ] );
			quotation = StructKeyExists( qMap, json.quotationId )
				? qMap[ json.quotationId ]
				: null;
		}

		// QuotationItem: se il chiamante l'ha già caricato viene riusato,
		// altrimenti caricamento singolo originale
		var quotationItem = arguments.preloadedQuotationItem;
		if ( IsNull( quotationItem ) && !isNull( json.quotationItem.id ) && json.quotationItem.id != '' ) {
			var qiMap = getMany( [ json.quotationItem.id ] );
			quotationItem = StructKeyExists( qiMap, json.quotationItem.id )
				? qiMap[ json.quotationItem.id ]
				: null;
		}

		var price = calculator.calculate(
			product.id,
			json.quotationItem.quantity,
			json.quotationItem.quotationZone.id,
			productItemsIds,
			0,
			0,
			quotation,
			quotationItem,
			NullValue()
		);

		var line = super.bean( "QuotationItemPriceLine" );

		line.setName( "Prezzo base" );
		line.setAmount( price.finalPrice );
		line.setCost( price.totalCost );

		lines.add( line );

		pricing.setLines( lines );
		// Prodotto senza prezzo: riga a 0 marcata (a prezzo fisso decide l'utente, nessun avviso)
		pricing.setMissingPrice( price.missingPrice && !pricing.isFixed() );

		return pricing;
	}

	public function getAltreRigheByQuotationLineIdAndFinishId(
		required String quotationItemId,
		required String quotationId,
		required String lineId,
		required String finishId,
		String modelId = ""
	){
		if ( IsNull( quotationId ) ) {
			return [];
		}
		return getDao().getAltreRigheByQuotationLineIdAndFinishId(argumentCollection = arguments);
	}

	public function getAltreRigheByQuotationAndProductId(
		required String quotationItemId,
		required String quotationId,
		required String productId
	){
		if ( IsNull( quotationId ) ) {
			return [];
		}
		return getDao().getAltreRigheByQuotationAndProductId(argumentCollection = arguments);
	}

	/**
	 * Precarica in batch i dati di pricing per gli item passati, sfruttando i bean già
	 * caricati in batch da getMany():
	 * 1. totali di quantità "altre righe" -> memo di richiesta usata dai wrapper di
	 *    PriceCalculatorService (getQuantitaTotaleAltreRighe*): una query di gruppo al
	 *    posto di una SUM per item;
	 * 2. bean ProductItem già completi -> memo per id usata dal calcolo dei prezzi:
	 *    ogni gemello ha il suo prodotto (quindi i suoi product item), ma sono già in
	 *    memoria dopo il caricamento in batch, il pricing non deve rileggerli dal DB.
	 * Da chiamare DOPO l'update della placca salvata (valori freschi) e prima del ciclo
	 * di ricalcolo dei gemelli; nel resto della richiesta le quantità non cambiano.
	 *
	 * @param quotationId  id del preventivo (solo per costruire le chiavi di memo)
	 * @param itemIds      id degli item da precalcolare
	 * @param itemMap      mappa id -> bean QuotationItem già caricati (per il prefill dei ProductItem)
	 * @returns            void
	 */
	private void function precomputeBatchTotals( required String quotationId, required Array itemIds, required Struct itemMap ){
		if ( !ArrayLen( arguments.itemIds ) ) {
			return;
		}

		if ( !StructKeyExists( request, "_pricingSiblingTotals" ) ) {
			request._pricingSiblingTotals = {};
		}

		// Per ogni item la memo contiene tre chiavi: "|lf|" = totale di quantità delle righe
		// con la stessa linea+finitura (esclusa l'item stessa), "|lm|" = totale delle righe
		// con la stessa linea+modello, "|p|" = totale delle righe con lo stesso prodotto.
		// I wrapper di PriceCalculatorService leggono queste chiavi al posto di eseguire
		// una SUM per ogni item gemello.
		var totalRows = getDao().getQuantitaTotaliBatchByQuotationItemIds( arguments.itemIds );
		for ( var totalRow in totalRows ) {
			request._pricingSiblingTotals[ arguments.quotationId & "|lf|" & totalRow.quotation_item_id ] = Val( totalRow.total_by_line_finish ?: 0 );
			request._pricingSiblingTotals[ arguments.quotationId & "|lm|" & totalRow.quotation_item_id ] = Val( totalRow.total_by_line_model ?: 0 );
			request._pricingSiblingTotals[ arguments.quotationId & "|p|" & totalRow.quotation_item_id ] = Val( totalRow.total_by_product ?: 0 );
		}

		// Prefill della memo dei ProductItem (per id) con i bean già caricati in batch:
		// il pricing di ogni gemello trova così i suoi item in memoria e non fa query
		if ( !StructKeyExists( request, "_pricingItemBeanMemo" ) ) {
			request._pricingItemBeanMemo = {};
		}
		// Gli stessi id servono per precompilare la memo dei componenti per product item
		var batchProductItemIds = [];
		for ( var siblingId in arguments.itemMap ) {
			var siblingItems = arguments.itemMap[ siblingId ].getItems();
			if ( !IsNull( siblingItems ) ) {
				for ( var siblingItem in siblingItems ) {
					var siblingProductItem = siblingItem.getProductItem();
					if ( !IsNull( siblingProductItem ) && !IsNull( siblingProductItem.getId() ) ) {
						request._pricingItemBeanMemo[ siblingProductItem.getId() ] = siblingProductItem;
						batchProductItemIds.append( siblingProductItem.getId() );
					}
				}
			}
		}

		// Prefill della memo dei componenti per product item (priceCalculatorSearchByProductItemIds):
		// una passata sola per l'intero batch; le letture ERP interne sono già no-op perché lo
		// sweep di prewarmPricingComponents ha riempito le memo dei costi
		getComponentService().priceCalculatorSearchByProductItemIds( batchProductItemIds );
	}

	/*
		Ricalcola le righe del preventivo che condividono un costo fisso con l'item:
		stessa linea+finitura (costo linea/finitura) e, se passato modelId, stessa
		linea+modello (costo linea/modello).
	*/
	public function aggiornaPrezzoAltriArticoliByQuotationIdLineIdFinishId(
		required String quotationItemId,
		required String quotationId,
		required String lineId,
		required String finishId,
		String modelId = ""
	){
		var rows = this.getAltreRigheByQuotationLineIdAndFinishId(
			"quotationItemId" = quotationItemId,
			"quotationId" = quotationId,
			"lineId" = lineId,
			"finishId" = finishId,
			"modelId" = modelId
		);

		// Precarica tutti i QuotationItem in batch per evitare N+1
		var itemIds = [];
		for ( var row in rows ) {
			itemIds.append( row.quotation_item_id );
		}
		var itemMap = ArrayLen( itemIds ) ? getMany( itemIds ) : {};

		// Totali "altre righe" precalcolati per tutto il batch (vedi precomputeBatchTotals)
		precomputeBatchTotals( arguments.quotationId, StructKeyArray( itemMap ), itemMap );

		// Prewarm verticale per TUTTI i gemelli in una passata: raccoglie item, prodotti
		// (placca + frutti + tappi) e modelli distinti dai bean già caricati e fa una sola
		// coppia di query listin/artico per l'intero batch. Senza questo sweep ogni gemella
		// farebbe le proprie letture ERP (decine di round trip su preventivi con molte placche).
		// I prewarm interni dei singoli aggiornaPrezzo vengono poi saltati (skipPrewarm),
		// perché tutto il necessario è già nelle memo.
		var hoistItemIds    = [];
		var hoistProductIds = [];
		var hoistModelIds   = {};
		var hoistSeen       = {};

		for ( var sibKey in itemMap ) {
			var sib = itemMap[ sibKey ];

			if ( !IsNull( sib.getProduct() ) ) {
				var sibProductId = sib.getProduct().getId();
				if ( !StructKeyExists( hoistSeen, "p" & sibProductId ) ) {
					hoistSeen[ "p" & sibProductId ] = true;
					hoistProductIds.append( sibProductId );
				}
				if ( !IsNull( sib.getProduct().getModel() ) ) {
					hoistModelIds[ sib.getProduct().getModel().getId() ] = true;
				}
			}

			if ( !IsNull( sib.getItems() ) ) {
				for ( var sibItem in sib.getItems() ) {
					var sibItemPiId = sibItem.getProductItem().getId();
					if ( !StructKeyExists( hoistSeen, "i" & sibItemPiId ) ) {
						hoistSeen[ "i" & sibItemPiId ] = true;
						hoistItemIds.append( sibItemPiId );
					}
				}
			}

			if ( IsInstanceOf( sib, "com.apirone.core.model.bean.QuotationItemPlate" ) && !IsNull( sib.getFruits() ) ) {
				for ( var sibFruit in sib.getFruits() ) {
					if ( !IsNull( sibFruit.getFruit() ) ) {
						var sibFruitProductId = sibFruit.getFruit().getId();
						if ( !StructKeyExists( hoistSeen, "p" & sibFruitProductId ) ) {
							hoistSeen[ "p" & sibFruitProductId ] = true;
							hoistProductIds.append( sibFruitProductId );
						}
					}
					if ( !IsNull( sibFruit.getItems() ) ) {
						for ( var sibFruitItem in sibFruit.getItems() ) {
							var sibFruitPiId = sibFruitItem.getProductItem().getId();
							if ( !StructKeyExists( hoistSeen, "i" & sibFruitPiId ) ) {
								hoistSeen[ "i" & sibFruitPiId ] = true;
								hoistItemIds.append( sibFruitPiId );
							}
						}
					}
				}
			}
		}

		// tappi (viti a vista no): getPlatePricing precarica anche i plug products
		for ( var plugProductId in variables.plugProductIdList ) {
			if ( !StructKeyExists( hoistSeen, "p" & plugProductId ) ) {
				hoistSeen[ "p" & plugProductId ] = true;
				hoistProductIds.append( plugProductId );
			}
		}

		getComponentService().prewarmPricingComponents(
			productItemIds = hoistItemIds,
			productIds     = hoistProductIds,
			lineId         = arguments.lineId,
			modelIds       = StructKeyArray( hoistModelIds )
		);

		// La Quotation è la stessa per tutte le righe: viene estratta una sola volta dai bean
		// già caricati in batch e passata a ogni aggiornaPrezzo (evita il rebuild per item, N+1).
		var sharedQuotation = NullValue();
		for ( var loadedRow in rows ) {
			if ( StructKeyExists( itemMap, loadedRow.quotation_item_id ) ) {
				var itemQuotation = itemMap[ loadedRow.quotation_item_id ].getQuotation();
				if ( !IsNull( itemQuotation ) ) {
					sharedQuotation = itemQuotation;
					break;
				}
			}
		}

		for ( var row in rows ) {
			var quotationItem = StructKeyExists( itemMap, row.quotation_item_id )
				? itemMap[ row.quotation_item_id ]
				: NullValue();
			if (
				IsNull( quotationItem ) ||
				( !IsInstanceOf(quotationItem, "com.apirone.core.model.bean.QuotationItemPlate") &&
				!IsInstanceOf(quotationItem, "com.apirone.core.model.bean.QuotationItemSignage") )
			) {
				continue;
			}

			aggiornaPrezzo( quotationItem, sharedQuotation, true );
		}
	}

	public function aggiornaPrezzoAltriArticoliByQuotationIdAndProductId(
		required String quotationItemId,
		required String quotationId,
		required String productId
	){
		var rows = this.getAltreRigheByQuotationAndProductId(
			"quotationItemId" = quotationItemId,
			"quotationId" = quotationId,
			"productId" = productId
		);

		// Precarica tutti i QuotationItem in batch per evitare N+1
		var itemIds = [];
		for ( var row in rows ) {
			itemIds.append( row.quotation_item_id );
		}
		var itemMap = ArrayLen( itemIds ) ? getMany( itemIds ) : {};

		// Anche questo aggregatore precalcola i totali per i suoi item (chiavi già presenti
		// vengono semplicemente riscritte con lo stesso valore)
		precomputeBatchTotals( arguments.quotationId, StructKeyArray( itemMap ), itemMap );

		// La Quotation è la stessa per tutte le righe: viene estratta una sola volta dai bean
		// già caricati in batch e passata a ogni aggiornaPrezzo (evita il rebuild per item, N+1).
		var sharedQuotation = NullValue();
		for ( var loadedRow in rows ) {
			if ( StructKeyExists( itemMap, loadedRow.quotation_item_id ) ) {
				var itemQuotation = itemMap[ loadedRow.quotation_item_id ].getQuotation();
				if ( !IsNull( itemQuotation ) ) {
					sharedQuotation = itemQuotation;
					break;
				}
			}
		}

		for ( var row in rows ) {
			var quotationItem = StructKeyExists( itemMap, row.quotation_item_id )
				? itemMap[ row.quotation_item_id ]
				: NullValue();
			if (
				IsNull( quotationItem ) ||
				IsInstanceOf(quotationItem, "com.apirone.core.model.bean.QuotationItemPlate") ||
				IsInstanceOf(quotationItem, "com.apirone.core.model.bean.QuotationItemSignage") ||
				!isNull(quotationItem.getArticle())
			) {
				continue;
			}

			aggiornaPrezzo( quotationItem, sharedQuotation );
		}
	}

	/*
		Ricalcola il prezzo dell'item ricevuto.
		Il parametro opzionale preloadedQuotation permette al chiamante (es.
		aggiornaPrezzoAltriArticoli...) di passare la Quotation già caricata in
		batch, evitando un refetch completo della Quotation per ogni riga (N+1).
	*/
	public function aggiornaPrezzo( required quotationItem, preloadedQuotation = javacast( "null", "" ), skipPrewarm = javacast( "null", "" ) )
	{

		// skipPrewarm letto con StructKeyExists: un null passato posizionalmente non viene bindato
		var doSkipPrewarm = StructKeyExists( arguments, "skipPrewarm" ) && !IsNull( arguments.skipPrewarm ) && arguments.skipPrewarm;

		if (!isNull(quotationItem.getArticle())) {
			return false;
		}
		// Una riga gemella con quantità 0 (es. in compilazione) non è prezzabile: PriceCalculatorService
		// rifiuta quantità <= 0. Saltarla qui evita che blocchi il ricalcolo/salvataggio delle altre righe.
		if ( Val( quotationItem.getQuantity() ) <= 0 ) {
			return false;
		}
		var quotationId = quotationItem.getQuotation().getId()
		var productId = quotationItem.getProduct().getId();
		var quantity = quotationItem.getQuantity();
		var productItemIds = [];
		if (!isNull(quotationItem.getItems())) {
			for (var item in quotationItem.getItems()) {
				productItemIds.append(item.getProductItem().getId())
			}
		}

		//questa parte serve per replicare le strutture dati che si aspettano getSignagePricing e la getPlatePricing quando chiamate dal client
		if (IsInstanceOf(quotationItem, "com.apirone.core.model.bean.QuotationItemPlate")) {
			var json =
			{
				"quotationId": "",
				"price": {
					"quantity": 0,
					"discount1": 0,
					"discount2": 0,
					"total": 0,
					"method": { "id": "" }
				},
				"item": {
					"id": "",
					"quantity": 0,
					"product": {
						"id": "",
						"items": { "_data": [] }
					},
					"quotationZone": {
						"id": ""
					},
					"fruits": { "_data": [] }
				}
			}
			json.quotationId = quotationId;
			json.item.id = quotationItem.getId();
			json.item.quotationZone.id = quotationItem.getQuotationZone().getId();
			json.item.quantity = quantity;
			if (!isNull(quotationItem.getPrice())) {
				json.price.id = quotationItem.getPrice().getId();
				json.price.discount1 = quotationItem.getPrice().getDiscount1();
				json.price.discount2 = quotationItem.getPrice().getDiscount2();
				json.price.method.id = quotationItem.getPrice().getMethod().getId();
				json.price.total = quotationItem.getPrice().getMethod().getId() == "F" ? quotationItem.getPrice().getAmount() : 0;
			}
			json.item.product.id = productId;
			for (productItemId in productItemIds) {
				json.item.product.items._data.append({
					values = [
						{ selected = true, productItemId = productItemId }
					]
				});
			}
			var PLUG_IDS = variables.plugProductIdList;
			var realFruits = [];
			var positions = {};
			var fruits = quotationItem.getFruits();
			for (var fruit in fruits) {
				// escludi tappi esistenti: verranno ricalcolati
				if ( PLUG_IDS.find( LCase( fruit.getFruit().getId() ) ) ) continue;
				realFruits.append( fruit );
				var fruitItems = [];
				if ( !isNull( fruit.getItems() ) ) {
					for (fruitItem in fruit.getItems()) {
						fruitItems.append({
							values = [
								{ selected = true, productItemId = fruitItem.getProductItem().getId() }
							]
						})
					}
				}
				json.item.fruits._data.append({
					"fruit": {
						"name": fruit.getFruit().getName(),
						"id": fruit.getFruit().getId()
					},
					"fruitId": fruit.getId(),
					"items": { "_data": fruitItems }
				});
				// costruisce json.positions per computePlugRuns
				var fruitPositions = fruit.getPositions();
				if ( !isNull( fruitPositions ) && ArrayLen( fruitPositions ) ) {
					var posArr = [];
					for ( var fp in fruitPositions ) {
						var posId = StructKeyExists( fp, "id" ) ? fp.id : ( StructKeyExists( fp, "position" ) ? fp.position : "" );
						if ( Len( posId ) ) posArr.append( { id: posId, order: fp.order } );
					}
					positions[ fruit.getId() ] = posArr;
				}
			}
			// fornisce frame.code e orientation a computePlugRuns
			json.positions = positions;
			json.item.product.frame = { "code": quotationItem.getProduct().getModel().getCode() };
			json.item.product.orientation = { "id": quotationItem.getFrame().getOrientation().getId() };
			// ricalcola i tappi e aggiorna la lista fruits
			var plugBeans = buildPlugFruitBeans( json );
			var allFruits = [];
			allFruits.append( realFruits, true );
			allFruits.append( plugBeans, true );
			quotationItem.setFruits( allFruits );
			// doSkipPrewarm: l'eventuale sweep di massa è già stato fatto dall'aggregatore
			var price = getPlatePricing( json, preloadedQuotation, quotationItem, doSkipPrewarm )
		}

		if (IsInstanceOf(quotationItem, "com.apirone.core.model.bean.QuotationItemSignage")) {
			json = {
				"quotationId": "",
				"quotationItem": {
					"id": "",
					"quantity": 0,
					"price": {
						"id": 0,
						"discount1": 0,
						"discount2": 0,
						"method": { "id": "F" },
						"total": 0
					},
					"quotationZone": {
						"id": ""
					},
					"product": {
						"id": "",
					"items": { "_data": [] }
					},
					"signageRows": { "_data": [] },
					"signageConfigItem": { "id": 0 }
				}
			}

			json.quotationId = quotationId;
			json.quotationItem.id = quotationItem.getId()
			json.quotationItem.quotationZone.id = quotationItem.getQuotationZone().getId()
			json.quotationItem.quantity = quantity
			if (!isNull(quotationItem.getPrice())) {
				json.quotationItem.price.id = quotationItem.getPrice().getId();
				json.quotationItem.price.discount1 = quotationItem.getPrice().getDiscount1();
				json.quotationItem.price.discount2 = quotationItem.getPrice().getDiscount2();
				json.quotationItem.price.method.id = quotationItem.getPrice().getMethod().getId();
				json.quotationItem.price.total = quotationItem.getPrice().getMethod().getId() == "F" ? quotationItem.getPrice().getAmount() : 0;
			}
			json.quotationItem.product.id = productId;
			for (productItemId in productItemIds) {
				json.quotationItem.product.items._data.append({
					values = [
						{ selected = true, product_item_id = productItemId }
					]
				});
			}

			json.quotationItem.signageConfigItem.id = quotationItem.getSignageConfigItem().getId()
			for ( var signageRow in quotationItem.getSignageRows() ) {
				json.quotationItem.signageRows._data.append({ charCount = signageRow.getCharCount(), content = signageRow.getContent() ?: "" });
			}
			var price = getSignagePricing( json, preloadedQuotation, quotationItem )
		} elseif (isNull(quotationItem.getArticle()) && !IsInstanceOf(quotationItem, "com.apirone.core.model.bean.QuotationItemPlate")) {
			json = {
				"quotationId": "",
				"quotationItem": {
					"id": "",
					"quantity": 0,
					"price": {
						"id": 0,
						"discount1": 0,
						"discount2": 0,
						"method": { "id": "F" },
						"total": 0
					},
					"quotationZone": {
						"id": ""
					},
					"product": {
						"id": "",
					"items": { "_data": [] }
					}
				}
			}

			json.quotationId = quotationId;
			json.quotationItem.id = quotationItem.getId()
			json.quotationItem.quotationZone.id = quotationItem.getQuotationZone().getId()
			json.quotationItem.quantity = quantity
			if (!isNull(quotationItem.getPrice())) {
				json.quotationItem.price.id = quotationItem.getPrice().getId();
				json.quotationItem.price.discount1 = quotationItem.getPrice().getDiscount1();
				json.quotationItem.price.discount2 = quotationItem.getPrice().getDiscount2();
				json.quotationItem.price.method.id = quotationItem.getPrice().getMethod().getId();
				json.quotationItem.price.total = quotationItem.getPrice().getMethod().getId() == "F" ? quotationItem.getPrice().getAmount() : 0;
			}
			json.quotationItem.product.id = productId;
			for (productItemId in productItemIds) {
				json.quotationItem.product.items._data.append({
					values = [
						{ selected = true, product_item_id = productItemId }
					]
				});
			}
			var price = getPricing( json, preloadedQuotation, quotationItem )
		}

		// Conserva l'id della riga prezzo esistente prima di sostituire il bean: il ricalcolo
		// produce un prezzo nuovo e quindi la riga su DB va aggiornata, non duplicata.
		// Con l'id già valorizzato update() salta la ricerca del prezzo corrente (3
		// query per gemello). Gli item senza prezzo salvato (primo prezzo) seguono
		// la ricerca come prima.
		var existingPriceId = ( !IsNull( quotationItem.getPrice() ) && !IsNull( quotationItem.getPrice().getId() ) && Len( quotationItem.getPrice().getId() ) )
			? quotationItem.getPrice().getId()
			: NullValue();
		quotationItem.setPrice( price )
		if ( !IsNull( existingPriceId ) ) {
			price.setId( existingPriceId );
		}
		update(quotationItem)
	}

	public function validateQuantity(
		required Quotation quotation,
		required QuotationItem quotationItem
	) {
		var productMinQuantity = quotationItem.getProduct().getMinQuantity()
		var productMaxQuantity = quotationItem.getProduct().getMaxQuantity()

		var productQuantity = 0
		if (productMinQuantity > 0 || productMaxQuantity > 0) {
			productQuantity = getProductQuantityByQuotation( quotation, quotationItem.getProduct() )
		}

		if ( productQuantity LT productMinQuantity || productQuantity GT productMaxQuantity ) {
			return false;
		}

		return true;
	}

	public function getProductQuantityByQuotation( Quotation quotation, Product product ) {
		var quotationItems = list( quotationId = quotation.getId() )
		var quantity = 0;
		for ( var item in quotationItems ) {
			if (!isNull(item.getArticle())) {
				continue;
			}
			if (item.getProduct().getId() == product.getId() ) {
				quantity += item.getQuantity()
			}
		}

		return quantity;
	}

	public function validateDiscounts(
		required numeric maxUserDiscount,
		required numeric quotationDiscount1,
		required numeric quotationDiscount2,
		required numeric itemDiscount1,
		required numeric itemDiscount2
	) {
		var factor =
			( 1 - arguments.quotationDiscount1 / 100 ) *
			( 1 - arguments.quotationDiscount2 / 100 ) *
			( 1 - itemDiscount1 / 100 ) *
			( 1 - itemDiscount2 / 100 );
		var totalDiscount = ( 1 - factor ) * 100;

		if ( totalDiscount GT arguments.maxUserDiscount ) {
			return false;
		}

		return true;
	}
}
