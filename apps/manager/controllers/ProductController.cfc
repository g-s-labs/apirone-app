component extends="com.apirone.core.controller.AbsController" {

	function list( event, rc, prc ){
		// var params[ "categoryModeId" ] = "COM";

		var memy = super.getMementify();

		prc.page['categories'] = super.fire( "productCategory.list", { modeId = "COM" } );
		prc.page['lines']      = super.fire( "line.list" );
		prc.page['models']     = super.fire( "model.list" );
		prc.statuses   = super.fire( "status.list", [ "line" ] );
		prc.finishes   = super.fire( "finish.list" );

		prc.page['statuses'] = prc.statuses;
		// memento: il nome delle finiture vive nei texts, il bean grezzo non lo espone
		prc.page['finishes'] = memy.convertList( prc.finishes );

		prc.title = "Prodotti complessi";

		prc.jsFiles.add( "app-product-list" );
		prc.jsFiles.add( "app-price" );

		prc.page[ "methods" ] = memy.convertList( super.fire( "lookup.list", { "entity" = "priceMethod" } ) );

		event.setView( "product/list" );
	}

	function detail( event, rc, prc ){
		var product = super.fire( "product.get", [ rc.id ] );
		var memy    = super.getMementify();

		if ( IsNull( product ) ) {
			// TODO: better than this
			event.renderData( data = "<h3>Articolo non trovato</h3>" );
			return;
		}

		prc.product = product;


		// frutti
		if (
			product
				.getCategory()
				.getMode()
				.getId() == "BAS"
		) {
			prc.title    = product.getName();
			prc.subtitle = product.getCategory().getName();
			prc.textLink = "Componenti per #product.getCategory().getName()# / #product.getName()#";
		} else {
			prc.model    = product.getModel();
			prc.finish   = product.getFinish();
			prc.line     = product.getLine();
			prc.category = product.getCategory();

			prc.title    = "Modello #product.getModel().getName()# (#product.getModel().getCode()#), finitura #product.getFinish().getName()#";
			prc.subtitle = "Categoria #product.getCategory().getName()#, linea #product.getLine().getName()#";
			prc.textLink = "Componenti per #product.getLine().getName()# / #product.getModel().getCode()# / #product.getFinish().getName()#";

			prc.statusList = super.fire( "status.list", [ "line" ] );
			prc.models     = super.fire(
				"model.list",
				{
					catalogBundleLineId     = prc.line.getId(),
					catalogBundleCategoryId = prc.category.getId()
				}
			);
			prc.finishes = super.fire( "finish.list", { lineId = prc.line.getId() } );

			prc.page[ "lineId" ] = prc.line.getId();

			// solo la categoria del prodotto: la stessa linea + modello + finitura può esistere
			// anche in altre categorie e il menu sceglie il prodotto per modello + finitura
			var products = super.fire( "product.list", { lineId = prc.line.getId(), categoryId = prc.category.getId() } );

			prc.page[ "products" ] = [];

			// We need speed...
			products.each(
				function( product ){
					prc.page[ "products" ].add( memy.convert( product, "menu" ) )
				},
				true,
				4
			);
		}


		var fontSizeOptions   = [];
		if (
			product
				.getCategory()
				.getType()
				.getId() == "SEG"
		) {
			/*
				selected fonts
			*/
			var signageConfigs = super.fire( "signageConfig.list", { "catalogBundleId" = product.getCatalogBundle().getId() } );
			fontSizeOptions.add( {
				"id" = "null",
				"name" = "Seleziona font/altezza",
				"height" = null,
				// rowCount e lineHeights servono al frontend per popolare gli input
				// delle interlinee: rowCount indica quante righe mostrare,
				// lineHeights contiene i valori configurati per ciascuna riga.
				"rowCount" = 0
			} );
			for ( var signageConfig in signageConfigs ) {
				var obj = memy.convert( signageConfig, "list" );

				for ( var signageConfigItem in signageConfig.getItems() ) {

					var name = !isNull(signageConfig.getFont()) ? signageConfig.getFont().getName() : ''
					if (isNull(signageConfigItem.getSize()) || isNull(signageConfigItem.getSize().getName())) {
						continue;
					}

				// rowCount serve al frontend per sapere quante righe di input mostrare.
				// lineHeights è l'array posizionale dei valori configurati (es. [15, null, 20]).
				fontSizeOptions.add( {
					"id"     = signageConfigItem.getId(),
					"name"   = name & " - " & signageConfigItem.getSize().getName() & "mm",
					"height" = signageConfigItem.getSize().getName(),
					"rowCount" = signageConfigItem.getRowCount(),
					"lineHeights" = signageConfigItem.getLineHeights()
				} );
				}

			}
		}

		prc.page[ "fontSizeOptions" ]     = fontSizeOptions;
		prc.page[ "productId" ]           = product.getId();
		prc.page[ "attributeStatusList" ] = memy.convertList( super.fire( "status.list", [ "attribute" ] ) );
		prc.page[ "methods" ]             = memy.convertList( super.fire( "lookup.list", { "entity" = "priceMethod" } ) );
		prc.page[ "statuses" ]            = memy.convertList( super.fire( "status.list", [ "PRODUCT" ] ) );
		// prc.page[ "attributes" ]          = memy.convertList( super.fire( "attribute.list" ), "suggest" );
		prc.page[ "product" ]             = memy.convert( prc.product, "detail" );

		// Griglia incisioni: solo per i frutti con attributi radice dell'incisione (IS, II, IL).
		// I marker veri li carica il tab via ajax; qui bastano attributi, immagine e moduli.
		var engravingService    = super.service( "ProductEngravingMarker" );
		var engravingAttributes = engravingService.listEngravingAttributes( productId = product.getId(), langId = ( request.keyExists( "lang" ) ? request.lang.getId() : "IT" ) );
		var engravingImage      = engravingService.findBaseImage( productId = product.getId(), positionCount = Val( product.getPositionCount() ) );
		prc.page[ "engraving" ] = {
			"attributes"    = engravingAttributes,
			"rootCodes"     = engravingService.rootAttributeCodes(),
			"positionCount" = Val( product.getPositionCount() ),
			"image"         = engravingImage,
			"canEdit"       = ( !IsNull( session.user ) && !IsNull( session.user.getRole() ) && ArrayContains( [ "ADM", "TCD" ], session.user.getRole().getId() ) )
		};
		if ( ArrayLen( engravingAttributes ) ) {
			prc.jsFiles.add( "app-product-engravings" );
		}

		prc.page[ "categories" ] = super.getCategoriesAsJSON();

		prc.jsFiles.add( "app-file" );
		prc.jsFiles.add( "app-price" );
		prc.jsFiles.add( "app-component-modal" );
		prc.jsFiles.add( "app-attribute-detail" );
		prc.jsFiles.add( "app-product-items" );

		event.setView( "product/detail" );
	}

	function items( event, rc, prc ){
		var data   = [];
		var result = super.getResult();

		var items = super.fire( "ProductItemProduct.calculate", { productId = rc.id } );

		event.setView( "product/items" );
	}


	function combinations( event, rc, prc ){
		param rc.id = "";

		var product  = super.service( "Product" ).get( rc.id );
		prc.statuses = super.fire( "status.list", [ "PRODUCT" ] );

		// prc.title = "Combinazioni #product.getModel().getCode()#, finitura #product.getFinish().getName()#";
		// TODO: migliorare titolo per base/complesso
		prc.title    = "Combinazioni";
		prc.subtitle = "Linea -";

		prc.jsFiles.add( "app-file" );
		prc.jsFiles.add( "app-product-combinations" );

		prc.page[ "statuses" ]  = prc.statuses;
		prc.page[ "productId" ] = product.getId();

		event.setView( "product/combinations" );
	}

	function print( event, rc, prc ){
		param rc.report = "bill-of-material";

		prc.title = "Distinte basi";

		var memy = super.getMementify();

		var searchArgs = {};
		var filters    = {};

		if ( Len( rc.lineId ) ) {
			var line = super.service( "line" ).get( rc.lineId );

			searchArgs.lineId  = rc.lineId;
			filters[ "Linea" ] = line.getName();
		}

		if ( Len( rc.categoryId ) ) {
			var category = super.service( "productCategory" ).get( rc.categoryId )

			searchArgs.categoryId  = rc.categoryId;
			filters[ "Categoria" ] = category.getName();
		}

		if ( Len( rc.modelId ) ) {
			var model = super.service( "model" ).get( rc.modelId )

			searchArgs.modelId   = rc.modelId;
			filters[ "Modello" ] = model.getName();
		}

		if ( Len( rc.statusId ) ) {
			var status = super.service( "status" ).get( rc.statusId )

			searchArgs.statusId = rc.statusId;
			filters[ "Status" ] = status.getName();
		}


		var products = super.fire( "product.list", searchArgs );

		var data = {};

		data.products = [];

		var blundlesCreated = {};

		for ( var product in products ) {
			var row = {}

			row.line   = memy.convert( product.getLine() );
			row.model  = memy.convert( product.getModel() );
			row.finish = memy.convert( product.getFinish() );

			row.bundle = {};

			if ( !blundlesCreated.keyExists( "#lineId#__#modelId#" ) ) {
				row[ "bundle" ][ "#lineId#__#modelId#" ] = memy.convertList(
					service( "component" ).list( lineId = lineId, modelId = modelId )
				);

				blundlesCreated[ "#lineId#__#modelId#" ] = true;
			}

			var components = service( "component" ).list( productId = product.getId() );

			row[ "components" ] = memy.convertList( components, "list" );

			row[ "title" ] = "#product.getCategory().getName()# - #product.getLine().getName()# - #product.getModel().getName()# (#product.getModel().getCode()#) - #product.getFinish().getName()#"

			var productItems = service( "ProductItem" ).getFlatTree(
				productId            = product.getId(),
				includeMissingValues = false
			);

			var items = [];

			for ( var productItem in productItems ) {
				var item = {};

				item = memy.convert( productItem, "list" );

				var itemComponents = service( "component" ).list(
					productItemId                  = productItem.getId(),
					includeBaseAttributeComponents = true
				);

				item[ "components" ] = memy.convertList( itemComponents, "list" );

				items.add( item )
			}

			row[ "productItems" ] = items;

			data.products.add( row );
		}

		var params = {
			title   = "Distinte basi",
			filters = filters,
			data    = data,
			pdfArgs = {
				bookmark          = true,
				backgroundVisible = true,
				orientation       = "landscape",
				pageType          = "A4",
				overwrite         = true,
				fontEmbed         = true,
				saveAsName        = "#rc.report#_#DateTimeFormat( Now(), "yyyyMMdd-HHnnss" )#.pdf"
			}
		}

		event.renderData( data = view( view = "report/template/#rc.report#", args = params ), type = "PDF" );
	}


	/*
		private methods
	*/

	private Array function convertTree( required Array items ){
		var result = [];

		for ( thisItem in items ) {
			var row = super.getDataMapper().convert( thisItem, "ProductItemTree", true );

			if ( !IsNull( thisItem?.getChildren() ) ) {
				row[ "children" ] = convertTree( items = thisItem.getChildren() );
			}

			ArrayAppend( result, row );
		}

		return result;
	}

}
