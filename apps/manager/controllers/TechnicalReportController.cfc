component extends="com.apirone.core.controller.AbsController" {

	// Mappa tipologia di stampa -> template. Le voci sono sempre unite per hash: il
	// secondo livello della dialog ( groupByCategory ) decide solo se spezzarle in
	// sezioni per tipo di categoria, non quale template usare.
	// La proforma riusa il template del preventivo: le differenze ( testata, validità,
	// pagamento, totale a pagare, avviso non fiscale ) sono condizionate lì su params.report.
	variables.REPORT_TEMPLATES = {
		'classic'   = 'print-quotation-classic',
		'zone'      = 'print-quotation-zone',
		'photo'     = 'print-quotation-photo-grouped',
		'technical' = 'print-quotation-technical-grouped',
		'proforma'  = 'print-quotation-classic'
	};

	// Prefisso del nome del PDF per tipo di stampa ( poi " <numero>_<versione>.pdf" )
	variables.REPORT_FILE_PREFIXES = {
		'classic'   = 'OFFERTA',
		'zone'      = 'OFFERTA_ZONE',
		'photo'     = 'OFFERTA_FOTO',
		'technical' = 'OFFERTA_TECNICA',
		'proforma'  = 'PROFORMA'
	};

	// Tela su cui il designer disegna l'anteprima della placca, in px: fissa, e
	// scambiata quando la placca è verticale. L'armatura ci sta dentro centrata, a
	// non più di PLATE_CANVAS_MAX_SCALE px per mm.
	// Sono le stesse di applyPlateCanvasSize in app-quotation-plate-vue.js: qui
	// servono per ritrovare la placca dentro all'anteprima già salvata, quindi se
	// cambiano di là vanno cambiate anche qui, o le stampe ritagliano storto.
	variables.PLATE_CANVAS_LONG_PX   = 1200;
	variables.PLATE_CANVAS_SHORT_PX  = 500;
	variables.PLATE_CANVAS_MAX_SCALE = 4;
	// Bordo da aggiungere all'armatura, per lato, quando in model_configs mancano le
	// misure della placca intera: le placche hanno di norma 2-3 cm di corpo attorno ai frutti.
	variables.PLATE_BORDER_FALLBACK_MM = 25;

	// Lato lungo, in px, della copia di stampa delle planimetrie ( vedi printSizedImagePath ).
	variables.PLANT_PRINT_MAX_PX = 1600;

	// Tipologie generabili anche su un preventivo non ancora calcolato, perché il
	// loro template non riporta prezzi né totali e quindi non legge quotationPrice.
	// Tenere allineato REPORTS_WITHOUT_PRICE in app-quotation-detail.js.
	variables.REPORTS_WITHOUT_PRICE = [ 'photo' ];

	function print(event, rc, prc) {

		var idPreventivo = rc.id;
		var printParams = {
			'report' = StructKeyExists( rc, 'report' ) ? rc.report : 'classic',
			'images' = printFlag( rc, 'images' ),
			'note' = printFlag( rc, 'note' ),
			'groupByCategory' = printFlag( rc, 'groupByCategory' ),
			'discounts' = printFlag( rc, 'discounts' ),
			'plants' = printFlag( rc, 'plants' ),
			'hideTotal' = printFlag( rc, 'hideTotal' ),
			// solo per la stampa per zona: accorpa le sottozone alla zona padre
			// invece di elencarle separate
			'grouped' = printFlag( rc, 'grouped' ),
			'progressivo' = StructKeyExists( rc, 'progressivo' ) ? Trim( rc.progressivo ) : '',
			'percentuale' = StructKeyExists( rc, 'percentuale' ) && IsNumeric( rc.percentuale ) ? Val( rc.percentuale ) : 0,
			// Alternativo alla percentuale: se valorizzato, l'anticipo è questo
			// importo e la percentuale viene ignorata.
			'importo' = StructKeyExists( rc, 'importo' ) && IsNumeric( rc.importo ) ? Val( rc.importo ) : 0
		}

		// La proforma non riporta mai le foto degli articoli.
		if ( printParams.report == 'proforma' ) {
			printParams.images = false;

			// Il progressivo identifica la proforma dentro al preventivo: se è già
			// stato usato la stampa va rifiutata, non deve sovrascrivere quella
			// precedente. Il controllo sta qui, prima di generare il PDF, così non
			// si lascia un file orfano su disco. Il vincolo unico sul DB resta come
			// ultima difesa contro due richieste in parallelo.
			var giaUsato = super.fire(
				"QuotationProforma.existsProgressivo",
				[ rc.id, printParams.progressivo ]
			);

			if ( giaUsato ) {
				Throw(
					message = "Progressivo proforma già utilizzato",
					detail  = "Per questo preventivo esiste già una proforma con progressivo "
						& printParams.progressivo
						& ". Indicane uno diverso: le proforma già emesse restano scaricabili dallo storico."
				);
			}
		}

		if ( !StructKeyExists( variables.REPORT_TEMPLATES, printParams.report ) ) {
			Throw( message = "Tipologia di stampa non riconosciuta: #printParams.report#" );
		}

		var templatePath = "report/template/" & variables.REPORT_TEMPLATES[ printParams.report ];

		prc.title = "Preventivo";

		var quotation = service("Quotation").get(quotationId = idPreventivo);
		// stampa aperta senza passare dal dettaglio: i totali si calcolano qui
		service("QuotationPrice").ensure( idPreventivo );
		var quotationPrice = service("QuotationPrice").getByQuotationId(quotationId = idPreventivo);

		var quoteObj = {
			quotation      = quotation,
			quotationPrice = quotationPrice,
			quotationItems = []
		};

		// Prima del calcolo il preventivo non ha un QuotationPrice. Le stampe che
		// riportano prezzi e totali non hanno i dati per esistere, la foto sì:
		// il suo template non legge mai quotationPrice.
		// Il modale già propone la sola foto in questo stato (vedi
		// app-quotation-detail.js), ma il controllo va tenuto anche qui perché
		// la stampa si apre con una GET e l'URL è manipolabile a mano.
		if ( IsNull( quotationPrice ) && !ArrayFindNoCase( variables.REPORTS_WITHOUT_PRICE, printParams.report ) ) {
			Throw(
				message = "
				Preventivo non calcolato"
			);
			return;
		}

		// La stampa per zona organizza le voci per ambiente e non per categoria,
		// quindi si prepara i dati per conto suo.
		if ( printParams.report == 'zone' ) {
			quoteObj = printZone( quoteObj, printParams );
		} else {
			quoteObj = printClassic( quoteObj, printParams );
		}

		var customerShippingProfile = {
			'name' = '',
			'via' = '',
			'cap' = '',
			'citta' = '',
			'provincia' = '',
			'paese' = ''
		};

		if (!isNull(quotation.getCustomer()) && !isNull(quotation.getCustomer().getShippingProfiles()) && quotation.getCustomer().getShippingProfiles().len() > 0) {
			customerShippingProfile = quotation.getCustomer().getShippingProfiles()[1];
		}

		```
		<cfquery name="total" datasource="apirone">
			SELECT SUM(amount) AS total
			FROM quotation_items
				INNER JOIN quotation_item_prices ON quotation_items.quotation_item_id = quotation_item_prices.quotation_item_id
			WHERE 1=1
				AND quotation_items.quotation_id = '#idPreventivo#'
		</cfquery>
		```
		quoteObj.totalSpent = total.total;

		var saveAsName = "#variables.REPORT_FILE_PREFIXES[ printParams.report ]# #quotation.getFileNumber()#.pdf";

		var params = {
			title   = "Preventivo",
			data    = quoteObj,
			params  = printParams,
			pdfArgs = {
				bookmark          = true,
				backgroundVisible = true,
				orientation       = "portrait",
				pageType          = "A4",
				overwrite         = true,
				fontEmbed         = true,
				saveAsName        = saveAsName
			}
		}

		// La proforma viene archiviata: è un documento che il cliente riceve e che
		// deve restare riscaricabile dallo storico (vedi quotation_proformas).
		// Le altre stampe restano volatili, si rigenerano quando servono.
		if ( printParams.report == 'proforma' ) {
			archiveProforma( event, templatePath, params, idPreventivo, printParams );
			return;
		}

		event.renderData( data = view( view = templatePath, args = params ), type = "PDF" );
	}

	/**
	 * Genera la proforma su file, ne registra la riga di storico e serve il PDF.
	 *
	 * cfdocument con "filename" scrive su disco e non produce output, quindi il
	 * documento va poi riletto e restituito: è il prezzo da pagare per averne una
	 * copia archiviata invece di un flusso che si perde.
	 */
	private void function archiveProforma(
		required Any event,
		required String templatePath,
		required Struct params,
		required String quotationId,
		required Struct printParams
	){
		var directory  = DateFormat( Now(), "yyyy/mm" );
		var destDir    = ExpandPath( "/../repository/public/media/quotation-proformas/#directory#" );
		var storedName = "proforma_#CreateUUID()#.pdf";
		var fullPath   = "#destDir#/#storedName#";

		DirectoryCreate( destDir, true, true );

		arguments.params.pdfArgs.filename = fullPath;

		// scrive il file; l'output della view è vuoto perché c'è filename
		view( view = arguments.templatePath, args = arguments.params );

		var proforma = super.bean( "QuotationProforma" );
		proforma.setQuotationId( arguments.quotationId );
		proforma.setProgressivo( arguments.printParams.progressivo );
		proforma.setStoredName( storedName );
		proforma.setDirectory( directory );

		// percentuale e importo sono alternativi: si registra solo quello indicato
		if ( Val( arguments.printParams.importo ) GT 0 ) {
			proforma.setImporto( arguments.printParams.importo );
		} else {
			proforma.setPercentuale( arguments.printParams.percentuale );
		}

		if ( !IsNull( session.user ) ) {
			proforma.setCreatedBy( session.user.getId() );
		}

		super.fire( "QuotationProforma.create", [ proforma ] );

		// Il PDF esiste già su disco: va servito così com'è.
		//
		// Non si usa renderData(): "pdf" convertirebbe l'HTML in PDF, e qui la
		// conversione è già stata fatta da cfdocument, mentre "binary" non è un
		// tipo valido in questa versione di ColdBox (JSON, JSONP, JSONT, XML,
		// WDDX, TEXT, PLAIN, PDF). Si scrive il file nella risposta e si dice a
		// ColdBox di non aggiungerci una view sopra.
		arguments.event.noRender();

		cfheader(
			name  = "Content-Disposition",
			value = 'inline; filename="#arguments.params.pdfArgs.saveAsName#"'
		);

		cfcontent( type = "application/pdf", file = fullPath, reset = true );
	}

	/**
	 * Dati della stampa per zona: le voci raggruppate per ambiente invece che per
	 * categoria. Le zone padre precedono le proprie sottozone; con printParams.grouped
	 * le sottozone non compaiono da sole e le loro voci confluiscono nella zona padre.
	 * Le righe articolo ( servizi ) vengono estratte dalla zona "Non assegnato".
	 */
	function printZone( quoteObj, printParams ) {
		var quotation = quoteObj.quotation;
		var idPreventivo = quotation.getId();

		//ordiniamo le zone in modo da avere prima quelle padre
		var zones = super.fire('QuotationZone.list', [ 'quotationId' = idPreventivo, 'orderby' = [ { field = "quotationItemZone.originId", dir = "desc" } ] ]);

		var sortedZones = [];
		for (var zone in zones) {
			if (zone.getName() == 'Non assegnato') {
				var unassignedZone = zone;
				continue;
			}
			//aggiungiamo le zone figlie ad ogni zona padre
			if (isNull(zone.getOrigin())) {
				sortedZones.add(zone)
				var subZones = super.fire('QuotationZone.list', [ 'quotationId' = idPreventivo, 'originId' = zone.getId() ])
				for ( var subZone in subZones ) {
					sortedZones.add(subZone)
				}
			}
		}
		// "Non assegnato" puo' non esserci: in quel caso non si aggiunge nulla
		if ( !IsNull( unassignedZone ) ) {
			sortedZones.add( unassignedZone );
		}
		var articleItems = [];
		for ( var i = 1; i LTE ArrayLen( sortedZones ); i++ ) {
			var zone = sortedZones[i];
			//se stampa raggruppata
			if (printParams.grouped) {
				if (!isNull((zone.getOrigin()))) {
					continue;
				}
				//delle zone padre aggiungiamo gli items
				var zoneItems = super.fire('QuotationItem.list', [ 'quotationId' = idPreventivo, 'quotationZoneId' = zone.getId() ]);
				var subZones = zones.filter(function(item) {
					return !isNull(item.getOrigin()) && item.getOrigin().getId() == zone.getId()
				})
				//aggiungiamo gli items delle zone figlie
				for ( var subZone in subZones ) {
					var thisSubZoneItems = super.fire('QuotationItem.list', [ 'quotationId' = idPreventivo, 'quotationZoneId' = subZone.getId() ]);
					arrayAppend(zoneItems, thisSubZoneItems, true);
				}
				//se stampa non raggruppata ad ogni zona o sottozona assegnamo gli items
			} else {
				var zoneItems = super.fire('QuotationItem.list', [ 'quotationId' = idPreventivo, 'quotationZoneId' = zone.getId() ]);
			}
			if (zone.getName() == 'Non assegnato') {
				articleItems = zoneItems.filter(function(item) {
					return !isNull(item.getArticle())
				});
			}
			zoneItems = zoneItems.filter(function(item) {
				return isNull(item.getArticle())
			})
			zone.zoneItems = zoneItems;
		}

		if (printParams.grouped) {
			sortedZones = sortedZones.filter(function(item) {
				return isNull(item.getOrigin())
			})
		}

		quoteObj.zones = sortedZones;
		quoteObj.articleItems = articleItems;

		var allItems = [];
		for ( var z in sortedZones ) {
			arrayAppend( allItems, z.zoneItems, true );
		}
		quoteObj.modelConfigMap = buildModelConfigMap( allItems );
		quoteObj.plateImages    = buildPlateCrops( allItems, quoteObj.modelConfigMap );

		// Piante: ogni zona stampa la propria prima dei suoi articoli. Nella stampa
		// raggruppata la zona padre porta anche quelle delle sue sottozone, i cui
		// articoli confluiscono già nel suo elenco.
		for ( var z in sortedZones ) {
			z.plants = [];
		}

		if ( printParams.plants ?: false ) {
			var allPlants = buildPlants( idPreventivo, allItems );

			for ( var z in sortedZones ) {
				for ( var plant in allPlants ) {
					if ( plant.zoneId == z.getId() || ( printParams.grouped && plant.originId == z.getId() ) ) {
						ArrayAppend( z.plants, plant );
					}
				}
			}
		}

		return quoteObj;
	}


	function printClassic( quoteObj, printParams ) {
		var quotation = quoteObj.quotation;
		var idPreventivo = quotation.getId();
		var items = super.fire('QuotationItem.list', [ 'quotationId' = idPreventivo ]);
		var productItems = items.filter(function(item) {
			return !isNull(item.getProduct())
		});
		var articleItems = items.filter(function(item) {
			return !isNull(item.getArticle())
		});
		items = groupItems(productItems);
		quoteObj.items = items;
		quoteObj.itemGroups = groupByCategoryType( items, printParams.groupByCategory ?: false );
		quoteObj.articleItems = articleItems;

		// Codici export delle voci, risolti qui in una sola query: i template ne
		// hanno bisogno riga per riga e non devono interrogare il database.
		// Chiave = hash della voce; le voci senza codice semplicemente non ci sono.
		// Niente operatori ?: qui dentro: dentro a un ciclo fanno fallire la
		// compilazione dell'intero componente su questo Lucee.
		var hashes = [];
		for ( var thisItem in productItems ) {
			var thisHash = thisItem.getHash();
			if ( !IsNull( thisHash ) && Len( thisHash ) ) {
				hashes.add( thisHash );
			}
		}
		quoteObj.exportCodes = super.fire( "ExportCode.mapByHashes", [ hashes ] );

		// Preventivo non ancora esportato: il codice si ricompone al volo con la
		// stessa logica dell'esportazione (Quotation.composeExportCode), senza
		// scrivere nulla in export_codes. Il codice salvato resta prioritario.
		var missingHashes = [];
		for ( var thisHash in hashes ) {
			if ( !StructKeyExists( quoteObj.exportCodes, thisHash ) ) {
				missingHashes.add( thisHash );
			}
		}

		if ( ArrayLen( missingHashes ) ) {
			var computedCodes = super.fire( "Quotation.mapComputedExportCodesByHashes", [ missingHashes ] );
			for ( var thisHash in computedCodes ) {
				quoteObj.exportCodes[ thisHash ] = computedCodes[ thisHash ];
			}
		}

		// Piante: in testa al documento quando le voci sono in elenco unico,
		// dentro ogni sezione quando sono separate per categoria.
		quoteObj.plants = [];
		for ( var group in quoteObj.itemGroups ) {
			group.plants = [];
		}

		// Le piante si costruiscono una volta sola dalle voci già lette; le sezioni per
		// categoria ne prendono solo i marker del proprio tipo.
		if ( printParams.plants ?: false ) {
			var allPlants = buildPlants( idPreventivo, productItems );

			if ( printParams.groupByCategory ?: false ) {
				for ( var group in quoteObj.itemGroups ) {
					group.plants = plantsOfCategoryType( allPlants, group.id );
				}
			} else {
				quoteObj.plants = allPlants;
			}
		}

		var allItems = [];
		for ( var hashKey in quoteObj.items ) {
			arrayAppend( allItems, quoteObj.items[hashKey].item );
		}
		quoteObj.modelConfigMap = buildModelConfigMap( allItems );
		quoteObj.plateImages    = buildPlateCrops( allItems, quoteObj.modelConfigMap );

		return quoteObj;
	}


	private Boolean function printFlag( required Struct rc, required String key ){
		return StructKeyExists( arguments.rc, arguments.key ) && arguments.rc[ arguments.key ] == 'true';
	}

	/**
	 * Anteprime delle placche ritagliate sull'armatura, con il loro ingombro reale.
	 *
	 * L'anteprima salvata dal designer è una tela fissa ( 1200x500 px, scambiata se
	 * la placca è verticale ) con l'armatura disegnata al centro: il contorno è
	 * fondo, non prodotto. Stamparla intera spreca foglio, e siccome la tela cambia
	 * forma con l'orientamento mentre la placca no, la stessa placca girata usciva
	 * a una scala diversa.
	 *
	 * Qui si ricostruisce quel calcolo per ritagliare via il contorno e sapere
	 * quanti millimetri misura davvero il ritaglio. L'armatura si ritrova dal
	 * codice del modello, come fa il designer ( loadFrame in
	 * app-quotation-plate-vue.js ): non esiste una chiave esterna che la leghi alla
	 * voce di preventivo.
	 *
	 * Restituisce le voci ritagliate indicizzate per id, più l'ingombro della più
	 * grande: serve alla stampa per scegliere un unico fattore mm -> cm. Le voci
	 * che non si riescono a ritagliare non ci sono, e la stampa le adatta al box
	 * com'è sempre stato.
	 */
	private Struct function buildPlateCrops( required Array items, Struct modelConfigMap = {} ){
		var crops  = { "byItem" = {}, "maxWidthMm" = 0, "maxHeightMm" = 0 };
		var frames = {};

		for ( var item in arguments.items ) {
			if ( !IsInstanceOf( item, "com.apirone.core.model.bean.QuotationItemPlate" ) ) continue;
			if ( IsNull( item.getImage() ) ) continue;

			// immagine caricata a mano al posto del disegno: non è in scala
			if ( !IsNull( item.getCustomImage() ) && item.getCustomImage() ) continue;

			if ( IsNull( item.getProduct() ) || IsNull( item.getProduct().getModel() ) ) continue;

			var modelCode = item.getProduct().getModel().getCode();

			if ( !StructKeyExists( frames, modelCode ) ) {
				// il wrapper serve perché una chiave a null in Lucee non si crea,
				// e senza si riproverebbe la stessa lettura per ogni voce
				var found = service( "Frame" ).getByCode( modelCode );
				frames[ modelCode ] = IsNull( found ) ? { "ok" = false } : { "ok" = true, "frame" = found };
			}

			if ( !frames[ modelCode ].ok ) continue;

			var orientationId = "";
			if ( !IsNull( item.getFrame() ) && !IsNull( item.getFrame().getOrientation() ) ) {
				orientationId = item.getFrame().getOrientation().getId();
			}

			var overrides = IsNull( item.getBlockOrientations() ) ? "" : item.getBlockOrientations();

			var geometry = service( "Frame" ).layout(
				frame             = frames[ modelCode ].frame,
				orientationId     = orientationId,
				blockOrientations = overrides
			);

			// armatura senza blocchi ( le legacy su file JSON ): non se ne conosce
			// l'ingombro in millimetri, quindi niente ritaglio
			if ( geometry.width LTE 0 || geometry.height LTE 0 ) continue;

			// Ingombro della placca intera, non della sola armatura: le immagini prodotto
			// sono in scala (stessi px/mm dell'armatura) e disegnano tutto il corpo della
			// placca centrato nella tela, quindi si può ritagliare la placca com'è davvero,
			// col bordo attorno ai frutti. Le misure stanno in model_configs (orizzontali);
			// se mancano si allarga l'armatura di un bordo standard per lato.
			var plateWidth  = 0;
			var plateHeight = 0;
			var productId   = item.getProduct().getId();
			if ( StructKeyExists( arguments.modelConfigMap, productId ) ) {
				var modelConfig = arguments.modelConfigMap[ productId ];
				plateWidth  = Val( modelConfig.getWidth() );
				plateHeight = Val( modelConfig.getHeight() );
				if ( geometry.orientationId EQ "VER" ) {
					var swap    = plateWidth;
					plateWidth  = plateHeight;
					plateHeight = swap;
				}
			}
			if ( plateWidth LTE 0 || plateHeight LTE 0 ) {
				plateWidth  = geometry.width  + 2 * variables.PLATE_BORDER_FALLBACK_MM;
				plateHeight = geometry.height + 2 * variables.PLATE_BORDER_FALLBACK_MM;
			}
			// la placca non può essere più piccola dell'armatura
			geometry[ "plateWidth" ]  = Max( plateWidth,  geometry.width );
			geometry[ "plateHeight" ] = Max( plateHeight, geometry.height );

			var path = cropPlateImage( item.getImage(), geometry );

			if ( !Len( path ) ) continue;

			crops.byItem[ item.getId() ] = {
				"path"     = path,
				"widthMm"  = geometry.plateWidth,
				"heightMm" = geometry.plateHeight
			};

			crops.maxWidthMm  = Max( crops.maxWidthMm,  geometry.plateWidth );
			crops.maxHeightMm = Max( crops.maxHeightMm, geometry.plateHeight );
		}

		return crops;
	}

	/**
	 * Ritaglia l'anteprima sulla placca intera ( armatura più bordo ) e restituisce il percorso del PNG.
	 *
	 * Il file prende il nome dal ritaglio e viene riusato: la stessa placca ricorre
	 * più volte nello stesso documento e fra una stampa e l'altra.
	 *
	 * Niente ImageWrite sul file temporaneo: il formato lo decide dall'estensione e
	 * un ".tmp" non lo saprebbe scrivere, quindi si passa da ImageIO come per i
	 * marker delle piante.
	 *
	 * @return percorso del PNG ritagliato, stringa vuota se non si riesce ( in quel
	 *         caso la stampa ripiega sull'immagine intera )
	 */
	private String function cropPlateImage( required any image, required Struct geometry ){
		try {
			var isVertical = arguments.geometry.orientationId EQ "VER";
			var canvasW    = isVertical ? variables.PLATE_CANVAS_SHORT_PX : variables.PLATE_CANVAS_LONG_PX;
			var canvasH    = isVertical ? variables.PLATE_CANVAS_LONG_PX  : variables.PLATE_CANVAS_SHORT_PX;

			// stessa scala di disegno del designer: la placca entra nella tela, e
			// comunque non oltre il tetto di px per mm
			var displayScale = Min(
				Min( canvasW / arguments.geometry.width, canvasH / arguments.geometry.height ),
				variables.PLATE_CANVAS_MAX_SCALE
			);

			// rettangolo da ritagliare: la placca intera ( plateWidth/plateHeight, calcolati
			// da buildPlateCrops ), centrata nella tela come l'armatura e comunque dentro la tela
			var plateW = Min( canvasW, ( arguments.geometry.plateWidth  ?: arguments.geometry.width )  * displayScale );
			var plateH = Min( canvasH, ( arguments.geometry.plateHeight ?: arguments.geometry.height ) * displayScale );

			var storedW = IsNull( arguments.image.getWidth() )  ? 0 : Val( arguments.image.getWidth() );
			var storedH = IsNull( arguments.image.getHeight() ) ? 0 : Val( arguments.image.getHeight() );

			if ( storedW LTE 0 || storedH LTE 0 ) return "";

			// L'immagine deve essere quella tela, riconoscibile dalle proporzioni: fra
			// le anteprime salvate ce ne sono di vecchie, fatte quando la tela si
			// prendeva le misure dal server ( es. 952x656 invece di 1200x500 ), e su
			// quelle il ritaglio cadrebbe nel punto sbagliato tagliando la placca.
			// Meglio lasciarle intere: la stampa le inscrive nel box come sempre.
			if ( Abs( ( storedW / storedH ) - ( canvasW / canvasH ) ) GT ( canvasW / canvasH ) * 0.02 ) {
				return "";
			}

			// il PNG salvato non è grande quanto la tela: il salvataggio lo riduce a
			// 800px di larghezza. Il rapporto riporta le coordinate sui pixel veri.
			var ratio = storedW / canvasW;

			var x = Round( Max( 0, ( canvasW - plateW ) / 2 ) * ratio );
			var y = Round( Max( 0, ( canvasH - plateH ) / 2 ) * ratio );
			var w = Min( Round( plateW * ratio ), storedW - x );
			var h = Min( Round( plateH * ratio ), storedH - y );

			if ( w LTE 0 || h LTE 0 ) return "";

			var source = arguments.image.getPath();

			if ( !FileExists( source ) ) return "";

			var dir  = GetTempDirectory() & "apirone-plate-crops";
			var path = dir & "/" & arguments.image.getId() & "_" & x & "-" & y & "-" & w & "x" & h & ".png";

			if ( FileExists( path ) ) return path;

			if ( !DirectoryExists( dir ) ) {
				DirectoryCreate( dir, true );
			}

			var cropped = ImageRead( source );
			ImageCrop( cropped, x, y, w, h );

			// scrittura su nome temporaneo e rinomina: due stampe in parallelo
			// possono chiedere lo stesso ritaglio
			var tmpPath = path & "." & CreateUUID() & ".tmp";

			CreateObject( "java", "javax.imageio.ImageIO" ).write(
				cropped.getBufferedImage(), "png", CreateObject( "java", "java.io.File" ).init( tmpPath )
			);

			if ( FileExists( path ) ) {
				FileDelete( tmpPath );
			} else {
				FileMove( tmpPath, path );
			}

			return path;
		} catch ( any error ) {
			// l'immagine intera è meglio di una stampa che non esce
			return "";
		}
	}

	private Struct function buildModelConfigMap( required Array items ){
		var map = {};
		for ( var item in arguments.items ) {
			if ( isNull( item.getProduct() ) ) continue;
			var productId = item.getProduct().getId();
			if ( StructKeyExists( map, productId ) ) continue;
			var prod = item.getProduct();
			if ( isNull( prod.getModel() ) || isNull( prod.getLine() ) || isNull( prod.getCategory() ) ) continue;
			var configs = service( "ModelConfig" ).list(
				modelId           = prod.getModel().getId(),
				lineId            = prod.getLine().getId(),
				productCategoryId = prod.getCategory().getId()
			);
			if ( ArrayLen( configs ) ) {
				map[ productId ] = configs[1];
			}
		}
		return map;
	}

	/**
	 * Raggruppa le righe già unite per hash nei tipi di categoria prodotto
	 * ( Placche, Frutti, Segnaletica, Accessori ), nell'ordine di
	 * product_category_types.orderby. Le righe senza tipo finiscono in coda.
	 *
	 * Con byCategory = false restituisce un gruppo unico e senza nome, con tutte le
	 * righe ordinate per hash: stessa stampa, senza le intestazioni di sezione.
	 *
	 * NB: groupItems() restituisce una Struct, che non ha ordine: l'ordinamento
	 * va quindi ricostruito qui, non prima.
	 *
	 * @return Array di { id, name, orderby, items }, items ordinati per hash
	 */
	private Array function groupByCategoryType( required Struct groupedItems, required Boolean byCategory ){
		if ( !arguments.byCategory ) {
			var flat = [];
			for ( var hashKey in arguments.groupedItems ) {
				ArrayAppend( flat, arguments.groupedItems[ hashKey ] );
			}
			ArraySort( flat, function( a, b ){
				return Compare( itemSortKey( a ), itemSortKey( b ) );
			} );

			return [ { 'id' = '', 'name' = '', 'orderby' = 0, 'items' = flat } ];
		}

		var buckets = {};

		for ( var hashKey in arguments.groupedItems ) {
			var entry  = arguments.groupedItems[ hashKey ];
			var type   = categoryTypeOf( entry.item );
			var typeId = IsNull( type ) ? "" : type.getId();

			if ( !StructKeyExists( buckets, typeId ) ) {
				var orderby = 999999;
				var name    = "";

				if ( !IsNull( type ) ) {
					if ( !IsNull( type.getName() ) ) name = type.getName();
					if ( !IsNull( type.getOrderby() ) ) orderby = type.getOrderby();
				}

				buckets[ typeId ] = { 'id' = typeId, 'name' = name, 'orderby' = orderby, 'items' = [] };
			}

			ArrayAppend( buckets[ typeId ].items, entry );
		}

		var groups = [];
		for ( var key in buckets ) {
			ArrayAppend( groups, buckets[ key ] );
		}

		ArraySort( groups, function( a, b ){
			if ( a.orderby NEQ b.orderby ) return a.orderby LT b.orderby ? -1 : 1;
			return Compare( a.name, b.name );
		} );

		for ( var group in groups ) {
			ArraySort( group.items, function( a, b ){
				return Compare( itemSortKey( a ), itemSortKey( b ) );
			} );
		}

		return groups;
	}

	/**
	 * Piante da stampare: una per ogni zona che ha una planimetria e almeno un marker
	 * visibile. Ogni marker porta il tipo di categoria della sua voce, così le sezioni
	 * per categoria si ricavano con plantsOfCategoryType() senza rileggere niente.
	 *
	 * Le voci sono quelle già lette dalla stampa ( con la loro zona ): rileggerle zona
	 * per zona, e per ogni sezione, costava più di un secondo.
	 *
	 * Il disegno è ricostruito dai dati ( coordinate 0-1, angolo, moltiplicatore ) e non
	 * dalla cattura html2canvas della pagina Posizioni in pianta, che vive nel browser.
	 *
	 * @return Array di { zoneName, imagePath, markers = [ { x, y, size, angle, color, label, typeId } ] }
	 */
	private Array function buildPlants( required String quotationId, required Array items ){
		var plants      = [];
		var zones       = super.fire( 'QuotationZone.list', [ 'quotationId' = arguments.quotationId ] );
		var itemsByZone = {};

		for ( var thisItem in arguments.items ) {
			var thisZone = thisItem.getQuotationZone();
			if ( IsNull( thisZone ) ) continue;

			if ( !StructKeyExists( itemsByZone, thisZone.getId() ) ) {
				itemsByZone[ thisZone.getId() ] = [];
			}
			ArrayAppend( itemsByZone[ thisZone.getId() ], thisItem );
		}

		for ( var zone in zones ) {
			if ( IsNull( zone.getImage() ) ) continue;
			if ( !StructKeyExists( itemsByZone, zone.getId() ) ) continue;

			var markers = [];

			for ( var item in itemsByZone[ zone.getId() ] ) {
				if ( IsNull( item.getProduct() ) || IsNull( item.getPositions() ) ) continue;

				var type   = categoryTypeOf( item );
				var typeId = IsNull( type ) ? "" : type.getId();

				for ( var pos in item.getPositions() ) {
					if ( IsNull( pos.getVisible() ) || !pos.getVisible() ) continue;

					var size  = Round( 35 * ( Val( pos.getSizeMultiplier() ?: 100 ) / 100 ) );
					// +135 come a schermo: porta lo zero dell'angolo salvato a
					// coincidere con l'orientamento di riferimento della goccia
					var angle = Val( pos.getAngle() ?: 0 ) + 135;
					var color = markerColor( item );

					ArrayAppend( markers, {
						'x'     = Val( pos.getCoordinateX() ) * 100,
						'y'     = Val( pos.getCoordinateY() ) * 100,
						'size'  = size,
						'angle' = angle,
						'color' = color,
						'pin'    = pinImagePath( size, angle, color ),
						'label'  = markerLabel( item ),
						'typeId' = typeId
					} );
				}
			}

			if ( ArrayLen( markers ) ) {
				// Il box di disegno va dato in centimetri: cfdocument non applica
				// max-width/max-height, e senza dimensioni esplicite il posizionamento
				// percentuale dei marker non avrebbe un riferimento.
				var imgWidth  = Val( zone.getImage().getWidth() ?: 0 );
				var imgHeight = Val( zone.getImage().getHeight() ?: 0 );
				var boxWidth  = 17;
				var boxHeight = imgWidth GT 0 && imgHeight GT 0 ? boxWidth * imgHeight / imgWidth : boxWidth * 0.75;

				// non oltre l'altezza utile della pagina
				if ( boxHeight GT 20 ) {
					boxWidth  = boxWidth * 20 / boxHeight;
					boxHeight = 20;
				}

				ArrayAppend( plants, {
					'zoneId'    = zone.getId(),
					'originId'  = IsNull( zone.getOrigin() ) ? "" : zone.getOrigin().getId(),
					'zoneName'  = zone.getName(),
					'imagePath' = plantImagePath( zone.getImage() ),
					'boxWidth'  = NumberFormat( boxWidth, "9.99" ),
					'boxHeight' = NumberFormat( boxHeight, "9.99" ),
					'markers'   = markers
				} );
			}
		}

		return plants;
	}

	/**
	 * Piante di una sezione di categoria: stesse piante, solo i marker di quel tipo.
	 * Le zone senza marker del tipo spariscono.
	 */
	private Array function plantsOfCategoryType( required Array plants, required String categoryTypeId ){
		var result = [];

		for ( var plant in arguments.plants ) {
			var markers = [];

			for ( var marker in plant.markers ) {
				if ( marker.typeId == arguments.categoryTypeId ) {
					ArrayAppend( markers, marker );
				}
			}

			if ( ArrayLen( markers ) ) {
				var copy = StructCopy( plant );
				copy.markers = markers;
				ArrayAppend( result, copy );
			}
		}

		return result;
	}

	/**
	 * Percorso su disco della planimetria, per cfdocument.
	 *
	 * Non si usa File.getPath() perché applica ExpandPath due volte e finisce per
	 * ri-radicare un percorso già assoluto sotto la webroot ( /app/repository/... ).
	 * Il repository media sta fuori dalla webroot in produzione e dentro /public in
	 * sviluppo, quindi si prova l'uno e poi l'altro; in ultima istanza si ripiega
	 * sull'URI http, che cfdocument sa scaricare.
	 */
	private String function plantImagePath( required any file ){
		var relative = arguments.file.getRelativePath();

		for ( var root in [ ExpandPath( "/../repository/public" ), ExpandPath( "/public" ) ] ) {
			var candidate = root & relative;

			if ( FileExists( candidate ) ) {
				return printSizedImagePath( candidate );
			}
		}

		return arguments.file.getUri();
	}

	/**
	 * Copia ridotta della planimetria per la stampa.
	 *
	 * La pianta occupa al massimo 17 cm: l'originale ( spesso 3000 px e oltre, più di
	 * un MB ) finiva intero nel PDF, appesantendo documento e conversione. A
	 * PLANT_PRINT_MAX_PX sul lato lungo restano circa 240 dpi, più che sufficienti.
	 *
	 * La copia sta nella cartella temporanea, con nome ricavato da percorso, data di
	 * modifica e misura: si rigenera da sola se la planimetria cambia, e fra una
	 * stampa e l'altra si riusa. Ridimensionamento con Graphics2D e non con
	 * ImageResize, per lo stesso problema JAI descritto in pinImagePath().
	 *
	 * @return percorso della copia ridotta; l'originale se è già abbastanza piccolo
	 *         o se la copia non si riesce a generare
	 */
	private String function printSizedImagePath( required String sourcePath ){
		try {
			var source   = CreateObject( "java", "java.io.File" ).init( arguments.sourcePath );
			var maxPx    = variables.PLANT_PRINT_MAX_PX;
			var dir      = GetTempDirectory() & "apirone-plant-images";
			var name     = "plant_" & Hash( arguments.sourcePath & "|" & source.lastModified(), "MD5" ) & "_" & maxPx & ".jpg";
			var path     = dir & "/" & name;

			if ( FileExists( path ) ) {
				return path;
			}

			var imageIO  = CreateObject( "java", "javax.imageio.ImageIO" );
			var original = imageIO.read( source );

			if ( IsNull( original ) ) {
				return arguments.sourcePath;
			}

			var width  = original.getWidth();
			var height = original.getHeight();
			var scale  = maxPx / Max( width, height );

			if ( scale GTE 1 ) {
				return arguments.sourcePath;
			}

			var newWidth  = Max( 1, Round( width * scale ) );
			var newHeight = Max( 1, Round( height * scale ) );

			var resized = CreateObject( "java", "java.awt.image.BufferedImage" ).init(
				JavaCast( "int", newWidth ),
				JavaCast( "int", newHeight ),
				JavaCast( "int", 1 )   // TYPE_INT_RGB: il JPEG non ha trasparenza
			);

			var gfx   = resized.createGraphics();
			var hints = CreateObject( "java", "java.awt.RenderingHints" );

			gfx.setRenderingHint( hints.KEY_INTERPOLATION, hints.VALUE_INTERPOLATION_BILINEAR );
			gfx.setRenderingHint( hints.KEY_RENDERING, hints.VALUE_RENDER_QUALITY );
			// fondo bianco: un PNG con trasparenza diventerebbe nero in JPEG
			gfx.setColor( CreateObject( "java", "java.awt.Color" ).WHITE );
			gfx.fillRect( 0, 0, JavaCast( "int", newWidth ), JavaCast( "int", newHeight ) );
			gfx.drawImage( original, 0, 0, JavaCast( "int", newWidth ), JavaCast( "int", newHeight ), JavaCast( "null", "" ) );
			gfx.dispose();

			if ( !DirectoryExists( dir ) ) {
				DirectoryCreate( dir, true );
			}

			// scrittura su nome temporaneo e rinomina, come per i pin
			var tmpPath = path & "." & CreateUUID() & ".tmp";

			imageIO.write( resized, "jpg", CreateObject( "java", "java.io.File" ).init( tmpPath ) );

			if ( FileExists( path ) ) {
				FileDelete( tmpPath );
			} else {
				FileMove( tmpPath, path );
			}

			return path;
		} catch ( any error ) {
			// meglio la planimetria intera che una pianta mancante
			return arguments.sourcePath;
		}
	}

	/**
	 * Marker della pianta come PNG già ruotato, da stampare al posto del div.
	 *
	 * cfdocument ignora "transform: rotate()": provando quattro pin a 0, 45, 90 e
	 * 180 gradi escono tutti con la punta nella stessa direzione, quindi la
	 * rotazione impostata in "Posizioni in pianta" andava persa in stampa mentre
	 * dimensione, colore e posizione arrivavano corrette. La goccia si disegna
	 * quindi con Graphics2D già orientata.
	 *
	 * Niente ImageRotate: su questo JDK la rotazione JAI di Lucee fallisce con
	 * IllegalAccessError su sun.awt.image.
	 *
	 * Il file prende il nome dai suoi parametri e viene riusato: gli stessi marker
	 * ricorrono più volte nello stesso documento e fra una stampa e l'altra.
	 *
	 * @return percorso del PNG, stringa vuota se non si riesce a generarlo ( in
	 *         quel caso la stampa ripiega sul marker non ruotato )
	 */
	private String function pinImagePath(
		required Numeric size,
		required Numeric angle,
		required String color
	){
		try {
			var pinSize = Max( 4, Round( arguments.size ) );
			// la punta della goccia sta su un angolo del quadrato, quindi ruotando
			// esce dal quadrato stesso: la tela va allargata o si taglierebbe
			var canvas  = Ceiling( pinSize * 1.6 );
			var deg     = ( ( Round( arguments.angle ) % 360 ) + 360 ) % 360;
			var rgb     = ReMatch( "\d+", arguments.color );

			if ( ArrayLen( rgb ) LT 3 ) {
				return "";
			}

			var dir  = GetTempDirectory() & "apirone-plant-pins";
			var name = "pin_" & pinSize & "_" & deg & "_" & rgb[ 1 ] & "-" & rgb[ 2 ] & "-" & rgb[ 3 ] & ".png";
			var path = dir & "/" & name;

			if ( FileExists( path ) ) {
				return path;
			}

			if ( !DirectoryExists( dir ) ) {
				DirectoryCreate( dir, true );
			}

			var off    = Int( ( canvas - pinSize ) / 2 );
			var half   = Int( pinSize / 2 );
			var center = canvas / 2;

			var image = CreateObject( "java", "java.awt.image.BufferedImage" ).init(
				JavaCast( "int", canvas ),
				JavaCast( "int", canvas ),
				JavaCast( "int", 2 )   // TYPE_INT_ARGB: fondo trasparente
			);

			var gfx   = image.createGraphics();
			var hints = CreateObject( "java", "java.awt.RenderingHints" );

			gfx.setRenderingHint( hints.KEY_ANTIALIASING, hints.VALUE_ANTIALIAS_ON );
			gfx.setColor( CreateObject( "java", "java.awt.Color" ).init(
				JavaCast( "int", Val( rgb[ 1 ] ) ),
				JavaCast( "int", Val( rgb[ 2 ] ) ),
				JavaCast( "int", Val( rgb[ 3 ] ) )
			) );

			// senso orario come la rotate() del CSS, così l'angolo salvato vale
			// identico a schermo e in stampa
			gfx.rotate(
				JavaCast( "double", deg * Pi() / 180 ),
				JavaCast( "double", center ),
				JavaCast( "double", center )
			);

			// border-radius: 50% 50% 50% 0 = cerchio pieno più il quadrante in
			// basso a sinistra, che resta a spigolo e fa la punta
			gfx.fillOval(
				JavaCast( "int", off ), JavaCast( "int", off ),
				JavaCast( "int", pinSize ), JavaCast( "int", pinSize )
			);
			gfx.fillRect(
				JavaCast( "int", off ), JavaCast( "int", off + half ),
				JavaCast( "int", half ), JavaCast( "int", half )
			);
			gfx.dispose();

			// scrittura su nome temporaneo e rinomina: due stampe in parallelo
			// possono chiedere lo stesso marker
			var tmpPath = path & "." & CreateUUID() & ".tmp";

			CreateObject( "java", "javax.imageio.ImageIO" ).write(
				image, "png", CreateObject( "java", "java.io.File" ).init( tmpPath )
			);

			if ( FileExists( path ) ) {
				FileDelete( tmpPath );
			} else {
				FileMove( tmpPath, path );
			}

			return path;
		} catch ( any error ) {
			// il marker non ruotato è meglio di una stampa che non esce
			return "";
		}
	}

	// Stessa scala colori di getColor() in app-quotation-plant-positions.js.
	private String function markerColor( required any quotationItem ){
		var product  = arguments.quotationItem.getProduct();
		var category = NullValue();

		if ( !IsNull( product ) && !IsNull( product.getCatalogBundle() ) && !IsNull( product.getCatalogBundle().getCategory() ) ) {
			category = product.getCatalogBundle().getCategory();
		} else if ( !IsNull( product ) && !IsNull( product.getCategory() ) ) {
			category = product.getCategory();
		}

		if ( IsNull( category ) ) return "rgb(232, 93, 68)";

		var typeId  = !IsNull( category.getType() ) ? category.getType().getId() : "";
		var catName = UCase( category.getName() ?: "" );

		if ( typeId == "PLA" ) return "rgb(68, 130, 232)";
		if ( catName CONTAINS "EMERGENZA" ) return "rgb(220, 30, 30)";
		if ( catName CONTAINS "INTERNA" ) return "rgb(34, 139, 34)";
		if ( catName CONTAINS "ESTERNA" ) return "rgb(139, 90, 43)";

		return "rgb(128, 0, 128)";
	}

	// Come formatLabelText(): codice posizione troncato a 3 caratteri.
	private String function markerLabel( required any quotationItem ){
		var code = "";

		if ( !IsNull( arguments.quotationItem.getPosition() ) ) {
			code = arguments.quotationItem.getPosition().getCode() ?: "";
		}

		return Left( Len( code ) ? code : "N/A", 3 );
	}

	private any function categoryTypeOf( required any quotationItem ){
		var product = arguments.quotationItem.getProduct();

		if ( IsNull( product ) || IsNull( product.getCategory() ) ) {
			return NullValue();
		}

		return product.getCategory().getType();
	}

	function groupItems( quotationItems ) {
		var groupedItems = {};

		for ( var quotationItem in quotationItems ) {
			var hashKey = quotationItem.getHash();
			var zone    = quotationItem.getQuotationZone();

			var zoneQuantity = !isNull( zone.getOrigin() ) ?
				zone.getOrigin().getQuantity() * zone.getQuantity() :
				zone.getQuantity();

			var itemQuantity = quotationItem.getQuantity() * zoneQuantity;

			if ( !structKeyExists( groupedItems, hashKey ) ) {
				groupedItems[hashKey] = {
					'item' = quotationItem,
					'quantity' = itemQuantity,
					'zones' = {},
					'positionCodes' = []
				};
			} else {
				groupedItems[hashKey].quantity += itemQuantity;
			}

			var zoneName = zone.getName();

			if ( !structKeyExists( groupedItems[hashKey].zones, zoneName ) ) {
				// quantity serve quando la riga non ha codice posizione: si stampa quella
				groupedItems[hashKey].zones[ zoneName ] = { 'positions' = [], 'quantity' = 0 };
			}

			groupedItems[hashKey].zones[ zoneName ].quantity += itemQuantity;

			var position = quotationItem.getPosition();
			var code     = !isNull( position ) ? ( position.getCode() ?: "" ) : "";

			if ( Len( code ) ) {
				// NB: il confronto va fatto sul codice, non sull'oggetto posizione
				if ( !arrayContains( groupedItems[hashKey].zones[ zoneName ].positions, code ) ) {
					arrayAppend( groupedItems[hashKey].zones[ zoneName ].positions, code );
				}
				if ( !arrayContains( groupedItems[hashKey].positionCodes, code ) ) {
					arrayAppend( groupedItems[hashKey].positionCodes, code );
				}
			}
		}

		return groupedItems;
	}

	/**
	 * Chiave di ordinamento di riga: prima le voci con codice posizione, in ordine
	 * alfanumerico naturale; poi quelle senza, nell'ordine manuale del preventivo.
	 */
	private String function itemSortKey( required Struct entry ){
		if ( ArrayLen( arguments.entry.positionCodes ) ) {
			var best = positionSortKey( arguments.entry.positionCodes[ 1 ] );

			for ( var code in arguments.entry.positionCodes ) {
				var key = positionSortKey( code );
				if ( Compare( key, best ) LT 0 ) best = key;
			}

			return "A" & best;
		}

		return "B" & NumberFormat( Val( arguments.entry.item.getOrdinamento() ?: 0 ), "0000000000" );
	}

	/**
	 * Rende un codice posizione confrontabile come stringa mantenendo l'ordine
	 * naturale dei numeri: le cifre vengono allineate a 10 posizioni, così "2"
	 * precede "10" e "EL-2" precede "EL-15".
	 */
	private String function positionSortKey( required String code ){
		var key    = "";
		var digits = "";
		var text   = LCase( Trim( arguments.code ) );

		for ( var i = 1; i LTE Len( text ); i++ ) {
			var c = Mid( text, i, 1 );

			if ( REFind( "[0-9]", c ) ) {
				digits &= c;
				continue;
			}

			if ( Len( digits ) ) {
				key &= RepeatString( "0", Max( 0, 10 - Len( digits ) ) ) & digits;
				digits = "";
			}

			key &= c;
		}

		if ( Len( digits ) ) {
			key &= RepeatString( "0", Max( 0, 10 - Len( digits ) ) ) & digits;
		}

		return key;
	}
}
