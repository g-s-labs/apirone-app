component extends="com.apirone.core.model.service.AbsService" accessors="true" {

	property name="dao" inject="CrmSyncDAO";

	/**
	 * Avvia la sincronizzazione dal CRM in background, se non ne è già in corso una.
	 * Stessa logica di VerticaleSyncService.run() ma su un lock separato
	 * (crm_sync_status): indipendente dalla sync di Verticale.
	 */
	public Struct function run( String userId = "" ){
		var acquired = getDao().tryAcquireLock( arguments.userId );

		if ( !acquired ) {
			return { started = false, alreadyRunning = true };
		}

		// I cfthread ereditano il timeout della richiesta che li avvia: senza
		// alzarlo, cfhttp dentro il thread viene interrotto dopo i 30s di default
		// (troppo poco per paginare ~127mila record via API), anche se il thread
		// gira ormai "in background" dopo che questa run() è già tornata al chiamante.
		setting requesttimeout = 1800;

		var syncDao      = getDao();
		var logger       = getLogger();
		var cacheManager = getCacheManager();
		var threadName   = "crmSync" & CreateUUID();

		var cacheScopesToClear = [ "Customer.bean", "Lead.bean", "Opportunity.bean" ];

		thread name=threadName dao=syncDao logger=logger cacheManager=cacheManager cacheScopesToClear=cacheScopesToClear {
			var errors = [];

			var steps = {
				"account" = function(){ attributes.dao.syncAccounts(); },
				"lead"    = function(){ attributes.dao.syncLeads(); },
				"opportunità" = function(){ attributes.dao.syncOpportunities(); }
			};

			for ( var stepName in steps ) {
				try {
					steps[ stepName ]();
				} catch ( any e ) {
					// Per gli errori delle API del CRM detail ha l'URL chiamato ed
					// extendedInfo la curl equivalente (AbsRestApi.buildCurl):
					// finiscono in last_error per poter rifare la chiamata a mano.
					var errorText = e.message;
					if ( Len( e.detail ?: "" ) ) errorText &= " | " & e.detail;
					if ( Len( e.extendedInfo ?: "" ) ) errorText &= " | curl: " & e.extendedInfo;

					attributes.logger.error( "CrmSyncService. Errore sincronizzando [#stepName#]: #errorText#" );
					ArrayAppend( errors, "#stepName#: #errorText#" );
				}
			}

			for ( var scope in attributes.cacheScopesToClear ) {
				attributes.cacheManager.removeByScope( scope );
			}

			if ( ArrayLen( errors ) ) {
				attributes.dao.releaseLock( false, ArrayToList( errors, " | " ) );
			} else {
				attributes.dao.releaseLock( true );
			}
		}

		return { started = true, alreadyRunning = false };
	}

	public Struct function getStatus(){
		var record = getDao().getStatus();

		var lastCompletedAt = "";
		if ( record.recordCount AND IsDate( record.finished_at[ 1 ] ) ) {
			lastCompletedAt = DateTimeFormat( record.finished_at[ 1 ], "yyyy-mm-dd'T'HH:nn:ss" ) & "Z";
		}

		return {
			running         = record.recordCount ? ( record.running[ 1 ] ? true : false ) : false,
			lastCompletedAt = lastCompletedAt
		};
	}

}
