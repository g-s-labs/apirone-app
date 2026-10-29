component extends="com.apirone.core.controller.AbsController" {

	function get( event, rc, prc ){
		param rc.id        = 0; // signageConfigItemId, at least this
		param rc.productId = "";

		var memy = super.getMementify();

		var item    = super.service( "SignageConfigItem" ).get( rc.id );
		var signage = super.service( "SignageConfig" ).get( item.getSignageConfigId() );

		var bundleId = signage.getCatalogBundle().getId();

		// se l'id prodotto non è definito, setto il primo prodotto del bundle
		if ( !Len( rc.productId ) ) {
			var bundle   = super.service( "CatalogBundle" ).get( bundleId );
			var products = super.service( "Product" ).list( catalogBundleId = bundle.getId() );
			prc.product  = products[ 1 ];

			var redirectTo = "/manager/signages/rows-config-item/#rc.id#/product/#prc.product.getId()#";

			cflocation( url = redirectTo, addToken = "false" );
		} else {
			prc.product = super.service( "Product" ).get( rc.productId );
		}

		var lineId = prc.product.getLine().getId();

		prc.models       = super.fire( "model.list", { lineId = lineId } );
		prc.finishes     = super.fire( "finish.list", { lineId = lineId } );
		prc.signageItems = super.fire( "signageConfig.list", { "catalogBundleId" = bundleId } );

		prc.signageConfigItemId = item.getId()

		prc.title    = "Configurazione per < #prc.product.getLine().getName()#, #prc.product.getModel().getName()#, #prc.product.getFinish().getName()# / #signage.getFont().getName()#, #item.getSize().getName()#mm >";
		prc.subtitle = "#signage.getCategory().getName()# / ALTEZZA FONT";

		prc.page[ "productId" ]         = prc.product.getId();
		prc.page[ "lineId" ]            = lineId;
		prc.page[ "signageConfigItem" ] = memy.convert( item );

		// solo la categoria del bundle: la stessa linea + modello + finitura può esistere anche in altre categorie
		var products = super.fire( "product.list", { lineId = lineId, categoryId = signage.getCatalogBundle().getCategory().getId() } );

		prc.page[ "products" ] = super.eachParallelAndReorder( products, function( item, index ){
			var row = super.getMementify().convert( item, "menu" );
			return row;
		} );

		prc.jsFiles.add( "app-component-modal" );
		prc.jsFiles.add( "app-signage-config-item" );

		event.setView( "signage/signage-config-item" );
	}

}
