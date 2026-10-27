component extends="com.apirone.core.controller.AbsController" {

	function simulate( event, rc, prc ){
		// argomenti posizionali con i null espliciti: con gli argomenti per nome Lucee non accetta il default nullo di
		// quotation ( tipo Quotation ). L'ultimo, allowMissingPrice, simula anche un prodotto senza prezzo
		var result = super.service( "PriceCalculator" ).simulate( rc.id, rc.quantity, null, ListToArray( rc.itemIds ), rc.currencyId, 0, 0, null, null, null, null, true );

		var description = renderExplanation( result.explain );

		var output = {
			"price"       = result.values.finalPrice,
			"description" = description
		}

		event.setValue( "result", output );
	}

	function simulateSignage( event, rc, prc ){
		var result = super.service( "PriceCalculator" ).simulate( rc.id, rc.quantity, null, ListToArray( rc.itemIds ), rc.currencyId, rc.lettersQuantity, rc.simulationSignageConfigItemId, null, null, null, null, true );

		var description = renderExplanation( result.explain );

		var output = {
			"price"       = result.values.finalPrice,
			"description" = description
		}

		event.setValue( "result", output );
	}

	function calculateQuotation( event, rc, prc ){
	}


	function list( event, rc, prc ){
		var params = {}
		var data   = [];
		var result = super.getResult();
		var mm     = super.getMementify();

		var entity;

		if ( rc.by == "products" ) {
			params[ "productId" ] = rc.id;
			entity                = "PRODUCT";
		}

		if ( rc.by == "product-items" ) {
			params[ "productItemId" ] = rc.id;
			entity                    = "PRODUCT_ITEM";
		}


		var allTypes = super.fire( "priceType.list", { entityId = entity } );

		var rows = super.fire( "price.list", { argumentCollection = params } );

		// INFO: ensure all types are present
		// 		even those with no price assigned yet
		// 		by creating empty price entries

		var output = []

		for ( var type in allTypes ) {
			var found = false;

			for ( var row in rows ) {
				if ( row.getType().getId() EQ type.getId() ) {
					found = true;
					output.append( row );
					break;
				}
			}

			if ( !found ) {
				var empyPrice = super.bean( "Price" );

				empyPrice.setType( type );
				empyPrice.setAmount( 0 );
				empyPrice.setMethod( super.fire( "lookup.get", { "entity" = "priceMethod", value = "F" } ) );

				output.append( empyPrice );
			}
		}

		for ( var item in output ) {
			var row          = mm.convert( item );
			row[ "deleted" ] = false;
			data.add( row );
		}

		result.setTotal( data.len() );
		result.setCount( data.len() );
		result.setData( data );

		event.setValue( "result", result );
	}

	function save( event, rc, prc ){
		var result = super.getResult();
		var json   = DeserializeJSON( GetHTTPRequestData().content );

		var messageId = "prices.updated";

		var key   = "";
		var value = "";

		if ( rc.by == "products" ) {
			key   = "product.id";
			value = json.item.id;
		}

		if ( rc.by == "product-items" ) {
			key   = "productItem.id";
			value = json.item.id;
		}

		if ( key == "" ) {
			Throw(
				type    = "apirone.error.price.InvalidEntityType",
				message = "You must specify the entity for which the price is saved."
			);
		}

		for ( var item in json.prices ) {
			var price  = super.bean( "Price" );
			var method = super.bean( "PriceMethod" );
			var entity = super.bean( "Entity" );

			price.setId( item?.id );
			price.setAmount( item.amount );
			price.setMethod( method.setId( item.method.id ) );
			price.setEntity( entity.setKey( key ).setValue( value ) );


			if ( Len( item?.id ) ) {
				// var obj = get( item.id );
				// price.setEntity( obj.getEntity() );

				if ( item.deleted ) {
					super.fire( "price.delete", [ item.id ] );
				} else {
					super.fire( "price.update", [ price ] );
				}
			} else {
				if ( Len( item.amount ) ) {
					var type = super.bean( "PriceType" );
					price.setType( type.setId( item.type.id ) );
					super.fire( "price.create", [ price ] );
				}
			}
		}

		var message = completeMessage( messageId );
		result.setData( { "message" = message } );

		event.setValue( "result", result );
	}


	function reassign( event, rc, prc ){
		var result = super.getResult();
		var args   = {};

		var messageId = "price.reassigned";

		for ( var key in rc ) {
			if ( Len( rc[ key ] ) ) {
				args[ key ] = rc[ key ];
			}
		}

		var outout = super.fire( "price.massiveReassign", { argumentCollection = args } );

		var message = completeMessage( messageId );

		result.setData( { "message" = message }, { "payload" = outout } );

		event.setValue( "result", result );
	}

	/*
		private methods
	*/

	/*
		Tabella del simula: la spiegazione di questo solo calcolo ( PriceCalculatorService.explainPricing ),
		non il file di log, che accumula tutti i calcoli dall'avvio dell'applicazione.
	*/
	private String function renderExplanation( required Array rows ){
		var result = "<table class='price-log-table'>";

		for ( var row in arguments.rows ) {
			var text   = EncodeForHTML( row.text );
			var value  = Len( row.value ) ? row.value & " &euro;" : "";
			var detail = Len( row.detail ) ? "<br><small class='text-muted'>" & EncodeForHTML( row.detail ) & "</small>" : "";

			switch ( row.kind ) {
				case "section":
					result &= "<tr><td colspan='2' class='pt-3'><b>#text#</b></td></tr>";
					break;
				case "note":
					result &= "<tr><td colspan='2'><small class='text-muted'>#text#</small></td></tr>";
					break;
				case "subtotal":
					result &= "<tr><td><b>#text#</b></td><td width='140' class='text-end'><b>#value#</b></td></tr>";
					break;
				case "total":
					result &= "<tr class='price-log-table-tr-highlight'><td><b>#text#</b></td><td width='140' class='text-end'><b>#value#</b></td></tr>";
					break;
				default:
					result &= "<tr><td>#text##detail#</td><td width='140' class='text-end'>#value#</td></tr>";
			}
		}

		return result & "</table>";
	}

}
