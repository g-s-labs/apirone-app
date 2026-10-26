component extends="com.apirone.core.controller.AbsController" {

	function list( event, rc, prc ){
		param rc.customerId = "";
		listBy( event, "customer_id", rc.customerId, "customerId" );
	}

	function listByLead( event, rc, prc ){
		param rc.leadId = "";
		listBy( event, "lead_id", rc.leadId, "leadId" );
	}

	function listByOpportunity( event, rc, prc ){
		param rc.opportunityId = "";
		listBy( event, "opportunity_id", rc.opportunityId, "opportunityId" );
	}

	/**
	 * Preventivi collegati a un record del CRM: column è customer_id, lead_id o
	 * opportunity_id (mai input dell'utente), crmId l'id del record nel CRM.
	 */
	private function listBy( event, required string column, required string crmId, required string paramName ){
		var result = super.getResult();

		if ( !Len( arguments.crmId ) ) {
			result.setStatus( "ERROR" );
			result.setData( { "message" = "#arguments.paramName# is required", "type" = "MissingParameter" } );
			event.setValue( "result", result );
			return;
		}

		var siteMain = server.system.properties[ "site.main" ] ?: "";

		var q = queryExecute(
			"SELECT CAST(quotation_id AS varchar) AS quotation_id,
			        quotation_number,
			        version_number,
			        quotation,
			        quotation_date
			 FROM quotations
			 WHERE #arguments.column# = CAST(? AS UUID)
			 ORDER BY quotation_number DESC, version_number DESC",
			[ { value: arguments.crmId, cfsqltype: "CF_SQL_VARCHAR" } ],
			{ datasource: "apirone" }
		);

		var rows = [];
		for ( var row in q ) {
			ArrayAppend( rows, {
				"id":               row.quotation_id,
				"quotation_number": row.quotation_number,
				"version_number":   row.version_number,
				"quotation":        row.quotation,
				"quotation_date":   ( !IsNull( row.quotation_date ) && IsDate( row.quotation_date ) ) ? DateFormat( row.quotation_date, "yyyy-mm-dd" ) : "",
				"url":              "#siteMain#/manager/quotations/#row.quotation_id#"
			} );
		}

		result.setData( rows );
		result.setTotal( rows.len() );
		result.setCount( rows.len() );
		event.setValue( "result", result );
	}

}
