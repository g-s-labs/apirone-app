component extends="com.apirone.core.controller.AbsController" {

	/**
	 * Elenco delle proforma già stampate per un preventivo, dalla più recente.
	 * Alimenta lo storico nella dialog di stampa, da cui si riscaricano i PDF.
	 */
	function list( event, rc, prc ){
		var result    = super.getResult();
		var mm        = super.getMementify();
		var proformas = super.fire( "QuotationProforma.list", [ rc.quotationId ] );
		var data      = [];

		for ( var proforma in proformas ) {
			data.add( mm.convert( proforma ) );
		}

		result.setData( data );
		result.setTotal( data.len() );
		result.setCount( data.len() );

		event.setValue( "result", result );
	}

	/**
	 * Apre il PDF di una proforma archiviata.
	 *
	 * Il file potrebbe essere raggiunto anche direttamente sul repository
	 * statico, ma si passa di qui per due motivi: viene servito dietro
	 * l'autenticazione dell'applicazione, e il browser riceve un nome
	 * leggibile ("PROFORMA 140_1.pdf") invece dello stored_name con l'uuid.
	 *
	 * Disposition "inline": il PDF si apre nel visualizzatore. Perché funzioni
	 * serve un Content-Type corretto — vedi la nota in nginx_foto.conf, dove
	 * la mancanza di mime.types faceva servire i PDF come text/plain e il
	 * browser si rifiutava di aprirli.
	 */
	function download( event, rc, prc ){
		var proforma = super.fire( "QuotationProforma.get", [ rc.id ] );

		if ( IsNull( proforma ) ) {
			cfheader( statusCode = 404, statusText = "Not Found" );
			abort;
		}

		var filePath = ExpandPath(
			"/../repository/public/media/quotation-proformas/#proforma.getDirectory()#/#proforma.getStoredName()#"
		);

		if ( !FileExists( filePath ) ) {
			cfheader( statusCode = 404, statusText = "Not Found" );
			abort;
		}

		// nome parlante per l'utente, non lo storedName con l'uuid
		var quotation = super.fire( "Quotation.get", [ proforma.getQuotationId() ] );
		var nomeFile  = "PROFORMA #quotation.getFileNumber()#.pdf";

		cfheader( name = "Content-Disposition", value = "inline; filename=""#nomeFile#""" );
		cfcontent( type = "application/pdf", file = filePath, deleteFile = false, reset = true );
		abort;
	}

}
