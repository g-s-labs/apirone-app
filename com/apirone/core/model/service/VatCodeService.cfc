component extends="com.apirone.core.model.service.AbsService" accessors="true" {

	property name="dao" inject="VatCodeDAO";
	property name="cacheScope" type="String" default="VatCode.bean";

	public com.apirone.core.model.bean.VatCode function get( required String vatCodeId ){
		var cm = getCacheManager();

		var cache = cm.get( getCacheScope(), arguments.vatCodeId );

		if ( cache.status ) {
			return cache.data;
		}

		var vatCode = build( arguments.vatCodeId );
		cm.put( getCacheScope(), arguments.vatCodeId, vatCode );

		return vatCode;
	}

	public Array function list() {
		arguments[ "limit" ] = -1;
		return search( argumentCollection = arguments ).getData();
	}

	public com.apirone.core.model.bean.Result function search(
		required Numeric limit  = 50,
		required Numeric offset = 0,
		Boolean activeOnly      = false, // solo i codici selezionabili ( verticale_vat_codes.active )
		String includeId        = ""     // con activeOnly: anche questo codice, se non attivo ( quello del preventivo aperto )
	){
		var rows   = [];
		var result = super.getResult();

		var records = getDao().find( argumentCollection = arguments );

		for ( var record in records ) {
			rows.add( get( vatCodeId = record.ivacod ) )
		}

		result.setData( rows );
		result.setCount( Val( records.recordcount ) );
		result.setTotal( Val( records.total ) );

		return result;
	}

	/**
	 * @private
	 */
	private com.apirone.core.model.bean.VatCode function build( required String vatCodeId ){
		var record = getDao().read( vatCodeId = arguments.vatCodeId );

		var bean = NullValue();

		if ( record.RecordCount ) {
			var bean = super.bean( "VatCode" );
			
			var record = trimQueryFields( record );

			bean.setId( record.ivacod );
			bean.setName( record.ivades );
			bean.setValue( record.ivaper );
		}

		return bean;
	}

}
