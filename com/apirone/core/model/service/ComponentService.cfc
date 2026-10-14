component extends="com.apirone.core.model.service.AbsService" accessors="true" {

	property name="dao" inject="ComponentDAO";
	property name="statusService" inject="StatusService";
	property name="rawProductService" inject="RawProductService";
	property name="variantService" inject="VariantService";
	property name="colorService" inject="ColorService";
	property name="productService" inject="ProductService";
	property name="productItemService" inject="ProductItemService";
	property name="productItemDAO" inject="ProductItemDAO";
	property name="componentOverrideService" inject="ComponentOverrideService";
	property name="lineService" inject="LineService";
	property name="modelService" inject="ModelService";
	property name="costService" inject="CostService";
	property name="signageConfigItemService" inject="SignageConfigItemService";
	property name="CatalogBundleService" inject="CatalogBundleService";
	property name="TextService" inject="TextService";
	property name="PriceService" inject="PriceService";
	property name="FileService" inject="FileService";
	property name="FinishService" inject="FinishService";
	property name="ProductCategoryService" inject="ProductCategoryService";

	public com.apirone.core.model.bean.Component function get( required String componentId ){
		return build( arguments.componentId );
	}

	public Array function list(){
		arguments[ "limit" ] = -1;

		return search( argumentCollection = arguments ).getData();
	}

	/**
	 * Recupera in batch i componenti collegati a una lista di product_item_id.
	 * Restituisce un array di bean Component (own components) senza i base-attribute.
	 * Utilizzato da QuotationService.getComponents() per evitare N+1.
	 *
	 * @productItemIds Array di productItemId
	 * @return Array di bean Component
	 */
	public Array function listByProductItemIds( required Array productItemIds ){
		var records = getDao().readByProductItemIds( arguments.productItemIds );
		var ids     = [];
		for ( var r in records ) {
			ArrayAppend( ids, r.component_id );
		}

		if ( !ArrayLen( ids ) ) {
			return [];
		}

		var beanMap = getMany( ids );
		var result  = [];
		for ( var id in ids ) {
			if ( StructKeyExists( beanMap, id ) ) {
				ArrayAppend( result, beanMap[ id ] );
			}
		}

		return result;
	}

	/**
	 * Recupera in batch i componenti di tipo SignageItemProduct per una lista di
	 * product_item_id (join) dato l'ID della config segnaletica.
	 * Restituisce un array di bean Component.
	 * Utilizzato da QuotationService.getComponents() per evitare N+1.
	 *
	 * @signageConfigItemId ID della config segnaletica
	 * @productItemIds Array di productItemId (join)
	 * @return Array di bean Component
	 */
	public Array function listBySignageItemProductJoinIds(
		required String signageConfigItemId,
		required Array productItemIds
	){
		var records = getDao().readBySignageItemProductJoinIds(
			signageConfigItemId = arguments.signageConfigItemId,
			productItemIds      = arguments.productItemIds
		);
		var ids = [];
		for ( var r in records ) {
			ArrayAppend( ids, r.component_id );
		}

		if ( !ArrayLen( ids ) ) {
			return [];
		}

		var beanMap = getMany( ids );
		var result  = [];
		for ( var id in ids ) {
			if ( StructKeyExists( beanMap, id ) ) {
				ArrayAppend( result, beanMap[ id ] );
			}
		}

		return result;
	}

	public Numeric function count(
		String lineId,
		String modelId,
		String productId,
		Numeric productItemId,
		Numeric attributeValueId
	){
		var result = getDao().find( argumentCollection = arguments );

		return Val( result.total );
	}

	public Array function priceCalculatorSearch(
		String lineId,
		String modelId,
		String productId,
		Numeric productItemId,
		Numeric attributeValueId,
		Boolean includeBaseAttributeComponents = false hint="Only for product productItemId",
		limit = -1,
		skipPrewarm = javacast( "null", "" )
	){
		// skipPrewarm letto con StructKeyExists: un null non viene bindato e la chiave non esisterebbe
		var doSkipPrewarm = StructKeyExists( arguments, "skipPrewarm" ) && !IsNull( arguments.skipPrewarm ) && arguments.skipPrewarm;

		if ( !IsNull( arguments.productItemId ) AND arguments.includeBaseAttributeComponents ) {
			return searchByProductItemIdForPriceCalculator( arguments.productItemId );
		}

		var rows   = [];
		var result = super.getResult();

		// Riuso per richiesta: i path linea+modello e prodotto (senza productItemId) restituiscono
		// gli stessi componenti per tutta la richiesta (es. N placche gemelle dello stesso modello
		// riusano gli stessi componenti bundle): una lettura sola invece di una per chiamata.
		//
		// Il productItemId (override scoped per item), l'attributeValueId e il path signage
		// rendono il risultato variabile per chiamata: non si memoizzano.
		var searchMemoKey = "";
		if ( IsNull( arguments.productItemId ) && IsNull( arguments.attributeValueId ) && IsNull( arguments.signageItemProduct ) ) {
			if ( !IsNull( arguments.lineId ) && !IsNull( arguments.modelId ) ) {
				searchMemoKey = "bundle_" & arguments.lineId & "_" & arguments.modelId;
			} else if ( !IsNull( arguments.productId ) ) {
				searchMemoKey = "product_" & arguments.productId & ( arguments.includeBaseAttributeComponents ? "_ba" : "" );
			}
		}
		if ( !StructKeyExists( request, "_componentSearchMemo" ) ) {
			request._componentSearchMemo = {};
		}
		if ( Len( searchMemoKey ) && StructKeyExists( request._componentSearchMemo, searchMemoKey ) ) {
			return request._componentSearchMemo[ searchMemoKey ];
		}

		var records = getDao().find( argumentCollection = arguments );

		// Prewarm verticale in batch: legge raw|variant|color di tutti i componenti
		// trovati in una sola query (apirone) e precompila le memo ERP (listin +
		// artico), così i priceCalculatorRead per componente non interrogano
		// verticale uno alla volta.
		if ( !doSkipPrewarm && records.recordCount GT 0 ) {
			var componentIdsForPrewarm = [];
			records.each( function( record ){
				ArrayAppend( componentIdsForPrewarm, record.component_id );
			} );

			var triplesForPrewarm = getDao().getComponentTriplesByComponentIds( componentIdsForPrewarm );
			var prewarmTriples    = [];
			var prewarmRawIds     = [];
			var seenRawIds        = {};
			triplesForPrewarm.each( function( t ){
				if ( !IsNull( t.raw_product_id ) && Len( Trim( t.raw_product_id ) ) ) {
					ArrayAppend( prewarmTriples, {
						rawProductId = t.raw_product_id,
						variantId    = t.variant_id,
						colorId      = t.color_id
					} );
					if ( !StructKeyExists( seenRawIds, t.raw_product_id ) ) {
						seenRawIds[ t.raw_product_id ] = true;
						ArrayAppend( prewarmRawIds, t.raw_product_id );
					}
				}
			} );
			getDao().getComponentCostByTriples( prewarmTriples );
			getDao().getRawProductDataByIds( prewarmRawIds );
		}

		records.each( function( record ){
			var component = getDao().priceCalculatorRead( componentId = record.component_id, productItemId = !isNull(arguments.productItemId) ? arguments.productItemId : null )
			rows.add(component)
		} );

		if ( Len( searchMemoKey ) ) {
			request._componentSearchMemo[ searchMemoKey ] = rows;
		}

		return rows
	}

	/**
	 * Precarica in batch TUTTI i dati verticale (costi listin + nomi raw product) necessari al
	 * calcolo prezzo di una placca: componenti own e attributo degli item selezionati, componenti
	 * di placca/frutti/tappi e componenti linea+modello (bundle). Chiamato una sola volta a inizio
	 * pricing (getPlatePricing) così i calcoli per frutto/tappo e i prewarm interni dei path di
	 * calcolo non fanno più round trip verso l'ERP (memo già popolata, batch early-return).
	 *
	 * @productItemIds Array di productItemId (componenti own + attributo legati agli item selezionati)
	 * @productIds      Array di productId (componenti di placca/frutti/tappi)
	 * @lineId          Linea della placca (per i componenti bundle)
	 * @modelId         Modello della placca (per i componenti bundle, chiamata singola)
	 * @modelIds        Lista di modelli distinti (per il prewarm di più placche gemelle
	 *                  con la stessa linea ma modelli diversi); alternativo a modelId
	 */
	public void function prewarmPricingComponents(
		required Array productItemIds,
		required Array productIds,
		String lineId,
		String modelId,
		Array modelIds
	){
		var tripleMap = {};
		var rawIdMap  = {};

		// Collettore locale: deduplica le triple e raccoglie i raw id da qualsiasi set di record
		var collectTriples = function( records ){
			for ( var rec in records ) {
				if ( !IsNull( rec.raw_product_id ) && Len( Trim( rec.raw_product_id ) ) ) {
					tripleMap[ Trim( rec.raw_product_id ) & "|" & Trim( rec.variant_id ) & "|" & Trim( rec.color_id ) ] = {
						rawProductId = rec.raw_product_id,
						variantId    = rec.variant_id,
						colorId      = rec.color_id
					};
					rawIdMap[ rec.raw_product_id ] = true;
				}
			}
		};

		if ( ArrayLen( arguments.productItemIds ) ) {
			// Componenti own degli item (stessa sorgente del path item del calcolo prezzo)
			collectTriples( getDao().priceCalculatorReadByProductItemIds( arguments.productItemIds ) );

			// Componenti attributo degli item (l'altra sorgente del path item)
			var piRecords = getProductItemDAO().readByIds( arguments.productItemIds );
			var attrValueIds    = [];
			var attrValueSeen   = {};
			for ( var pi in piRecords ) {
				if ( !IsNull( pi.attribute_raw_value_id ) && !StructKeyExists( attrValueSeen, pi.attribute_raw_value_id ) ) {
					attrValueSeen[ pi.attribute_raw_value_id ] = true;
					ArrayAppend( attrValueIds, pi.attribute_raw_value_id );
				}
			}
			if ( ArrayLen( attrValueIds ) ) {
				collectTriples( getDao().readByAttributeValueIds( attrValueIds ) );
			}
		}

		if ( ArrayLen( arguments.productIds ) ) {
			collectTriples( getDao().getComponentTriplesByProductIds( arguments.productIds ) );
		}

		if ( !IsNull( arguments.lineId ) && !IsNull( arguments.modelId ) ) {
			collectTriples( getDao().getComponentTriplesByLineModel( arguments.lineId, arguments.modelId ) );
		} else if ( !IsNull( arguments.lineId ) && !IsNull( arguments.modelIds ) ) {
			// Modelli distinti (es. i gemelli condividono la linea ma non il modello): una lettura per modello
			for ( var hModelId in arguments.modelIds ) {
				collectTriples( getDao().getComponentTriplesByLineModel( arguments.lineId, hModelId ) );
			}
		}

		var triples = [];
		for ( var tripleKey in tripleMap ) {
			ArrayAppend( triples, tripleMap[ tripleKey ] );
		}

		getDao().getComponentCostByTriples( triples );
		getDao().getRawProductDataByIds( StructKeyArray( rawIdMap ) );
	}

	/**
	 * Recupera in batch i componenti (own + base attribute) per il calcolo prezzo
	 * di una lista di product_item_id. Sostituisce N chiamate a
	 * searchByProductItemIdForPriceCalculator() con poche query batch, evitando
	 * il problema N+1 nel loop di PriceCalculatorService.simulate().
	 *
	 * @productItemIds Array di productItemId
	 * @return Struct mappato per productItemId -> Array di struct componente
	 */
	public Struct function priceCalculatorSearchByProductItemIds( required Array productItemIds, skipPrewarm = javacast( "null", "" ) ){
		// Nessun item da processare: evita di generare una query con IN () vuoto.
		if ( !ArrayLen( arguments.productItemIds ) ) {
			return {};
		}

		// skipPrewarm letto con StructKeyExists: un null non viene bindato e la chiave non esisterebbe
		var doSkipPrewarm = StructKeyExists( arguments, "skipPrewarm" ) && !IsNull( arguments.skipPrewarm ) && arguments.skipPrewarm;

		// Memo per request per SINGOLO product item: i gemelli condividono gli stessi product
		// item (stessa linea e finitura), quindi il primo chiamante calcola i mancanti e i
		// successivi riusano i risultati senza query. I componenti sono struct di sola lettura
		// nel pricing (calculateComponentsTotal li legge, non li modifica).
		if ( !StructKeyExists( request, "_pcByProductItemMemo" ) ) {
			request._pcByProductItemMemo = {};
		}
		var missingIds = [];
		for ( var memoPid in arguments.productItemIds ) {
			if ( !StructKeyExists( request._pcByProductItemMemo, memoPid ) ) {
				missingIds.append( memoPid );
			}
		}

		if ( ArrayLen( missingIds ) ) {

		// 1) Componenti "own" (product_item_id = pid) con override correlato in una sola query
		var ownRecords = getDao().priceCalculatorReadByProductItemIds( missingIds );

		// 2) Componenti "base attribute" (attribute_raw_value_id) con override scoped per item
		var piRecords = getProductItemDAO().readByIds( missingIds );

		// Mappe: attribute_raw_value_id -> [productItemId] e lista degli attribute value unici
		var attrValueToPids = {};
		var attrValueIds    = [];
		var attrValueSeen   = {};
		for ( var pi in piRecords ) {
			if ( !IsNull( pi.attribute_raw_value_id ) ) {
				var attrValueId = pi.attribute_raw_value_id;

				if ( !StructKeyExists( attrValueToPids, attrValueId ) ) {
					attrValueToPids[ attrValueId ] = [];
				}
				ArrayAppend( attrValueToPids[ attrValueId ], pi.product_item_id );

				if ( !StructKeyExists( attrValueSeen, attrValueId ) ) {
					attrValueSeen[ attrValueId ] = true;
					ArrayAppend( attrValueIds, attrValueId );
				}
			}
		}

		var attrRecords = [];
		var overrideMap = {};
		if ( ArrayLen( attrValueIds ) ) {
			attrRecords = getDao().readByAttributeValueIds( attrValueIds );

			// Raccoglie gli id dei componenti attributo e legge gli override in batch
			var attrComponentIds = [];
			for ( var ar in attrRecords ) {
				ArrayAppend( attrComponentIds, ar.component_id );
			}

			if ( ArrayLen( attrComponentIds ) ) {
				var overrideRecords = getDao().readOverridesByComponentIdsAndProductItemIds(
					componentIds   = attrComponentIds,
					productItemIds = missingIds
				);
				for ( var ov in overrideRecords ) {
					overrideMap[ ov.component_id & "_" & ov.product_item_id ] = ov;
				}
			}
		}

		// 3) Prewarm verticale in batch: una sola query listin (una riga per terna raw|variant|color,
		// con la stessa priorità del singolo getComponentCost) e una sola query artico per i nomi.
		// Riempie le memo per request così i build seguenti non interrogano l'ERP uno alla volta.
		var tripleMap = {};
		var rawIdMap  = {};
		for ( var r in ownRecords ) {
			if ( !IsNull( r.raw_product_id ) && Len( Trim( r.raw_product_id ) ) ) {
				tripleMap[ Trim( r.raw_product_id ) & "|" & Trim( r.variant_id ) & "|" & Trim( r.color_id ) ] = {
					rawProductId = r.raw_product_id,
					variantId    = r.variant_id,
					colorId      = r.color_id
				};
				rawIdMap[ r.raw_product_id ] = true;
			}
		}
		for ( var ar in attrRecords ) {
			if ( !IsNull( ar.raw_product_id ) && Len( Trim( ar.raw_product_id ) ) ) {
				tripleMap[ Trim( ar.raw_product_id ) & "|" & Trim( ar.variant_id ) & "|" & Trim( ar.color_id ) ] = {
					rawProductId = ar.raw_product_id,
					variantId    = ar.variant_id,
					colorId      = ar.color_id
				};
				rawIdMap[ ar.raw_product_id ] = true;
			}
		}
		var triples = [];
		for ( var tripleKey in tripleMap ) {
			ArrayAppend( triples, tripleMap[ tripleKey ] );
		}

		// Con skipPrewarm il chiamante ha già precaricato tutto lo sweep (memo piena,
		// i due batch sarebbero no-op): si salta anche l'attraversamento delle triple.
		if ( !doSkipPrewarm ) {
			getDao().getComponentCostByTriples( triples );
			getDao().getRawProductDataByIds( StructKeyArray( rawIdMap ) );
		}

		// Inizializza una voce vuota per ogni item mancante (preserva gli item senza componenti)
		for ( var pid in missingIds ) {
			request._pcByProductItemMemo[ pid ] = [];
		}

		// 4) Componenti "own": costruiti dopo il prewarm, i getComponentCost/getRawProductData interni
		// trovano tutto già in memo (zero query ERP per componente)
		for ( var r in ownRecords ) {
			var component = buildPriceCalculatorComponent(
				id            = r.id,
				isDeleted     = r.isDeleted,
				totalQuantity = r.totalQuantity,
				rawProductId  = r.raw_product_id,
				variantId     = r.variant_id,
				colorId       = r.color_id
			);

			if ( StructKeyExists( request._pcByProductItemMemo, r.product_item_id ) ) {
				ArrayAppend( request._pcByProductItemMemo[ r.product_item_id ], component );
			}
		}

		// 5) Costruisce i componenti attributo per ogni product item (override scoped per item)
		for ( var ar in attrRecords ) {
			var pids = StructKeyExists( attrValueToPids, ar.attribute_raw_value_id )
				? attrValueToPids[ ar.attribute_raw_value_id ]
				: [];

			for ( var pid in pids ) {
				var overrideKey = ar.component_id & "_" & pid;
				var overrideRow = StructKeyExists( overrideMap, overrideKey ) ? overrideMap[ overrideKey ] : NullValue();

				var isDeleted = false;
				var totalQuantity = ar.quantity;
				if ( !IsNull( overrideRow ) ) {
					isDeleted = !IsNull( overrideRow.deleted ) && BooleanFormat( overrideRow.deleted );
					if ( isDeleted ) {
						totalQuantity = 0;
					} else if ( !IsNull( overrideRow.quantity ) ) {
						totalQuantity = ar.quantity + overrideRow.quantity;
					}
				}

				var component = buildPriceCalculatorComponent(
					id            = ar.component_id,
					isDeleted     = isDeleted,
					totalQuantity = totalQuantity,
					rawProductId  = ar.raw_product_id,
					variantId     = ar.variant_id,
					colorId       = ar.color_id
				);

				if ( StructKeyExists( request._pcByProductItemMemo, pid ) ) {
					ArrayAppend( request._pcByProductItemMemo[ pid ], component );
				}
			}
		}

		}

		// Risultato: tutte le voci richieste, dal calcolo o dalla memo
		var result = {};
		for ( var outPid in arguments.productItemIds ) {
			result[ outPid ] = request._pcByProductItemMemo[ outPid ];
		}

		return result;
	}

	/**
	 * Costruisce lo struct componente usato dal calcolo prezzo (stessa forma di
	 * ComponentDAO.priceCalculatorRead()) e risolve il costo verticale.
	 */
	private Struct function buildPriceCalculatorComponent(
		required id,
		required isDeleted,
		required totalQuantity,
		required rawProductId,
		required variantId,
		required colorId
	){
		var component = {
			"id"             = arguments.id,
			"isDeleted"      = arguments.isDeleted,
			"totalQuantity"  = arguments.totalQuantity,
			"raw_product_id" = arguments.rawProductId,
			"variant_id"     = arguments.variantId,
			"color_id"       = arguments.colorId,
			"costAmount"     = getDao().getComponentCost(
				rawProductId = arguments.rawProductId,
				variantId    = arguments.variantId,
				colorId      = arguments.colorId
			)
		};

		var rawProductData = getDao().getRawProductData( arguments.rawProductId );
		component[ "raw_product_name" ] = rawProductData.raw_product_name;
		component[ "raw_product_processiong_type" ] = rawProductData.raw_product_processiong_type;
		component[ "raw_product_unit" ] = rawProductData.raw_product_unit;

		return component;
	}

	/**
	 * Maggiorazione delle quantità dei componenti la cui materia prima non è a pezzi
	 * ( sfrido ): +15%. Vale sia per i costi ( PriceCalculatorService ) sia per la
	 * distinta base esportata a Verticale ( QuotationService.exportProducts ).
	 * Escluse anche PA ( paia ), EU ( valuta in euro ) e NR ( numero ). Unità vuota = PZ, come in
	 * RawProductService.
	 */
	public Numeric function quantityWasteFactor( unit ){
		var u = IsNull( arguments.unit ) ? "" : UCase( Trim( arguments.unit ) );
		return ( !Len( u ) || ListFind( "PZ,PA,EU,NR", u ) ) ? 1 : 1.15;
	}

	public com.apirone.core.model.bean.Result function search(
		// TODO: add category
		String lineId,
		String modelId,
		String productId,
		Numeric productItemId,
		Numeric attributeValueId,
		Boolean includeBaseAttributeComponents = false hint="Only for product productItemId"
	){
		if ( !IsNull( arguments.productItemId ) AND arguments.includeBaseAttributeComponents ) {
			return searchByProductItemId( arguments.productItemId );
		}

		var rows   = [];
		var result = super.getResult();

		// Primo passaggio: il find() restituisce solo gli ID (più il totale per paginazione)
		var records = getDao().find( argumentCollection = arguments );

		// Raccoglie tutti gli ID e carica i record in blocco con una sola query
		var ids = [];
		records.each( function( r ){
			ids.append( r.component_id );
		} );

		// Costruisce tutti i bean in batch con getMany() ottimizzato (evita N+1)
		var beanMap = ArrayLen( ids ) ? getMany( ids ) : {};

		// Ricostruisce le righe nell'ordine del find() originale
		records.each( function( record ){
			rows.add( beanMap[ record.component_id ] );
		} );

		result.setData( rows );
		result.setCount( Val( records.recordcount ) );
		result.setTotal( Val( records.total ) );
		return result;
	}

	public Numeric function massiveReassign(
		String rawProductId,
		String variantId,
		String colorId,
		String paramCategory,
		String newParam,
		String oldParam
	){
		arguments[ "limit" ] = -1;

		var rows   = [];
		var result = super.getResult();

		var records = getDao().find( argumentCollection = arguments );
		var params  = {};

		if ( paramCategory == "rawProductId" ) {
			params = { "paramCategory" = paramCategory, "newParam" = newParam }
		}

		if ( paramCategory == "variantId" ) {
			params = { "paramCategory" = paramCategory, "newParam" = newParam }
		}

		if ( paramCategory == "colorId" ) {
			params = { "paramCategory" = paramCategory, "newParam" = newParam }
		}

		super.logEvent(
			event   = "component.MULTI_UPDATED",
			message = "Massive component reassign procedure started",
			payload = {
				"criteria" = paramCategory,
				"oldValue" = oldParam,
				"newValue" = newParam
			}
		);
		records.each( function( record ){
			var rowParams              = params;
			rowParams[ "componentId" ] = record.component_id;

			getDao().reassign( argumentCollection = rowParams );

			super.logEvent(
				event   = "component.UPDATED",
				message = "Component [#rowParams[ "componentId" ]#] updated.",
				payload = {
					"criteria" = rowParams[ "paramCategory" ],
					"id"       = rowParams[ "componentId" ],
					"oldValue" = oldParam,
					"newValue" = rowParams[ "newParam" ]
				}
			);

		} );

		super.logEvent(
			event   = "component.MULTI_UPDATED",
			message = "Massive component reassign procedure ended",
			payload = {
				"criteria"      = paramCategory,
				"oldValue"      = oldParam,
				"newValue"      = newParam,
				"recordUpdated" = Val( records.recordcount )
			}
		);

		return Val( records.recordcount );
	}

	public Numeric function massiveDelete(
		String rawProductId,
		String variantId,
		String colorId,
		String paramCategory,
		String oldParam
	){
		arguments[ "limit" ] = -1;

		var rows   = [];
		var result = super.getResult();

		var records = getDao().find( argumentCollection = arguments );
		var params  = {};

		super.logEvent(
			event   = "component.MULTI_DELETED",
			message = "Massive component delete procedure started",
			payload = { "criteria" = paramCategory, "value" = oldParam }
		);

		records.each( function( record ){
			delete( record.component_id );
		} );

		super.logEvent(
			event   = "component.MULTI_DELETED",
			message = "Massive component delete procedure ended",
			payload = {
				"criteria"      = paramCategory,
				"value"         = oldParam,
				"recordDeleted" = Val( records.recordcount )
			}
		);

		return Val( records.recordcount );
	}

	public com.apirone.core.model.bean.Outcome function delete( required String componentId ){
		var outcome = super.bean( "Outcome" );

		var obj = get( arguments.componentId, false );

		outcome.setData( { componentId = arguments.componentId } );

		transaction {
			try {
				getDao().delete( arguments.componentId );
				super.logEvent(
					event   = "component.DELETED",
					message = "Component [#arguments.componentId#] deleted.",
					payload = { "id" = arguments.componentId }
				);
			} catch ( any error ) {
				outcome.setError( error );
				outcome.setStatus( "ERROR" );
				outcome.setType( "ApirOne.CannotDeleteComponent" );
				outcome.setMessage( "Cannot delete component [#arguments.componentId#]" );
			}
		}

		return outcome;
	}

	public com.apirone.core.model.bean.Outcome function deleteByParams(
		required  com.apirone.core.model.bean.Component component
	){
		var outcome = super.bean( "Outcome" );

		var obj = get( arguments.component.getId() );

		outcome.setData( { component = arguments.component } );

		transaction {
			try {
				getDao().deleteByParams( arguments.component );
			} catch ( any error ) {
				outcome.setError( error );
				outcome.setStatus( "ERROR" );
				outcome.setType( "ApirOne.CannotDeleteComponent" );
				outcome.setMessage( "Cannot delete component [#obj.getId()#]" );
			}
		}

		return outcome;
	}

	public String function create( required com.apirone.core.model.bean.Component component ){
		// TODO: to fix, add validation

		if ( Len( arguments.component.getId() ) ) {
			var id = getDao().update( arguments.component.getId() );
		} else {
			var id = getDao().insert( arguments.component );
		}

		return id;
	}


	public String function update( required com.apirone.core.model.bean.Component component ){
		getDao().update( arguments.component );

		return arguments.component.getId();
	}


	/*
    	private method
	*/

	// TODO: di fatto avrebbe più senso sia searchByAttributeValueId, ma per ora lo lascio così
	private com.apirone.core.model.bean.Result function searchByProductItemId( required String productItemId ){
		var data   = [];
		var result = getResult();

		// components of productItem
		var componentItems = list( productItemId = arguments.productItemId );

		for ( var item in componentItems ) {
			item.setTypeId( "own" );
			data.add( item );
		}

		// components of attribute of productItem
		var productItem = getProductItemService().get( arguments.productItemId );

		if ( Len( productItem.getAttributeValue().getId() ) ) {
			var attrComponents = list( attributeValueId = productItem.getAttributeValue().getId() );

			for ( var thisComponent in attrComponents ) {

				// thisComponent is ComponentAttributeValue
				// move to ComponentProductItem

				var bean = super.bean("ComponentProductItem");

				bean.setRawMemento( thisComponent.getRawMemento() );
				bean.setProductItem( productItem );
				bean.setTypeId( "base" );

				var override = getComponentOverrideService().list( productItem.getId(), thisComponent.getId() );

				if ( override.len() ) {
					// TODO: should be only one override. Add check? db guarantees uniqueness

					bean.setOverride( override[ 1 ] );
				}

				data.add( bean );
			}
		}

		result.setData( data );
		result.setCount( data.len() );
		result.setTotal( data.len() );

		return result;
	}

	private Array function searchByProductItemIdForPriceCalculator( required String productItemId ){
		// Delega al nuovo path batch (override correttamente scoped per item) per non
		// mantenere due implementazioni del calcolo componenti di un singolo product item.
		var map = priceCalculatorSearchByProductItemIds( [ arguments.productItemId ] );
		return StructKeyExists( map, arguments.productItemId )
			? map[ arguments.productItemId ]
			: [];
	}

	/*
    	private method
	*/

	// TODO: di fatto avrebbe più senso sia searchByAttributeValueId, ma per ora lo lascio così
	private com.apirone.core.model.bean.Result function searchByProductItemIdOld( required String productItemId ){
		var data   = [];
		var result = getResult();

		// components of productItem
		var componentItems = list( productItemId = arguments.productItemId );

		for ( var item in componentItems ) {
			item.setTypeId( "own" );
			data.add( item );
		}

		// components of attribute of productItem
		var productItem = getProductItemService().get( arguments.productItemId );

		if ( Len( productItem.getAttributeValue().getId() ) ) {
			var attrComponents = list( attributeValueId = productItem.getAttributeValue().getId() );

			for ( var thisComponent in attrComponents ) {

				// thisComponent is ComponentAttributeValue
				// move to ComponentProductItem

				var bean = super.bean("ComponentProductItem");

				bean.setRawMemento( thisComponent.getRawMemento() );
				bean.setProductItem( productItem );
				bean.setTypeId( "base" );

				var override = getComponentOverrideService().list( productItem.getId(), thisComponent.getId() );

				if ( override.len() ) {
					// TODO: should be only one override. Add check? db guarantees uniqueness

					bean.setOverride( override[ 1 ] );
				}

				data.add( bean );
			}
		}

		result.setData( data );
		result.setCount( data.len() );
		result.setTotal( data.len() );

		return result;
	}

	/**
	 * Recupera in batch più Component dato un array di ID.
	 * Restituisce uno Struct chiave = componentId, valore = bean Component.
	 * precarica ProductItem, Product, SignageConfigItem, Line e Model in batch
	 * per evitare il problema N+1 nei rami condizionali di buildFromRow().
	 *
	 * @ids Array di componentId
	 * @return Struct mappato per componentId -> Component
	 */
	public Struct function getMany( required Array ids ){
		var records = getDao().readByIds( ids = arguments.ids );
		var map     = {};

		// Raccoglie gli ID delle FK dai rami condizionali
		var productItemIds       = [];
		var productIds           = [];
		var signageConfigItemIds = [];
		var lineIds              = [];
		var modelIds             = [];

		for ( var r in records ) {
			// ProductItem (sia join_id che product_item_id)
			if ( Val( r.product_item_id ) ) {
				productItemIds.append( r.product_item_id );
			}
			if ( Len( r.product_item_join_id ) ) {
				productItemIds.append( r.product_item_join_id );
			}

			// Product
			if ( Len( r.product_id ) ) {
				productIds.append( r.product_id );
			}

			// SignageConfigItem (sia signage_config_item_id che join)
			if ( Len( r.signage_config_item_id ) ) {
				signageConfigItemIds.append( r.signage_config_item_id );
			}
			if ( Len( r.signage_config_item_join_id ) ) {
				signageConfigItemIds.append( r.signage_config_item_join_id );
			}

			// CatalogBundle
			if ( Len( r.line_id ) ) {
				lineIds.append( r.line_id );
			}
			if ( Len( r.model_id ) ) {
				modelIds.append( r.model_id );
			}
		}

		// Precarica i ProductItem in batch con getMany() ottimizzato
		var productItemMap = {};
		if ( ArrayLen( productItemIds ) ) {
			productItemMap = getProductItemService().getMany( productItemIds );
		}

		// Precarica i Product in batch con getMany() ottimizzato di ProductService
		var productMap = {};
		if ( ArrayLen( productIds ) ) {
			productMap = getProductService().getMany( productIds );
		}

		// Precarica i SignageConfigItem in batch (getMany esiste)
		var signageConfigItemMap = {};
		if ( ArrayLen( signageConfigItemIds ) ) {
			signageConfigItemMap = getSignageConfigItemService().getMany( signageConfigItemIds );
		}

		// Precarica le Line in batch (getMany esiste)
		var lineMap = {};
		if ( ArrayLen( lineIds ) ) {
			lineMap = getLineService().getMany( lineIds );
		}

		// Precarica i Model in batch (getMany esiste)
		var modelMap = {};
		if ( ArrayLen( modelIds ) ) {
			modelMap = getModelService().getMany( modelIds );
		}

		// Costruisce i bean Component con le mappe pre-caricate
		for ( var r in records ) {
			var bean = super.bean( "Component" );

			// Rami condizionali: determina il tipo di Component
			if ( Len( r.signage_config_item_join_id ) && Len( r.product_item_join_id ) ) {
				bean = super.bean( "ComponentSignageItemProduct" );

				if ( StructKeyExists( productItemMap, r.product_item_join_id ) ) {
					bean.setProductItem( productItemMap[ r.product_item_join_id ] );
				}
				if ( StructKeyExists( signageConfigItemMap, r.signage_config_item_join_id ) ) {
					bean.setSignageConfigItem( signageConfigItemMap[ r.signage_config_item_join_id ] );
				}
			} else if ( Val( r.product_item_id ) ) {
				bean = super.bean( "ComponentProductItem" );

				if ( StructKeyExists( productItemMap, r.product_item_id ) ) {
					bean.setProductItem( productItemMap[ r.product_item_id ] );
				}
			} else if ( Len( r.product_id ) ) {
				bean = super.bean( "ComponentProduct" );

				if ( StructKeyExists( productMap, r.product_id ) ) {
					bean.setProduct( productMap[ r.product_id ] );
				}
			} else if ( Len( r.signage_config_item_id ) ) {
				bean = super.bean( "ComponentSignageConfigItem" );

				if ( StructKeyExists( signageConfigItemMap, r.signage_config_item_id ) ) {
					bean.setSignageConfigItem( signageConfigItemMap[ r.signage_config_item_id ] );
				}
			} else if ( Len( r.line_id ) && Len( r.model_id ) ) {
				bean = super.bean( "ComponentCatalogBundle" );

				if ( StructKeyExists( lineMap, r.line_id ) ) {
					bean.setLine( lineMap[ r.line_id ] );
				}
				if ( StructKeyExists( modelMap, r.model_id ) ) {
					bean.setModel( modelMap[ r.model_id ] );
				}
			}

			// Campi comuni
			bean.setId( r.component_id );
			bean.setQuantity( r.quantity );
			bean.setCreatedAt( r.created_at );
			bean.setStatus( getStatusService().get( r.status_id ) );
			bean.setOverride( super.bean( "ComponentOverride" ) );

			// Verticale: rawProduct, variant, color e cost caricati individualmente (cache interna)
			if ( request.loadFromVerticale ) {
				bean.setRawProduct( getRawProductService().get( r.raw_product_id ) );
				bean.setVariant( getVariantService().get( r.variant_id ) );
				bean.setColor( getColorService().get( r.color_id ) );

				// CostService.getByParams() richiede i bean già impostati
				if ( !IsNull( bean.getRawProduct() ) && !IsNull( bean.getVariant() ) && !IsNull( bean.getColor() ) ) {
					var cost = getCostService().getByParams(
						rawProductId = bean.getRawProduct().getId(),
						variantId    = bean.getVariant().getId(),
						colorId      = bean.getColor().getId()
					);
					bean.setCost( cost );
				}
			}

			map[ r.component_id ] = bean;
		}

		return map;
	}

	/**
	 * Costruisce un bean Component a partire dall'ID. Delega a buildFromRow() dopo la lettura del record.
	 */
	private com.apirone.core.model.bean.Component function build( required String componentId ){
		var record = getDao().read( arguments.componentId );

		if ( record.recordCount ) {
			return buildFromRow( record );
		}

		return NullValue();
	}

	/**
	 * Costruisce un bean Component a partire da una riga del query.
	 * Le sub-entity (ProductItem, Product, SignageConfigItem, Line, Model, ecc.) sono caricate con chiamate individuali.
	 */
	private com.apirone.core.model.bean.Component function buildFromRow( required any record ){
		// TODO: factory for all Component*
		var bean   = super.bean( "Component" );
	    var kindId = "CP";

		if ( Len( arguments.record.signage_config_item_join_id ) AND Len( arguments.record.product_item_join_id ) ) {
			bean = super.bean( "ComponentSignageItemProduct" );

			bean.setProductItem( getProductItemService().get( arguments.record.product_item_join_id ) );
			bean.setSignageConfigItem( getSignageConfigItemService().get( arguments.record.signage_config_item_join_id ) );

			kindId = "PS";
		}

		if ( Val( arguments.record.product_item_id ) ) {

			bean = super.bean( "ComponentProductItem" );
			bean.setProductItem( getProductItemService().get( arguments.record.product_item_id ) );
			kindId = "PI";
		}

		if ( Len( arguments.record.product_id ) ) {
			bean = super.bean( "ComponentProduct" );
			bean.setProduct( getProductService().get( arguments.record.product_id ) );
			kindId = "PR";
		}

		if ( Len( arguments.record.signage_config_item_id ) ) {
			bean = super.bean( "ComponentSignageConfigItem" );
			bean.setSignageConfigItem( getSignageConfigItemService().get( arguments.record.signage_config_item_id ) );
			kindId = "SI";
		}

		if ( Len( arguments.record.line_id ) AND Len( arguments.record.model_id ) ) {
			bean = super.bean( "ComponentCatalogBundle" );

			bean.setLine( getLineService().get( arguments.record.line_id ) );
			bean.setModel( getModelService().get( arguments.record.model_id ) );
			kindId = "CB";
		}

		bean.setId( arguments.record.component_id );

		// TODO: move to bean
		//bean.setKindId( kindId );

		if ( request.loadFromVerticale ) {
			bean.setRawProduct( getRawProductService().get( arguments.record.raw_product_id ) );
			bean.setVariant( getVariantService().get( arguments.record.variant_id ) );
			bean.setColor( getColorService().get( arguments.record.color_id ) );
		}

		bean.setQuantity( arguments.record.quantity );
		bean.setCreatedAt( arguments.record.created_at );

		bean.setStatus( getStatusService().get( arguments.record.status_id ) );

		// changes to Override are updated at runtime
		bean.setOverride( super.bean( "ComponentOverride" ) );

		var cost = getCostService().getByParams(
			rawProductId = bean.getRawProduct().getId(),
			variantId    = bean.getVariant().getId(),
			colorId      = bean.getColor().getId()
		);

		bean.setCost( cost );

		return bean;
	}

}
