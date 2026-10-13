component extends="com.apirone.core.controller.AbsController" {

	/**
	 * GET /api/quotations?from=YYYY-MM-DD&to=YYYY-MM-DD
	 *
	 * Preventivi (una riga per versione) con data preventivo o data conferma
	 * ordine nel periodo. Per ognuno: stato corrente (da quotation_status_history),
	 * Agente 1 tradotto nel suo id_agente_verticale e totale = somma prezzo x
	 * quantità delle righe (stesso calcolo di QuotationDAO.getQuotationTotals).
	 * lead_id / customer_id sono gli id CRM del lead e dell'azienda collegati.
	 *
	 * Usato dal CRM (laravel-api, App\Statistics\Support\ApironeQuotations) per la
	 * statistica "Budget di vendita". L'aggregazione per agente/mese è fatta dal CRM.
	 * Autenticazione: Bearer token, verificata da SecurityInterceptor (crm.api.token).
	 */
	function list( event, rc, prc ){
		param rc.from = "";
		param rc.to   = "";

		var result = super.getResult();

		if ( !IsDate( rc.from ) || !IsDate( rc.to ) ) {
			result.setStatus( "ERROR" );
			result.setData( { "message" = "from and to (YYYY-MM-DD) are required", "type" = "MissingParameter" } );
			event.setValue( "result", result );
			return;
		}

		var q = queryExecute(
			"SELECT CAST(q.quotation_id AS varchar) AS quotation_id,
			        q.quotation_number,
			        q.version_number,
			        q.quotation_date,
			        q.data_conferma_ordine,
			        COALESCE(h.status_id, q._status_id) AS status_id,
			        a.id_agente_verticale,
			        CAST(q.lead_id AS varchar) AS lead_id,
			        CAST(q.customer_id AS varchar) AS customer_id,
			        COALESCE(t.total_amount, 0) AS total_amount
			 FROM quotations q
			 LEFT JOIN quotation_status_history h
			        ON h.quotation_status_history_id = q.quotation_status_history_id
			 LEFT JOIN membership.accounts a
			        ON CAST(a.account_id AS varchar) = q.agente1
			 LEFT JOIN (
			        SELECT quotation_id, SUM(price * quantity) AS total_amount
			        FROM quotation_items
			        GROUP BY quotation_id
			 ) t ON t.quotation_id = q.quotation_id
			 WHERE (q.quotation_date BETWEEN CAST(? AS date) AND CAST(? AS date))
			    OR (q.data_conferma_ordine BETWEEN CAST(? AS date) AND CAST(? AS date))
			 ORDER BY q.quotation_number, q.version_number",
			[
				{ value: rc.from, cfsqltype: "CF_SQL_VARCHAR" },
				{ value: rc.to,   cfsqltype: "CF_SQL_VARCHAR" },
				{ value: rc.from, cfsqltype: "CF_SQL_VARCHAR" },
				{ value: rc.to,   cfsqltype: "CF_SQL_VARCHAR" }
			],
			{ datasource: "apirone" }
		);

		var rows = [];
		for ( var row in q ) {
			ArrayAppend( rows, {
				"id":                  row.quotation_id,
				"quotation_number":    row.quotation_number,
				"version_number":      Val( row.version_number ),
				"status_id":           IsNull( row.status_id ) ? "" : row.status_id,
				"quotation_date":      ( !IsNull( row.quotation_date ) && IsDate( row.quotation_date ) ) ? DateFormat( row.quotation_date, "yyyy-mm-dd" ) : "",
				"data_conferma_ordine": ( !IsNull( row.data_conferma_ordine ) && IsDate( row.data_conferma_ordine ) ) ? DateFormat( row.data_conferma_ordine, "yyyy-mm-dd" ) : "",
				"id_agente_verticale": IsNull( row.id_agente_verticale ) ? JavaCast( "null", "" ) : Val( row.id_agente_verticale ),
				"lead_id":             IsNull( row.lead_id ) ? "" : row.lead_id,
				"customer_id":         IsNull( row.customer_id ) ? "" : row.customer_id,
				"total_amount":        Val( row.total_amount )
			} );
		}

		result.setData( rows );
		result.setTotal( rows.len() );
		result.setCount( rows.len() );
		event.setValue( "result", result );
	}

}
