/*
	per signage:
		AND product_item_join_id = <cfqueryparam value="#arguments.signageItemProduct.productItemId#" cfsqltype="Integer">
		AND signage_config_item_join_id = <cfqueryparam value="#arguments.signageItemProduct.SignageConfigItemId#" cfsqltype="Integer">
*/

component extends="com.apirone.core.model.service.AbsService" accessors="true" {

	property name="productService" inject="ProductService";
	property name="productItemService" inject="ProductItemService";
	property name="quotationZoneService" inject="QuotationZoneService";
	property name="componentService" inject="ComponentService";
	property name="metadataService" inject="MetadataService";
	property name="currencyService" inject="CurrencyService";
	property name="quotationItemDAO" inject="QuotationItemDAO";

	variables.logConfig = {};

	private function isPlaccaOrSegnaletica(product)
	{
		if (isNull(product) || isNull(product.getCategory()) || isNull(product.getCategory().getType())) {
			return false;
		}
		return ListFind( "PLA,SEG", product.getCategory().getType().getId() );
	}

	private function getQuantitaTotaleAltreRigheByQuotationLineIdAndFinishId(quotation, quotationItemId, lineId, finishId) {
		if ( IsNull( quotation ) ) {
			return 0;
		}
		arguments['quotationId'] = quotation.getId();
		// Memo di batch: l'aggregatore dei gemelli precalcola i totali per tutti gli item
		// con una query di gruppo invece di una SUM per sibling. Valida perché il batch
		// gira dopo l'update della placca salvata e nel resto della richiesta le quantità
		// non cambiano; un item fuori memo (es. signage) cade sulla query singola.
		var memoKey = arguments.quotationId & "|lf|" & arguments.quotationItemId;
		if ( StructKeyExists( request, "_pricingSiblingTotals" ) && StructKeyExists( request._pricingSiblingTotals, memoKey ) ) {
			return request._pricingSiblingTotals[ memoKey ];
		}
		return getQuotationItemDAO().getQuantitaTotaleAltreRigheByQuotationLineIdAndFinishId(argumentCollection = arguments);
	}

	private function getQuantitaTotaleAltreRigheByQuotationLineIdAndModelId(quotation, quotationItemId, lineId, modelId) {
		if ( IsNull( quotation ) ) {
			return 0;
		}
		arguments['quotationId'] = quotation.getId();
		// Stessa memo di batch del wrapper linea+finitura, chiave "|lm|"
		var memoKey = arguments.quotationId & "|lm|" & arguments.quotationItemId;
		if ( StructKeyExists( request, "_pricingSiblingTotals" ) && StructKeyExists( request._pricingSiblingTotals, memoKey ) ) {
			return request._pricingSiblingTotals[ memoKey ];
		}
		return getQuotationItemDAO().getQuantitaTotaleAltreRigheByQuotationLineIdAndModelId(argumentCollection = arguments);
	}

	private function getQuantitaTotaleAltreRigheByQuotationAndProduct(quotation, quotationItemId) {
		if ( IsNull( quotation ) ) {
			return 0;
		}
		arguments['quotationId'] = quotation.getId();
		// Stessa memo di batch del wrapper linea+finitura (riempita da
		// QuotationItemService.precomputeBatchTotals): per ogni item la memo contiene
		// due chiavi, "|lf|" = totale delle righe con stessa linea+finitura (qui sotto
		// non serve: è il prezzo per prodotto) e "|p|" = totale delle righe dello stesso prodotto
		var memoKey = arguments.quotationId & "|p|" & arguments.quotationItemId;
		if ( StructKeyExists( request, "_pricingSiblingTotals" ) && StructKeyExists( request._pricingSiblingTotals, memoKey ) ) {
			return request._pricingSiblingTotals[ memoKey ];
		}
		return getQuotationItemDAO().getQuantitaTotaleAltreRigheByQuotationAndProduct(argumentCollection = arguments);
	}

	public function calculate(
		required String productId,
		required Numeric quantity = 1,
		quotationItemZoneId = javacast("null", ""),
		Array producItemtIds,
		Numeric lettersQuantity = 0,
		Numeric simulationSignageConfigItemId,
		Quotation quotation = javacast("null", ""),
		QuotationItem quotationItem = javacast("null", ""),
		any preloadedProduct = javacast("null", ""), // "any": con il tipo Product, Lucee non casta il default nullo quando l'argomento viene omesso (es. PriceAjaxController.simulate)
		any skipPrewarm = javacast("null", "") // true = il chiamante ha già fatto lo sweep verticale (es. prewarm di tutti gli articoli gemelli): salta i prewarm interni
	) {
		// Chiamata esplicita (non argumentCollection): con gli argomenti posizionali il forwarding
		// grezzo mappa la chiave numerica del decimo argomento sul decimo parametro di simulate
		// (preloadedProduct), sovrascrivendolo e perdendo skipPrewarm.
		// Nota: currencyId non esiste tra i parametri di calculate (il forwarding della vecchia
		// versione non lo passava mai): simulate usa il suo default "EUR".
		// skipPrewarm letto con StructKeyExists: un null passato posizionalmente non viene
		// bindato da Lucee e la chiave non esisterebbe nell'arguments scope.
		var doSkipPrewarm = StructKeyExists( arguments, "skipPrewarm" ) && !IsNull( arguments.skipPrewarm ) && arguments.skipPrewarm;

		// Prodotto senza prezzo configurato: non si blocca il salvataggio della riga, il
		// prodotto vale 0 e il chiamante marca la riga (QuotationItemPrice.missingPrice).
		// simulate() continua invece a lanciare l'eccezione (simulatore prezzi in admin).
		try {
			var price = simulate(
				productId                      = arguments.productId,
				quantity                       = arguments.quantity,
				quotationItemZoneId            = arguments.quotationItemZoneId,
				producItemtIds                 = arguments.producItemtIds,
				lettersQuantity                = arguments.lettersQuantity,
				simulationSignageConfigItemId  = arguments.simulationSignageConfigItemId,
				quotation                      = arguments.quotation,
				quotationItem                  = arguments.quotationItem,
				preloadedProduct               = arguments.preloadedProduct,
				skipPrewarm                    = doSkipPrewarm
			);
		} catch ( "ApirOne.NoPriceConfigured" e ) {
			return { finalPrice: 0, totalCost: 0, missingPrice: true, missingPriceMessage: e.message };
		}
		return { finalPrice: price.values.finalPrice, totalCost: price.values.totalCost, missingPrice: false };
	}

	public Struct function simulate(
		required String productId,
		required Numeric quantity = 1,
		quotationItemZoneId = javacast("null", ""),
		Array producItemtIds,
		String currencyId="EUR",
		Numeric lettersQuantity = 0,
		Numeric simulationSignageConfigItemId,
		Quotation quotation = javacast("null", ""),
		QuotationItem quotationItem = javacast("null", ""),
		any preloadedProduct = javacast("null", ""), // "any": con il tipo Product, Lucee non casta il default nullo quando l'argomento viene omesso (es. PriceAjaxController.simulate)
		any skipPrewarm = javacast("null", ""), // true = il chiamante ha già fatto lo sweep verticale: salta i prewarm interni
		Boolean allowMissingPrice = false // true = senza prezzo PRICE calcola lo stesso il costo ( simula della scheda prodotto ), il prezzo vale 0
	){
		if ( arguments.quantity LTE 0 ) {
			Throw(
				type    = "apirone.error.PriceCalculator.QuantityLessThenZero",
				message = "The quantity [#arguments.quantity#] must be greater than zero."
			);
		}

		// skipPrewarm letto con StructKeyExists: un null passato posizionalmente non viene
		// bindato e la chiave non esisterebbe; da qui in poi passa solo un booleano.
		var doSkipPrewarm = StructKeyExists( arguments, "skipPrewarm" ) && !IsNull( arguments.skipPrewarm ) && arguments.skipPrewarm;

		// spiegazione leggibile di QUESTO calcolo ( mostrata nel simula ), separata dal log di debug su file
		request._priceExplain = [];

		/*
			INFO:

			Σ  = componenti di 1 pezzo: linea / modello + prodotto + attributi + lettering ( per lettera × lettere )
			cB = componenti linea / modello + prodotto
			cA = componenti di ogni attributo ( nel lettering per lettera × lettere )
			M  = markup dell'articolo ( PRICE M )
			MA = ricarico dell'attributo: quello della riga ( PROD_ITEM_PRICE M ), altrimenti il markup
			     dell'articolo ( vedi itemMarkup() ). PROD_ITEM_GEN non si usa: è sempre uguale al prezzo dell'articolo
			FA = prezzi fissi degli attributi ( PROD_ITEM_PRICE F, anche per lettera × lettere )
			G  = markup generale ( metadata 107: corrente, affitti, personale... )

			costo  = Σ × G

			prezzo = ( cB × M + Σ( cA × MA ) + FA ) × G + costo fisso / pezzi
			         con l'articolo a importo fisso ( PRICE F ): ( cB + importo + Σ( cA × MA ) + FA ) × G + costo fisso / pezzi
			         ( qui l'attributo senza ricarico proprio vale i suoi componenti, MA = 1 )

			Il costo fisso / pezzi è una quota del prezzo: non entra nel costo, niente markup.
		*/

		var markup = 0;

		var productSvc   = getProductService();
		var componentSvc = getComponentService();
		var metadataSvc  = getMetadataService();
		var currencySvc  = getCurrencyService();

		var productId      = arguments.productId;
		var productItemIds = arguments.producItemtIds;

		// Carica il prodotto: se il chiamante ha già precaricato il bean (batch),
		// lo riusa; altrimenti carica via batch getMany() per evitare la cascata N+1
		// di buildFromRow() (CatalogBundle, Line, Model, Category, Finish, etc.)
		var product = NullValue();
		if ( !IsNull( arguments.preloadedProduct ) ) {
			product = arguments.preloadedProduct;
		} else {
			var productMap = getProductService().getMany( [ productId ] );
			product = StructKeyExists( productMap, productId )
				? productMap[ productId ]
				: NullValue();
			if ( IsNull( product ) ) {
				product = productSvc.get( productId );
			}
		}
		var price = product.getPrice( "PRICE" );
		var missingPrice = IsNull( price );
		if ( missingPrice && !arguments.allowMissingPrice ) {
			// messaggio rivolto all'utente: descrizione leggibile del prodotto (linea,
			// modello, finitura), non il guid interno - vedi anche "name" più sotto,
			// stesso pattern
			var missingPriceProductName = product.getDescription();
			if ( Len( product.getCode() ) ) {
				missingPriceProductName &= " (#product.getCode()#)";
			}

			Throw(
				type    = "ApirOne.NoPriceConfigured",
				message = "Nessun prezzo configurato per il prodotto [#missingPriceProductName#]."
			);
		}

		var quantity = arguments.quantity
		if (!isNull(arguments.quotationItemZoneId)) {
			// Memo per request: gli articoli gemelli condividono le stesse zone e il build di
			// QuotationZone è pesante (cascata fino alla quotation: utenti, ruoli, storico).
			// Il bean è usato in sola lettura nel pricing, quindi il riuso è sicuro.
			if ( !StructKeyExists( request, "_pricingZoneMemo" ) ) {
				request._pricingZoneMemo = {};
			}
			var zone = NullValue();
			if ( StructKeyExists( request._pricingZoneMemo, arguments.quotationItemZoneId ) ) {
				zone = request._pricingZoneMemo[ arguments.quotationItemZoneId ];
			} else {
				zone = getQuotationZoneService().get(arguments.quotationItemZoneId)
				request._pricingZoneMemo[ arguments.quotationItemZoneId ] = zone;
			}
			var originZone = zone.getOrigin()
			var zoneQuantity = zone.getQuantity();
			if (!isNull(originZone)) {
				zoneQuantity *= originZone.getQuantity()
			}
			quantity = arguments.quantity * zoneQuantity;
		}

		//var currency = currencySvc.get( arguments.currencyId );

		// Memo per request: il markup generale è configurazione statica riletta a ogni
		// calculate; il metadata type non cambia durante la richiesta
		if ( !StructKeyExists( request, "_pricingMetadataMemo" ) ) {
			request._pricingMetadataMemo = metadataSvc.list( typeId=107 );
		}
		var settings = request._pricingMetadataMemo;
		var generalMarkup = settings[1].getValue();

		// senza prezzo PRICE ( solo con allowMissingPrice ) si calcola il costo e il prezzo vale 0
		var isFixedPrice = missingPrice ? false : ( price.getMethod()?.getId() == "F" ?: true );
		var markup       = missingPrice ? 0 : ( price.getAmount() ?: 0 );

		var name = "#product.getDescription()# (#product.getCode()#)";

		appendLog(
			message   = "Inizio calcolo del prezzo per #name#, quantità: #arguments.quantity#. Prezzo: fisso: #isFixedPrice#, valore: #markup#",
			productId = product.getSerial()
		);

		/*
			fixed cost
		*/

		var quantitaTotale = arguments.quantity;
		var fixedCost = 0;
		var unitFixedCost = 0;
		// per la spiegazione: da dove viene il costo fisso unitario
		var fixedCostParts = [];
		if (isPlaccaOrSegnaletica(product)) {
			appendLog(
				message="Il prodotto è PLA o SEG: i costi fissi ( costo fisso dell'articolo, tabelle linea/finitura e linea/modello ) sono ripartiti sulle quantità delle righe del preventivo dello stesso gruppo"
			)
			if ( IsNull( arguments.quotationItem ) ) {
				appendLog(
					message="Siccome sto simulando il costo NON ho altri articoli con cui dividere il costo fisso, quindi divido solo per il campo quantità (#arguments.quantity#)"
				)
			}

			// Memo per request: la tabella dei costi fissi linea/finitura è configurazione
			// statica e i gemelli condividono la stessa coppia linea+finitura, quindi una
			// lettura sola al posto di una per sibling
			var lcKey = product.getLine().getId() & "|" & product.getFinish().getId();
			if ( !StructKeyExists( request, "_pricingLineCostMemo" ) ) {
				request._pricingLineCostMemo = {};
			}
			if ( StructKeyExists( request._pricingLineCostMemo, lcKey ) ) {
				lineCostRecord = request._pricingLineCostMemo[ lcKey ];
			} else {
				lineCostRecord = super.service( "LineCost" ).list(
					lineId   = product.getLine().getId(),
					finishId = product.getFinish().getId()
				);
				request._pricingLineCostMemo[ lcKey ] = lineCostRecord;
			}

			//Se non nullo leggo il campo "cost" e lo scrivo in fixedCost
			if ( len(lineCostRecord) > 0 ) {
				lineCostRecord = lineCostRecord[1];
				fixedCost += lineCostRecord.getCost();
				quantitaTotale = getQuantitaTotaleAltreRigheByQuotationLineIdAndFinishId(
					quotation,
					IsNull(quotationItem) ? null : quotationItem.getId(),
					product.getLine().getId(),
					product.getFinish().getId()
				);
				quantitaTotale += quantity;
				unitFixedCost = fixedCost / quantitaTotale;
				fixedCostParts.append( "linea/finitura #fmtNum( fixedCost )# € / #fmtFactor( quantitaTotale )# pezzi" );
			}

			// Costo fisso linea/modello (qualsiasi finitura): si somma a quello linea/finitura
			// ed è ripartito sul suo gruppo, cioè le righe del preventivo con stessa linea+modello
			if ( !IsNull( product.getModel() ) ) {
				var lmKey = product.getLine().getId() & "|" & product.getModel().getId();
				if ( !StructKeyExists( request, "_pricingLineModelCostMemo" ) ) {
					request._pricingLineModelCostMemo = {};
				}
				if ( !StructKeyExists( request._pricingLineModelCostMemo, lmKey ) ) {
					request._pricingLineModelCostMemo[ lmKey ] = super.service( "LineModelCost" ).list(
						lineId  = product.getLine().getId(),
						modelId = product.getModel().getId()
					);
				}
				var lineModelCostRecords = request._pricingLineModelCostMemo[ lmKey ];

				if ( ArrayLen( lineModelCostRecords ) ) {
					var lineModelFixedCost = Val( lineModelCostRecords[ 1 ].getCost() );
					var quantitaTotaleLineaModello = getQuantitaTotaleAltreRigheByQuotationLineIdAndModelId(
						quotation,
						IsNull(quotationItem) ? "" : quotationItem.getId(),
						product.getLine().getId(),
						product.getModel().getId()
					) + quantity;

					appendLog(
						message = "Costo fisso linea/modello per #quantitaTotaleLineaModello# pezzi. Costo fisso #lineModelFixedCost# / #quantitaTotaleLineaModello#;Costo fisso unitario: #formatExtended( lineModelFixedCost / quantitaTotaleLineaModello )#"
					);

					unitFixedCost += lineModelFixedCost / quantitaTotaleLineaModello;
					fixedCostParts.append( "linea/modello #fmtNum( lineModelFixedCost )# € / #fmtFactor( quantitaTotaleLineaModello )# pezzi" );
				}

				// Costo fisso dell'articolo ( prezzo COST_FIXED, di solito uguale per tutte le finiture
				// di linea+modello ): ripartito sulle quantità delle righe del preventivo con stessa
				// linea+modello, zone comprese. Nel simula ( nessun preventivo ) solo sulla quantità simulata.
				var productFixedCost = Val( product.getPrice( "COST_FIXED" )?.getAmount() ?: 0 );
				if ( productFixedCost > 0 ) {
					var quantitaGruppoArticolo = getQuantitaTotaleAltreRigheByQuotationLineIdAndModelId(
						quotation,
						IsNull(quotationItem) ? "" : quotationItem.getId(),
						product.getLine().getId(),
						product.getModel().getId()
					) + quantity;

					appendLog(
						message = "Costo fisso articolo per #quantitaGruppoArticolo# pezzi ( stessa linea e modello ). Costo fisso #productFixedCost# / #quantitaGruppoArticolo#;Costo fisso unitario: #formatExtended( productFixedCost / quantitaGruppoArticolo )#"
					);

					unitFixedCost += productFixedCost / quantitaGruppoArticolo;
					fixedCostParts.append( "costo fisso articolo #fmtNum( productFixedCost )# € / #fmtFactor( quantitaGruppoArticolo )# pezzi ( stessa linea e modello )" );
				}
			}
		} else {
			fixedCost     = product.getPrice( "COST_FIXED" )?.getAmount() ?: 0;
			quantitaTotale = getQuantitaTotaleAltreRigheByQuotationAndProduct(
				quotation,
				IsNull(quotationItem) ? null : quotationItem.getId(),
				product.getId()
			)
			quantitaTotale += quantity;
			unitFixedCost = fixedCost / quantitaTotale;
			if ( fixedCost > 0 ) {
				fixedCostParts.append( "costo fisso articolo #fmtNum( fixedCost )# € / #fmtFactor( quantitaTotale )# pezzi" );
			}
		}

		// per PLA/SEG fixedCost/quantitaTotale sono quelli linea/finitura; unitFixedCost
		// include anche l'eventuale quota linea/modello (loggata a parte sopra)
		appendLog(
			message = "Costo fisso per #quantitaTotale# pezzi. Costo fisso #fixedCost# / #quantitaTotale#;Costo fisso unitario totale: #formatExtended( unitFixedCost )#"
		);

		// il costo fisso, nonostante il nome, è una quota del prezzo di vendita: non entra nel costo di
		// produzione e si aggiunge al prezzo alla fine, senza markup generale né ricarichi

		/*
			cost bundle
		*/

		var bundleCost = 0;
		var bundleDetail = "";

		if ( IsInstanceOf( product, "com.apirone.core.model.bean.ProductComplex" ) ) {
			var bundleComponents = componentSvc.priceCalculatorSearch(
				lineId                         = product.getLine().getId(),
				modelId                        = product.getModel().getId(),
				includeBaseAttributeComponents = true,
				skipPrewarm                    = doSkipPrewarm
			);

			var bundleCost = calculateComponentsTotal( bundleComponents, "CatalogBundle" );
			bundleDetail = componentsDetail( bundleComponents );
		}

		// il log viene scritto da in calculateComponentsTotal()
		// appendLog( "Costo componenti per bundle;Totale attributi: #formatExtended( bundleCost )#" );

		/*
			cost base product
		*/

		var productComponents = componentSvc.priceCalculatorSearch( productId = productId, includeBaseAttributeComponents = true, skipPrewarm = doSkipPrewarm );

		var productCost = calculateComponentsTotal( productComponents, "Product" );
		var productDetail = componentsDetail( productComponents );

		// appendLog( message = "Costo componenti prodotto #productComponents#;Totale unitario: #formatExtended( productCost )#" );

		/*
			cost items
		*/

		appendLog( "** Inizio del calcolo del prezzo degli attributi: #ArrayToList(productItemIds)#" );

		// Valida gli item prima di eseguire qualsiasi query batch: se un attributo
		// non è stato compilato (itemId nullo) lancia l'errore previsto.
		for ( var itemId in productItemIds ) {
			if ( IsNull( itemId ) ) {
				throw ("Compilare tutti gli attributi!");
			}
		}

		// Precarica i ProductItem con memo per SINGOLO id: ogni gemello ha il suo set di item,
		// quindi una memo per lista di id non colpirebbe mai; per id invece ogni bean viene
		// letto una sola volta per richiesta e riusato da tutti i calcoli (beans in sola lettura)
		var productItemMap = {};
		var missingItemIds = [];
		if ( !StructKeyExists( request, "_pricingItemBeanMemo" ) ) {
			request._pricingItemBeanMemo = {};
		}
		for ( var itemId in productItemIds ) {
			if ( StructKeyExists( request._pricingItemBeanMemo, itemId ) ) {
				productItemMap[ itemId ] = request._pricingItemBeanMemo[ itemId ];
			} else {
				request._pricingProbeMissItem = ( request._pricingProbeMissItem ?: 0 ) + 1;
				missingItemIds.append( itemId );
			}
		}
		if ( ArrayLen( missingItemIds ) ) {
			var fetchedItemMap = getProductItemService().getMany( missingItemIds );
			for ( var fetchedId in fetchedItemMap ) {
				request._pricingItemBeanMemo[ fetchedId ] = fetchedItemMap[ fetchedId ];
				productItemMap[ fetchedId ] = fetchedItemMap[ fetchedId ];
			}
		}

		// Precarica in batch tutti i componenti (own + base attribute) di ogni item
		// per evitare una query per item (N+1) in priceCalculatorSearch()
		var itemComponentsMap = ArrayLen( productItemIds )
			? componentSvc.priceCalculatorSearchByProductItemIds( productItemIds, doSkipPrewarm )
			: {};

		// ricarico degli attributi senza ricarico proprio: il markup dell'articolo ( 1 se l'articolo ha un importo fisso )
		var articleItemMarkup = isFixedPrice ? 1 : markup;

		// costo dei componenti degli attributi: entra nel costo
		var pureItemsCost = 0;
		// componenti degli attributi × il loro ricarico: entra nel prezzo
		var itemsValue = 0;
		// somma dei prezzi fissi degli attributi ( PROD_ITEM_PRICE F ): solo prezzo
		var itemsFixedPrice = 0;
		// dati per la spiegazione: un elemento per attributo
		var itemsInfo = [];

		for ( var itemId in productItemIds ) {
			var itemComponents = StructKeyExists( itemComponentsMap, itemId )
				? itemComponentsMap[ itemId ]
				: [];

			var productItem = StructKeyExists( productItemMap, itemId )
				? productItemMap[ itemId ]
				: getProductItemService().get( itemId );

			var attributeName = "Item: #itemId#, Attributo: #productItem.getAttribute().getName()# / #productItem
				.getAttributeValue()
				.getRawValue()
				.getName()#";

			var compCost = calculateComponentsTotal( itemComponents, "ProductItem" );
			pureItemsCost += compCost;

			// nel prezzo i componenti dell'attributo valgono × il suo ricarico; il prezzo fisso dell'attributo
			// ( PROD_ITEM_PRICE F ) si somma a parte
			var itemMarkupInfo = itemMarkup( productItem, articleItemMarkup );
			var itemValue      = compCost * itemMarkupInfo.markup;
			itemsValue += itemValue;

			var itemFixedPrice = fixedItemPrice( productItem );
			itemsFixedPrice += itemFixedPrice;

			appendLog(
				message = "#attributeName#. Totale componenti: #compCost# * ricarico ( #itemMarkupInfo.source# ): #itemMarkupInfo.markup#" & ( itemFixedPrice > 0 ? " + prezzo fisso attributo: #itemFixedPrice#" : "" ) & ";Valore attributo: #formatExtended( itemValue + itemFixedPrice )#"
			);

			itemsInfo.append( {
				"label"      = attributeLabel( productItem ),
				"cost"       = compCost,
				"value"      = itemValue,
				"markup"     = itemMarkupInfo.markup,
				"source"     = itemMarkupInfo.source,
				"fixedPrice" = itemFixedPrice,
				"detail"     = componentsDetail( itemComponents )
			} );
		}

		appendLog( "** Fine del calcolo degli attributi; costo componenti: #formatExtended( pureItemsCost )#, valore ricaricato: #formatExtended( itemsValue )#, prezzi fissi: #formatExtended( itemsFixedPrice )#" );

		/*
			font price
		*/

		// componenti del lettering ( per lettera × lettere ): entrano nel costo
		var letteringCost = 0;
		// gli stessi × il ricarico di ogni attributo ( il formato × il markup dell'articolo ): entrano nel prezzo
		var letteringValue = 0;
		// prezzi fissi degli attributi per lettera × lettere: solo prezzo
		var letteringFixedPrice = 0;
		// per la spiegazione: componenti del formato ( per lettera ) e attributi per lettera
		var letterFormatCost   = 0;
		var letterFormatDetail = "";
		var letterItems        = [];
		var letterSizesLabel   = "";
		if ( lettersQuantity > 0 && simulationSignageConfigItemId GT 0 ) {
			appendLog( "** Inizio del calcolo del prezzo della segnaletica con lettering con #lettersQuantity# lettere;" );
			var fixedPricePerLetter = 0;
			var fontCostPerLetter   = 0;
			var valuePerLetter      = 0;
			var signageConfigItemSvc = super.service( "SignageConfigItem" );
			var signageConfigSvc = super.service( "SignageConfig" );
			var signageConfigItem    = signageConfigItemSvc.get( simulationSignageConfigItemId );
			var fontFamilySize = super.service( "FontFamilySize" ).get( signageConfigItem.getSize().getId() );

			if ( !IsNull( fontFamilySize ) && !isNull( signageConfigItem ) ) {
				var fontHeight = 0;
				var heightWidthRatio = 0;
				if ( isNull( fontFamilySize ) ) {
					appendLog( "ATTENZIONE: Impossibile recuperare l'altezza del font per il calcolo del prezzo della segnaletica." );
					return;
				}
				var fontHeight = fontFamilySize.getName();
				appendLog( "Altezza font: #fontHeight#mm" );

				var signageConfig = signageConfigSvc.get( signageConfigItem.getSignageConfigId() );
				var heightWidthRatio = signageConfig.getFont().getHeightWidthRatio();
				if  ( isNull( heightWidthRatio ) OR heightWidthRatio LTE 0 ) {
					appendLog( "ATTENZIONE: Impossibile recuperare il rapporto altezza/larghezza del font per il calcolo del prezzo della segnaletica." );
					return;
				}
				appendLog( "Larghezza font: #fontHeight / heightWidthRatio#mm" );

				var letteringThickeness = stringThicknessToDecimal( product.getModel().getCode() );
				if ( letteringThickeness GT 0 ) {
					appendLog( "Spessore font: #letteringThickeness#mm" );
				}

				var sizes = {
					"height" = fontHeight,
					"width"  = fontHeight / heightWidthRatio,
					"thickness" = letteringThickeness,
					"surfaceArea" = fontHeight * ( fontHeight / heightWidthRatio ),
					"volume" = letteringThickeness > 0 ? fontHeight * ( fontHeight / heightWidthRatio ) * letteringThickeness : 0
				}
				if ( sizes.surfaceArea GT 0 ) {
					appendLog( "Superficie font: #sizes.surfaceArea#mm²" );
				}
				if ( sizes.volume GT 0 ) {
					appendLog( "Volume font: #sizes.volume#mm³" );
				}
				letterSizesLabel = "lettera h #fmtFactor( sizes.height )# × l #fmtFactor( Round( sizes.width * 100 ) / 100 )# mm" & ( sizes.thickness > 0 ? " × sp #fmtFactor( sizes.thickness )# mm" : "" );
				if ( Len( productItemIds ) ) {
					//costo componenti items segnaletica
					for ( var productItemId in productItemIds ) {
						var signageItem = calculateSignageProductItemPrice( signageItemProduct = { productItemId = productItemId, signageConfigItemId = simulationSignageConfigItemId }, sizes = sizes, articleItemMarkup = articleItemMarkup );
						fixedPricePerLetter += signageItem.fixedPrice;
						fontCostPerLetter   += signageItem.cost;
						valuePerLetter      += signageItem.value;
						if ( signageItem.cost > 0 || signageItem.fixedPrice > 0 ) {
							letterItems.append( signageItem );
						}
					}
				}

				//calcolo costo componenti segnaletica
				if ( IsInstanceOf( product, "com.apirone.core.model.bean.ProductComplex" ) ) {
					var signageBundleComponents = componentSvc.priceCalculatorSearch(
						signageConfigItemId = simulationSignageConfigItemId,
						includeBaseAttributeComponents = true,
						skipPrewarm = doSkipPrewarm
					);

					// componenti del formato: × il markup dell'articolo
					var signageBundleCost = calculateComponentsTotal( signageBundleComponents, "SignageConfigItem" );
					fontCostPerLetter  += signageBundleCost;
					valuePerLetter     += signageBundleCost * articleItemMarkup;
					letterFormatCost   = signageBundleCost;
					letterFormatDetail = componentsDetail( signageBundleComponents );
				}

				letteringCost       = fontCostPerLetter * lettersQuantity;
				letteringValue      = valuePerLetter * lettersQuantity;
				letteringFixedPrice = fixedPricePerLetter * lettersQuantity;
			}

			appendLog( "** Fine del calcolo della segnaletica con lettering. Per lettera: costo #formatExtended( fontCostPerLetter )#, valore ricaricato #formatExtended( valuePerLetter )#, prezzi fissi #formatExtended( fixedPricePerLetter )#; Totale lettering: costo #formatExtended( letteringCost )#, valore #formatExtended( letteringValue )#, prezzi fissi #formatExtended( letteringFixedPrice )#" );
		}

		// costo: tutti i componenti per il markup generale ( corrente, affitti, personale... ).
		// Il costo fisso non entra: è una quota del prezzo di vendita ( vedi sotto )
		var componentsCost = bundleCost + productCost + pureItemsCost + letteringCost;
		var totalCost      = componentsCost * generalMarkup;
		appendLog(
			message    = "Costo finale: ( bundle: #bundleCost# + prodotto: #productCost# + componenti attributi: #pureItemsCost# + lettering: #letteringCost# ) * markup generale: #generalMarkup#;Costo finale: #formatExtended( totalCost )#",
			lineTypeId = "H"
		);

		// prezzi fissi degli attributi ( anche per lettera ): si sommano prima del markup generale
		var fixedPrices = itemsFixedPrice + letteringFixedPrice;

		if ( missingPrice ) {
			var finalPrice = 0;
			appendLog(
				message    = "Nessun prezzo PRICE configurato per il prodotto: il prezzo di vendita non si calcola;Prezzo finale: #formatExtended( finalPrice )#",
				lineTypeId = "H"
			);
		} else if ( isFixedPrice ) {
			// ricarico dell'articolo a importo fisso: si somma ai componenti di linea / modello + prodotto
			var finalPrice = ( bundleCost + productCost + markup + itemsValue + letteringValue + fixedPrices ) * generalMarkup + unitFixedCost;
			appendLog(
				message    = "Prezzo finale fisso. ( bundle: #bundleCost# + prodotto: #productCost# + importo articolo: #markup# + attributi ricaricati: #itemsValue# + lettering ricaricato: #letteringValue# + prezzi fissi attributi: #fixedPrices# ) * markup generale: #generalMarkup# + costo fisso: #unitFixedCost#;Prezzo finale: #formatExtended( finalPrice )#",
				lineTypeId = "H"
			);
		} else {
			// prezzo = ( ( linea / modello + prodotto ) × markup articolo + attributi × loro ricarico + prezzi fissi ) × markup generale + costo fisso / pezzi
			var finalPrice = ( ( bundleCost + productCost ) * markup + itemsValue + letteringValue + fixedPrices ) * generalMarkup + unitFixedCost;
			appendLog(
				message    = "Prezzo finale. ( ( bundle: #bundleCost# + prodotto: #productCost# ) * markup articolo: #markup# + attributi ricaricati: #itemsValue# + lettering ricaricato: #letteringValue# + prezzi fissi attributi: #fixedPrices# ) * markup generale: #generalMarkup# + costo fisso: #unitFixedCost#;Prezzo finale: #formatExtended( finalPrice )#",
				lineTypeId = "H"
			);
		}

		// disattivata la conversione, così non funziona, l'id di currency non è EUR, è un intero se usiamo verticale oppure un uuid se usiamo la nostra _currencies.
		// if( currency.getId() != "EUR" ){
		// 	var targetCurrency = currencySvc.get( arguments.currencyId );
		// 	var exchangeRate   = currencySvc.getExchangeRate( "EUR", currency.getId() );

		// 	finalPrice = finalPrice * exchangeRate;
		// 	finalCost  = finalCost * exchangeRate;
		// 	// all values

		// 	appendLog(
		// 		message    = "Conversione valuta da #currency.getCode()# a #targetCurrency.getCode()#. Tasso di cambio: #exchangeRate#;Prezzo finale convertito: #formatExtended( finalPrice )#;Costo finale convertito: #formatExtended( finalCost )#",
		// 		lineTypeId = "H"
		// 	);

		// }

		explainPricing( {
			"generalMarkup"       = generalMarkup,
			"missingPrice"        = missingPrice,
			"isFixedPrice"        = isFixedPrice,
			"markup"              = markup,
			"bundleCost"          = bundleCost,
			"bundleDetail"        = bundleDetail,
			"productCost"         = productCost,
			"productDetail"       = productDetail,
			"items"               = itemsInfo,
			"unitFixedCost"       = unitFixedCost,
			"fixedCostDetail"     = ArrayToList( fixedCostParts, " + " ),
			"lettersQuantity"     = lettersQuantity,
			"letterSizesLabel"    = letterSizesLabel,
			"letterFormatCost"    = letterFormatCost,
			"letterFormatDetail"  = letterFormatDetail,
			"letterItems"         = letterItems,
			"letteringCost"       = letteringCost,
			"letteringValue"      = letteringValue,
			"letteringFixedPrice" = letteringFixedPrice,
			"itemsValue"          = itemsValue,
			"componentsCost"      = componentsCost,
			"fixedPrices"         = fixedPrices,
			"totalCost"           = totalCost,
			"finalPrice"          = finalPrice
		} );

		var output = {
			"explain" = request._priceExplain,
			values = {
				"finalCost"      = totalCost,
				"componentsCost" = componentsCost,
				"bundleCost"     = bundleCost,
				"productCost"    = productCost,
				"itemsCost"      = pureItemsCost,
				"letteringCost"  = letteringCost,
				"itemsValue"     = itemsValue,
				"letteringValue" = letteringValue,
				"fixedPrices"    = fixedPrices,
				"totalCost"      = totalCost,
				"unitFixedCost"  = unitFixedCost,
				"finalPrice"     = finalPrice
			},
			"currency" = "EUR",
			"logFile" = variables.logConfig.filePath
		};
		if ( !missingPrice ) {
			output.values[ "priceType" ] = price;
		}

		return output;
	}

	/*
		Spiegazione del calcolo per il simula: due blocchi, costo e prezzo, una riga per voce con
		i componenti in piccolo sotto. Nel prezzo ogni voce è × il suo ricarico ( articolo o attributo ),
		poi tutto × markup generale, più il costo fisso: è la stessa formula di simulate() e il totale
		mostrato è finalPrice.
	*/
	private void function explainPricing( required Struct d ){
		var g = d.generalMarkup;

		explain( "Costo di produzione ( 1 pezzo )", "", "section" );
		if ( d.bundleCost > 0 || Len( d.bundleDetail ) ) {
			explain( "Linea / modello", d.bundleCost, "row", d.bundleDetail );
		}
		if ( d.productCost > 0 || Len( d.productDetail ) ) {
			explain( "Prodotto", d.productCost, "row", d.productDetail );
		}

		var noComponents = [];
		for ( var item in d.items ) {
			if ( item.cost > 0 ) {
				explain( "Attributo #item.label#", item.cost, "row", item.detail );
			} else {
				noComponents.append( item.label );
			}
		}
		if ( ArrayLen( noComponents ) ) {
			explain( "Attributi senza componenti: #ArrayToList( noComponents, ', ' )#", "", "note" );
		}

		if ( d.lettersQuantity > 0 ) {
			var letterCost   = d.lettersQuantity ? d.letteringCost / d.lettersQuantity : 0;
			var letterDetail = [];
			if ( Len( d.letterSizesLabel ) ) {
				letterDetail.append( d.letterSizesLabel );
			}
			if ( Len( d.letterFormatDetail ) ) {
				letterDetail.append( "formato: " & d.letterFormatDetail );
			}
			for ( var letterItem in d.letterItems ) {
				if ( letterItem.cost > 0 ) {
					letterDetail.append( "#letterItem.label#: #letterItem.detail#" );
				}
			}
			explain( "Lettering: #d.lettersQuantity# lettere × #fmtNum( letterCost )# €", d.letteringCost, "row", ArrayToList( letterDetail, " | " ) );
		}

		explain( "Totale componenti", d.componentsCost, "subtotal" );
		explain( "COSTO = #fmtNum( d.componentsCost )# × markup generale #fmtFactor( g )#", d.totalCost, "total" );

		explain( "Prezzo di vendita ( componenti × ricarichi × markup generale + costo fisso )", "", "section" );

		if ( d.missingPrice ) {
			explain( "Il prodotto non ha un prezzo ( ricarico o importo fisso dell'articolo ): il prezzo di vendita non si può calcolare. Si aggiunge da Manutenzioni → Aggiorna prezzi.", "", "note" );
			return;
		}

		var productComponents = d.bundleCost + d.productCost;
		var baseValue = d.isFixedPrice ? productComponents + d.markup : productComponents * d.markup;
		if ( d.isFixedPrice ) {
			explain( "Linea / modello + prodotto + importo fisso articolo", baseValue, "row", "#fmtNum( productComponents )# + #fmtNum( d.markup )# €" );
		} else {
			explain( "Linea / modello + prodotto", baseValue, "row", "#fmtNum( productComponents )# × markup articolo #fmtFactor( d.markup )#" );
		}

		for ( var item in d.items ) {
			if ( item.cost > 0 ) {
				explain( "Attributo #item.label#", item.value, "row", "#fmtNum( item.cost )# × #fmtFactor( item.markup )# ( #item.source# )" );
			}
			if ( item.fixedPrice > 0 ) {
				explain( "Prezzo fisso attributo #item.label#", item.fixedPrice, "row" );
			}
		}

		if ( d.lettersQuantity > 0 ) {
			var letterDetail = [];
			if ( d.letterFormatCost > 0 ) {
				letterDetail.append( "formato #fmtNum( d.letterFormatCost )# × #fmtFactor( d.isFixedPrice ? 1 : d.markup )#" );
			}
			for ( var letterItem in d.letterItems ) {
				if ( letterItem.cost > 0 ) {
					letterDetail.append( "#letterItem.label#: #fmtNum( letterItem.cost )# × #fmtFactor( letterItem.markup )# ( #letterItem.source# )" );
				}
			}
			explain( "Lettering: #d.lettersQuantity# lettere × #fmtNum( d.letteringValue / d.lettersQuantity )# €", d.letteringValue, "row", ArrayToList( letterDetail, " + " ) );

			if ( d.letteringFixedPrice > 0 ) {
				var letterFixedDetail = [];
				for ( var letterItem in d.letterItems ) {
					if ( letterItem.fixedPrice > 0 ) {
						letterFixedDetail.append( "#letterItem.label#: #fmtNum( letterItem.fixedPrice )# €" );
					}
				}
				explain( "Prezzi fissi attributi lettering: #d.lettersQuantity# lettere × #fmtNum( d.letteringFixedPrice / d.lettersQuantity )# €", d.letteringFixedPrice, "row", ArrayToList( letterFixedDetail, " + " ) );
			}
		}

		var beforeGeneral = baseValue + d.itemsValue + d.letteringValue + d.fixedPrices;
		explain( "#fmtNum( beforeGeneral )# × markup generale #fmtFactor( g )#", beforeGeneral * g, "subtotal" );

		if ( d.unitFixedCost > 0 ) {
			explain( "Costo fisso ( quota del prezzo, senza markup )", d.unitFixedCost, "row", d.fixedCostDetail );
		}

		explain( "PREZZO", d.finalPrice, "total" );
	}

	/*
		Aggiunge una riga alla spiegazione del calcolo corrente.
		kind: section ( intestazione ), row ( voce ), subtotal, total ( evidenziata ), note
	*/
	private void function explain( required String text, any value = "", String kind = "row", String detail = "" ){
		if ( !StructKeyExists( request, "_priceExplain" ) ) {
			request._priceExplain = [];
		}
		request._priceExplain.append( {
			"text"   = arguments.text,
			"value"  = IsNumeric( arguments.value ) ? fmtNum( arguments.value ) : "",
			"kind"   = arguments.kind,
			"detail" = arguments.detail
		} );
	}

	/*
		Componenti in una riga di testo ( codice, costo unitario × quantità con sfrido ), stessi
		numeri di calculateComponentsTotal(): serve alla spiegazione del simula.
	*/
	private String function componentsDetail( required Array components ){
		var parts = [];
		for ( var component in arguments.components ) {
			if ( component.isDeleted ) {
				continue;
			}
			var wasteFactor = getComponentService().quantityWasteFactor( component.raw_product_unit ?: "PZ" );
			parts.append(
				"#component.raw_product_id# #fmtNum( component.costAmount )# € × #fmtFactor( component.totalQuantity * wasteFactor )#"
				& ( wasteFactor != 1 ? " ( +15% sfrido )" : "" )
				& ( Val( component.costAmount ) == 0 ? " ( ATTENZIONE: prezzo 0 nel listino )" : "" )
			);
		}
		return ArrayToList( parts, "; " );
	}

	private String function attributeLabel( required productItem ){
		return arguments.productItem.getAttribute().getName() & " = " & arguments.productItem.getAttributeValue().getRawValue().getName();
	}

	// importo all'italiana: almeno 2 decimali, al massimo 4 ( 3,20 / 0,7157 / 228,97 )
	private String function fmtNum( required numeric value ){
		var text = Trim( LSNumberFormat( arguments.value, "9,999.9999", "it_IT" ) );
		return REReplace( text, "0{1,2}$", "" );
	}

	// fattore o quantità senza zeri inutili ( 34 / 1,2 / 0,5 )
	private String function fmtFactor( required numeric value ){
		var text = Trim( LSNumberFormat( arguments.value, "9,999.9999", "it_IT" ) );
		return REReplace( REReplace( text, "0+$", "" ), ",$", "" );
	}

	private Numeric function calculateComponentsTotal( Array components, String compType, Struct price ){
		var total = 0;
		var log   = "";

		if ( !Len( components ) ) {
			return 0
		}

		appendLog( "* Inizio del calcolo del costo dei componenti #compType#" );

		for ( var component in components ) {
			var name = "Componente: #component.id# - articolo: #component.raw_product_id# variante: #component.variant_id# colore: #component.color_id#";

			if ( !component.isDeleted ) {
				var amount = component.costAmount;

				var quantity = component.totalQuantity; // with override

				// materia prima non a pezzi ( né PA / EU / NR ): quantità +15% ( sfrido )
				var unit = component.raw_product_unit ?: "PZ";
				var wasteFactor = getComponentService().quantityWasteFactor( unit );
				quantity = quantity * wasteFactor;
				var wasteLabel = wasteFactor != 1 ? " (#unit# +15%)" : "";

				var rowTotal = amount * quantity;

				total = total + rowTotal;

				appendLog( "#name# - costo unitario: #amount#€ * quantità: #quantity##wasteLabel#; Costo compon.: #formatExtended( rowTotal )#€" );
			} else {
				appendLog( "#name#;CANCELLATO" );
			}
		}

		appendLog( "* Fine del calcolo del costo dei componenti #compType#;Totale compon.: #formatExtended( total )#€" );

		return total;
	}

	private Void function appendLog(
		required String message,
		String productId,
		String lineTypeId
	){
		var allowedLineType = "N,H"; // N=normal, H=highlighted

		if ( IsNull( arguments.lineTypeId ) ) {
			arguments.lineTypeId = "N" // normal
		}

		if ( !ListFind( allowedLineType, arguments.lineTypeId ) ) {
			Throw(
				type    = "apirone.error.PriceCalculator.LineTypeIdNotAllowed",
				message = "Only this line types is allowed: #allowedLineType#"
			)
		}

		if ( ListLen( message, ";" ) GT 2 ) {
			Throw(
				type    = "apirone.error.PriceCalculator.messageHasTooManyFields",
				message = "The log message can only have 2 fields (separated by ';')"
			)
		}

		if ( StructIsEmpty( variables.logConfig ) ) {
			if ( IsNull( productId ) ) {
				Throw(
					type    = "apirone.error.PriceCalculator.productIdRequired",
					message = "ProductId is required on the first invocation of appendLog()"
				)
			}

			startLog( productId );
		}

		var thisDate = DateTimeFormat( Now(), "yyyy-mm-dd HH:nn:ss" );

		var line = "#thisDate#;#arguments.lineTypeId#;#variables.logConfig.productId#;#message##Chr( 10 )#";

		FileAppend( variables.logConfig.filePath, line );
	}

	private Struct function startLog( required String productId ){
		var util = new com.apirone.core.util.Udf();
		// var name = util.prettyString( productName );

		var logsDir = ExpandPath( "/../repository/private/logs/prices" );

		if ( NOT DirectoryExists( logsDir ) ) {
			DirectoryCreate( logsDir, true );
		}

		var fileName = "product_"
		& DateTimeFormat( Now(), "yyyy-mm-dd_HH-nn-ss" )
		& "_serial-" & productId & ".log";

		if ( request.isDev() ) {
			fileName = "product_price_development_" & DateFormat( Now(), "yyyy-mm-dd" ) & ".log"
		}

		var filePath = logsDir & "/" & fileName;

		FileWrite( filePath, "", "UTF-8" );

		variables.logConfig = { filePath = filePath, productId = productId };

		return logConfig;
	}

	private Numeric function formatExtended( required Numeric value ){
		return NumberFormat( value, ".9999" );
	}

	/*
		Attributo della segnaletica con lettering, per una lettera: cost = componenti ( entrano nel costo ),
		value = componenti × ricarico dell'attributo ( itemMarkup(), entra nel prezzo ), fixedPrice = prezzo
		fisso dell'attributo ( solo prezzo ).
	*/
	private function calculateSignageProductItemPrice( Struct signageItemProduct, sizes, required numeric articleItemMarkup ){
		componentSvc = getComponentService();
		var itemComponents = componentSvc.priceCalculatorSearch( signageItemProduct = signageItemProduct );
		var compCost = 0;
		// per la spiegazione: un pezzo di testo per ogni componente che entra nel costo per lettera
		var detailParts = [];

		//recupero il product item id dalla struttura che uso per recuperare i componenti
		var itemId = signageItemProduct.productItemId;
		// il productItem è già nella memo della richiesta ( caricato da simulate() con gli attributi )
		var productItem = NullValue();
		if ( StructKeyExists( request, "_pricingItemBeanMemo" ) && StructKeyExists( request._pricingItemBeanMemo, itemId ) ) {
			productItem = request._pricingItemBeanMemo[ itemId ];
		} else {
			var piMap = getProductItemService().getMany( [ itemId ] );
			productItem = StructKeyExists( piMap, itemId )
				? piMap[ itemId ]
				: getProductItemService().get( itemId );
		}

		var attributeName = "Signage Item: #itemId#, Attributo: #productItem.getAttribute().getName()# / #productItem
			.getAttributeValue()
			.getRawValue()
			.getName()#";

		var fixedPrice     = fixedItemPrice( productItem );
		var itemMarkupInfo = itemMarkup( productItem, arguments.articleItemMarkup );

		for ( var itemComponent in itemComponents ) {
			var actualComponentCost = 0;
			var itemComponentCost = itemComponent.costAmount;
			if (itemComponentCost <= 0) {
				appendLog(
					message = "Componente: #itemComponent.raw_product_id#. Costo componente è zero, lo salto."
				);
				continue;
			}
			var itemComponentQuantity = itemComponent.totalquantity;
			if (itemComponentQuantity <= 0) {
				appendLog(
					message = "Componente: #itemComponent.raw_product_id#. Quantità componente è zero, lo salto."
				);
				continue;
			}
			// materia prima non a pezzi ( né PA / EU / NR ): quantità ( anche peso / superficie calcolati ) +15%
			var wasteFactor = getComponentService().quantityWasteFactor( itemComponent.raw_product_unit ?: "PZ" );
			var wasteLabel  = wasteFactor != 1 ? " * #wasteFactor# (#itemComponent.raw_product_unit# +15%)" : "";
			//se componente è materia prima faccio i calcoli in base all'unità di misura
			if (itemComponent.raw_product_processiong_type == 'MP') {
				// passaggi per ottenere il coefficiente dal metadata e l'unita di misura
				var measure = signageMaterialMeasure( productItem.getAttributeValue().getRawValue().getId() );
				if ( StructIsEmpty( measure ) ) {
					continue;
				}
				var coefficient = measure.coefficient;
				var measurementUnit = measure.unit;
				appendLog( message = "Coefficiente su Unità di misura: #coefficient# #measurementUnit#" );
				/* dato che la quantita del comoponente può essere diversa da 1, divio il costo del componente per la quantità
				e.g. 13.25€ costo / 2 quantità = 6.625€ costo per unità di quantità in modo da poter fare le operazioni di conversione con in mano il // costo unitario. */
				var unitPrice = itemComponentCost / itemComponentQuantity;
				if (measurementUnit EQ 'KG-MMC') {
					//se ho perso per volume, prendo il volume della lettera e lo moltiplico per il coefficiente
					var weight = sizes.volume * coefficient * wasteFactor
					appendLog( message = "Peso calcolato: #weight#kg da volume: #sizes.volume#mm³ e coefficiente: #coefficient# #measurementUnit##wasteLabel#" );
					//prendo il prezzo unitario e lo moltiplico per il peso calcolato
					var weightPrice = unitPrice * weight;
					//sommo il costo al costo dei componenti
					compCost += weightPrice;
					actualComponentCost = weightPrice;
					detailParts.append( "#itemComponent.raw_product_id# #fmtNum( unitPrice )# €/kg × #fmtNum( weight )# kg ( peso lettera, +15% sfrido )" );
					appendLog( message = "Componente: #itemComponent.raw_product_name#. Costo calcolato per peso: #weightPrice#€ ricavato moltiplicando #unitPrice#€ per #weight#kg; Costo componente calcolato: #formatExtended( actualComponentCost )#€" );
				} else if (measurementUnit EQ 'MQ') {
					//uguale al volume, ma usero la superficie invece del volume per i calcoli
					var surfaceArea = sizes.surfaceArea * coefficient * wasteFactor
					appendLog( message = "Superficie calcolata: #surfaceArea#mq da superficie: #sizes.surfaceArea#mm² e coefficiente: #coefficient# #measurementUnit##wasteLabel#" );
					var surfaceAreaPrice = unitPrice * surfaceArea;
					compCost += surfaceAreaPrice;
					actualComponentCost = surfaceAreaPrice;
					detailParts.append( "#itemComponent.raw_product_id# #fmtNum( unitPrice )# €/mq × #fmtNum( surfaceArea )# mq ( superficie lettera, +15% sfrido )" );
					appendLog( message = "Componente: #itemComponent.raw_product_name#. Costo calcolato per superficie: #surfaceAreaPrice#€ ricavato moltiplicando #unitPrice#€ per #surfaceArea#mq; Costo componente calcolato: #formatExtended( actualComponentCost )#€" );
				} else {
					actualComponentCost = itemComponentCost * itemComponentQuantity * wasteFactor;
					compCost += actualComponentCost;
					detailParts.append( "#itemComponent.raw_product_id# #fmtNum( itemComponentCost )# € × #fmtFactor( itemComponentQuantity * wasteFactor )#" & ( wasteFactor != 1 ? " ( +15% sfrido )" : "" ) );
					appendLog(
						message = "Componente: #itemComponent.raw_product_name#. Costo unitario componente: #formatExtended( itemComponentCost )#€ * quantità: #itemComponentQuantity##wasteLabel#; Costo componente calcolato: #formatExtended( actualComponentCost )#€"
					);
				}
			} else {
				//se non è materia prima sommo direttamente il costo moltiplicato per la quantità
				actualComponentCost = itemComponentCost * itemComponentQuantity * wasteFactor;
				appendLog(
					message = "Componente: #itemComponent.raw_product_name#. Costo unitario componente: #formatExtended( itemComponentCost )#€ * quantità: #itemComponentQuantity##wasteLabel#; Costo componente calcolato: #formatExtended( actualComponentCost )#€"
				);
				compCost += actualComponentCost;
				detailParts.append( "#itemComponent.raw_product_id# #fmtNum( itemComponentCost )# € × #fmtFactor( itemComponentQuantity * wasteFactor )#" & ( wasteFactor != 1 ? " ( +15% sfrido )" : "" ) );
			}

		}

		var itemValue = compCost * itemMarkupInfo.markup;
		appendLog(
			message = "#attributeName#. Totale componenti per lettera: #compCost# * ricarico ( #itemMarkupInfo.source# ): #itemMarkupInfo.markup#" & ( fixedPrice > 0 ? " + prezzo fisso attributo: #fixedPrice#" : "" ) & ";Valore attributo per lettera: #formatExtended( itemValue + fixedPrice )#"
		);

		return {
			"cost"       = compCost,
			"value"      = itemValue,
			"markup"     = itemMarkupInfo.markup,
			"source"     = itemMarkupInfo.source,
			"fixedPrice" = fixedPrice,
			"label"      = attributeLabel( productItem ),
			"detail"     = ArrayToList( detailParts, "; " )
		};
	}

	/*
		Ricarico di un attributo nel prezzo: quello della riga ( PROD_ITEM_PRICE M ), altrimenti il markup
		dell'articolo ( articleItemMarkup: 1 se l'articolo ha un importo fisso ). Un ricarico a 0 non conta.
		source serve alla spiegazione. Il ricarico generale degli attributi ( PROD_ITEM_GEN ) non si usa: nei
		dati è sempre uguale al prezzo dell'articolo ( 2026-10-28 ), verrà rimosso.
	*/
	private Struct function itemMarkup( required productItem, required numeric articleItemMarkup ){
		var itemPrice = arguments.productItem.getPrice( "PROD_ITEM_PRICE" );
		if ( !IsNull( itemPrice ) && itemPrice.getMethod().getId() == "M" && Val( itemPrice.getAmount() ?: 0 ) > 0 ) {
			return { "markup" = itemPrice.getAmount(), "source" = "ricarico attributo" };
		}
		return { "markup" = arguments.articleItemMarkup, "source" = "markup articolo" };
	}

	/* Prezzo fisso di un attributo ( PROD_ITEM_PRICE F ), 0 se non ce l'ha */
	private Numeric function fixedItemPrice( required productItem ){
		var itemPrice = arguments.productItem.getPrice( "PROD_ITEM_PRICE" );
		return !IsNull( itemPrice ) && itemPrice.getMethod().getId() == "F" ? ( itemPrice.getAmount() ?: 0 ) : 0;
	}

	/**
	 * Coefficiente e unità di misura ( KG-MMC, MQ, ... ) del primo metadata valorizzato
	 * del raw value di un attributo: servono a convertire le materie prime della
	 * segnaletica in peso/superficie della singola lettera. Struct vuota se non c'è.
	 */
	public Struct function signageMaterialMeasure( required rawValueId ){
		var metadata = metadataService.list( rawValueId = arguments.rawValueId );
		if ( Len( metadata ) == 0 ) {
			return {};
		}
		var valuedMetadataIndex = arrayFind( metadata, function( item ) {
			return item.getValue() && item.getValue() > 0;
		} );
		if ( valuedMetadataIndex EQ 0 ) {
			return {};
		}
		var valued = metadata[ valuedMetadataIndex ];
		return {
			"coefficient" = valued.getValue(),
			"unit"        = valued.getType().getMeasurementUnit().getId()
		};
	}

	/**
	 * Dimensioni della singola lettera ( stessa logica di calculate() ): altezza dal corpo
	 * del font, larghezza dal rapporto altezza/larghezza del font, spessore dal codice del
	 * modello del prodotto. Struct vuota se mancano corpo o rapporto.
	 */
	public Struct function signageLetterSizes( required signageConfigItemId, required product ){
		var signageConfigItem = super.service( "SignageConfigItem" ).get( arguments.signageConfigItemId );
		if ( IsNull( signageConfigItem ) || IsNull( signageConfigItem.getSize() ) ) {
			return {};
		}
		var fontFamilySize = super.service( "FontFamilySize" ).get( signageConfigItem.getSize().getId() );
		if ( IsNull( fontFamilySize ) ) {
			return {};
		}
		var signageConfig = super.service( "SignageConfig" ).get( signageConfigItem.getSignageConfigId() );
		var heightWidthRatio = signageConfig.getFont().getHeightWidthRatio();
		if ( IsNull( heightWidthRatio ) OR heightWidthRatio LTE 0 ) {
			return {};
		}
		var fontHeight = fontFamilySize.getName();
		var thickness  = stringThicknessToDecimal( arguments.product.getModel().getCode() );
		return {
			"height"      = fontHeight,
			"width"       = fontHeight / heightWidthRatio,
			"thickness"   = thickness,
			"surfaceArea" = fontHeight * ( fontHeight / heightWidthRatio ),
			"volume"      = thickness > 0 ? fontHeight * ( fontHeight / heightWidthRatio ) * thickness : 0
		};
	}

	private function stringThicknessToDecimal(str) {
		str = trim(str);

		if (!find("-", str)) {
			return 0;
		}

		var parts = listToArray(str, "-");
		var integerPart = val(parts[1]);
		var decimalPart = 0;

		if (arrayLen(parts) > 1 && len(parts[2])) {
			decimalPart = val(parts[2]);
			if (len(parts[2]) == 1) {
				decimalPart = decimalPart * 10;
			}
		}

		return integerPart + (decimalPart / 100);
	}
}
