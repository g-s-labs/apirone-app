component extends="com.apirone.core.model.service.AbsService" accessors="true" {

	property name="dao" inject="ProductDAO";
	property name="ModelService" inject="ModelService";
	property name="LineService" inject="LineService";
	property name="FinishService" inject="FinishService";
	property name="StatusService" inject="StatusService";
	property name="ProductCategoryService" inject="ProductCategoryService";
	property name="CatalogBundleService" inject="CatalogBundleService";
	property name="PriceService" inject="PriceService";
	property name="TextService" inject="TextService";
	property name="FileService" inject="FileService";
	property name="ProductItemService" inject="ProductItemService";
	property name="componentService" inject="ComponentService";
	property name="componentOverrideService" inject="ComponentOverrideService";
	property name="attributeService" inject="AttributeService";
	property name="catalogUsageService" inject="CatalogUsageService";

	public com.apirone.core.model.bean.Product function get( required String productId ){
		return build( arguments.productId );
	}

	// La stessa linea + modello + finitura può esistere in più categorie ( es. ACCESSORI
	// RECEPTION e RICAMBI ): senza categoria i prodotti trovati possono essere più di uno
	// e il risultato è null.
	public com.apirone.core.model.bean.Product function getByParams(
		required String lineId,
		required String finishId,
		required String modelId,
		Numeric categoryId
	){
		var record = getDao().find( argumentCollection = arguments );

		if ( record.recordcount == 1 ) {
			return get( record.product_id );
		}

		return NullValue();
	}

	public function readIds(){
		return getDao().readIds();
	}

	public Array function list(){
		// TODO: check formatter
		arguments[ "limit" ] = -1;

		return search( argumentCollection = arguments ).getData();
	}

	public Boolean function codeExists( required String code, String excludedId = "" ){
		var record = getDao().readByCode( arguments.code );

		if (
			record.recordCount
			&& record.product_id != arguments.excludedId
		) {
			return record.code == arguments.code;
		}

		return false;
	}

	public com.apirone.core.model.bean.Result function search(
		String str,
		String lineId,
		String catalogBundleId,
		Array excludedCategoryIds = [],
		required Numeric limit    = 15,
		required Numeric offset   = 0,
		required Array orderBy    = [ { field = "product.id" } ]
	){
		var rows   = [];
		var result = super.getResult();

		arguments[ "orderby" ] = super.createOrderBy( arguments[ "orderby" ] );

		// Primo passaggio: il find() restituisce solo gli ID (più il totale per paginazione)
		var records = getDao().find( argumentCollection = arguments );

		// Raccoglie tutti gli ID e carica i record in blocco con una sola query
		var ids = [];
		records.each( function( r ){
			ids.append( r.product_id );
		} );

		// Precarica tutte le FK entity in blocco e costruisce i bean senza chiamate DB individuali
		if ( ArrayLen( ids ) ) {
			var allRecords = getDao().readByIds( ids );
			var beanMap = buildMany( allRecords );
		} else {
			var beanMap = {};
		}

		// Ricostruisce le righe nell'ordine del find() originale
		records.each( function( record ){
			rows.add( beanMap[ record.product_id ] );
		} );

		result.setData( rows );
		result.setCount( Val( records.recordcount ) );
		result.setTotal( Val( records.total ) );

		return result;
	}

	public com.apirone.core.model.bean.Outcome function delete( required String productId ){
		var outcome = super.bean( "Outcome" );

		var obj = get( arguments.productId );

		outcome.setData( { productId = arguments.productId } );

		transaction {
			try {
				getFileService().purgeDeletedByProductId( arguments.productId );

				var catalogBundleId = getDao().delete( arguments.productId );
				if ( Len( catalogBundleId ) ) {
					getCatalogBundleService().deleteIfOrphaned( catalogBundleId );
				}
			} catch ( any error ) {
				outcome.setError( error );
				outcome.setStatus( "ERROR" );
				outcome.setType( "ApirOne.CannotDeleteProduct" );
				outcome.setMessage( friendlyDeleteErrorMessage( error, arguments.productId ) );
			}
		}

		return outcome;
	}

	/**
	 * Eliminazione secondo l'uso nei preventivi ( CatalogUsageService.remove ):
	 * { result = IN_USE | DEACTIVATED | DELETED | ERROR, quotations, closed, message }.
	 */
	public Struct function remove( required String productId ){
		var productId = arguments.productId;
		var state     = {};

		var removed = getCatalogUsageService().remove(
			{ productIds = [ productId ] },
			function(){
				state.outcome = this.delete( productId );
			}
		);

		if ( state.keyExists( "outcome" ) && state.outcome.getStatus() == "ERROR" ) {
			removed.result  = "ERROR";
			removed.message = state.outcome.getMessage();
		}

		return removed;
	}

	/**
	 * remove() su più prodotti: { quotations ( preventivi in corso che usano quelli
	 * non eliminati ), deactivated ( quanti eliminati logicamente ), errors }.
	 */
	public Struct function removeMany( required Array productIds ){
		var summary = { "quotations" = [], "deactivated" = 0, "errors" = [] };
		var seen    = {};

		for ( var productId in arguments.productIds ) {
			var removed = remove( productId );

			if ( removed.result == "IN_USE" ) {
				for ( var quotation in removed.quotations ) {
					if ( !seen.keyExists( quotation.id ) ) {
						seen[ quotation.id ] = true;
						summary.quotations.append( quotation );
					}
				}
			} else if ( removed.result == "DEACTIVATED" ) {
				summary.deactivated++;
			} else if ( removed.result == "ERROR" ) {
				summary.errors.append( { "message" = removed.message } );
			}
		}

		return summary;
	}

	/**
	 * Prodotto della matrice linea / modello / finitura, anche se eliminato
	 * logicamente: riaggiungendolo dalla matrice torna a catalogo invece di
	 * crearne un doppione.
	 */
	public any function getByParamsIncludingDeleted(
		required String lineId,
		required String finishId,
		required String modelId,
		required Numeric categoryId
	){
		var criteria = Duplicate( arguments );
		criteria.includeDeleted = true;
		criteria.limit          = -1;

		var records = getDao().find( argumentCollection = criteria );

		if ( records.recordcount ) {
			return get( records.product_id[ 1 ] );
		}

		return NullValue();
	}

	public void function restore( required String productId ){
		getCatalogUsageService().restoreProduct( arguments.productId );
	}

	public com.apirone.core.model.bean.Outcome function deleteByParams(
		required String lineId,
		required String finishId,
		required String modelId,
		Numeric categoryId
	){
		var outcome = super.bean( "Outcome" );

		var obj = getByParams( argumentCollection = arguments );

		var productId = obj.getId()

		outcome.setData( { productId = productId } );

		transaction {
			try {
				getFileService().purgeDeletedByProductId( productId );

				var catalogBundleId = getDao().delete( obj.getId() );
				if ( Len( catalogBundleId ) ) {
					getCatalogBundleService().deleteIfOrphaned( catalogBundleId );
				}
			} catch ( any error ) {
				outcome.setError( error );
				outcome.setStatus( "ERROR" );
				outcome.setType( "ApirOne.error.CannotDeleteProduct" );
				outcome.setMessage( friendlyDeleteErrorMessage( error, productId ) );
			}
		}


		return outcome;
	}

	/**
	 * Traduce l'errore di cancellazione prodotto in un messaggio utile per l'utente.
	 * Caso noto: FK su files (immagini/allegati del prodotto) - deleted_at su files è un
	 * soft delete, la riga resta fisicamente e blocca comunque la cancellazione del
	 * prodotto in FK, quindi il messaggio guida a rimuovere prima i file collegati.
	 * Per qualsiasi altro errore, mostra comunque il messaggio originale: meglio un errore
	 * tecnico visibile che un falso successo silenzioso.
	 */
	private String function friendlyDeleteErrorMessage( required any error, required String productId ){
		if ( FindNoCase( "files_product_id_fk", arguments.error.message ) ) {
			return "Impossibile eliminare: ci sono ancora file/immagini collegati a questo prodotto. Eliminali prima di rimuovere la combinazione.";
		}

		return "Cannot delete product [#arguments.productId#]: #arguments.error.message#";
	}

	public com.apirone.core.model.bean.Outcome function deleteAllByParams(
		required String lineId,
		required String categoryId
	){
		var outcome = super.bean( "Outcome" );

		outcome.setData( arguments );

		transaction {
			try {
				getDao().deleteAllByParams( lineId = arguments.lineId, categoryId = arguments.categoryId );
				getCatalogBundleService().deleteOrphanedByParams( lineId = arguments.lineId, categoryId = arguments.categoryId );
			} catch ( any error ) {
				outcome.setError( error );
				outcome.setStatus( "ERROR" );
				outcome.setType( "ApirOne.error.CannotDeleteProduct" );
				outcome.setMessage( friendlyDeleteErrorMessage( error, "#arguments.lineId#/#arguments.categoryId#" ) );
			}
		}

		return outcome;
	}

	public String function create( required com.apirone.core.model.bean.Product product ){
		var product = this.handleCatalogBundle( arguments.product );

		var newId = getDao().insert( product );

		if ( !IsNull( product.getTexts() ) AND product.getTexts().len() ) {
			transaction {
				for ( var text in product.getTexts() ) {
					var entity = super.bean( "Entity" );
					entity.setKey( "product.id" );
					entity.setValue( newId );
					text.setEntity( entity );
				}
				getTextService().bulkCreate( product.getTexts() );
			}
		}

		return newId;
	}

	public Struct function cloneTree( required String fromProductId, required String toProductId ){
		if ( fromProductId == toProductId ) {
			Throw(
				type    = "ApirOne.errors.productService.InvalidArgument",
				message = "fromProductId and toProductId cannot be the same"
			);
		}

		super.logEvent(
			event   = "product.CLONED_TREE",
			message = "Start clone tree of product [#arguments.fromProductId#] to [#arguments.toProductId#]",
			payload = {
				"fromProductId" = arguments.fromProductId,
				"toProductId"   = arguments.toProductId
			}
		);

		var componentService         = getComponentService();
		var componentOverrideService = getComponentOverrideService();

		function createProductItem(
			required String productId,
			required com.apirone.core.model.bean.ProductItem productItem,
			required Numeric level = 1
		){
			arguments.productItem.setProductId( arguments.productId );

			var newProductItemId = getProductItemService().create( arguments.productItem );

			var components = componentService.list(
				productItemId                  = arguments.productItem.getId(),
				includeBaseAttributeComponents = true
			);

			// TODO: move this logic tu ComponentService
			// We have in ComponentAjaxController too
			for ( var thisComponent in components ) {
				getLogger().debug( "Override [#thisComponent.getId()#] typeId [#thisComponent.getTypeId()#]" );

				// **
				// override components
				// **

				if ( thisComponent.getTypeId() == "base" ) {
					var overrideBean = super.bean( "ComponentOverride" );

					overrideBean.setId( "" );
					overrideBean.setDeleted( thisComponent.getOverride().getDeleted() );
					overrideBean.setQuantity( thisComponent.getOverride().getQuantity() );
					overrideBean.setComponentId( thisComponent.getId() );
					overrideBean.setProductItemId( newProductItemId );

					componentOverrideService.create( overrideBean );
				} else {
					var newComponent = Duplicate( thisComponent );

					newComponent.setId( "" );
					newComponent.getProductItem().setId( newProductItemId );

					componentService.create( newComponent );
				}
			}

			if ( arguments.productItem.getChildren().len() ) {
				for ( var child in arguments.productItem.getChildren() ) {
					child.getOrigin().setId( newProductItemId );

					createProductItem(
						productItem = child,
						level       = arguments.level + 1,
						productId   = arguments.productId
					);
				}
			}
		}

		transaction {
			getProductItemService().delete( productId = arguments.toProductId );

			var productItems = getProductItemService().getTree( productId = arguments.fromProductId );

			for ( var productItem in productItems ) {
				createProductItem(
					productItem = productItem,
					level       = 1,
					productId   = arguments.toProductId
				);
			}
		}

		super.logEvent(
			event   = "product.CLONED_TREE",
			message = "End clone tree of product [#arguments.fromProductId#] to [#arguments.toProductId#]",
			payload = {
				"fromProductId" = arguments.fromProductId,
				"toProductId"   = arguments.toProductId
			}
		);

		return {
			"status"  = "success",
			"payload" = {
				"fromProductId" = arguments.fromProductId,
				"toProductId"   = arguments.toProductId
			}
		};
	}

	public String function updateDetail( required com.apirone.core.model.bean.Product product ){

		getDao().updateDetail( arguments.product );

		return product.getId();
	}

	public String function update( required com.apirone.core.model.bean.Product product ){
		var product = this.handleCatalogBundle( arguments.product );

		getDao().update( arguments.product );

		var id = product.getId();

		if ( !IsNull( arguments.product.getTexts() ) ) {
			for ( var text in arguments.product.getTexts() ) {
				var entity = super.bean( "Entity" )

				entity.setKey( "product.id" );
				entity.setValue( id );

				text.setEntity( entity );

				if ( Len( text.getId() ) ) {
					getTextService().update( text );
				} else {
					getTextService().create( text );
				}
			}
		}

		return product.getId();
	}


	/*
			private method
	*/

	// normalize data for catalogBundle
	private com.apirone.core.model.bean.Product function handleCatalogBundle(
		required com.apirone.core.model.bean.Product product
	){
		if ( IsInstanceOf( product, "com.apirone.core.model.bean.ProductComplex" ) ) {
			var bundle = super.bean( "CatalogBundle" );
			bundle.setLine( product.getLine() );
			bundle.setModel( product.getModel() );
			bundle.setCategory( product.getCategory() );

			var catalogBundle = getCatalogBundleService().getOrCreate( bundle );
			product.setCatalogBundle( catalogBundle );
		}

		return product;
	}

	/**
	 * Recupera in batch più Product dato un array di ID.
	 * Restituisce uno Struct chiave = productId (raw varchar da DB), valore = bean Product completo.
	 * Precarica tutte le FK entity (Category, Line, Attribute, Finish, CatalogBundle)
	 * e le entity 1:N (Text, Price, File) in blocco per evitare il problema N+1.
	 *
	 * @ids Array di productId
	 * @return Struct mappato per productId (raw) -> Product
	 */
	public Struct function getMany( required Array ids ){
		var records = getDao().readByIds( ids = arguments.ids );

		return buildMany( records );
	}

	/**
	 * Costruisce in batch uno Struct mappato per product_id -> Product.
	 * precarica tutte le FK entity (Category, Line, Attribute, Finish, CatalogBundle)
	 * e le entity 1:N (Text, Price, File) in blocco per evitare il problema N+1.
	 *
	 * @records Risultato della query readByIds() con tutte le righe da elaborare
	 * @return Struct mappato per product_id -> Product
	 */
	private Struct function buildMany( required Query records ){
		var map = {};

		// --- Raccoglie tutti gli ID delle FK dai record dei prodotti ---
		var categoryIds = [];
		var finishIds   = [];
		var bundleIds   = [];
		var productIds  = [];
		var allLineIds  = [];
		var allAttrIds  = [];

		for ( var r in arguments.records ) {
			productIds.append( r.product_id );

			if ( !IsNull( r.product_category_id ) ) {
				categoryIds.append( r.product_category_id );
			}

			if ( !IsNull( r.finish_id ) ) {
				finishIds.append( r.finish_id );
			}

			if ( !IsNull( r.catalog_bundle_id ) ) {
				bundleIds.append( r.catalog_bundle_id );
			}

			// Linee dal JSONB lines
			var lines = IsNull( r.lines ) ? [] : DeserializeJSON( r.lines );
			if ( !IsNull( lines ) && ArrayLen( lines ) ) {
				for ( var lid in lines ) {
					allLineIds.append( lid );
				}
			}

			// Attributi dal JSONB attributes_important
			var attrs = IsNull( r.attributes_important ) ? [] : DeserializeJSON( r.attributes_important );
			if ( !IsNull( attrs ) && ArrayLen( attrs ) ) {
				for ( var aid in attrs ) {
					allAttrIds.append( aid );
				}
			}
		}

		// --- Fase 2: legge i CatalogBundle e raccoglie i loro FK ---
		var bundleLineIds  = [];
		var bundleModelIds = [];
		var bundleCatIds   = [];
		var bundleRecords  = QueryNew( "" );

		if ( ArrayLen( bundleIds ) ) {
			bundleRecords = getCatalogBundleService().getDao().readByIds( bundleIds );

			for ( var br in bundleRecords ) {
				if ( !IsNull( br.line_id ) ) {
					bundleLineIds.append( br.line_id );
				}
				if ( !IsNull( br.model_id ) ) {
					bundleModelIds.append( br.model_id );
				}
				if ( !IsNull( br.product_category_id ) ) {
					bundleCatIds.append( br.product_category_id );
				}
			}
		}

		// --- Fase 3: unisce gli ID delle FK in unica lista per tipo ---
		// Le linee dei bundle si aggiungono alle linee già raccolte dai prodotti
		for ( var lid in bundleLineIds ) {
			allLineIds.append( lid );
		}
		// Le categorie dei bundle si aggiungono alle categorie già raccolte
		for ( var cid in bundleCatIds ) {
			categoryIds.append( cid );
		}

		// --- Fase 4: precarica tutte le entity con una query batch ciascuna ---
		var categoryMap = {};
		if ( ArrayLen( categoryIds ) ) {
			categoryMap = getProductCategoryService().getMany( categoryIds );
		}

		var finishMap = {};
		if ( ArrayLen( finishIds ) ) {
			finishMap = getFinishService().getMany( finishIds );
		}

		var lineMap = {};
		if ( ArrayLen( allLineIds ) ) {
			lineMap = getLineService().getMany( allLineIds );
		}

		var attributeMap = {};
		if ( ArrayLen( allAttrIds ) ) {
			attributeMap = getAttributeService().getMany( allAttrIds );
		}

		var modelMap = {};
		if ( ArrayLen( bundleModelIds ) ) {
			modelMap = getModelService().getMany( bundleModelIds );
		}

		// Costruisce i bean CatalogBundle con le mappe pre-caricate
		var bundleMap = {};
		for ( var br in bundleRecords ) {
			var bundle = super.bean( "CatalogBundle" );

			bundle.setId( br.catalog_bundle_id );
			bundle.setName( br.catalog_bundle );
			bundle.setCreatedAt( br.created_at );
			bundle.setMarkupValue( br.markup_value );

			if ( !IsNull( br.line_id ) && StructKeyExists( lineMap, br.line_id ) ) {
				bundle.setLine( lineMap[ br.line_id ] );
			}
			if ( !IsNull( br.model_id ) && StructKeyExists( modelMap, br.model_id ) ) {
				bundle.setModel( modelMap[ br.model_id ] );
			}
			if ( !IsNull( br.product_category_id ) && StructKeyExists( categoryMap, br.product_category_id ) ) {
				bundle.setCategory( categoryMap[ br.product_category_id ] );
			}

			bundleMap[ br.catalog_bundle_id ] = bundle;
		}

		// Entity 1:N: carica tutti i testi/prezzi/file in blocco, raggruppati per product_id
		var textMap  = getTextService().listByEntityIds( "product.id", productIds );
		var priceMap = getPriceService().listByProductIds( productIds );
		var fileMap  = getFileService().listByEntityIds( "product.id", productIds );

		// --- Fase 5: costruisce i bean Product usando le mappe pre-caricate ---
		// Cache locale per status: evita lookup ripetuti nello stesso batch
		var statuses = {};

		for ( var r in arguments.records ) {
			if ( IsNull( r.catalog_bundle_id ) ) {
				var bean = super.bean( "ProductBase" );

				// Campi specifici ProductBase
				bean.setCode( r.code );

				if ( !IsNull( r.product_category_id ) && StructKeyExists( categoryMap, r.product_category_id ) ) {
					bean.setCategory( categoryMap[ r.product_category_id ] );
				}

				bean.setPositionCount( r.position_count );

				// Linee dal JSONB: filtra con lineMap pre-caricata
				var lines = IsNull( r.lines ) ? [] : DeserializeJSON( r.lines );
				var lineBeans = [];
				if ( !IsNull( lines ) && ArrayLen( lines ) ) {
					for ( var lid in lines ) {
						if ( StructKeyExists( lineMap, lid ) ) {
							lineBeans.append( lineMap[ lid ] );
						}
					}
				}
				bean.setLines( ArrayLen( lineBeans ) ? lineBeans : [] );
			} else {
				var bean = super.bean( "ProductComplex" );

				// CatalogBundle: imposta il bundle e deriva Line, Model, Category
				if ( StructKeyExists( bundleMap, r.catalog_bundle_id ) ) {
					var bundle = bundleMap[ r.catalog_bundle_id ];
					bean.setCatalogBundle( bundle );
					bean.setLine( bundle.getLine() );
					bean.setModel( bundle.getModel() );
					bean.setCategory( bundle.getCategory() );
				}

				// Finitura (solo ProductComplex)
				if ( !IsNull( r.finish_id ) && StructKeyExists( finishMap, r.finish_id ) ) {
					bean.setFinish( finishMap[ r.finish_id ] );
				}
			}

			// Campi comuni a ProductBase e ProductComplex
			bean.setId( r.product_id.toString() );
			bean.setSerial( r.serial );
			bean.setCreatedAt( r.created_at );
			bean.setSpecial( BooleanFormat( r.special ) ); //TODO: to remove
			bean.setMinQuantity( r.min_quantity );
			bean.setMaxQuantity( r.max_quantity );
			bean.setMarginTop( r.margin_top );
			bean.setMarginLeft( r.margin_left );
			bean.setPlateWidth( r.plate_width );
			bean.setPlateHeight( r.plate_height );

			// Status: cached localmente
			if ( !StructKeyExists( statuses, r.status_id ) ) {
				statuses[ r.status_id ] = getStatusService().get( r.status_id );
			}
			bean.setStatus( statuses[ r.status_id ] );

			// Testi dalla mappa batch
			if ( StructKeyExists( textMap, r.product_id ) ) {
				bean.setTexts( textMap[ r.product_id ] );
			}

			// Attributi importanti dalla mappa batch
			var attrs = IsNull( r.attributes_important ) ? [] : DeserializeJSON( r.attributes_important );
			var attrBeans = [];
			if ( !IsNull( attrs ) && ArrayLen( attrs ) ) {
				for ( var aid in attrs ) {
					if ( StructKeyExists( attributeMap, aid ) ) {
						attrBeans.append( attributeMap[ aid ] );
					}
				}
			}
			bean.setImportantAttributes( ArrayLen( attrBeans ) ? attrBeans : [] );

			// Prezzi dalla mappa batch
			if ( StructKeyExists( priceMap, r.product_id ) ) {
				bean.setPrices( priceMap[ r.product_id ] );
			}

			// Immagini dalla mappa batch
			if ( StructKeyExists( fileMap, r.product_id ) ) {
				var images = fileMap[ r.product_id ];
				if ( Len( images ) ) {
					bean.setImages( images );
				}
			}

			map[ r.product_id ] = bean;
		}

		return map;
	}

	/**
	 * Costruisce un bean Product a partire dall'ID. Delega a buildFromRow() dopo la lettura del record.
	 */
	private com.apirone.core.model.bean.Product function build( required String productId ){
		var record = getDao().read( arguments.productId );

		if ( record.recordCount ) {
			return buildFromRow( record );
		}

		return NullValue();
	}

	/**
	 * Costruisce un bean Product a partire da una riga del query.
	 * Le sub-entity (Category, Status, Texts, Prices, Files, ecc.) sono caricate con chiamate individuali.
	 */
	private com.apirone.core.model.bean.Product function buildFromRow( required any record ){
		// Campi diretti dal record (distingue ProductBase da ProductComplex)
		if ( IsNull( arguments.record.catalog_bundle_id ) ) {
			var bean = super.bean( "ProductBase" );

			bean.setCode( arguments.record.code );
			bean.setCategory( getProductCategoryService().get( arguments.record.product_category_id ) );
			bean.setPositionCount( arguments.record.position_count );
			bean.setLines( super.getLinesBeanByIds( arguments.record.lines ) );
		} else {
			var bean = super.bean( "ProductComplex" );

			bean.setCatalogBundle( getCatalogBundleService().get( arguments.record.catalog_bundle_id ) );

			bean.setLine( bean.getCatalogBundle().getLine() );
			bean.setModel( bean.getCatalogBundle().getModel() );
			bean.setCategory( bean.getCatalogBundle().getCategory() );

			// finish_id è nullable: prodotto censito senza finitura
				if ( !IsNull( record.finish_id ) && Len( record.finish_id ) ) {
					bean.setFinish( getFinishService().get( record.finish_id.toString() ) );
				}
		}

		// Campi comuni
		bean.setId( arguments.record.product_id.toString() );
		bean.setSerial( arguments.record.serial );
		bean.setCreatedAt( arguments.record.created_at );
		bean.setSpecial( BooleanFormat( arguments.record.special ) ); //TODO: to remove
		bean.setMinQuantity( arguments.record.min_quantity );
		bean.setMaxQuantity( arguments.record.max_quantity );
		bean.setMarginTop( arguments.record.margin_top );
		bean.setMarginLeft( arguments.record.margin_left );
		bean.setPlateWidth( arguments.record.plate_width );
		bean.setPlateHeight( arguments.record.plate_height );

		// Entity collegate (caricate singolarmente)
		bean.setStatus( getStatusService().get( arguments.record.status_id ) );
		bean.setTexts( getTextService().list( productId = arguments.record.product_id ) );
		bean.setImportantAttributes( super.getAttributesBeanByIds( arguments.record.attributes_important ) );
		bean.setPrices( getPriceService().list( productId = arguments.record.product_id ) );

		var images = getFileService().list( productId = arguments.record.product_id );
		if ( Len( images ) ) {
			bean.setImages( images )
		}

		return bean;
	}

}
