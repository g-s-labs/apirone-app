component extends="com.apirone.core.controller.AbsController" {

	function list( event, rc, prc ){
		
		var result = super.getResult();
		var params = super.paramsFromUrl();
		var memy   = super.getMementify();

		param rc.id = "";
		param rc.categoryId = "";
		param rc.quotationZoneId = "";

		prc.jsFiles.add( "app-file" );

		params[ "typeId" ] = getTypeIdBySlug( rc.typeId );
		params[ "quotationId" ] = rc.id;
		// Le righe del preventivo si vedono tutte: niente paginazione (paramsFromUrl imposta limit 15 di default)
		params[ "limit" ]  = -1;
		params[ "offset" ] = 0;
		// ordine trascinato ( ordinamento ); se mai riordinate, per posizione ( vedi QuotationItemDAO.find )
		params[ "orderBy" ] = [ { "field" = "quotationItem.ordinamento", "dir" = "asc" } ];
		params[ "quotationZoneId" ] = Len( rc.quotationZoneId ) ? rc.quotationZoneId : null;

		var rows = super.fire( "QuotationItem.search", params );
		var data = ( memy.convertList( rows.getData() ) );

		result.setTotal( rows.getTotal() );
		result.setCount( rows.getCount() );
		result.setData( data );
		

		event.setValue( "result", result );
	}

	function listByZone( event, rc, prc ){
		
		var result = super.getResult();
		var params = super.paramsFromUrl();

		params[ "quotationId" ] = rc.id;
		params[ "quotationZoneId" ] = Len( rc.zoneId ) ? rc.zoneId : null;
		// Anche per zona (pianta) servono tutte le righe, senza paginazione
		params[ "limit" ]  = -1;
		params[ "offset" ] = 0;

		var rows = super.fire( "QuotationItem.search", params );

		result.setTotal( rows.getTotal() );
		result.setCount( rows.getCount() );
		result.setData( rows.getData() );

		event.setValue( "result", result );
	}

	function editArticle( event, rc, prc ){
		var data   = {}
		var result = super.getResult();
		//var params = super.paramsFromUrl();
		var memy     = super.getMementify();

		var quotationItem = super.fire( "QuotationItem.get", { quotationItemId = rc.id } );

		var parsedQuotationItemData = memy.convert( quotationItem, "editArticle" );

		data.append( { "quotationItem" = parsedQuotationItemData } );

		result.setData( data );
		event.setValue( "result", result );
	}

	function saveArticle( event, rc, prc ){
		var json      = DeserializeJSON( GetHTTPRequestData().content );
		if ( super.rejectIfQuotationLocked( event, json.id ?: "" ) ) return;
		var thisId    = "";
		var messageId = "";

		var result = super.getResult();

		var id   = json.quotationItem.id;

		if ( !Len( id ) ) {
			var bean = super.bean( "QuotationItem" );
		} else {
			var bean = super.fire( "QuotationItem.get", { quotationItemId = id } );
		}

		bean.setQuotation( super.service( "Quotation" ).get( json.id ) );
		var quotationZone = super.service( "QuotationZone" ).list( quotationId = json.id, name = 'Non assegnato' );
		bean.setQuotationZone( quotationZone[ 1 ] );
		bean.setQuantity( json.quotationItem.quantity );
		bean.setArticle( super.fire( "Article.get", { articleId = json.quotationItem.article.id } ) );

		var price = super.bean( "QuotationItemPrice" );
		
		price.setDiscount1( 0 );
		price.setDiscount2( 0 );
		var method  = super.bean( "PriceMethod" );
		price.setMethod( method.setId( "F" ) );
		price.setAmount( Val( json.quotationItem.price.amount ) ? json.quotationItem.price.amount : 0 );
		var status  = super.bean( "Status" );
		bean.setStatus( status.setId( json.quotationItem.status.id ) );
		bean.setNote( json.quotationItem.note );
		if ( !IsNull( json.quotationItem.bozza ) ) bean.setBozza( json.quotationItem.bozza );

		bean.setPrice( price );

		if ( !Len( id ) ) {
			messageId = "quotationItem.created";
			thisId    = super.fire( "quotationItem.create", [ bean ] )
		} else {
			messageId = "quotationItem.updated";
			thisId    = super.fire( "quotationItem.update", [ bean ] );
			if ( !IsNull( bean.getInstanceGroupId() ) && Len( bean.getInstanceGroupId() ) ) {
				super.fire( "QuotationItem.syncInstanceGroup", { quotationItemId = thisId } );
			}
		}

		var message = completeMessage( messageId );

		result.setData( { "message" = message, "id" = thisId } );

		event.setValue( "result", result );
	}


	function listFruits( event, rc, prc ){
		
		var data   = [];
		var result = super.getResult();
		var memy   = super.getMementify();

		var quotationItem = super.fire( "QuotationItem.get", { quotationItemId = rc.id } );
		var fruits = quotationItem.getFruits();

		fruits.each( function( fruit ){
			data.add( memy.convert( fruit, "editForPlace" ) );
		} );

		result.setData( data );
		event.setValue( "result", result );
	}	

	function editPlate( event, rc, prc ){
		
		var data   = {};
		var result = super.getResult();
		var memy   = super.getMementify();

		var quotationItem = super.fire( "QuotationItem.get", { quotationItemId = rc.id } );

		var parsedQuotationItemData = memy.convert( quotationItem, "editPlate" );

		data.append( {
			"quotationItem" = parsedQuotationItemData,
			"plate" = {},
			"savedExportCode" = getSavedExportCode( quotationItem )
		} );

		result.setData( data );
		event.setValue( "result", result );
	}

	function plateExport( event, rc, prc ){
		var result = super.getResult();
		var langId = "IT";

		var item = super.fire( "QuotationItem.get", { quotationItemId = rc.id } );

		var data = {
			"id"       = item.getId(),
			"quantita" = item.getQuantity(),
			"note"     = item.getNote(),
			"speciale" = item.getSpecial()
		};

		if ( !isNull( item.getQuotationZone() ) ) {
			data["zona"] = item.getQuotationZone().getName();
		}

		if ( !isNull( item.getPosition() ) ) {
			data["posizione"] = item.getPosition().getCode();
		}

		var product = item.getProduct();
		var attributiPlacca = [];
		for ( var qi in item.getItems() ) {
			var pi = qi.getProductItem();
			ArrayAppend( attributiPlacca, {
				"attributo" = pi.getAttribute().getName( langId ),
				"valore"    = pi.getAttributeValue().getName( langId ),
				"nota"      = qi.getNote()
			});
		}
		data["prodotto"] = {
			"id"       = product.getId(),
			"codice"   = product.getCode(),
			"linea"    = product.getLine().getName( langId ),
			"modello"  = product.getModel().getCode() & " – " & product.getModel().getName( langId ),
			"finitura" = product.getFinish().getCode() & " – " & product.getFinish().getName( langId ),
			"attributi" = attributiPlacca
		};

		if ( !isNull( item.getFrame() ) ) {
			data["frame"] = {
				"codice"       = item.getFrame().getCode(),
				"orientamento" = item.getFrame().getOrientation().getId()
			};
		}

		var frutti = [];
		var fruitOrder = 1;
		for ( var fruit in item.getFruits() ) {
			var fruttoProdotto = fruit.getFruit();
			var slots = [];
			for ( var pos in fruit.getPositions() ) {
				ArrayAppend( slots, { "slot" = pos.position, "ordine" = pos.order } );
			}
			var attributiFrutto = [];
			for ( var qif in fruit.getItems() ) {
				var pif = qif.getProductItem();
				ArrayAppend( attributiFrutto, {
					"attributo" = pif.getAttribute().getName( langId ),
					"valore"    = pif.getAttributeValue().getName( langId ),
					"nota"      = qif.getNote()
				});
			}
			ArrayAppend( frutti, {
				"ordine"  = fruitOrder,
				"note"    = fruit.getNote(),
				"prodotto" = {
					"id"       = fruttoProdotto.getId(),
					"codice"   = fruttoProdotto.getCode(),
					"nome"     = fruttoProdotto.getName( langId ),
					"linea"    = fruttoProdotto.getLine().getName( langId ),
					"modello"  = fruttoProdotto.getModel().getCode() & " – " & fruttoProdotto.getModel().getName( langId ),
					"finitura" = fruttoProdotto.getFinish().getCode() & " – " & fruttoProdotto.getFinish().getName( langId )
				},
				"slots"     = slots,
				"attributi" = attributiFrutto
			});
			fruitOrder++;
		}
		data["frutti"] = frutti;

		if ( !isNull( item.getPrice() ) ) {
			var price = item.getPrice();
			var righe = [];
			for ( var line in price.getLines() ) {
				ArrayAppend( righe, {
					"nome"    = line.getName(),
					"importo" = line.getAmount(),
					"costo"   = line.getCost()
				});
			}
			data["prezzo"] = {
				"totale"       = price.getTotal(),
				"costo_totale" = price.getCost(),
				"sconto1"      = !isNull( price.getDiscount1() ) ? price.getDiscount1() : 0,
				"sconto2"      = !isNull( price.getDiscount2() ) ? price.getDiscount2() : 0,
				"metodo"       = price.getMethod().getId(),
				"righe"        = righe
			};
		}

		result.setData( data );
		event.setValue( "result", result );
	}

	function plate3dExport( event, rc, prc ){
		var result = super.getResult();
		var item = super.fire( "QuotationItem.get", { quotationItemId = rc.id } );
		result.setData( build3dItemJson( item ) );
		event.setValue( "result", result );
	}

	function plates3dExport( event, rc, prc ){
		var result = super.getResult();
		var plates = super.service( "QuotationItem" ).list( quotationId = rc.id, typeId = "PLA" );
		var data = [];
		for ( var plate in plates ) {
			var fullItem = super.fire( "QuotationItem.get", { quotationItemId = plate.getId() } );
			ArrayAppend( data, build3dItemJson( fullItem ) );
		}
		result.setData( data );
		event.setValue( "result", result );
	}

	/**
	 * Nodo "incisione" per l'export 3D: griglia (codice attributo radice), numero del marker
	 * e coordinate del centro dell'incisione, sia in px dell'immagine orizzontale del frutto
	 * sia in mm, rispetto al CENTRO del frutto (possono essere negative, il marker può stare
	 * fuori dal frutto). Null se il valore non è posizionato.
	 */
	private Any function buildEngravingJson( required quotationItemProductItem ){
		var qipi = arguments.quotationItemProductItem;

		if ( IsNull( qipi.getEngravingMarkerId() ) && IsNull( qipi.getEngravingXMm() ) ) {
			return NullValue();
		}

		var griglia = "";
		var marker  = "";

		if ( !IsNull( qipi.getEngravingMarkerId() ) ) {
			var markerBean = super.service( "ProductEngravingMarker" ).get( qipi.getEngravingMarkerId() );

			if ( !IsNull( markerBean ) && !IsNull( markerBean.getId() ) && Len( markerBean.getId() ) ) {
				marker = markerBean.getOrder();

				var attribute = super.service( "Attribute" ).get( markerBean.getAttributeId() );
				if ( !IsNull( attribute ) ) {
					griglia = attribute.getCode();
				}
			}
		}

		return {
			"griglia" = griglia,
			"marker"  = marker,
			"x_px"    = ( IsNull( qipi.getEngravingXPx() ) ? "" : qipi.getEngravingXPx() ),
			"y_px"    = ( IsNull( qipi.getEngravingYPx() ) ? "" : qipi.getEngravingYPx() ),
			"x_mm"    = ( IsNull( qipi.getEngravingXMm() ) ? "" : qipi.getEngravingXMm() ),
			"y_mm"    = ( IsNull( qipi.getEngravingYMm() ) ? "" : qipi.getEngravingYMm() )
		};
	}

	/**
	 * Categoria, linea, modello e finitura di un prodotto per l'export 3D, con codice e nome
	 * (nella lingua del preventivo) in campi separati. Stringa vuota se il dato manca.
	 */
	private Struct function build3dClassificationJson( required product, String langId = "IT" ){
		var p = arguments.product;
		var l = arguments.langId;

		return {
			"codiceCategoria" = !isNull( p.getCategory() ) ? p.getCategory().getCode()  : "",
			"nomeCategoria"   = !isNull( p.getCategory() ) ? p.getCategory().getName( l ) : "",
			"codiceLinea"     = !isNull( p.getLine() )     ? p.getLine().getCode()      : "",
			"nomeLinea"       = !isNull( p.getLine() )     ? p.getLine().getName( l )     : "",
			"codiceModello"   = !isNull( p.getModel() )    ? p.getModel().getCode()     : "",
			"nomeModello"     = !isNull( p.getModel() )    ? p.getModel().getName( l )    : "",
			"codiceFinitura"  = !isNull( p.getFinish() )   ? p.getFinish().getCode()    : "",
			"nomeFinitura"    = !isNull( p.getFinish() )   ? p.getFinish().getName( l )   : ""
		};
	}

	private Struct function build3dItemJson( required item, String langId = "IT" ){
		var codiceArticolo = "";
		var codiceVariante = "";
		var codiceColore   = "";

		if ( !isNull( arguments.item.getHash() ) && Len( Trim( arguments.item.getHash() ) ) ) {
			var productHash = super.service( "ProductHash" ).getByHash( arguments.item.getHash() );
			if ( !isNull( productHash ) ) {
				var exportCodes = super.service( "ExportCode" ).list( productHashId = productHash.getId() );
				if ( exportCodes.len() > 0 ) {
					codiceArticolo = exportCodes[1].getName().left( 15 );
					codiceVariante = exportCodes[1].getName().right( 10 );
					codiceColore   = exportCodes[1].getCounter();
				}
			}
		}

		var quantita = arguments.item.getQuantity();
		if ( !isNull( arguments.item.getQuotationZone() ) ) {
			if ( !isNull( arguments.item.getQuotationZone().getOrigin() ) ) {
				quantita *= arguments.item.getQuotationZone().getOrigin().getQuantity();
			}
			quantita *= arguments.item.getQuotationZone().getQuantity();
		}

		var product = arguments.item.getProduct();
		var attributiPlacca = [];
		for ( var qi in arguments.item.getItems() ) {
			var pi = qi.getProductItem();
			ArrayAppend( attributiPlacca, {
				"attributo"      = pi.getAttribute().getName( arguments.langId ),
				"attributo_code" = pi.getAttribute().getCode(),
				"valore"         = pi.getAttributeValue().getName( arguments.langId ),
				"valore_code"    = !isNull( pi.getAttributeValue().getRawValue() ) ? pi.getAttributeValue().getRawValue().getCode() : ""
			});
		}

		var placca = build3dClassificationJson( product, arguments.langId );
		placca[ "attributi" ] = attributiPlacca;

		var placcaOrientationId = "";

		// mappa slot (intero, 1..N) -> orientamento effettivo del blocco che lo contiene,
		// stesso algoritmo di FrameAjaxController.buildBlocksResponse()
		var slotOrientations = {};

		if ( !isNull( arguments.item.getFrame() ) ) {
			placcaOrientationId    = arguments.item.getFrame().getOrientation().getId();
			placca["orientamento"] = placcaOrientationId;

			// arguments.item.getFrame() è un bean "snapshot" con la sola orientation
			// valorizzata (vedi QuotationItemService.buildFromRow/getMany): per i blocchi
			// serve ricaricare il Frame vero e proprio dal suo code (== code del modello).
			if ( !isNull( product.getModel() ) && Len( product.getModel().getCode() ) ) {
				var frameBean = super.service( "Frame" ).getByCode( product.getModel().getCode() );

				if ( !isNull( frameBean ) ) {
					placca["frame"] = frameBean.getCode();

					if ( !isNull( frameBean.getBlocks() ) && ArrayLen( frameBean.getBlocks() ) ) {
						var blockOverrides = {};
						if ( !isNull( arguments.item.getBlockOrientations() ) && IsJSON( arguments.item.getBlockOrientations() ) ) {
							blockOverrides = DeserializeJSON( arguments.item.getBlockOrientations() );
						}

						var slotCounter = 0;
						for ( var block in frameBean.getBlocks() ) {
							var effectiveOri = ( block.getOrientationMode() == "HAV" ? placcaOrientationId : block.getOrientationMode() );

							var orderKey = ToString( block.getOrder() );
							if ( StructKeyExists( blockOverrides, orderKey ) && ListFindNoCase( "HOR,VER", blockOverrides[ orderKey ] ) ) {
								effectiveOri = UCase( blockOverrides[ orderKey ] );
							}

							for ( var i = 1; i <= block.getSlotCount(); i++ ) {
								slotCounter++;
								slotOrientations[ slotCounter ] = effectiveOri;
							}
						}
					}
				}
			}
		}

		var frutti = [];
		var fruitOrder = 1;
		for ( var fruit in arguments.item.getFruits() ) {
			var fruttoProdotto = fruit.getFruit();
			if ( isNull( fruttoProdotto ) ) {
				fruitOrder++;
				continue;
			}
			var slots = [];
			if ( !isNull( fruit.getPositions() ) ) {
				for ( var pos in fruit.getPositions() ) {
					ArrayAppend( slots, pos.position );
				}
			}

			// orientamento del frutto = orientamento del blocco a cui appartiene il suo primo slot;
			// se il blocco non è individuabile (placca legacy, slot non numerico) si usa quello della placca
			var orientamentoFrutto = placcaOrientationId;
			if ( slots.len() && IsNumeric( slots[1] ) && StructKeyExists( slotOrientations, slots[1] ) ) {
				orientamentoFrutto = slotOrientations[ slots[1] ];
			}

			var attributiFrutto = [];
			if ( !isNull( fruit.getItems() ) ) {
				for ( var qif in fruit.getItems() ) {
					var pif = qif.getProductItem();
					var attributoFrutto = {
						"attributo"      = pif.getAttribute().getName( arguments.langId ),
						"attributo_code" = pif.getAttribute().getCode(),
						"valore"         = pif.getAttributeValue().getName( arguments.langId ),
						"valore_code"    = !isNull( pif.getAttributeValue().getRawValue() ) ? pif.getAttributeValue().getRawValue().getCode() : ""
					};

					// posizione dell'incisione scelta sulla griglia del frutto (solo sul simbolo)
					var incisione = buildEngravingJson( qif );
					if ( !IsNull( incisione ) ) {
						attributoFrutto[ "incisione" ] = incisione;
					}

					ArrayAppend( attributiFrutto, attributoFrutto );
				}
			}
			var frutto = build3dClassificationJson( fruttoProdotto, arguments.langId );
			frutto[ "ordine" ]       = fruitOrder;
			frutto[ "codice" ]       = fruttoProdotto.getCode();
			frutto[ "slots" ]        = slots;
			frutto[ "orientamento" ] = orientamentoFrutto;
			frutto[ "attributi" ]    = attributiFrutto;
			ArrayAppend( frutti, frutto );
			fruitOrder++;
		}

		return {
			"codice_articolo" = codiceArticolo,
			"codice_variante" = codiceVariante,
			"codice_colore"   = codiceColore,
			"quantita"        = quantita,
			"placca"          = placca,
			"frutti"          = frutti
		};
	}

	function signageExport( event, rc, prc ){
		var result = super.getResult();
		var langId = "IT";

		var item = super.fire( "QuotationItem.get", { quotationItemId = rc.id } );

		var data = {
			"id"       = item.getId(),
			"quantita" = item.getQuantity(),
			"note"     = item.getNote(),
			"speciale" = item.getSpecial()
		};

		if ( !isNull( item.getQuotationZone() ) ) {
			data["zona"] = item.getQuotationZone().getName();
		}

		if ( !isNull( item.getPosition() ) ) {
			data["posizione"] = item.getPosition().getCode();
		}

		var product = item.getProduct();
		var attributiSegnaletica = [];
		if ( !isNull( item.getItems() ) ) {
			for ( var qi in item.getItems() ) {
				var pi = qi.getProductItem();
				ArrayAppend( attributiSegnaletica, {
					"attributo" = pi.getAttribute().getName( langId ),
					"valore"    = pi.getAttributeValue().getName( langId ),
					"nota"      = qi.getNote()
				});
			}
		}
		data["prodotto"] = {
			"id"        = product.getId(),
			"codice"    = product.getCode(),
			"linea"     = product.getLine().getName( langId ),
			"modello"   = product.getModel().getCode() & " – " & product.getModel().getName( langId ),
			"finitura"  = product.getFinish().getCode() & " – " & product.getFinish().getName( langId ),
			"attributi" = attributiSegnaletica
		};

		var configItem = item.getSignageConfigItem();
		var signageConfig = super.fire( "SignageConfig.get", { signageConfigId = configItem.getSignageConfigId() } );
		data["segnaletica"] = {
			"font"         = signageConfig.getFont().getName( langId ),
			"altezza_font" = configItem.getHeightInPixel(),
			"righe_max"    = configItem.getRowCount(),
			"char_max"     = configItem.getCharCount()
		};

		var righe = [];
		for ( var row in item.getSignageRows() ) {
			ArrayAppend( righe, {
				"ordine"       = row.getOrderby(),
				"allineamento" = row.getTextAlign(),
				"contenuto"    = row.getContent(),
				"char_count"   = row.getCharCount()
			});
		}
		data["righe"] = righe;

		if ( !isNull( item.getPrice() ) ) {
			var price = item.getPrice();
			var righePrezzo = [];
			for ( var line in price.getLines() ) {
				ArrayAppend( righePrezzo, {
					"nome"    = line.getName(),
					"importo" = line.getAmount(),
					"costo"   = line.getCost()
				});
			}
			data["prezzo"] = {
				"totale"       = price.getTotal(),
				"costo_totale" = price.getCost(),
				"sconto1"      = !isNull( price.getDiscount1() ) ? price.getDiscount1() : 0,
				"sconto2"      = !isNull( price.getDiscount2() ) ? price.getDiscount2() : 0,
				"metodo"       = price.getMethod().getId(),
				"righe"        = righePrezzo
			};
		}

		result.setData( data );
		event.setValue( "result", result );
	}

	function editSignage( event, rc, prc ){
		
		var data   = {};
		var result = super.getResult();
		var params = super.paramsFromUrl();
		var mm     = super.getMementify();

		params[ "quotationItemId" ] = rc.id;

		var quotationItem = super.fire( "QuotationItem.get", { quotationItemId = rc.id } );
		var parsedQuotationItemData = mm.convert( quotationItem, "edit" );

		var signageConfig = super.fire(
			"SignageConfig.get",
			{
				signageConfigId = quotationItem.getSignageConfigItem().getSignageConfigId()
			}
		);
		var parsedSignageConfigData = ( mm.convert( signageConfig ) );

		data.append( {
			"quotationItem" = parsedQuotationItemData,
			"signageConfig" = parsedSignageConfigData,
			"savedExportCode" = getSavedExportCode( quotationItem )
		} );

		result.setData( data );
		event.setValue( "result", result );
	}

	function editAccessory( event, rc, prc ){
		var data   = {}
		var result = super.getResult();
		var memy     = super.getMementify();
		var quotationItem = super.fire( "QuotationItem.get", { quotationItemId = rc.id } );

		var item = memy.convert( quotationItem, "edit" );
		item.product["category"] = memy.convert( quotationItem.getProduct().getCategory() );
		data.append( { "quotationItem" = item, "savedExportCode" = getSavedExportCode( quotationItem ) } );

		result.setData( data );
		event.setValue( "result", result );
	}

	function saveAccessory( event, rc, prc ){
		setting requestTimeout=120;
		var json      = DeserializeJSON( GetHTTPRequestData().content );
		if ( super.rejectIfQuotationLocked( event, json.quotationId ?: "" ) ) return;
		var thisId    = "";
		var messageId = "";
		var texts     = [];

		var status = super.bean( "Status" );
		var result = super.getResult();

		var id   = json.quotationItem.id;
		var type = json.type

		if ( !Len( id ) ) {
			var bean = super.bean( "QuotationItem" );
		} else {
			var bean = super.fire( "QuotationItem.get", { quotationItemId = id } );
		}

		bean.setQuotation( super.service( "Quotation" ).get( json.quotationId ) ); //TODO: move to QuotationId
		bean.setQuotationZone( super.service( "QuotationZone" ).get( json.quotationItem.quotationZone.id ) );
		bean.setQuantity( json.quotationItem.quantity );
		bean.setCustomImage( json.quotationItem.customImage );

		bean.setSpecial( json.quotationItem.special );
		if ( !IsNull( json.quotationItem.bozza ) ) bean.setBozza( json.quotationItem.bozza );
		bean.setNote( json.quotationItem.note );
		bean.setStatus( status.setId( json.quotationItem.status.id ) );
		if ( !Len( id ) ) {
			json.quotationItem.id = lcase(createUUID());
		}

		if( Len( json.quotationItem?.position?.code ) ) {
			var position = populatePositionBean( json.quotationItem.position );
			bean.setPosition( position );
		} else  {
			bean.setPosition( null );
		}
		
		try {
			var price = super.fire( 'QuotationItem.getPricing', { 'data' = json } );
		} catch ( "ApirOne.ProductNotFound" e ) {
			// nessun prodotto per la combinazione scelta: messaggio al client, non un 500
			result.setStatus( "INVALID" );
			result.setData( { "general" = [ { "message" = e.message } ] } );
			event.setValue( "result", result );
			return;
		}
		bean.setPrice( price );

		// includeDeleted: la riga può essere di un prodotto eliminato dopo ( CatalogUsageService )
		var product = super
			.fire(
				"Product.search",
				{
					lineId     = json.quotationItem.product.line.id,
					modelId    = json.quotationItem.product.model.id,
					categoryId = json.quotationItem.product.category.id,
					finishId   = json.quotationItem.product.finish.id,
					includeDeleted = true
				}
			)
			.getData();

		if ( !Len( product ) || Len( product ) > 1 ) {
			var message = "Combinazione Linea/Modello/Categoria/Finitura non disponibile.";
			result.setData( { "error" = message } );
			result.setStatus( "ERRORE" );
			event.setValue( "result", result );
			return;
		}

		product = product[ 1 ];

		bean.setProduct( super.fire( "Product.get", { "productId" = product.getId() } ) );

		var _items1 = json.quotationItem.product.keyExists( "items" ) ? ( json.quotationItem.product.items ?: [] ) : [];
		var productItemsData = isArray( _items1 ) ? _items1 : ( structKeyExists( _items1, "_data" ) ? _items1._data : [] );

		var missingAttributes = findMissingProductItemAttributes( productItemsData );
		if ( ArrayLen( missingAttributes ) ) {
			result.setStatus( "INVALID" );
			result.setData( { "general" = [ { "message" = "Completa tutti gli attributi prima di salvare: " & ArrayToList( missingAttributes, ", " ) } ] } );
			event.setValue( "result", result );
			return;
		}

		transaction {
			if ( !Len( id ) ) {
				messageId = "quotationItem.created";
				thisId    = super.fire( "quotationItem.create", [ bean ] )
			} else {
				messageId = "quotationItem.updated";
				thisId    = super.fire( "quotationItem.update", [ bean ] );
				if ( !IsNull( bean.getInstanceGroupId() ) && Len( bean.getInstanceGroupId() ) ) {
					super.fire( "QuotationItem.syncInstanceGroup", { quotationItemId = thisId } );
				}
			}

			var quotationItemProductItems = super.fire(
				"quotationItemProductItem.list",
				{ quotationItemId = thisId }
			);

			quotationItemProductItems.each( function( quotationItemProductItem ){
				super.fire(
					"quotationItemProductItem.delete",
					{ "productItemId" = quotationItemProductItem.getId() }
				)
			} );

			if ( ArrayLen( productItemsData ) ) {
				productItemsData.each( function( productItemRow ){
					var selectedValue = selectedValues = ArrayFilter( productItemRow.values, function( v ){
						return v.selected;
					} );

					if ( Len( selectedValue ) > 0 ) {
						selectedValue   = selectedValue[ 1 ];
						var productItem = super.fire(
							"productItem.get",
							{ "productItemId" = selectedValue.product_item_id }
						);

						var quotationItemProductItemBean = super.bean( "quotationItemProductItem" );
						
						quotationItemProductItemBean.setQuotationItemId( thisId );
						quotationItemProductItemBean.setProductItem( productItem );
						quotationItemProductItemBean.setOrigin( productItem.getOrigin() );
						quotationItemProductItemBean.setLevel( productItemRow.level );
						if (structKeyExists(productItemRow, 'note')) {
							quotationItemProductItemBean.setNote( productItemRow.note );
						}
						quotationItemProductItemBean.setId( thisId )

						super.fire(
							"quotationItemProductItem.create",
							{ "productItem" = quotationItemProductItemBean }
						)
					}
				} )
			}

			super.fire( "quotationItem.aggiornaPrezzoAltriArticoliByQuotationIdAndProductId", {
				"quotationId" = json.quotationId,
				"quotationItemId" = thisId,
				"productId" = json.quotationItem.product.id
				}
			);
		}

		saveImage( imageBase64 = json.imageBase64, quotationItemId = thisId, typeId = "accessory" );

		if ( !Len( id ) ) {
			var productHash = super.fire('ProductHash.createHash', { quotationItemId = thisId });
			super.fire('quotationItem.updateHash', { quotationItemId = thisId, hash = productHash });
		}

		var message = completeMessage( messageId );

		result.setData( { "message" = message, "id" = thisId } );

		event.setValue( "result", result );
	}

	function saveSignage( event, rc, prc ){
		setting requestTimeout=120;
		var json      = DeserializeJSON( GetHTTPRequestData().content );
		if ( super.rejectIfQuotationLocked( event, json.quotationId ?: "" ) ) return;
		var thisId    = "";
		var messageId = "";
		var texts     = [];

		var status = super.bean( "Status" );
		var result = super.getResult();

		var id   = json.quotationItem.id;
		var type = json.type

		if ( !Len( id ) ) {
			var bean = super.bean( "QuotationItemSignage" );
		} else {
			var bean = super.fire( "QuotationItem.get", { quotationItemId = id } );
		}

		bean.setSpecial( json.quotationItem.special );
		if ( !IsNull( json.quotationItem.bozza ) ) bean.setBozza( json.quotationItem.bozza );
		bean.setNote( json.quotationItem.note );
		bean.setStatus( status.setId( json.quotationItem.status.id ) );
		if ( !Len( id ) ) {
			json.quotationItem.id = lcase(createUUID());
		}
		try {
			var price = super.fire( 'QuotationItem.getSignagePricing', { 'data' = json } );
		} catch ( "ApirOne.NoPriceConfigured" e ) {
			result.setStatus( "INVALID" );
			result.setData( { "general" = [ { "message" = e.message } ] } );
			event.setValue( "result", result );
			return;
		}
		bean.setPrice( price );

		if( Len( json.quotationItem?.position?.code ) ) {
			var position = populatePositionBean( json.quotationItem.position );
			bean.setPosition( position );
		} else  {
			bean.setPosition( null );
		}

		bean.setSignageConfigItem(
			super.service( "SignageConfigItem" ).get( json.quotationItem.signageConfigItem.id )
		);

		bean.setQuotation( super.service( "Quotation" ).get( json.quotationId ) );
		bean.setQuotationZone( super.service( "QuotationZone" ).get( json.quotationItem.quotationZone.id ) );
		bean.setQuantity( json.quotationItem.quantity );
		bean.setCustomImage( json.quotationItem.customImage );

		if( Len( json.quotationItem?.position?.code ) ) {
			var position = populatePositionBean( json.quotationItem.position );
			bean.setPosition( position );
		} else  {
			bean.setPosition( null );
		}


		// includeDeleted: la riga può essere di un prodotto eliminato dopo ( CatalogUsageService )
		var product = super
			.fire(
				"Product.search",
				{
					lineId     = json.signageConfig.catalogBundle.line.id,
					modelId    = json.signageConfig.catalogBundle.model.id,
					categoryId = json.signageConfig.catalogBundle.category.id,
					finishId   = json.quotationItem.product.finish.id,
					includeDeleted = true
				}
			)
			.getData();
		
		product = product[ 1 ];

		bean.setProduct( super.fire( "Product.get", { "productId" = product.getId() } ) );

		var _items2 = json.quotationItem.product.items ?: [];
		var productItemsData = isArray( _items2 ) ? _items2 : ( structKeyExists( _items2, "_data" ) ? _items2._data : [] );

		var missingAttributes = findMissingProductItemAttributes( productItemsData );
		if ( ArrayLen( missingAttributes ) ) {
			result.setStatus( "INVALID" );
			result.setData( { "general" = [ { "message" = "Completa tutti gli attributi prima di salvare: " & ArrayToList( missingAttributes, ", " ) } ] } );
			event.setValue( "result", result );
			return;
		}

		var message = 'Errore durante il salvataggio della segnaletica.'
		transaction {
			if ( !Len( id ) ) {
				messageId = "quotationItem.created";
				thisId    = super.fire( "quotationItem.create", [ bean ] )
			} else {
				messageId = "quotationItem.updated";
				thisId    = super.fire( "quotationItem.update", [ bean ] );
				if ( !IsNull( bean.getInstanceGroupId() ) && Len( bean.getInstanceGroupId() ) ) {
					super.fire( "QuotationItem.syncInstanceGroup", { quotationItemId = thisId } );
				}
			}

			for ( var signageRow in json.quotationItem.signageRows._data ) {
				var signageRowBean = super.fire(
					"QuotationItemSignageRow.get",
					{ quotationItemSignageRowId = signageRow.id }
				);

				if ( !Len( signageRowBean ) ) {
					var signageRowBean = super.bean( "QuotationItemSignageRow" );
					var messaggiId     = "QuotationItemSignageRow.create";
				} else {
					var messaggiId = "QuotationItemSignageRow.update";
				}

				signageRowBean.setQuotationItemId( thisId );
				signageRowBean.setTextAlign( signageRow.textAlign );
				signageRowBean.setContent( signageRow.content );
				signageRowBean.setCharCount( signageRow.charCount );
				signageRowBean.setOrderby( signageRow.index );

				super.fire( messaggiId, [ signageRowBean ] );
			}

			var quotationItemProductItems = super.fire(
				"quotationItemProductItem.list",
				{ quotationItemId = thisId }
			);

			quotationItemProductItems.each( function( quotationItemProductItem ){
				super.fire(
					"quotationItemProductItem.delete",
					{ "productItemId" = quotationItemProductItem.getId() }
				)
			} );

			productItemsData.each( function( productItemRow ){
				var selectedValue = selectedValues = ArrayFilter( productItemRow.values, function( v ){
					return v.selected;
				} )
				if ( Len( selectedValue ) > 0 ) {
					selectedValue   = selectedValue[ 1 ];
					var productItem = super.fire(
						"productItem.get",
						{ "productItemId" = selectedValue.product_item_id }
					);

					var quotationItemProductItemBean = super.bean( "quotationItemProductItem" );

					quotationItemProductItemBean.setQuotationItemId( thisId );
					quotationItemProductItemBean.setProductItem( productItem );
					quotationItemProductItemBean.setOrigin( productItem.getOrigin() );
					quotationItemProductItemBean.setLevel( productItemRow.level );
					if (structKeyExists(productItemRow, 'note')) {
						quotationItemProductItemBean.setNote( productItemRow.note );
					}
					quotationItemProductItemBean.setId( thisId )

					super.fire(
						"quotationItemProductItem.create",
						{ "productItem" = quotationItemProductItemBean }
					)
				}
			} )

			super.fire( "quotationItem.aggiornaPrezzoAltriArticoliByQuotationIdLineIdFinishId", {
				"quotationId" = json.quotationId, 
				"quotationItemId" = thisId, 
				"lineId" = json.signageConfig.catalogBundle.line.id,
				"finishId" = json.quotationItem.product.finish.id,
				"modelId" = json.signageConfig.catalogBundle.model.id
				} 
			);
			message = completeMessage( messageId );
		}

		saveImage( imageBase64 = json.imageBase64, quotationItemId = thisId, typeId = "signage" );

		if ( !Len( id ) ) {
			var productHash = super.fire('ProductHash.createHash', { quotationItemId = thisId });
			super.fire('quotationItem.updateHash', { quotationItemId = thisId, hash = productHash });
		}

		result.setData( { "message" = message, "id" = thisId } );

		event.setValue( "result", result );
	}

	function savePlate( event, rc, prc ){
		setting requestTimeout=120;
		var json      = DeserializeJSON( GetHTTPRequestData().content );
		if ( super.rejectIfQuotationLocked( event, json.quotationId ?: "" ) ) return;
		var thisId    = "";
		var messageId = "";

		var result = super.getResult();
		var tmpDir = super.getTempDir();
		
		var status      = super.bean( "Status" );
		var zone        = super.bean( "QuotationZone" );
		var bean        = super.bean( "QuotationItemPlate" );
		var frame       = super.bean( "Frame" );
		var orientation = super.bean( "Orientation" );

		var beanFruits = [];

		var id = json.item.id;

		if ( Len( id ) ) {
			var bean = duplicate( super.fire( "QuotationItem.get", { quotationItemId = id } ) );
		}

		bean.setQuotation( super.fire( "Quotation.get", [ json.quotationId ] ) ); //TODO: move to QuotationId
		
		bean.setQuantity( json.item.quantity );
		bean.setStatus( status.setId( json.item.status.id ) );
		bean.setQuotationZone( zone.setId( json.item.quotationZone.id ) );
		bean.setSpecial( json.item.special );
		if ( !IsNull( json.item.bozza ) ) bean.setBozza( json.item.bozza );
		bean.setCustomImage( json.item.customImage );
		bean.setFrame( frame.setOrientation( orientation.setId( json.item.product.orientation.id ) ) );
		bean.setNote( json.item.note )

		// override orientamento dei singoli blocchi (placche a blocchi)
		if ( !IsNull( json.item.blockOrientations ) && IsStruct( json.item.blockOrientations ) && !StructIsEmpty( json.item.blockOrientations ) ) {
			bean.setBlockOrientations( SerializeJSON( json.item.blockOrientations ) );
		} else {
			bean.setBlockOrientations( "" );
		}

		if( Len( json.item?.position?.code ) ) {
			var position = populatePositionBean( json.item.position );
			bean.setPosition( position );
		}

		var pricing = super.fire( 'QuotationItem.getPlatePricing', { 'data' = json } );

		bean.setPrice( pricing );
		
		// includeDeleted: la riga può essere di un prodotto eliminato dopo ( CatalogUsageService )
		var product = super.fire( "Product.search",
				{
					categoryId = 22,
					lineId     = json.item.product.line.id,
					modelId    = json.item.product.model.id,
					finishId   = json.item.product.finish.id,
					includeDeleted = true
				}
			).getData();

		product = product[ 1 ];

		bean.setProduct( product );

		// --- Preload batch dei bean necessari al salvataggio (evita l'N+1 su product.get, QuotationItemFruit.get e productItem.get) ---

		// 1) Precarica i Product dei frutti in una sola getMany() (evita un product.get per frutto).
		var fruitProductIds = [];
		for ( var f in json.item.fruits._data ) {
			fruitProductIds.append( f.fruit.id );
		}
		var fruitProductMap = ArrayLen( fruitProductIds )
			? super.service( "Product" ).getMany( fruitProductIds )
			: {};

		// 2) Precarica i QuotationItemFruit già salvati (id numerico) in una sola getMany().
		var existingFruitIds = [];
		for ( var f in json.item.fruits._data ) {
			if ( IsNumeric( f.id ) && !json.isClone ) {
				existingFruitIds.append( f.id );
			}
		}

		var existingFruitMap = ArrayLen( existingFruitIds )
			? super.service( "QuotationItemFruit" ).getMany( existingFruitIds )
			: {};

		// 3) Precarica i ProductItem selezionati (frutti + righe placca) in una sola getMany().
		// ATTENZIONE: il filtro di selezione qui sotto deve restare allineato a quello dei due loop
		// di salvataggio (frutti e righe placca): se cambia in un punto, va cambiato ovunque.
		var selectedProductItemIds = [];
		for ( var f in json.item.fruits._data ) {
			var fruitItemsSource = f.items ?: [];
			var fruitItemsData   = isArray( fruitItemsSource ) ? fruitItemsSource : ( structKeyExists( fruitItemsSource, "_data" ) ? fruitItemsSource._data : [] );
			for ( var fruitItemRow in fruitItemsData ) {
				var fruitSel = ArrayFilter( fruitItemRow.values, function( value ) { return value.selected; } );
				if ( Len( fruitSel ) > 0 && !ArrayContains( selectedProductItemIds, fruitSel[ 1 ].productItemId ) ) {
					selectedProductItemIds.append( fruitSel[ 1 ].productItemId );
				}
			}
		}
		var plateItemsSource = json.item.product.items ?: [];
		var plateItemsData   = isArray( plateItemsSource ) ? plateItemsSource : ( structKeyExists( plateItemsSource, "_data" ) ? plateItemsSource._data : [] );
		for ( var plateItemRow in plateItemsData ) {
			var plateSel = ArrayFilter( plateItemRow.values, function( value ) { return value.selected; } );
			if ( Len( plateSel ) > 0 && !ArrayContains( selectedProductItemIds, plateSel[ 1 ].productItemId ) ) {
				selectedProductItemIds.append( plateSel[ 1 ].productItemId );
			}
		}
		var missingAttributes = findMissingProductItemAttributes( plateItemsData );
		if ( ArrayLen( missingAttributes ) ) {
			result.setStatus( "INVALID" );
			result.setData( { "general" = [ { "message" = "Completa tutti gli attributi della placca prima di salvare: " & ArrayToList( missingAttributes, ", " ) } ] } );
			event.setValue( "result", result );
			return;
		}

		var productItemMap = ArrayLen( selectedProductItemIds )
			? super.service( "ProductItem" ).getMany( selectedProductItemIds )
			: {};

		var engravingService = super.service( "ProductEngravingMarker" );

		for ( var thisFruit in json.item.fruits._data ) {

			var positions = json.positions[ thisFruit.id ];
			
			/*
				INFO:
				se id è numerico: è stato già salvato nel db
				se id è stringa: è stato agenerato da js per il dnd, record nuovo
			*/
			if ( IsNumeric( thisFruit.id ) && !json.isClone ) {
				// update: bean già precaricato in existingFruitMap
				var fruitBean = existingFruitMap[ thisFruit.id ];
			} else {
				// create
				var fruitBean = super.bean( "QuotationItemFruit" );
			}

			// Product già precaricato in fruitProductMap (evita un product.get per frutto)
			var product = fruitProductMap[ thisFruit.fruit.id ];

			fruitBean.setFruit( product );
			fruitBean.setPositions( positions );

			var items = [];

			var _fruitItems = thisFruit.items ?: [];
			var fruitProductItemsData = isArray( _fruitItems ) ? _fruitItems : ( structKeyExists( _fruitItems, "_data" ) ? _fruitItems._data : [] );

			var missingFruitAttributes = findMissingProductItemAttributes( fruitProductItemsData );
			if ( ArrayLen( missingFruitAttributes ) ) {
				result.setStatus( "INVALID" );
				result.setData( { "general" = [ { "message" = "Completa tutti gli attributi del frutto '" & ( thisFruit.fruit?.name ?: "" ) & "' prima di salvare: " & ArrayToList( missingFruitAttributes, ", " ) } ] } );
				event.setValue( "result", result );
				return;
			}

			fruitProductItemsData.each( function( productItemRow ){
				var selectedValue = selectedValues = ArrayFilter( productItemRow.values, function( value ){
					return value.selected;
				} )

				if ( Len( selectedValue ) > 0 ) {
					selectedValue = selectedValue[ 1 ];

					var productItemBean = super.bean( "QuotationItemProductItem" );
					var productItem     = productItemMap[ selectedValue.productItemId ];

					//productItemBean.setQuotationItemFruitId( fruitBean.getId() );
					productItemBean.setProductItem( productItem );
					productItemBean.setOrigin( productItem.getOrigin() );
					if (structKeyExists(selectedValue, 'note')) {
						productItemBean.setNote( selectedValue.note );
					}
					productItemBean.setLevel( productItemRow.level );

					// griglia incisioni: posizione scelta per il simbolo. Il marker arriva dal
					// client, ma le coordinate si rileggono dal db (il preventivo non deve
					// cambiare se la griglia del frutto viene modificata dopo il salvataggio).
					if ( !IsNull( selectedValue.engravingMarkerId ) && Len( selectedValue.engravingMarkerId ) ) {
						var engravingMarker = engravingService.findMarkerForProductItem(
							productEngravingMarkerId = selectedValue.engravingMarkerId,
							productItemId            = selectedValue.productItemId,
							productId                = product.getId()
						);

						if ( !IsNull( engravingMarker ) ) {
							productItemBean.setEngravingMarkerId( engravingMarker.getId() );
							productItemBean.setEngravingXPx( engravingMarker.getXPx() );
							productItemBean.setEngravingYPx( engravingMarker.getYPx() );
							productItemBean.setEngravingXMm( engravingMarker.getXMm() );
							productItemBean.setEngravingYMm( engravingMarker.getYMm() );
						}
					}

					items.add( productItemBean );
				}
			} );
			
			fruitBean.setItems( items );

			beanFruits.add( fruitBean );

		}

		var plugBeans = super.fire( "QuotationItem.buildPlugFruitBeans", { "data" = json } );
		for ( var plugBean in plugBeans ) {
			beanFruits.add( plugBean );
		}

		bean.setFruits( beanFruits );

		var message = 'Errore durante il salvataggio della placca.'
		transaction {
			if ( !Len( id ) OR json.isClone ) {
				messageId = "quotationItem.created";
				thisId    = super.fire( "quotationItem.create", [ bean ] )
			} else {
				messageId = "quotationItem.updated";
				thisId    = super.fire( "quotationItem.update", [ bean ] );
				if ( !IsNull( bean.getInstanceGroupId() ) && Len( bean.getInstanceGroupId() ) ) {
					super.fire( "QuotationItem.syncInstanceGroup", { quotationItemId = thisId } );
				}
			}

			var quotationItemProductItems = super.fire( "quotationItemProductItem.list", { quotationItemId = thisId });

			quotationItemProductItems.each( function( quotationItemProductItem ){
				super.fire( "quotationItemProductItem.delete", { "productItemId" = quotationItemProductItem.getId() } )
			} );

			var _items3 = json.item.product.items ?: [];
			var productItemsData = isArray( _items3 ) ? _items3 : ( structKeyExists( _items3, "_data" ) ? _items3._data : [] );

			productItemsData.each( function( productItemRow ){
				var selectedValue = selectedValues = ArrayFilter( productItemRow.values, function( value ){
					return value.selected;
				} )

				if ( Len( selectedValue ) > 0 ) {
					selectedValue = selectedValue[ 1 ];

					var productItemBean = super.bean( "QuotationItemProductItem" );
					var productItem     = productItemMap[ selectedValue.productItemId ];

					productItemBean.setQuotationItemId( thisId );
					productItemBean.setProductItem( productItem );
					productItemBean.setOrigin( productItem.getOrigin() );
					if (structKeyExists(selectedValue, 'note')) {
						productItemBean.setNote( selectedValue.note );
					}
					productItemBean.setLevel( productItemRow.level );
					// productItemBean.setId( thisId )

					super.fire( "quotationItemProductItem.create", [ productItemBean ] )
				}
			} );


			//Funzione che riceve quotationItemId, quotationId, line e finish e aggiorna tutte le righe con quotationItemId <> da quotationItemId e stessa line e finish con i dati del quotationItem con id = quotationItemId
			//che condividono quotation,line e finish, ripartendo il fixed_cost sulla nuova quantita totale
			super.fire( "quotationItem.aggiornaPrezzoAltriArticoliByQuotationIdLineIdFinishId", {
				"quotationId" = json.quotationId, 
				"quotationItemId" = thisId, 
				"lineId" = json.item.product.line.id,
				"finishId" = json.item.product.finish.id,
				"modelId" = json.item.product.model.id
				} 
			);
			
			message = completeMessage( messageId );
		}

		saveImage( imageBase64 = json.imageBase64, quotationItemId = thisId, typeId = "plate" );

		if ( !Len( id ) OR json.isClone ) {
			var productHash = super.fire('ProductHash.createHash', { quotationItemId = thisId });
			super.fire('quotationItem.updateHash', { quotationItemId = thisId, hash = productHash });
		}

		result.setData( { "message" = message, "id" = thisId } );

		event.setValue( "result", result );
	}

	function duplicate( event, rc, prc ){
		var result = super.getResult();
		var json   = DeserializeJSON( GetHTTPRequestData().content );
		var id     = rc.id;
		var asInstance = IsBoolean( json.asInstance ?: false ) ? json.asInstance : false;
		if ( super.rejectIfQuotationLocked( event, quotationIdOfItem( id ) ) ) return;

		// una nuova riga non può usare elementi eliminati dal catalogo
		var notInCatalog = super.service( "CatalogUsage" ).deletedInQuotationItem( id );
		if ( notInCatalog.len() ) {
			result.setStatus( "ERROR" );
			result.setData( { "message" = "Non si può duplicare: la riga contiene elementi non più a catalogo ( " & ArrayToList( notInCatalog, ", " ) & " )." } );
			event.setValue( "result", result );
			return;
		}

		try {
			var newId = super.fire( "QuotationItem.clone", { quotationItemId = id, asInstance = asInstance } );

			// Se viene passata la posizione originale, aggiorna la prima posizione del clone con le stesse coordinate e visibilità
			if ( !IsNull( json.position ?: NullValue() ) ) {
				var newItem = super.fire( "QuotationItem.get", [ newId ] );
				var newPositions = newItem.getPositions();
				if ( !IsNull( newPositions ) && newPositions.len() > 0 ) {
					var firstPos = newPositions[ 1 ];
					firstPos.setCoordinateX( Val( json.position.coordinateX ) );
					firstPos.setCoordinateY( Val( json.position.coordinateY ) );
					firstPos.setVisible( json.position.visible == true || json.position.visible == 1 );
					firstPos.setAngle( Int( Val( json.position.angle ?: 0 ) ) );
					firstPos.setSizeMultiplier( Int( Val( json.position.sizeMultiplier ?: 100 ) ) );
					super.fire( "QuotationItemPosition.update", [ firstPos ] );
				}
			}

			result.setData( { "id" = newId, "message" = "Articolo duplicato correttamente." } );
		} catch ( any e ) {
			result.setStatus( "ERROR" );
			result.setData( { "message" = "Errore durante la duplicazione: #e.message#" } );
		}

		event.setValue( "result", result );
	}

	function delete( event, rc, prc ){
		var result     = super.getResult();
		var validation = getValidationResult();

		var id = GetHTTPRequestData().content;

		var quotationItem = super.fire( "quotationItem.get", [ id ]);
		var quotationId = quotationItem.getQuotation().getId()
		if ( super.rejectIfQuotationLocked( event, quotationId ) ) return;
		if (isNull(quotationItem.getArticle())) {
			var lineId = quotationItem.getProduct().getLine().getId()
			var finishId = quotationItem.getProduct().getFinish().getId()
			var modelId = !IsNull( quotationItem.getProduct().getModel() ) ? quotationItem.getProduct().getModel().getId() : ""
			var productId = quotationItem.getProduct().getId()
		}

		transaction {
			var outcome = super.fire( "quotationItem.delete", [ id ] );

			if ( outcome.getStatus() == "ERROR" ) {
				var error = super.getValidationError(
					message = getMessage( "quotationItem.notDeleted" ),
					field   = "general"
				);
				validation.addError( error );

				event.setValue( "result", validation );
				return;
			}

			if (IsInstanceOf(quotationItem, "com.apirone.core.model.bean.QuotationItemPlate") || IsInstanceOf(quotationItem, "com.apirone.core.model.bean.QuotationItemSignage")) {
				super.fire( "quotationItem.aggiornaPrezzoAltriArticoliByQuotationIdLineIdFinishId", {
					"quotationId" = quotationId,
					"quotationItemId" = id, 
					"lineId" = lineId,
					"finishId" = finishId,
					"modelId" = modelId
					} 
				);
			} elseif (isNull(quotationItem.getArticle())) {
				super.fire( "quotationItem.aggiornaPrezzoAltriArticoliByQuotationIdAndProductId", {
					"quotationId" = quotationId,
					"quotationItemId" = id, 
					"productId" = productId
					} 
				);
			}
			result.setData( { "message" = getMessage( "quotationItem.deleted" ) } );
		}

		event.setValue( "result", result );
	}

	function updateAllPrices( event, rc, prc ){
		var result     = super.getResult();
		var validation = getValidationResult();

		var id = rc.id;

		if ( !IsNull( id ) && super.rejectIfQuotationLocked( event, id ) ) return;

		if (!IsNull(id)) {
			var quotationItems = super.fire( "quotationItem.list", { quotationId = id } );

			// La Quotation è la stessa per tutti gli item, già caricata in batch dalla list:
			// viene passata a ogni aggiornaPrezzo per evitare il refetch completo per ogni riga (N+1).
			var sharedQuotation = NullValue();
			if ( ArrayLen( quotationItems ) ) {
				sharedQuotation = quotationItems[ 1 ].getQuotation();
			}

			transaction {
				for (var quotationItem in quotationItems) {
					if (isNull(quotationItem.getArticle())) {
						super.fire( "quotationItem.aggiornaPrezzo", { "quotationItem" = quotationItem, "preloadedQuotation" = sharedQuotation } );
					}
				}
				result.setData( { "message" = getMessage( "quotationItem.deleted" ) } );
			}
		}

		event.setValue( "result", result );
	}

	/**
	 * Applica uno sconto a tutte le righe di una famiglia (placche, segnaletiche,
	 * accessori, servizi) del preventivo, in tutte le zone. Sovrascrive gli sconti
	 * di riga (discount1 = sconto, discount2 = 0); le righe a prezzo fisso restano invariate.
	 */
	function applyDiscountByType( event, rc, prc ){
		var result = super.getResult();
		var json   = DeserializeJSON( GetHTTPRequestData().content );
		var types  = { "plate" = "PLA", "accessory" = "ACC", "signage" = "SEG", "article" = "ART" };

		var discount = !isNull( json.discount ) && IsNumeric( json.discount ) ? Val( json.discount ) : -1;

		if ( !StructKeyExists( types, rc.typeId ) || discount LT 0 || discount GT 100 ) {
			result.setStatus( "INVALID" );
			result.setData( { "message" = "Indicare uno sconto compreso tra 0 e 100." } );
			event.setValue( "result", result );
			return;
		}

		var quotation = super.fire( "Quotation.get", [ rc.id ] );

		if ( isNull( quotation ) || quotation.isLocked() ) {
			result.setStatus( "INVALID" );
			result.setData( { "message" = "Il preventivo non è modificabile" & ( !isNull( quotation ) ? " perché " & quotation.lockReason() : "" ) & "." } );
			event.setValue( "result", result );
			return;
		}

		var outcome = super.fire( "QuotationItemPrice.applyDiscountByType", {
			"quotationId" = rc.id,
			"typeId"      = types[ rc.typeId ],
			"discount"    = discount
		} );

		result.setData( outcome );
		event.setValue( "result", result );
	}

	/*
		Riepilogo delle righe del preventivo salvate senza prezzo configurato, per tipo
		(slug come nei tab: plate/signage/accessory): { total, byType: { signage: 2, ... } }.
	*/
	function missingPrices( event, rc, prc ){
		var result  = super.getResult();
		var slugs   = { "PLA" = "plate", "SEG" = "signage", "ACC" = "accessory" };
		var byType  = {};
		var total   = 0;

		var records = super.service( "QuotationItemPrice" ).getDao().countMissingPriceByQuotationId( rc.id );
		for ( var record in records ) {
			var slug = StructKeyExists( slugs, record.type_id ) ? slugs[ record.type_id ] : LCase( record.type_id );
			byType[ slug ] = record.items;
			total += record.items;
		}

		result.setData( { "total" = total, "byType" = byType } );
		event.setValue( "result", result );
	}

	/**
	 * Cosa non è più a catalogo nella riga: in modifica la riga si salva così
	 * com'è, ma l'utente va avvisato.
	 */
	function notInCatalog( event, rc, prc ){
		var result = super.getResult();
		result.setData( { "labels" = super.service( "CatalogUsage" ).deletedInQuotationItem( rc.id ) } );
		event.setValue( "result", result );
	}

	function productItems( event, rc, prc ){
		var result = super.getResult();
		var memny  = super.getMementify();

		var quotationItemId = rc.id;

		var productItems = super.fire( "QuotationItemProductItem.list", { quotationItemId = quotationItemId } );

		var productItems = memny.convertList( productItems );

		result.setCount( Len( productItems ) );
		result.setData( productItems );

		event.setValue( "result", result );
	}

	function fruitProductItems( event, rc, prc ){
		var result = super.getResult();
		var memny  = super.getMementify();
		
		/*
			INFO:
			se id numerico: è stato già salvato nel db
			se id stringa: è stato agenerato da js per il dnd, record nuovo
		*/
		if( IsNumeric( rc.id ) ) {
			var quotationItemFruitId = rc.id;

			var productItems = super.fire( "QuotationItemProductItem.list", { quotationItemFruitId = quotationItemFruitId } );

			var productItems = memny.convertList( productItems );
			
			result.setCount( Len( productItems ) );
			result.setData( productItems );

		} else {
			result.setCount( 0 );
			result.setData( [] );
		}

		event.setValue( "result", result );
	}

	function calculate( event, rc, prc ){
		var json = DeserializeJSON( GetHTTPRequestData().content )

		try {
			if (rc.type == "signage") {
				var price = super.fire( 'QuotationItem.getSignagePricing', { 'data' = json } );
			} elseif(rc.type == "plate") {
				var price = super.fire( 'QuotationItem.getPlatePricing', { 'data' = json } );
			} else {
				var price = super.fire( 'QuotationItem.getPricing', { 'data' = json } );
			}
		} catch ( "ApirOne.ProductNotFound" e ) {
			// nessun prodotto per la combinazione scelta: messaggio al client, non un 500
			var result = super.getResult();
			result.setStatus( "INVALID" );
			result.setData( { "general" = [ { "message" = e.message } ] } );
			event.setValue( "result", result );
			return;
		} catch ( "ApirOne.NoPriceConfigured" e ) {
			// combinazione di attributi non ancora completa (es. finitura non selezionata):
			// messaggio al client, non un 500 - stesso trattamento di saveSignage()
			var result = super.getResult();
			result.setStatus( "INVALID" );
			result.setData( { "general" = [ { "message" = e.message } ] } );
			event.setValue( "result", result );
			return;
		}

		var memy = super.getMementify();
		var data = memy.convert( price );

		event.setValue( "result", data );
	}

	/*
		Verifica che ogni riga dell'albero attributi (placca/segnaletica/accessorio, o i
		frutti di una placca) abbia un valore selezionato. In precedenza una riga senza
		selezione veniva semplicemente saltata in fase di salvataggio (nessun
		quotationItemProductItem creato per quell'attributo): l'articolo veniva salvato
		comunque, con l'attributo mancante. Restituisce i nomi degli attributi non
		compilati (vuoto se tutto è a posto), da mostrare in un errore INVALID al client
		invece di salvare.
	*/
	/*
		Codice export effettivamente salvato in export_codes per la configurazione ATTUALE
		dell'item (chiave: quotation_items.hash, l'impronta ricalcolata ad ogni salvataggio -
		vedi QuotationItemService.update). Restituisce "" se l'item non ha hash (mai salvato)
		o se questa esatta configurazione non è mai stata esportata: la modale mostra in quel
		caso solo il codice calcolato al volo (AP.quotation.exportCode), senza quello salvato.
	*/
	/**
	 * Id del preventivo di una riga, per rejectIfQuotationLocked ( "" se la riga non esiste ).
	 */
	private String function quotationIdOfItem( required String quotationItemId ){
		if ( !Len( arguments.quotationItemId ) ) return "";
		var item = super.fire( "QuotationItem.get", [ arguments.quotationItemId ] );
		return ( !IsNull( item ) && !IsNull( item.getQuotation() ) ) ? item.getQuotation().getId() : "";
	}

	private String function getSavedExportCode( required quotationItem ){
		var itemHash = arguments.quotationItem.getHash();
		if ( IsNull( itemHash ) || !Len( itemHash ) ) {
			return "";
		}

		var exportCodesMap = super.fire( "ExportCode.mapByHashes", [ [ itemHash ] ] );

		return StructKeyExists( exportCodesMap, itemHash ) ? exportCodesMap[ itemHash ] : "";
	}

	private Array function findMissingProductItemAttributes( required Array productItemsData ){
		var missing = [];
		for ( var row in arguments.productItemsData ) {
			var selected = ArrayFilter( row.values, function( v ){ return v.selected; } );
			if ( !ArrayLen( selected ) ) {
				missing.append( row.attribute_name ?: ( row.attributeName ?: "attributo" ) );
			}
		}
		return missing;
	}

	private Struct function populatePositionBean(
			required Struct data
		){
		
		var position = super.bean( "QuotationZonePosition" );

		position.setId( data.id );
		position.setCode( data.code );
		//position.setName( data.name );

		return position;

	}

	private Struct function saveImage( 
			required String imageBase64, 
			required String quotationItemId,
			required String typeId
		){
		
		var tmpDir = getTempDir();

		// INFO: se uso il get qui il servizio crea la cache senza immagine
		// che sarà vuota quando viene serializzata
		//var item = service("QuotationItem").get( arguments.quotationItemId );

		//var type = "accessory";

		/*
		if( IsInstanceOf( item, "com.apirone.core.model.bean.QuotationItemPlate" ) ){
			type = "plate";
		}

		if( IsInstanceOf( item, "com.apirone.core.model.bean.QuotationItemSignage" ) ){
			type = "signage";
		}
		*/

		var fileName   = "preview_" & arguments.typeId & "_id_" & arguments.quotationItemId & ".png";
		var filePath   = tmpDir & "/" & fileName;
		var binaryData = ToBinary( arguments.imageBase64 );

		FileWrite( filePath, binaryData );

		var files = super.fire( "File.search", { quotationItemId = arguments.quotationItemId } );
		
		if ( Len( files.getData() ) ) {
			for ( var file in files.getData() ) {
				super.fire( "File.delete", { fileId = file.getId() } );
			}
		}

		var entity = super.bean( "Entity" );
		
		entity.setKey( "quotationItem.id" );
		entity.setValue( arguments.quotationItemId );

		var fileId = super.fire(
			"file.create",
			{
				filePath = filePath,
				typeId   = "default",
				kindId   = "quotationItem",
				entity   = entity
			}
		);

		var result = {	
			"fileId"   = fileId,
			"fileName" = fileName,
			"type" = arguments.typeId
		};

		return result;

	}

	function reorder( event, rc, prc ){
		var result = super.getResult();
		var json   = DeserializeJSON( GetHTTPRequestData().content );

		if ( IsArray( json.ids ?: "" ) && ArrayLen( json.ids ) && super.rejectIfQuotationLocked( event, quotationIdOfItem( json.ids[ 1 ] ) ) ) return;

		super.fire( "QuotationItem.reorder", { ids = json.ids } );

		result.setData( {} );
		event.setValue( "result", result );
	}

	/**
	 * Anteprima del codice export (codice articolo + codice variante a 10 caratteri)
	 * per la configurazione corrente di una modale articolo. Usa la stessa logica
	 * dell'esportazione (Quotation.composeExportCode) senza scrivere nulla, così
	 * l'utente vede subito se gli attributi "da esportare" entrano nei 10 caratteri.
	 * Body JSON: { productId, productItemIds: [], signage: bool, signageConfigItemId }
	 */
	function exportCodePreview( event, rc, prc ){
		var result = super.getResult();
		var json   = DeserializeJSON( GetHTTPRequestData().content );

		var data = {
			"success"             = false,
			"error"               = "",
			"articleCode"         = "",
			"variantCode"         = "",
			"name"                = "",
			"variantParts"        = [],
			"importantAttributes" = []
		};

		var productId = json.productId ?: "";

		if ( !Len( productId ) ) {
			data.error = "Prodotto non selezionato.";
			result.setData( data );
			event.setValue( "result", result );
			return;
		}

		var product = super.service( "Product" ).get( productId );
		if ( IsNull( product ) ) {
			data.error = "Prodotto non trovato.";
			result.setData( data );
			event.setValue( "result", result );
			return;
		}

		// Attributi "da esportare" del prodotto (id + codice): servono alla modale per evidenziarli
		var importantAttributes = product.getImportantAttributes();
		if ( !IsNull( importantAttributes ) ) {
			for ( var importantAttribute in importantAttributes ) {
				var attribute = super.service( "Attribute" ).get( attributeId = importantAttribute.getId() );
				if ( IsNull( attribute ) ) continue;
				ArrayAppend( data.importantAttributes, {
					"id"   = attribute.getId(),
					"code" = Trim( attribute.getCode() ?: "" )
				} );
			}
		}

		var quotationItemData = {
			"productId"    = product.getId(),
			"categoryId"   = IsNull( product.getCategory() ) ? "" : product.getCategory().getId(),
			"lineId"       = IsNull( product.getLine() )     ? "" : product.getLine().getId(),
			"modelId"      = IsNull( product.getModel() )    ? "" : product.getModel().getId(),
			"finishId"     = IsNull( product.getFinish() )   ? "" : product.getFinish().getId(),
			"productItems" = []
		};

		for ( var productItemId in ( json.productItemIds ?: [] ) ) {
			if ( Len( Trim( productItemId ) ) ) {
				ArrayAppend( quotationItemData.productItems, { "productItemId" = productItemId } );
			}
		}

		// Placche: l'orientamento (HOR/VER) apre il codice variante, come nell'export
		if ( Len( Trim( json.orientationId ?: "" ) ) ) {
			quotationItemData[ "orientationId" ] = Trim( json.orientationId );
		}

		// Segnaletica: la variante è font + corpo, esattamente come nell'export
		var isSignage = json.signage ?: false;
		if ( IsBoolean( isSignage ) && isSignage ) {
			quotationItemData[ "signageRows" ] = [];
			if ( Len( json.signageConfigItemId ?: "" ) ) {
				quotationItemData[ "signageConfigItemId" ] = json.signageConfigItemId;
			}
		}

		try {
			var outcome = super.service( "Quotation" ).composeExportCode( quotationItemData = quotationItemData );
			data.success      = outcome.success;
			data.error        = outcome.error;
			data.articleCode  = outcome.articleCode;
			data.variantCode  = outcome.variantCode;
			data.name         = outcome.name;
			data.variantParts = outcome.variantParts;
		} catch ( any e ) {
			data.error = "Codice non componibile: configurazione incompleta.";
		}

		result.setData( data );
		event.setValue( "result", result );
	}

	private String function getTypeIdBySlug(
			required String slug
		){

		var params = {
			"plate"     = "PLA",
			"accessory" = "ACC",
			"signage"   = "SEG",
			"article"   = "ART"
		}

		return params[ arguments.slug ];		

	}

}
