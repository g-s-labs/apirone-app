
component extends="com.apirone.core.controller.AbsController" {

	function list( event, rc, prc ){
		param rc.by = "____";
		var data    = [];
		var item    = {};

		var imageConfigs = getConfiguration().get( "imagesConfig" );

		var file = super.bean( "File" );

		if ( rc.by == "products" ) {
			var params = { productId = rc.id }
			var config = imageConfigs[ "product" ];
		}

		if ( rc.by == "product-items" ) {
			var params = { productItemId = rc.id }
			var config = imageConfigs[ "productItem" ];
		}

		if ( rc.by == "combinations" ) {
			var params = { combinationId = rc.id }
			var config = imageConfigs[ "combination" ];
		}

		if ( rc.by == "attributes-values" ) {
			var params = { attributeValueId = rc.id }
			var config = imageConfigs[ "attributeValue" ];
		}

		if ( rc.by == "quotation-items" ) {
			var params = { quotationItemId = rc.id }
			var config = imageConfigs[ "quotationItem" ];
		}

		if ( rc.by == "quotation-zones" ) {
			var params = { quotationZoneId = rc.id }
			var config = imageConfigs[ "quotationZone" ];
		}

		for ( var typeId in config.types ) {
			params.put( "typeId", typeId );

			var images = super.fire( "file.list", params );
			var json = {};

			if ( images.len() ) {
				// esiste l'immagine la servo
				var image = images[ 1 ];

				json = super.getMementify().convert( image, "list" );
				json[ "complete" ] = true;

			} else {
				// se non esiste, servo un'immagine vuota
				var type = super.fire( "fileType.get", [ typeId ] );

				json[ "id" ]        = "";
				json[ "uri" ]       = "";
				json[ "name" ]      = "";
				json[ "shortId" ]   = "";
				json[ "directory" ] = "";
				json[ "type" ]      = super.getMementify().convert( type );
				json[ "complete" ]  = false;
			}

			data.add( json );
		}

		event.setValue( "result", data );
	}

	function upload( event, rc, prc ){
		var tmpDir = getTempDir();
		var entity = super.bean( "Entity" );

		if ( rc.by == "product-items" ) {
			entity.setKey( "productItem.id" );
			var kindId = "productItem";
		}

		if ( rc.by == "products" ) {
			entity.setKey( "product.id" );
			var kindId = "product";
		}

		if ( rc.by == "combinations" ) {
			entity.setKey( "combination.id" );
			var kindId = "combination";
		}

		if ( rc.by == "attributes-values" ) {
			entity.setKey( "attributeValue.id" );
			var kindId = "attributeValue";
		}

		if ( rc.by == "quotation-items" ) {
			//cerco la quotationItem. se la trovo, imposto customImage a true. Questa cosa è resa necessaria perchè il componente FE app-file, non sa niente del contesto dove viene usato e
			//quando carichi un'immagine ricarica. Siccome noi, potremmo non aver ancora flaggato customImage quando salviamo l'immagine, ci troveremmo ad avere un prodotto con un'immagine custom ma
			//senza il flag.
			var quotationItem = super.fire( 'QuotationItem.get', [ rc.id ] )
			if (!isNull(quotationItem)) {
				quotationItem.setCustomImage(true)
				super.fire( 'QuotationItem.update', [ quotationItem ] )
			}
			entity.setKey( "quotationItem.id" );
			var kindId = "quotationItem";
		}

		if ( rc.by == "quotation-zones" ) {
			entity.setKey( "quotationZone.id" );
			var kindId = "quotationZone";
		}

		entity.setValue( rc.id );

		// solo immagini e pdf: il controllo sul MIME (strict) e quello sull'estensione vanno fatti entrambi
		var allowedExtensions = [ "jpg", "jpeg", "png", "gif", "webp", "pdf" ];

		cffile(
			filefield    = rc.files[ 1 ],
			nameconflict = "MAKEUNIQUE",
			destination  = tmpDir,
			action       = "UPLOAD",
			accept       = "image/jpeg,image/png,image/gif,image/webp,application/pdf",
			strict       = true
		);

		if ( !ArrayFindNoCase( allowedExtensions, cffile.ServerFileExt ) ) {
			FileDelete( "#tmpDir#/#cffile.ServerFile#" );

			var invalidResult = super.getResult();
			invalidResult.setStatus( "ERROR" );
			invalidResult.setData( { "message" = "Tipo di file non ammesso" } );
			event.setValue( "result", invalidResult );
			return;
		}

		if ( Len( rc.fileId ) ) {
			super.fire( "file.delete", { fileId = rc.fileId } );
		}

		var fileId = super.fire(
			"file.create",
			{
				filePath = "#tmpDir#/#cffile.ServerFile#",
				entity   = entity,
				typeId   = rc.typeId,
				kindId   = kindId // product, productItem, combination, attributeValue [signage]
			}
		);

		var result = super.getResult();

		var file = super.fire( "file.get", [ fileId ] );

		var message = super.completeMessage( "file.imageCreated" );

		if (rc.by == "quotation-zones") {
			// se sto aggiornando (rc.is is not null) cerco le eventuali sottozone e per ciascuna, se non presente l'immagine, imposto questa.
			if (!isNull(rc.id)) {
				var quotationZone = super.service( "QuotationZone" ).get( rc.id );
				var children = super.service( "QuotationZone" ).list( "originId" = rc.id );
				for (var child in children) {
					if (IsNull(child.getImage())) {
						var oldImage = file;
						oldImage.setId( null );
						var entity = super.bean( "Entity" );
						entity.setKey( "quotationZone.id" );
						entity.setValue( child.getId() );
						super.service( "File" ).getDao().duplicateQuotationZoneFile(file = oldImage, quotationZoneId = child.getId() );
					}
				}
			}
		}

		result.setData( {
			"message" = message,
			"payload" = { "imageId" = file.getId() }
		} );

		event.setValue( "result", result );
	}


	function delete( event, rc, prc ){
		var result = super.getResult();

		super.fire( "file.delete", { fileId = rc.id } );

		var message = super.completeMessage( "file.imageDeleted" );

		result.setData( { "message" = message, "payload" = { "imageId" = rc.id } } );

		event.setValue( "result", result );
	}

}
