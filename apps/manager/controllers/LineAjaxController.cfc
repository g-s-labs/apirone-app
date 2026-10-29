component extends="com.apirone.core.controller.AbsController" {

	function list( event, rc, prc ){
		var data   = [];
		var result = super.getResult();
		var mm     = super.getMementify();

		var params = super.paramsFromUrl();

		var rows = super.fire( "line.search", params );

		for ( var row in rows.getData() ) {
			var obj = mm.convert( row, "list" );
			data.append( obj );
		}

		result.setTotal( rows.getTotal() );
		result.setCount( rows.getCount() );
		result.setData( data );

		event.setValue( "result", result );
	}

	// TODO: potrei usare solo list
	function listByCategoryId( event, rc, prc ){
		var data   = [];
		var result = super.getResult();
		var memy   = super.getMementify();

		var params = super.paramsFromUrl();

		var params[ "categoryId" ] = rc.categoryId;

		var lines = super.fire( "line.search", params );

		// Carica tutte le ProductCategoryLine per la categoria in batch (1 query invece di N)
		var allCategoryLines = super.service( "ProductCategoryLine" ).listByCategoryId( rc.categoryId );
		var markupByLineId   = {};
		for ( var pcl in allCategoryLines ) {
			markupByLineId[ pcl.getLine().getId() ] = pcl.getMarkup();
		}

		for ( var line in lines.getData() ) {
			var markup = StructKeyExists( markupByLineId, line.getId() ) ? markupByLineId[ line.getId() ] : 0;

			var obj = memy.convert( line, "list" );

			obj[ "markup" ] = markup;

			data.add( obj );
		}

		result.setTotal( lines.getTotal() );
		result.setCount( lines.getCount() );
		result.setData( data );

		event.setValue( "result", result );
	}

	function clone( event, rc, prc ){
		setting requesttimeout=600;

		var data = DeserializeJSON( GetHTTPRequestData().content );

		var params = {
			fromLineId = data.fromLineId,
			toLineId   = data.toLineId,
			categoryId = data.categoryId
		}

		var result = super.fire( "line.clone", params );

		event.setValue( "result", result );
	}

	function get( event, rc, prc ){
		param rc.id = "___";
		var result  = super.getResult();

		if ( !super.isUuid( rc.id ) ) {
			return event.setValue( "result", "No UUID" );
		}

		var bean = super.fire( "line.get", [ rc.id ] );

		var obj = super.getMementify().convert( bean, "list" );

		if ( !obj.keyExists( "thickness" ) ) {
			obj[ "thickness" ] = { "id" = "", "name" = "" }
		}

		result.setData( obj );

		event.setValue( "result", result );
	}

	function attributes( event, rc, prc ){
		param rc.str = "";
		var result   = super.getResult();

		var params = {}

		params.str = Len( rc.str ) ? rc.str : NullValue();

		var list = fire( "attributes.search", params );

		result = list;

		event.setValue( "result", result );
	}

	function createProduct( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		// Prodotto eliminato logicamente ( usato in preventivi chiusi ): torna a
		// catalogo, con righe attributo-valore e prezzi, invece di crearne un doppione.
		var deleted = super.service( "Product" ).getByParamsIncludingDeleted(
			lineId     = rc.id,
			finishId   = json.finishId,
			modelId    = json.modelId,
			categoryId = json.categoryId
		);

		if ( !IsNull( deleted ) ) {
			super.service( "Product" ).restore( deleted.getId() );

			event.setValue(
				"result",
				{
					"message" = super.completeMessage( "product.created" ),
					"payload" = {
						"productId" = deleted.getId(),
						"finishId"  = json.finishId,
						"modelId"   = json.modelId
					}
				}
			);
			return;
		}

		var line     = super.bean( "Line" );
		var model    = super.bean( "Model" );
		var finish   = super.bean( "Finish" );
		var product  = super.bean( "ProductComplex" );
		var status   = super.bean( "Status" );
		var category = super.bean( "ProductCategory" );
		var bundle   = super.bean( "CatalogBundle" );

		bundle.setModel( model.setId( json.modelId ) );
		bundle.setLine( line.setId( rc.id ) );
		bundle.setCategory( category.setId( json.categoryId ) );

		product.setCatalogBundle( bundle );
		product.setLine( line.setId( rc.id ) );
		product.setFinish( finish.setId( json.finishId ) );
		product.setModel( model.setId( json.modelId ) );
		product.setCategory( category.setId( json.categoryId ) );
		product.setStatus( status.setId( "ACT" ) );

		var newId = super.fire( "product.create", [ product ] );

		var message = super.completeMessage( "product.created" );

		var obj = super.fire( "product.get", [ newId ] );

		event.setValue(
			"result",
			{
				"message" = message,
				"payload" = {
					"productId" = newId,
					"finishId"  = obj.getFinish().getId(),
					"modelId"   = obj.getModel().getId()
				}
			}
		);
	}

	function deleteProduct( event, rc, prc ){
		var json   = DeserializeJSON( GetHTTPRequestData().content );
		var result = super.getResult();

		var product = super.service( "Product" ).getByParams(
			lineId     = rc.id,
			finishId   = json.finishId,
			modelId    = json.modelId,
			categoryId = json.categoryId
		);

		if ( IsNull( product ) ) {
			result.setStatus( "ERROR" );
			result.setData( { "message" = "Prodotto non trovato." } );
			event.setValue( "result", result );
			return;
		}

		// usato in preventivi in corso: bloccato; solo in preventivi chiusi:
		// eliminato logicamente; mai usato: cancellato ( CatalogUsageService )
		var removed = super.service( "Product" ).remove( product.getId() );

		if ( removed.result == "IN_USE" ) {
			result.setStatus( "INVALID" );
			result.setData( { "quotations" = removed.quotations } );
			event.setValue( "result", result );
			return;
		}

		if ( removed.result == "ERROR" ) {
			result.setStatus( "ERROR" );
			result.setData( { "message" = removed.message } );
			event.setValue( "result", result );
			return;
		}

		var message = removed.result == "DEACTIVATED"
			? { "text" = deactivatedMessage( removed.closed ) }
			: super.completeMessage( "product.deleted" );

		result.setData( { "message" = message, "deactivated" = removed.result == "DEACTIVATED" } );
		event.setValue( "result", result );
	}

	function codeExists( event, rc, prc ){
		param rc.id   = "_";
		param rc.code = "";

		var result = super.fire( "line.codeExists", { code = rc.code, excludedId = rc.id } );

		event.setValue( "result", result );
	}

	function saveMarkup( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		var thisId    = "";
		var messageId = "productCategoryLine.created";

		var result = super.getResult();

		for ( var item in json._data ) {
			var line     = super.bean( "Line" );
			var category = super.bean( "ProductCategory" );
			var bean     = super.bean( "productCategoryLine" );

			bean.setLine( line.setId( item.id ) );
			bean.setProductCategory( category.setId( rc.categoryId ) );
			bean.setMarkup( item.markup );

			super.fire( "productCategoryLine.create", [ bean ] )
		}

		var message = completeMessage( messageId );

		result.setData( { "message" = message }, { "payload" = { id = thisId } } );

		event.setValue( "result", result );
	}

	function save( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		var thisId     = "";
		var messageId  = "";
		var categories = [];

		var result    = super.getResult();
		var line      = super.bean( "Line" );
		var status    = super.bean( "Status" );
		var thickness = super.bean( "Thickness" );
		var category  = super.bean( "ProductCategory" );

		for ( var thisCategory in json.selectedCategories ) {
			var category = super.bean( "ProductCategory" );

			category.setId( thisCategory.id )
			categories.add( category );
		}

		line.setId( json.id );
		line.setCode( json.code );
		line.setName( json.name );
		if ( !isNull( json.hscode ) ) line.setHscode( json.hscode );

		line.setStatus( status.setId( json.status.id ) );
		line.setCategories( categories );
		line.setThickness( thickness.setId( json?.thickness?.id ) );

		var nameItem        = super.buildTextBean( json.nameItem, "NAME" );
		var descriptionItem = super.buildTextBean( json.descriptionItem, "DESC" );

		line.setTexts( [ nameItem, descriptionItem ] );

		if ( !Len( json.id ) ) {
			messageId = "line.created";
			thisId    = super.fire( "line.create", [ line ] )
		} else {
			messageId = "line.updated";
			thisId    = super.fire( "line.update", [ line ] )
		}

		var message = completeMessage( messageId );

		result.setData( { "message" = message }, { "payload" = { id = thisId } } );

		event.setValue( "result", result );
	}

	function delete( event, rc, prc ){
		var result    = super.getResult();
		var list      = GetHTTPRequestData().content;
		var messageId = "line.deletedAllRecords";

		var errors  = [];
		var payload = "";

		var ids = ListToArray( list );

		for ( var id in ids ) {
			var outcome = super.fire( "line.delete", [ id ] );

			if ( outcome.getStatus() == "ERROR" ) {
				errors.add( { "message" = "Non sono riuscito a cancellare l'Id #id#" } )
			}
		}

		if ( errors.len() ) {
			messageId = "line.deletedNotAllRecords"
			payload   = { "errors" = errors };
		}

		var message = super.completeMessage( messageId );

		result.setData( { "message" = message, "payload" = payload } );

		event.setValue( "result", result );
	}

}

