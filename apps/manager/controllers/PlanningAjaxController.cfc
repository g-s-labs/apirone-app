/**
 * API della pianificazione ( Gantt ), solo ADM ( permissionRoutes.json.cfm ).
 */
component extends="com.apirone.core.controller.AbsController" {

	/* ======================= Persone ======================= */

	function listPeople( event, rc, prc ){
		var result = super.getResult();
		result.setData( super.service( "Planning" ).listPeople() );
		event.setValue( "result", result );
	}

	function savePerson( event, rc, prc ){
		var result = super.getResult();
		var json   = DeserializeJSON( GetHTTPRequestData().content );

		try {
			super.service( "Planning" ).savePerson( rc.id, workTypeIdsOf( json ), json.hours ?: [], json.dayStart ?: "08:00" );
			result.setData( { "message" = "Disponibilità salvata." } );
		} catch ( any e ) {
			// errori di validazione del service ( apirone.planning.* ): messaggio all'utente
			if ( !e.type.startsWith( "apirone.planning." ) ) rethrow;
			fail( result, e.message );
		}

		event.setValue( "result", result );
	}

	/**
	 * Persona senza accesso all'app ( utente disattivato ).
	 */
	function createPerson( event, rc, prc ){
		var result = super.getResult();
		var json   = DeserializeJSON( GetHTTPRequestData().content );

		try {
			var id = super.service( "Planning" ).createPerson( json.name ?: "", workTypeIdsOf( json ) );
			result.setData( { "id" = id, "message" = "Persona creata." } );
		} catch ( any e ) {
			// errori di validazione del service ( apirone.planning.* ): messaggio all'utente
			if ( !e.type.startsWith( "apirone.planning." ) ) rethrow;
			fail( result, e.message );
		}

		event.setValue( "result", result );
	}

	/* ======================= Gantt ======================= */

	/**
	 * Dati del Gantt per l'intervallo from / to ( yyyy-mm-dd, inclusi ).
	 */
	function gantt( event, rc, prc ){
		var result = super.getResult();

		if ( !IsDate( rc.from ?: "" ) || !IsDate( rc.to ?: "" ) ) {
			fail( result, "Intervallo di date non valido." );
		} else {
			result.setData( super.service( "Planning" ).ganttData( ParseDateTime( rc.from ), ParseDateTime( rc.to ) ) );
		}

		event.setValue( "result", result );
	}

	/* ======================= Blocchi ======================= */

	/*
		Operazioni sui blocchi del Gantt: la logica ( distribuzione delle ore,
		capacità, giorni lavorabili ) è in PlanningService. Dopo ogni operazione
		il client ricarica i dati del Gantt.
	*/

	function createBlock( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			return { "id" = service.createBlock(
				quotationId = json.quotationId,
				userId      = json.userId,
				workTypeId  = json.workTypeId,
				start       = parseDay( json.start ),
				hours       = Val( json.hours ),
				extra       = IsBoolean( json.extra ?: "" ) && json.extra,
				startTime   = json.startTime ?: "",
				note        = json.note ?: "",
				createdBy   = session.user.getId()
			) };
		} );
	}

	function moveBlock( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.moveBlock( blockId = Val( rc.id ), start = parseDay( json.start ), userId = json.userId ?: "" );
		} );
	}

	function resizeBlock( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.resizeBlock( blockId = Val( rc.id ), end = parseDay( json.end ) );
		} );
	}

	function splitBlock( event, rc, prc ){
		blockAction( event, function( service ){
			return { "id" = service.splitBlock( blockId = Val( rc.id ) ) };
		} );
	}

	function setBlockDay( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.setDayHours( blockId = Val( rc.id ), day = parseDay( json.day ), hours = Val( json.hours ) );
		} );
	}

	function setBlockFlags( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.setBlockFlags(
				blockId       = Val( rc.id ),
				useSaturday   = IsBoolean( json.useSaturday ?: "" ) && json.useSaturday,
				forceHolidays = IsBoolean( json.forceHolidays ?: "" ) && json.forceHolidays
			);
		} );
	}

	/**
	 * Ora di inizio o di fine del blocco ( "HH:MM", passi di 30 minuti ).
	 */
	function setBlockTimes( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.setBlockTimes( blockId = Val( rc.id ), start = json.start ?: "", end = json.end ?: "" );
		} );
	}

	function setBlockExtra( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.setBlockExtra( blockId = Val( rc.id ), extra = IsBoolean( json.extra ?: "" ) && json.extra );
		} );
	}

	function setBlockNote( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.setBlockNote( blockId = Val( rc.id ), note = json.note ?: "" );
		} );
	}

	/**
	 * Lucchetto del blocco ( locked ): lo mette chiunque, lo toglie solo un ADM.
	 */
	function setBlockLock( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.setBlockLock(
				blockId = Val( rc.id ),
				locked  = IsBoolean( json.locked ?: "" ) && json.locked,
				userId  = session.user.getId(),
				isAdmin = !IsNull( session.user.getRole() ) && session.user.getRole().getId() == "ADM"
			);
		} );
	}

	function deleteBlock( event, rc, prc ){
		blockAction( event, function( service ){
			service.deleteBlock( Val( rc.id ) );
		} );
	}

	/* ======================= Costi orari ======================= */

	function listPersonCosts( event, rc, prc ){
		var result = super.getResult();
		result.setData( super.service( "Planning" ).personCosts( rc.id ) );
		event.setValue( "result", result );
	}

	function savePersonCost( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			if ( !IsNumeric( json.hourlyCost ?: "" ) ) {
				Throw( type = "apirone.planning.InvalidCost", message = "Inserisci il costo orario." );
			}
			service.savePersonCost(
				userId     = rc.id,
				validFrom  = parseDay( json.validFrom ?: "" ),
				hourlyCost = json.hourlyCost,
				createdBy  = session.user.getId()
			);
			return { "costs" = service.personCosts( rc.id ) };
		} );
	}

	function deletePersonCost( event, rc, prc ){
		blockAction( event, function( service ){
			service.deletePersonCost( Val( rc.id ) );
		} );
	}

	/* ======================= Statistiche ======================= */

	function stats( event, rc, prc ){
		var result = super.getResult();
		result.setData( super.service( "Planning" ).projectStats() );
		event.setValue( "result", result );
	}

	/* ======================= Chiusure aziendali ======================= */

	function listClosures( event, rc, prc ){
		var result = super.getResult();
		var year   = Val( rc.year ?: Year( Now() ) );

		result.setData( {
			"closures" = super.service( "WorkCalendar" ).listClosures( CreateDate( year, 1, 1 ), CreateDate( year, 12, 31 ) ),
			"holidays" = super.service( "WorkCalendar" ).holidays( year )
		} );
		event.setValue( "result", result );
	}

	function saveClosure( event, rc, prc ){
		var result = super.getResult();
		var json   = DeserializeJSON( GetHTTPRequestData().content );

		if ( !IsDate( json.day ?: "" ) ) {
			fail( result, "Data non valida." );
		} else {
			super.service( "WorkCalendar" ).saveClosure( ParseDateTime( json.day ), json.description ?: "" );
			result.setData( { "message" = "Chiusura salvata." } );
		}

		event.setValue( "result", result );
	}

	function deleteClosure( event, rc, prc ){
		var result = super.getResult();
		super.service( "WorkCalendar" ).deleteClosure( Val( rc.id ) );
		result.setData( { "message" = "Chiusura eliminata." } );
		event.setValue( "result", result );
	}

	/* ======================= Progetti ( ore delle voci del Gantt ) ======================= */

	/**
	 * Voci del Gantt pianificabili: preventivi attivi non persi né estinti e
	 * non collegati a un progetto, e progetti, con ore
	 * stimate e pianificate per tipo e stato ( concluso ).
	 */
	function listProjects( event, rc, prc ){
		var result = super.getResult();
		var projects = super.service( "Planning" ).plannableItems().filter( function( item ){
			return item.plannable;
		} );
		result.setData( projects );
		event.setValue( "result", result );
	}

	/**
	 * Ore stimate, budget e pianificazione ( stato, data con tipo, priorità,
	 * note ) di una voce ( preventivo o progetto ).
	 */
	function saveProject( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.saveProject(
				quotationId = rc.id,
				hours       = json.hours ?: {},
				budgets     = json.budgets ?: {},
				planning    = IsStruct( json.planning ?: "" ) ? json.planning : {},
				userId      = session.user.getId()
			);
			return { "message" = "Progetto salvato." };
		} );
	}

	/**
	 * Nuovo progetto ( nome + rif. libero ): compare nel Gantt come un preventivo.
	 */
	function createProject( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			var id = service.createProject( json.name ?: "", json.rifLibero ?: "", session.user.getId() );
			return { "id" = id, "message" = "Progetto creato." };
		} );
	}

	function updateProject( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.updateProject( rc.id, json.name ?: "", json.rifLibero ?: "" );
			return { "message" = "Progetto salvato." };
		} );
	}

	function deleteProject( event, rc, prc ){
		blockAction( event, function( service ){
			service.deleteProject( rc.id );
			return { "message" = "Progetto eliminato." };
		} );
	}

	/**
	 * Collega un preventivo al progetto: i suoi blocchi passano al progetto.
	 */
	function linkQuotation( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content );

		blockAction( event, function( service ){
			service.linkQuotation( rc.id, json.quotationId ?: "" );
			return { "message" = "Preventivo collegato al progetto." };
		} );
	}

	function unlinkQuotation( event, rc, prc ){
		blockAction( event, function( service ){
			service.unlinkQuotation( rc.id, rc.quotationId );
			return { "message" = "Preventivo scollegato dal progetto." };
		} );
	}

	/**
	 * Preventivi da collegare a un progetto ( str: numero, nome, rif. libero o cliente ).
	 */
	function searchQuotations( event, rc, prc ){
		var result = super.getResult();
		result.setData( super.service( "Planning" ).searchQuotations( rc.str ?: "" ) );
		event.setValue( "result", result );
	}

	/*
		private methods
	*/

	/**
	 * Esegue un'operazione del service ( blocchi, progetti ): gli errori di
	 * validazione ( apirone.planning.* ) tornano all'utente come messaggio.
	 */
	private void function blockAction( required any event, required any action ){
		var result = super.getResult();

		try {
			var data = arguments.action( super.service( "Planning" ) );
			result.setData( IsStruct( data ?: "" ) ? data : {} );
		} catch ( any e ) {
			if ( !e.type.startsWith( "apirone.planning." ) ) rethrow;
			fail( result, e.message );
		}

		arguments.event.setValue( "result", result );
	}

	/**
	 * Tipologie della persona dal JSON ( workTypeIds: array di codici ).
	 */
	private Array function workTypeIdsOf( required Struct json ){
		var ids = arguments.json.workTypeIds ?: [];
		return IsArray( ids ) ? ids.map( function( id ){ return UCase( Trim( id ) ); } ) : [];
	}

	private Date function parseDay( required String day ){
		if ( !REFind( "^\d{4}-\d{2}-\d{2}$", arguments.day ) ) {
			Throw( type = "apirone.planning.InvalidDate", message = "Data non valida: #arguments.day#" );
		}
		return CreateDate( ListGetAt( arguments.day, 1, "-" ), ListGetAt( arguments.day, 2, "-" ), ListGetAt( arguments.day, 3, "-" ) );
	}

	private void function fail( required any result, required String message ){
		arguments.result.setStatus( "ERROR" );
		arguments.result.setData( { "message" = arguments.message } );
	}

}
