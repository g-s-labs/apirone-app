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
	variables.costs     = [];

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
		any skipPrewarm = javacast("null", "") // true = il chiamante ha già fatto lo sweep verticale: salta i prewarm interni
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

		variables.costs     = [];
		// spiegazione leggibile di QUESTO calcolo ( mostrata nel simula ), separata dal log di debug su file
		request._priceExplain = [];

		/*
			INFO:

			c1 = componenti bundle ( linea / modello )
			c2 = componenti prodotto
			cA = componenti attributi ( senza ricarico )
			cL = componenti lettering ( per lettera × lettere, senza ricarico )
			G  = markup generale ( metadata 107 )

			costo  = ( c1 + c2 + cA + cL ) × G

			prezzo = ( ( c1 + c2 ) × ricarico articolo ( PRICE M ), oppure ( c1 + c2 ) + importo fisso ( PRICE F )
					 + attributi ricaricati ( PROD_ITEM_PRICE / PROD_ITEM_GEN, o prezzo fisso dell'attributo )
					 + lettering ricaricato ) × G
					 + costo fisso unitario ( quota del prezzo: non entra nel costo, niente markup )
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
		if ( IsNull( price ) ) {
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

		// TODO: verificare come gestire la mancanza di prezzo
		var isFixedPrice = ( price?.getMethod()?.getId() == "F" ?: true );
		var markup       = price?.getAmount() ?: 0;

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
		addCost( "Costo fisso", unitFixedCost, "P" );

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

		addCost(
			"Costo componenti linea / modello",
			bundleCost,
			"P"
		);

		/*
			cost base product
		*/

		var productComponents = componentSvc.priceCalculatorSearch( productId = productId, includeBaseAttributeComponents = true, skipPrewarm = doSkipPrewarm );

		var productCost = calculateComponentsTotal( productComponents, "Product" );
		var productDetail = componentsDetail( productComponents );

		// appendLog( message = "Costo componenti prodotto #productComponents#;Totale unitario: #formatExtended( productCost )#" );

		addCost( "Costo componenti prodotto", productCost, "P" );

		/*
			cost items
		*/

		var attributePrice = product.getPrice( "PROD_ITEM_GEN" );

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

		// costo puro degli attributi ( componenti senza ricarico ): è quello che entra nel costo,
		// mentre il valore ricaricato ( markup o prezzo fisso dell'attributo ) entra solo nel prezzo
		var pureItemsCost = 0;
		// dati per la spiegazione: un elemento per attributo
		var itemsInfo = [];

		for ( var itemId in productItemIds ) {
			var itemComponents = StructKeyExists( itemComponentsMap, itemId )
				? itemComponentsMap[ itemId ]
				: [];

			var itemCost = 0;

			var productItem = StructKeyExists( productItemMap, itemId )
				? productItemMap[ itemId ]
				: getProductItemService().get( itemId );

			var attributeName = "Item: #itemId#, Attributo: #productItem.getAttribute().getName()# / #productItem
				.getAttributeValue()
				.getRawValue()
				.getName()#";

			var compCost = calculateComponentsTotal( itemComponents, "ProductItem" );
			pureItemsCost += compCost;

			var productItemPrice = productItem.getPrice( "PROD_ITEM_PRICE" );

			var priceProcessed = false;
			// per la spiegazione: F = prezzo fisso dell'attributo, M = ricarico, N = nessun ricarico configurato
			var itemMode   = "N";
			var itemMarkup = 0;

			if ( !IsNull( productItemPrice ) ) {
				var amount = productItemPrice.getAmount() ?: 0;

				if ( productItemPrice.getMethod().getId() == "F" ) {
					appendLog(
						message = "#attributeName#. Prezzo -fisso- per questo attributo: #productItemPrice.getAmount()# ( costo componenti: #compCost# );Valore attributo: #formatExtended( amount )#"
					);

					itemCost = amount;
					itemMode = "F";
					itemMarkup = amount;
					priceProcessed = true;
				} else if ( productItemPrice.getMethod().getId() == "M" ) {
					itemCost = compCost * productItemPrice.getAmount();
					itemMode = "M";
					itemMarkup = amount;

					appendLog(
						message = "#attributeName#. Markup per questo attributo: #productItemPrice.getAmount()#. Totale componenti: #compCost# * markup: #productItemPrice.getAmount()#;Valore attributo: #formatExtended( itemCost )#"
					);

					priceProcessed = true;
				}
			} else {
				if ( !IsNull( attributePrice ) ) {
					var amount = attributePrice.getAmount() ?: 0;

					itemCost = compCost * amount;
					itemMode = "M";
					itemMarkup = amount;

					appendLog(
						message = "Markup generale per questo attributo: #productItem.getId()#. Totale componenti: #compCost# * markup: #amount#;Valore attributo: #formatExtended( itemCost )#"
					);

					priceProcessed = true;
				}
			}

			if ( !priceProcessed ) {
				appendLog(
					message = "ATTENZIONE: Nessun prezzo (nè generale, nè specifico) trovato per l'attributo #attributeName# (id: #itemId#), nel prezzo vale 0 ( costo componenti: #compCost# );Valore attributo: 0"
				);
			}

			addCost( "Costo attributo #itemId#", itemCost, "I" );

			itemsInfo.append( {
				"label"  = attributeLabel( productItem ),
				"cost"   = compCost,
				"value"  = itemCost,
				"mode"   = itemMode,
				"markup" = itemMarkup,
				"detail" = componentsDetail( itemComponents )
			} );
		}

		appendLog( "** Fine del calcolo del prezzo degli attributi; Valore attributi: #formatExtended( calculateTotalCostItems() )#, costo componenti: #formatExtended( pureItemsCost )#" );

		/*
			base cost: solo bundle + prodotto ( senza attributi e lettering, il costo totale è più sotto )
		*/

		var baseCost = bundleCost + productCost;

		appendLog(
			message    = "Costo base ( senza attributi e lettering ). Bundle: #bundleCost# + prodotto base: #productCost#;Costo base: #formatExtended( baseCost )#"
		);

		/*
			final price
		*/

		var totalCostItems = calculateTotalCostItems();

		/*
			font price
		*/

		var letteringPrice = 0;
		// costo puro del lettering ( componenti per lettera senza ricarico degli attributi )
		var letteringCost = 0;
		// per la spiegazione: componenti del formato ( per lettera ) e attributi per lettera
		var letterFormatCost   = 0;
		var letterFormatDetail = "";
		var letterItems        = [];
		var letterSizesLabel   = "";
		if ( lettersQuantity > 0 && simulationSignageConfigItemId GT 0 ) {
			appendLog( "** Inizio del calcolo del prezzo della segnaletica con lettering con #lettersQuantity# lettere;" );
			var fontPricePerLetter = 0;
			var fontCostPerLetter  = 0;
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
						var signageItem = calculateSignageProductItemPrice( signageItemProduct = { productItemId = productItemId, signageConfigItemId = simulationSignageConfigItemId }, attributePrice = attributePrice, sizes = sizes );
						fontPricePerLetter += signageItem.price;
						fontCostPerLetter  += signageItem.cost;
						if ( signageItem.cost > 0 || signageItem.price > 0 ) {
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

					// componenti del formato: senza ricarico, valgono uguale per prezzo e costo
					var signageBundleCost = calculateComponentsTotal( signageBundleComponents, "SignageConfigItem" );
					fontPricePerLetter += signageBundleCost;
					fontCostPerLetter  += signageBundleCost;
					letterFormatCost   = signageBundleCost;
					letterFormatDetail = componentsDetail( signageBundleComponents );
				}

				addCost(
					"Costo componenti Segnaletica",
					fontPricePerLetter,
					"P"
				);

				letteringPrice = fontPricePerLetter * lettersQuantity;
				letteringCost  = fontCostPerLetter * lettersQuantity;
			}

			appendLog( "** Fine del calcolo del prezzo della segnaletica con lettering; Valore per lettera: #formatExtended( fontPricePerLetter )# ( costo #formatExtended( fontCostPerLetter )# ), Valore totale lettering: #formatExtended( letteringPrice )# ( costo #formatExtended( letteringCost )# )" );
		}

		letteringPriceString = letteringPrice GT 0 ? "+ lettering: #formatExtended( letteringPrice )#": "";

		// costo: componenti senza ricarichi di articolo / attributi, moltiplicati per il markup generale.
		// Il prezzo qui sotto non cambia: è lo stesso costo ( × markup generale ) per i ricarichi
		// il costo fisso non entra: è una quota del prezzo di vendita ( vedi sotto )
		var componentsCost = bundleCost + productCost + pureItemsCost + letteringCost;
		var totalCost      = componentsCost * generalMarkup;
		appendLog(
			message    = "Costo finale: ( bundle: #bundleCost# + prodotto: #productCost# + componenti attributi: #pureItemsCost# + lettering: #letteringCost# ) * markup generale: #generalMarkup#;Costo finale: #formatExtended( totalCost )#",
			lineTypeId = "H"
		);

		if ( isFixedPrice ) {
			var finalPrice = ( ( bundleCost + productCost + totalCostItems ) + markup + letteringPrice ) * generalMarkup + unitFixedCost;
			appendLog(
				message    = "Prezzo finale fisso. ( ( bundle: #bundleCost# + prodotto: #productCost# + totale items: #totalCostItems# ) + markup: #markup# #letteringPriceString# ) * markup generale: #generalMarkup# + costo fisso: #unitFixedCost#;Prezzo finale: #formatExtended( finalPrice )#",
				lineTypeId = "H"
			);
		} else {
			var finalPrice = ( ( ( bundleCost + productCost ) * markup ) + totalCostItems + letteringPrice ) * generalMarkup + unitFixedCost;
			appendLog(
				message    = "Prezzo finale. ( ( ( bundle: #bundleCost# + prodotto: #productCost# ) * markup: #markup# ) + totale items: #totalCostItems# #letteringPriceString# ) * markup generale: #generalMarkup# + costo fisso: #unitFixedCost#;Prezzo finale: #formatExtended( finalPrice )#",
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
			"generalMarkup"      = generalMarkup,
			"isFixedPrice"       = isFixedPrice,
			"markup"             = markup,
			"bundleCost"         = bundleCost,
			"bundleDetail"       = bundleDetail,
			"productCost"        = productCost,
			"productDetail"      = productDetail,
			"items"              = itemsInfo,
			"unitFixedCost"      = unitFixedCost,
			"fixedCostDetail"    = ArrayToList( fixedCostParts, " + " ),
			"lettersQuantity"    = lettersQuantity,
			"letterSizesLabel"   = letterSizesLabel,
			"letterFormatCost"   = letterFormatCost,
			"letterFormatDetail" = letterFormatDetail,
			"letterItems"        = letterItems,
			"letteringCost"      = letteringCost,
			"letteringPrice"     = letteringPrice,
			"componentsCost"     = componentsCost,
			"totalCost"          = totalCost,
			"finalPrice"         = finalPrice
		} );

		var output = {
			"explain" = request._priceExplain,
			values = {
				"finalCost"      = totalCost,
				"baseCost"       = baseCost,
				"bundleCost"     = bundleCost,
				"productCost"    = productCost,
				"totalCostItems" = totalCostItems,
				"totalCost"      = totalCost,
				"unitFixedCost"  = unitFixedCost,
				"finalPrice"     = finalPrice,
				"priceType"      = price
			},
			"currency" = "EUR",
			"logFile" = variables.logConfig.filePath
		};

		return output;
	}

	/*
		Spiegazione del calcolo per il simula: due blocchi, costo e prezzo, una riga per voce con
		i componenti in piccolo sotto ( così non si sommano due volte ). Il prezzo è scritto come
		costo ( × markup generale ) × ricarico di ogni voce, più il costo fisso alla fine: è la
		stessa formula di simulate(), raccolta voce per voce, e il totale mostrato è finalPrice.
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

		explain( "Prezzo di vendita ( costo × ricarichi + costo fisso )", "", "section" );

		var baseCost = ( d.bundleCost + d.productCost ) * g;
		if ( d.isFixedPrice ) {
			explain( "Linea / modello + prodotto", baseCost, "row", "#fmtNum( d.bundleCost + d.productCost )# × #fmtFactor( g )#, nessun ricarico ( l'articolo ha un ricarico a importo fisso )" );
			explain( "Ricarico articolo a importo fisso", d.markup * g, "row", "#fmtNum( d.markup )# € × #fmtFactor( g )#" );
		} else {
			explain( "Linea / modello + prodotto", baseCost * d.markup, "row", "#fmtNum( d.bundleCost + d.productCost )# × #fmtFactor( g )# = #fmtNum( baseCost )# × ricarico articolo #fmtFactor( d.markup )#" );
		}

		for ( var item in d.items ) {
			if ( item.mode == "F" ) {
				explain( "Attributo #item.label#", item.value * g, "row", "prezzo fisso dell'attributo #fmtNum( item.markup )# € × #fmtFactor( g )#" );
			} else if ( item.cost > 0 ) {
				if ( item.mode == "M" && item.markup > 0 ) {
					explain( "Attributo #item.label#", item.value * g, "row", "#fmtNum( item.cost )# × #fmtFactor( g )# = #fmtNum( item.cost * g )# × ricarico attributo #fmtFactor( item.markup )#" );
				} else {
					explain( "Attributo #item.label#", 0, "row", "ricarico attributo assente o 0: non entra nel prezzo" );
				}
			}
		}

		if ( d.lettersQuantity > 0 ) {
			var letterValue  = d.lettersQuantity ? d.letteringPrice / d.lettersQuantity : 0;
			var letterDetail = [];
			if ( d.letterFormatCost > 0 ) {
				letterDetail.append( "formato #fmtNum( d.letterFormatCost )# × #fmtFactor( g )#" );
			}
			for ( var letterItem in d.letterItems ) {
				if ( letterItem.mode == "F" ) {
					letterDetail.append( "#letterItem.label#: prezzo fisso #fmtNum( letterItem.price )# € × #fmtFactor( g )#" );
				} else {
					letterDetail.append( "#letterItem.label#: #fmtNum( letterItem.cost )# × #fmtFactor( g )# × ricarico #fmtFactor( letterItem.markup )#" );
				}
			}
			explain( "Lettering: #d.lettersQuantity# lettere × #fmtNum( letterValue * g )# €", d.letteringPrice * g, "row", ArrayToList( letterDetail, " + " ) );
		}

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

	private Void function addCost(
		required String label,
		required Numeric amount,
		required String typeId = "P"
	){
		variables.costs.add( {
			"label"  = arguments.label,
			"amount" = arguments.amount,
			"typeId" = arguments.typeId
		} );
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

	private Numeric function calculateTotalCostItems(){
		var total = 0;

		for ( var item in variables.costs ) {
			if ( item.typeId EQ "I" ) {
				total = total + item.amount
			}
		}

		return total;
	}

	private Numeric function formatExtended( required Numeric value ){
		return NumberFormat( value, ".9999" );
	}

	private function calculateSignageProductItemPrice( Struct signageItemProduct, attributePrice, sizes ){
		componentSvc = getComponentService();
		var itemComponents = componentSvc.priceCalculatorSearch( signageItemProduct = signageItemProduct );
		if ( Len( itemComponents ) EQ 0 ) {
			return { "price" = 0, "cost" = 0 };
		}
		var itemCost = 0;
		var compCost = 0;
		// per la spiegazione: un pezzo di testo per ogni componente che entra nel costo per lettera
		var detailParts = [];

		//recupero il product item id dalla struttura che uso per recuperare i componenti
		var itemId = signageItemProduct.productItemId;
		// Carica il productItem via batch getMany() per evitare cascata N+1
		var piMap = getProductItemService().getMany( [ itemId ] );
		var productItem = StructKeyExists( piMap, itemId )
			? piMap[ itemId ]
			: getProductItemService().get( itemId );

		var attributeName = "Signage Item: #itemId#, Attributo: #productItem.getAttribute().getName()# / #productItem
			.getAttributeValue()
			.getRawValue()
			.getName()#";

		// recupero il price specifico per l'item se presente
		var productItemPrice = productItem.getPrice( "PROD_ITEM_PRICE" );
		var priceProcessed = false;

		var markup = 0;
		if ( !IsNull( productItemPrice ) ) {
			// imposto il markup specifico per l'item
			markup = productItemPrice.getAmount();

			//se product item price è fisso il prezzo è l'importo fisso ( i componenti servono solo per il costo )
			if ( productItemPrice.getMethod().getId() == "F" ) {
				appendLog(
					message = "#attributeName#. Prezzo -fisso- per questo attributo: #productItemPrice.getAmount()#;Valore attributo: #formatExtended( markup )#"
				);

				itemCost = markup;
				priceProcessed = true;
			}
		//se non è presente un price specifico per l'item o se esiste ma è percentuale e non fisso, uso il markup generale
		} else {
			if ( !IsNull( attributePrice ) ) {
				markup = attributePrice.getAmount();
			}
		}

		// per ora forzo il markup a 1 se è zero
		markup = markup > 0 ? markup : 1
		// costo dei componenti per lettera: calcolato sempre, anche con prezzo fisso dell'attributo,
		// perché è il costo di produzione ( il ricarico entra solo nel prezzo )
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

		if ( priceProcessed ) {
			appendLog(
				message = "Prezzo fisso per questo attributo: #productItem.getId()#. Costo componenti: #compCost#;Valore attributo: #formatExtended( itemCost )#"
			);
		} else {
			itemCost = compCost * markup;
			appendLog(
				message = "Markup generale per questo attributo: #productItem.getId()#. Totale componenti: #compCost# * markup: #markup#;Valore attributo: #formatExtended( itemCost )#"
			);
		}

		addCost( "Costo attributo #itemId#", itemCost, "I" );
		// price = valore per lettera ricaricato ( entra nel prezzo ), cost = componenti per lettera ( entra nel costo )
		return {
			"price"  = itemCost,
			"cost"   = compCost,
			"label"  = attributeLabel( productItem ),
			"detail" = ArrayToList( detailParts, "; " ),
			"mode"   = priceProcessed ? "F" : "M",
			"markup" = markup
		};
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
