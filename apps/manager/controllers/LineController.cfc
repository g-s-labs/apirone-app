component extends="com.apirone.core.controller.AbsController" {

	function list( event, rc, prc ){
		prc.title = "Linee";

		prc.statuses       = super.fire( "status.list", [ "LINE" ] );
		prc.thicknesses    = super.fire( "lookup.list", [ "thickness" ] );
		prc.lineCategories = super.fire( "ProductCategory.list" );

		prc.jsFiles.add( "app-line" );

		prc.page[ "statuses" ]    = prc.statuses;
		prc.page[ "thicknesses" ] = prc.thicknesses;

		prc.page[ "categories" ] = super.getCategoriesAsJSON();

		event.setView( "line/list" );
	}

	function listByCategoryId( event, rc, prc ){
		if ( !rc.keyExists( "categoryId" ) ) {
			// move to most used category: plates
			cflocation( url = "/manager/lines/categories/22", addToken = "false" );
			abort;
		}

		prc.category   = super.fire( "ProductCategory.get", [ rc.categoryId ] );
		prc.categories = super.fire( "ProductCategory.list", { modeId = "COM" } );
		prc.title      = "Linee per < #prc.category.getName()# >";
		prc.statuses   = super.fire( "status.list", [ "LINE" ] );

		prc.jsFiles.add( "app-line-category" );

		prc.page[ "statuses" ]   = prc.statuses;
		prc.page[ "categoryId" ] = prc.category.getId();

		event.setView( "line/list-category" );
	}


	function attributes( event, rc, prc ){
		var products = super.fire( "product.list", { lineId = rc.id, categoryId = rc.categoryId } );

		var destination = "/manager/lines/#rc.id#/products";

		if ( Len( cgi.http_referer ) ) {
			destination = cgi.http_referer;
		}

		if ( products.len() ) {
			cflocation( url = "/manager/products/#products[ 1 ].getId()#", addToken = false );
		} else {
			setMessage( type = "warning", message = "Carica almeno un prodotto" );

			relocate(
				uri               = destination,
				postProcessExempt = false,
				addToken          = false
			);
		}
	}

	function products( event, rc, prc ){
		var memy = super.getMementify();

		prc.existingProducts = [];

		// prc.line     = memy.convert( super.fire( "line.get", [ rc.id ] ) );
		prc.line     = super.fire( "line.get", [ rc.id ] );
		prc.category = super.fire( "productCategory.get", [ rc.categoryId ] );

		prc.page[ "line" ] = memy.convert( prc.line );

		prc.title    = "Categoria #prc.category.getName()# linea #prc.line.getName()#";
		prc.subtitle = "Prodotti disponibili";

		// Unione di due liste, non solo il filtro per linea+categoria: la colonna deve
		// comparire sia per i modelli "candidati" per questa categoria (tag globale
		// models.categories, es. taggati ma mai ancora abbinati a QUESTA linea - serve per
		// poter aggiungere per la prima volta un modello mai usato qui, via il "+" della
		// griglia) sia per i modelli già effettivamente in catalog_bundles per questa
		// esatta linea+categoria (altrimenti un modello con products/catalog_bundle reali
		// ma tag models.categories non aggiornato - es. mai taggato o taggato altrove -
		// sparirebbe dalla griglia pur avendo prodotti attivi).
		var modelsByCategoryTag = super.fire( "model.list", { categoryId = prc.category.getId() } );
		var modelsByCatalogBundle = super.fire(
			"model.list",
			{
				catalogBundleLineId     = prc.line.getId(),
				catalogBundleCategoryId = prc.category.getId()
			}
		);

		var models = [];
		var seenModelIds = {};
		for ( var model in modelsByCategoryTag ) {
			seenModelIds[ model.getId() ] = true;
			models.append( model );
		}
		for ( var model in modelsByCatalogBundle ) {
			if ( !StructKeyExists( seenModelIds, model.getId() ) ) {
				models.append( model );
			}
		}

		prc.models = models;

		prc.finishes = super.fire( "finish.list", { categoryId = prc.category.getId() } );

		for ( var model in models ) {
			var existingModelConfig = super.fire(
				"modelConfig.list",
				{
					modelId           = model.getId(),
					productCategoryId = Int( rc.categoryId ),
					lineId            = rc.id
				}
			);

			model.modelConfig = NullValue();

			if ( existingModelConfig.len() ) {
				model.modelConfig = existingModelConfig[ 1 ];
			}
		}

		// solo i prodotti di questa categoria: la stessa linea + modello + finitura può
		// esistere anche in altre categorie ( es. RICAMBI )
		var productsList = super.fire( "product.list", { lineId = rc.id, categoryId = Int( rc.categoryId ) } );

		for ( var product in productsList ) {
			prc.existingProducts.add( "#product.getModel().getId()#__#product.getFinish().getId()#" );
		}

		prc.jsFiles.add( "app-line" );

		event.setView( "line/products" );
	}

}
