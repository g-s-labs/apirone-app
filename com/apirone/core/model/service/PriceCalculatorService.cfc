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

		/*
			INFO:

			c1 = totale costi comp. bundle
			c2 = totale costi comp. articolo
			s1 = ( c1+c2 ) * markup articolo (PRICE);

			sN = per ogni productItem
					totale costi dei componenti
						* marktup attr generale (PROD_ITEM_GEN) o quello specifico (PROD_ITEM_PRICE)

			sT = totale costi productItems (somma sN)

			costo finale  = c1 + c2 + costo fisso;
			prezzo finale = s1 + sT + costo fisso;
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
		if (isPlaccaOrSegnaletica(product)) {
			appendLog(
				message="Il prodotto è PLA o SEG, quindi i COST_FIXED li calcolo dividendo il costo fisso della tabella costi fissi linea_finitura su tutti gli altri articoli del preventivo"
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
		}

		// per PLA/SEG fixedCost/quantitaTotale sono quelli linea/finitura; unitFixedCost
		// include anche l'eventuale quota linea/modello (loggata a parte sopra)
		appendLog(
			message = "Costo fisso per #quantitaTotale# pezzi. Costo fisso #fixedCost# / #quantitaTotale#;Costo fisso unitario totale: #formatExtended( unitFixedCost )#"
		);

		addCost( "Costo fisso", unitFixedCost, "P" ); // sommerò gli "P" per il costo finale

		/*
			cost bundle
		*/

		var bundleCost = 0;

		if ( IsInstanceOf( product, "com.apirone.core.model.bean.ProductComplex" ) ) {
			var bundleComponents = componentSvc.priceCalculatorSearch(
				lineId                         = product.getLine().getId(),
				modelId                        = product.getModel().getId(),
				includeBaseAttributeComponents = true,
				skipPrewarm                    = doSkipPrewarm
			);

			var bundleCost = calculateComponentsTotal( bundleComponents, "CatalogBundle" );
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

		for ( var itemId in productItemIds ) {
			var itemComponents = StructKeyExists( itemComponentsMap, itemId )
				? itemComponentsMap[ itemId ]
				: [];

			var itemCost = 0;
			var compCost = 0;

			var productItem = StructKeyExists( productItemMap, itemId )
				? productItemMap[ itemId ]
				: getProductItemService().get( itemId );

			var attributeName = "Item: #itemId#, Attributo: #productItem.getAttribute().getName()# / #productItem
				.getAttributeValue()
				.getRawValue()
				.getName()#";

			var productItemPrice = productItem.getPrice( "PROD_ITEM_PRICE" );

			var priceProcessed = false;

			if ( !IsNull( productItemPrice ) ) {
				var amount = productItemPrice.getAmount() ?: 0;

				if ( productItemPrice.getMethod().getId() == "F" ) {
					appendLog(
						message = "#attributeName#. Prezzo -fisso- per questo attributo: #productItemPrice.getAmount()#. Salto i costi dei componenti;Costo attributo: #formatExtended( amount )#"
					);

					itemCost = amount;
					priceProcessed = true;
				} else if ( productItemPrice.getMethod().getId() == "M" ) {
					var compCost = calculateComponentsTotal( itemComponents, "ProductItem" );
					itemCost     = compCost * productItemPrice.getAmount();

					appendLog(
						message = "#attributeName#. Markup per questo attributo: #productItemPrice.getAmount()#. Totale componenti: #compCost# * markup: #productItemPrice.getAmount()#;Costo attributo: #formatExtended( itemCost )#"
					);

					priceProcessed = true;
				}
			} else {
				if ( !IsNull( attributePrice ) ) {
					var compCost = calculateComponentsTotal( itemComponents, "ProductItem" );

					var amount = attributePrice.getAmount() ?: 0;

					itemCost = compCost * amount;

					appendLog(
						message = "Markup generale per questo attributo: #productItem.getId()#. Totale componenti: #compCost# * markup: #amount#;Costo attributo: #formatExtended( itemCost )#"
					);

					priceProcessed = true;
				}
			}

			if ( !priceProcessed ) {
				appendLog(
					message = "ATTENZIONE: Nessun prezzo (nè generale, nè specifico) trovato per l'attributo #attributeName# (id: #itemId#);Costo attributo: 0"
				);
			}

			addCost( "Costo attributo #itemId#", itemCost, "I" );
		}

		appendLog( "** Fine del calcolo del prezzo degli attributi; Totale attributi: #formatExtended( calculateTotalCostItems() )#" );

		/*
			final cost
		*/

		var finalCost = bundleCost + productCost + unitFixedCost;

		appendLog(
			message    = "Costi finali. Bundle: #bundleCost# + prodotto base: #productCost# + costo fisso: #unitFixedCost#;Costo finale: #formatExtended( finalCost )#",
			lineTypeId = "H"
		);

		/*
			final price
		*/

		var totalCostItems = calculateTotalCostItems();

		/*
			font price
		*/

		var letteringPrice = 0;
		if ( lettersQuantity > 0 && simulationSignageConfigItemId GT 0 ) {
			appendLog( "** Inizio del calcolo del prezzo della segnaletica con lettering con #lettersQuantity# lettere;" );
			var fontPricePerLetter = 0;
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
				if ( Len( productItemIds ) ) {
					//costo componenti items segnaletica
					for ( var productItemId in productItemIds ) {
						var fontPricePerLetter += calculateSignageProductItemPrice( signageItemProduct = { productItemId = productItemId, signageConfigItemId = simulationSignageConfigItemId }, attributePrice = attributePrice, sizes = sizes );
					}
				}

				//calcolo costo componenti segnaletica
				var signageBundleCost = 0;
				if ( IsInstanceOf( product, "com.apirone.core.model.bean.ProductComplex" ) ) {
					var signageBundleComponents = componentSvc.priceCalculatorSearch(
						signageConfigItemId = simulationSignageConfigItemId,
						includeBaseAttributeComponents = true,
						skipPrewarm = doSkipPrewarm
					);

					var fontPricePerLetter += calculateComponentsTotal( signageBundleComponents, "SignageConfigItem" );
				}

				addCost(
					"Costo componenti Segnaletica",
					fontPricePerLetter,
					"P"
				);

				letteringPrice = fontPricePerLetter * lettersQuantity;
			}

			appendLog( "** Fine del calcolo del prezzo della segnaletica con lettering; Costo per lettera: #formatExtended( fontPricePerLetter )#, Costo totale lettering: #formatExtended( fontPricePerLetter * lettersQuantity )#" );
		}

		letteringPriceString = letteringPrice GT 0 ? "+ costo lettering: #formatExtended( letteringPrice )#": "";

		var totalCost = bundleCost + productCost + totalCostItems + unitFixedCost + letteringPrice;
		appendLog(
			message    = "Costo finale fisso: bundle: #bundleCost# + prodotto: #productCost# + totale items: #totalCostItems# + costo fisso: #unitFixedCost# #letteringPriceString# = Costo finale: #formatExtended( totalCost )#",
			lineTypeId = "H"
		);

		if ( isFixedPrice ) {
			var finalPrice = ( ( bundleCost + productCost + totalCostItems + unitFixedCost ) + markup + letteringPrice ) * generalMarkup;
			appendLog(
				message    = "Prezzo finale fisso. ( ( bundle: #bundleCost# + prodotto: #productCost# + totale items: #totalCostItems# + costo fisso: #unitFixedCost# ) + markup: #markup# #letteringPriceString# ) * markup generale: #generalMarkup#;Prezzo finale: #formatExtended( finalPrice )#",
				lineTypeId = "H"
			);
		} else {
			var finalPrice = ( ( ( bundleCost + productCost ) * markup ) + totalCostItems + unitFixedCost + letteringPrice ) * generalMarkup;
			appendLog(
				message    = "Prezzo finale. ( ( ( bundle: #bundleCost# + prodotto: #productCost# ) * markup: #markup# ) + totale items: #totalCostItems# + costo fisso: #unitFixedCost# #letteringPriceString# ) * markup generale: #generalMarkup#;Prezzo finale: #formatExtended( finalPrice )#",
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

		var output = {
			values = {
				"finalCost"      = finalCost,
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
			return;
		}
		var itemCost = 0;
		var compCost = 0;

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

			//se product item price è fisso non faccio nessun ragionamento o conversione sui componenti
			if ( productItemPrice.getMethod().getId() == "F" ) {
				appendLog(
					message = "#attributeName#. Prezzo -fisso- per questo attributo: #productItemPrice.getAmount()#. Salto i costi dei componenti;Costo attributo: #formatExtended( markup )#"
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
		// qui entro solo se ho un markup e se non ho già processato il prezzo come fisso
		if ( priceProcessed == false ) {
			// calcolo il costo dei componenti
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
						appendLog( message = "Componente: #itemComponent.raw_product_name#. Costo calcolato per peso: #weightPrice#€ ricavato moltiplicando #unitPrice#€ per #weight#kg; Costo componente calcolato: #formatExtended( actualComponentCost )#€" );
					} else if (measurementUnit EQ 'MQ') {
						//uguale al volume, ma usero la superficie invece del volume per i calcoli
						var surfaceArea = sizes.surfaceArea * coefficient * wasteFactor
						appendLog( message = "Superficie calcolata: #surfaceArea#mq da superficie: #sizes.surfaceArea#mm² e coefficiente: #coefficient# #measurementUnit##wasteLabel#" );
						var surfaceAreaPrice = unitPrice * surfaceArea;
						compCost += surfaceAreaPrice;
						actualComponentCost = surfaceAreaPrice;
						appendLog( message = "Componente: #itemComponent.raw_product_name#. Costo calcolato per superficie: #surfaceAreaPrice#€ ricavato moltiplicando #unitPrice#€ per #surfaceArea#mq; Costo componente calcolato: #formatExtended( actualComponentCost )#€" );
					} else {
						actualComponentCost = itemComponentCost * itemComponentQuantity * wasteFactor;
						compCost += actualComponentCost;
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
				}

			}

			itemCost = compCost * markup;
			priceProcessed = true;
		}

		appendLog(
			message = "Markup generale per questo attributo: #productItem.getId()#. Totale componenti: #compCost# * markup: #markup#;Costo attributo: #formatExtended( itemCost )#"
		);

		if ( !priceProcessed ) {
			appendLog(
				message = "ATTENZIONE: Nessun prezzo (nè generale, nè specifico) trovato per l'attributo #attributeName# (id: #itemId#);Costo attributo: 0"
			);
		}

		addCost( "Costo attributo #itemId#", itemCost, "I" );
		return itemCost;
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
