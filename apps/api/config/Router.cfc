component {

	function configure(){

		setFullRewrites( true );

		post( "raw-products/:rawProductId/notify-change" )
			.to( "RawProductController.notifyChange" ).end();

		get( "customers/:customerId/quotations" )
			.to( "CustomerQuotationsController.list" ).end();
		// Preventivi collegati a lead e opportunità del CRM (pannello nelle schede dettaglio)
		get( "leads/:leadId/quotations" )
			.to( "CustomerQuotationsController.listByLead" ).end();
		get( "opportunities/:opportunityId/quotations" )
			.to( "CustomerQuotationsController.listByOpportunity" ).end();
		// Preventivi per periodo, usati dal CRM (statistica Budget di vendita)
		get( "quotations" )
			.to( "QuotationsController.list" ).end();

	}

}
