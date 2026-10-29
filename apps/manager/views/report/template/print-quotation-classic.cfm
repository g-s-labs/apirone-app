<cfoutput>
	<cfset langId = (!isNull(args.data.quotation.getLang()) ? UCase(args.data.quotation.getLang().getId()) : "IT")>
	<!--- proforma: stessa stampa del preventivo, con testata, pagamento e totali dedicati --->
	<cfset isProforma      = (args.params.report ?: "") EQ "proforma">
	<cfset proformaProg    = Trim( args.params.progressivo ?: "" )>
	<cfset proformaPercent = Val( args.params.percentuale ?: 0 )>
	<!--- L'importo, se indicato, sostituisce la percentuale: l'anticipo e' quella cifra. --->
	<cfset proformaAmount  = Val( args.params.importo ?: 0 )>
	<cfset proformaByAmount = proformaAmount GT 0>
	<cfset proformaAdvanceLabel = proformaByAmount
			? LSNumberFormat( proformaAmount, "9,999.99", "it_IT" ) & " &euro; " & printLabel( 'advancePayment', langId )
			: ( proformaPercent EQ Int( proformaPercent ) ? Int( proformaPercent ) : LSNumberFormat( proformaPercent, "9.99" ) ) & "% " & printLabel( 'advancePayment', langId )>
	<cfdocument attributeCollection="#args.pdfArgs#" marginTop="2.6" marginLeft="0.1" marginRight="0.1">
		#printStyle()#
		<cfif isQuotationDraftForPrint( args.data.quotation )>
			<style>
				@page {
					background-image: url('/assets/main/img/quotation-watermark-2.jpg');
					background-repeat: repeat;
					background-size: 1920px;
					z-index: 900;
					background-color:rgba(0, 0, 0, 0.1);
				}
			</style>
		</cfif>
		<div>
			<cfdocumentitem type="header">
				<table style="border: 0; width: 20cm; margin-left: 0.1in;">
					<tbody>
						<tr style="border: 0;">
							<td style="border: 0;">
								#getPrintFullHeader()#
							</td>
							<td style="border: 0; width: 9cm; padding-top: .4in;">
								<h2 style="text-align: right; margin-right: .1in;"><cfif isProforma>#printLabel('proforma', langId)# N. #args.data.quotation.getQuotationNumber()#/#args.data.quotation.getVersionNumber()#<cfif Len( proformaProg )>/#proformaProg#</cfif><cfelse>#printLabel('quotation', langId)# N. #args.data.quotation.getQuotationNumber()#/#args.data.quotation.getVersionNumber()#</cfif></h2>
								<table style="width: 100%; border-collapse: collapse; border-top: 1px solid black; border-left: 1px solid black;">
									<tr>
										<td style="width: 40%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">#printLabel('date', langId)#</td>
										<td style="width: 60%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black; padding-left: 5px;">#DateFormat( args.data.quotation.getQuotationDate(), "dd/mm/yyyy" )#</td>
									</tr>
									<cfif !isProforma>
										<tr>
											<td style="width: 40%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">#printLabel('offerValidity', langId)#</td>
											<td style="width: 60%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black; padding-left: 5px;">#DateFormat( args.data.quotation.getValidityDate(), "dd/mm/yyyy" )#</td>
										</tr>
									</cfif>
									<tr>
										<td style="width: 40%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">#printLabel('paymentMethod', langId)#</td>
										<td style="width: 60%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black; padding-left: 5px;"><cfif isProforma>#proformaAdvanceLabel#<cfelse>#args.data.quotation.getPaymentMethodName()#</cfif></td>
									</tr>
									<!--- modalità di pagamento: solo con pagamento 26 SCADENZE DA IMPUTARE ( altrimenti è vuota ) --->
									<cfif !isProforma AND Len( args.data.quotation.getCustomPaymentMethod() ?: "" )>
										<tr>
											<td style="width: 40%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">#printLabel('customPaymentMethod', langId)#</td>
											<td style="width: 60%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black; padding-left: 5px;">#EncodeForHTML( args.data.quotation.getCustomPaymentMethod() )#</td>
										</tr>
									</cfif>
									<tr>
										<td style="width: 40%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black; vertical-align: top;">#printLabel('salesAgent', langId)#</td>
										<td style="width: 60%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black; padding-left: 5px;">#printSalesAgent(salesAgent = args.data.quotation.getSalesAgent(), langId = langId)#</td>
									</tr>
								</table>
							</td>
						</tr>
					</tbody>
				</table>

			</cfdocumentitem>

			<cfdocumentitem type="footer">
				#getPrintFooter()#
			</cfdocumentitem>

			<cfoutput>
				<div>
					<table class="cstmtable" style="margin-top: .1in; width: 100%;">
						<tr>
							<td style="width: 50%;"></td>
							<cfif !isNull(args.data.quotation.getShippingProfile())>
								<td style="width: 50%; padding-left: 0.05in;"><strong>#printLabel('shippingAddress', langId)#</strong></td>
							<cfelse>
								<td style="width: 50%;"></td>
							</cfif>
						</tr>
						<tr>
							<td>
								<cfif !isNull(args.data.quotation.getCustomer())>
									<table style="width: 100%; padding: 0; border: 0; border-collapse: collapse;">
										<tr style="border: 0">
											<td style="border: 0; font-weight: bold; padding-left: 0.05in;">#printLabel('company', langId)#: </td>
											<td style="border: 0; padding-left: 0.05in; width: 65%;">#args.data.quotation.getCustomer().getCompany()#</td>
										</tr>
										<tr style="border: 0">
											<td style="border: 0; font-weight: bold; padding-left: 0.05in;">#printLabel('phone', langId)#: </td>
											<td style="border: 0; padding-left: 0.05in;">#args.data.quotation.getCustomer().getPhone()#</td>
										</tr>
										<tr style="border: 0">
											<td style="border: 0; font-weight: bold; padding-left: 0.05in;">#printLabel('email', langId)#: </td>
											<td style="border: 0; padding-left: 0.05in;">#args.data.quotation.getCustomer().getEmail() ?: ""#</td>
										</tr>
										<tr style="border: 0">
											<td style="border: 0; font-weight: bold; padding-left: 0.05in;">#printLabel('vatNumber', langId)#: </td>
											<td style="border: 0; padding-left: 0.05in;">#args.data.quotation.getCustomer().getVatNumber()#</td>
										</tr>
										<tr style="border: 0">
											<td style="border: 0; vertical-align: top; font-weight: bold; padding-left: 0.05in;">#printLabel('address', langId)#: </td>
											<td style="border: 0; padding-left: 0.05in;">
												#args.data.quotation.getCustomer().getStreet()# #args.data.quotation.getCustomer().getPostalCode()#<br>
												#args.data.quotation.getCustomer().getCity()# #args.data.quotation.getCustomer().getState()#
												<cfif !isNull(args.data.quotation.getCustomer().getCountry())><cfset custCountry = args.data.quotation.getCustomer().getCountry()>#Len( Trim( custCountry.getIsoCode() ?: '' ) ) ? custCountry.getIsoCode() : ( custCountry.getCode() ?: '' )#<br></cfif>
											</td>
										</tr>
									</table>
								<cfelseif !isNull(args.data.quotation.getLead())>
									<table style="width: 100%; padding: 0; border: 0; border-collapse: collapse;">
										<tr style="border: 0">
											<td style="border: 0; font-weight: bold; padding-left: 0.05in;">#printLabel('lead', langId)#: </td>
											<td style="border: 0; padding-left: 0.05in; width: 65%;">#args.data.quotation.getLead().getName()#</td>
										</tr>
									</table>
								<cfelseif !isNull(args.data.quotation.getOpportunity())>
									<table style="width: 100%; padding: 0; border: 0; border-collapse: collapse;">
										<tr style="border: 0">
											<td style="border: 0; font-weight: bold; padding-left: 0.05in;">#printLabel('opportunity', langId)#: </td>
											<td style="border: 0; padding-left: 0.05in; width: 65%;">#args.data.quotation.getOpportunity().getName()#</td>
										</tr>
									</table>
								</cfif>
							</td>
							<td>
								<cfif !isNull(args.data.quotation.getShippingProfile())>
									<table style="width: 100%; padding: 0; border: 0; border-collapse: collapse;">
										<tr style="border: 0">
											<td style="border: 0; font-weight: bold; padding-left: 0.05in;">#printLabel('shippingName', langId)#: </td>
											<td style="border: 0; width: 75%">#args.data.quotation.getShippingProfile().getCompany()#</td>
										</tr>
										<tr style="border: 0">
											<td style="border: 0; vertical-align: top; font-weight: bold; padding-left: 0.05in;">#printLabel('address', langId)#: </td>
											<td style="border: 0">
												#args.data.quotation.getShippingProfile().getStreet()# #args.data.quotation.getShippingProfile().getPostalCode()#<br>
												#args.data.quotation.getShippingProfile().getCity()# #args.data.quotation.getShippingProfile().getState()#
												<cfif !isNull(args.data.quotation.getShippingProfile().getCountry())><cfset spCountry = args.data.quotation.getShippingProfile().getCountry()>#Len( Trim( spCountry.getIsoCode() ?: '' ) ) ? spCountry.getIsoCode() : ( spCountry.getCode() ?: '' )#<br></cfif>
											</td>
										</tr>
									</table>
								</cfif>
							</td>
						</tr>
					</table>

					<cfset blundlesPrinted = {}>
				</div>
			</cfoutput>

			<cfoutput>

				<!--- fattore unico per le placche ritagliate: la piu' grande riempie il box,
				      le altre le restano proporzionate --->
				<cfset imgScale = printImageScale( data = args.data, boxWidthCm = 5, boxHeightCm = 5 )>
				<cfloop array="#args.data.plants#" index="plant">
					#printPlant(plant = plant, langId = langId)#
				</cfloop>
				<cfloop array="#args.data.itemGroups#" index="categoryGroup">
					<cfset groupItemsCount = ArrayLen( categoryGroup.items )>
					<cfset groupPlantsCount = ArrayLen( categoryGroup.plants )>
					<cfset sectionTitle = Len( categoryGroup.id ) ? printCategoryType(categoryGroup.id, categoryGroup.name, langId) : "">
					<cfloop from="1" to="#groupPlantsCount#" index="plantIndex">
						#printPlant(plant = categoryGroup.plants[plantIndex], langId = langId, sectionTitle = plantIndex EQ 1 ? sectionTitle : "")#
					</cfloop>
					<cfif groupItemsCount GT 0>
						<cfif Len( sectionTitle ) AND groupPlantsCount EQ 0><div class="category-section">#sectionTitle#</div></cfif>
						<!---
							Una sola tabella per gruppo, con l'intestazione colonne nel <thead>.
							Prima ogni voce era una tabella a se' e l'intestazione si ripeteva
							sotto ogni articolo.
							-fs-table-paginate e' l'estensione di Flying Saucer che fa ripetere
							il <thead> dopo un salto pagina: senza, cfdocument lo stampa una volta
							sola e le pagine successive restano senza intestazione ( verificato ).
							Il blocco non spezzabile e' passato dal <div> per voce alla <tr>,
							altrimenti le righe non potrebbero stare tutte nella stessa tabella.
						--->
						<table style="border-collapse: collapse; width: 100%; -fs-table-paginate: paginate;">
							<thead>
								<tr>
								<td style="width: 11.2cm; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 1px solid black; border-right: 0; padding-left: 0.1in;">#printLabel('article', langId)#</td>
								<td style="width: 2.0cm; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 0; border-right: 0; text-align: right; white-space: nowrap; padding-right: 0.1in;">#printLabel('unitPrice', langId)#</td>
								<cfif args.params.discounts><td style="width: 1.5cm; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 0; border-right: 0; text-align: right; white-space: nowrap; padding-right: 0.1in;">#printLabel('discount', langId)#</td></cfif>
								<td style="width: 1.0cm; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 0; border-right: 0; text-align: right; white-space: nowrap; padding-right: 0.1in;">#printLabel('qty', langId)#</td>
								<td style="width: 2.1cm; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 0; border-right: 0; text-align: right; white-space: nowrap; padding-right: 0.1in;">#printLabel('netUnitPrice', langId)#</td>
								<td style="width: 2.2cm; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 0; border-right: 1px solid black; text-align: right; white-space: nowrap; padding-right: 0.1in;">#printLabel('total', langId)#</td>
								</tr>
							</thead>
							<tbody>
							<cfloop from="1" to="#groupItemsCount#" index="groupItemIndex">
								<cfset oggetto = categoryGroup.items[groupItemIndex]>
								<cfset zones = oggetto.zones>
								<cfset quantity = oggetto.quantity>
								<cfset oggetto = oggetto.item>
								<cfset hasDim = StructKeyExists(args.data, "modelConfigMap") && StructKeyExists(args.data.modelConfigMap, oggetto.getProduct().getId())>
								<cfif hasDim><cfset thisDimMC = args.data.modelConfigMap[oggetto.getProduct().getId()]></cfif>
								<cfset thisDimType = hasDim && !isNull(oggetto.getProduct().getCategory()) && !isNull(oggetto.getProduct().getCategory().getType()) ? oggetto.getProduct().getCategory().getType().getId() : "">
								<cfset prezzoScontato = oggetto.getPrice().getTotal()>
								<cfset sconto1 = Val( oggetto.getPrice().getDiscount1() ?: 0 )>
								<cfset sconto2 = Val( oggetto.getPrice().getDiscount2() ?: 0 )>
								<cfset moltiplicatore = (1 - (sconto1 / 100)) * (1 - (sconto2 / 100))>
								<cfset prezzoPieno = moltiplicatore EQ 0 ? 0 : prezzoScontato / moltiplicatore>
								<cfset scontoTesto = "">
								<cfif sconto1 GT 0><cfset scontoTesto = printPercent( sconto1 )></cfif>
								<cfif sconto2 GT 0><cfset scontoTesto = ListAppend( scontoTesto, printPercent( sconto2 ), "+" )></cfif>
								<cfif !Len( scontoTesto )><cfset scontoTesto = printPercent( 0 )></cfif>
								<tr style="page-break-inside: avoid;">
								<td style="margin: 0 !important; padding: 3px; align-items: center; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 1px solid black; border-right: 0; width: 11.2cm !important;">
									<table class="hiddenTable">
										<tr>
											<cfif args.params.images>
												<td style="vertical-align: middle; width: 5cm;" rowspan="2">
													<!--- box uguale per tutte le immagini: e' quello che rimette
													      alla stessa scala placche orizzontali e verticali --->
													#printItemImage( item = oggetto, data = args.data, boxWidthCm = 5, boxHeightCm = 5, cmPerMm = imgScale )#
												</td>
											</cfif>
											<!---
												Lo stacco dall'immagine sta qui e non sulla cella
												dell'immagine: hiddenTable è table-layout: fixed con
												box-sizing: border-box, quindi un padding a sinistra
												ridurrebbe lo spazio utile dei 5cm e l'immagine, forzata
												a 5cm, sborderebbe riprendendosi il margine.
												Condizionato perché senza immagine non serve rientro.
											--->
											<td style="<cfif args.params.images>padding-left: 0.25cm;</cfif>">
												<!---
													Nome, finitura e dimensioni ( sempre qui sotto al nome, anche
													per placche e segnaletica ): vedi printItemDescription.
												--->
												<cfif !isNull(oggetto.getArticle())>
													<span style="font-size: 7pt; text-transform: lowecase">#oggetto.getArticle().getName()#</span><br>
													<cfif hasDim>
														#printDimensions( thisDimMC, langId, ( thisDimType EQ "PLA" OR thisDimType EQ "SEG" ) ? "mm" : "cm" )#
													</cfif>
												<cfelse>
													#printItemDescription( oggetto, args.data, langId )#
												</cfif>
												<cfif !isNull(oggetto.getItems()) && oggetto.getItems().len() GT 0>
													<cfset itemsCount = ArrayLen( oggetto.getItems() )>
													<cfloop from="1"  to="#itemsCount#" index="item">
														<cfset item = oggetto.getItems()[item]>
														<span style="font-size: 7pt; text-transform: lowecase">#item.getProductItem().getAttribute().getName()#: #item.getProductItem().getAttributeValue().getRawValue().getName()#</span><br>
													</cfloop>
												</cfif>
												<!---
													Nota della voce una volta sola, qui in fondo. Prima usciva
													anche subito sotto al titolo ( e lì ignorando il flag note ),
													quindi si vedeva doppia. Fuori dal blocco degli attributi:
													anche le voci senza attributi devono mostrarla.
												--->
												<cfif !isNull(oggetto.getNote()) && Len( Trim( oggetto.getNote() ) ) && args.params.note>
													<span style="font-size: 7pt; text-transform: lowecase">Note: #oggetto.getNote()#</span>
												</cfif>
											</td>
										</tr>
										<tr>
											<!--- seconda riga del rowspan dell'immagine: stesso stacco
											      applicato alla descrizione, altrimenti "Posizioni" e
											      la lista frutti restano incollate all'immagine --->
											<td style="vertical-align: bottom; padding: 3pt 0 3px <cfif args.params.images>0.25cm<cfelse>0</cfif>;">
												<cfif IsInstanceOf(oggetto, "com.apirone.core.model.bean.QuotationItemPlate") && oggetto.getFruits().len() GT 0>
													<div style="font-size: 7pt; line-height: 15px;">
														Lista Frutti:
														<cfif NOT isNull(oggetto.getFruits())>
															<cfset fruitsCount = ArrayLen( oggetto.getFruits() )>
															<ul style="padding: 0 0 0 24px;">
																<cfloop from="1" to="#fruitsCount#" index="fi">
																	<cfset fruit = oggetto.getFruits()[fi]>
																	<li style="padding: 0">
																		<b>P.
																			<cfset fruitPositionsCount = ArrayLen( fruit.getPositions() )>
																			<cfloop from="1" to="#fruitPositionsCount#" index="fpi">
																				<cfset fruitPosition = fruit.getPositions()[fpi]>
																				#fruitPosition.order + 1#<cfif fpi < fruitPositionsCount > - </cfif>
																			</cfloop>
																		</b> : Cod.
																		<span style="text-transform: lowercase; font-size: 7pt;">
																			#fruit.getFruit().getCode()#<br>
																			<cfif IsArray( fruit.getItems() )>
																				<cfloop array="#fruit.getItems()#" index="fruitItem">
																					<span style="font-size: 7pt; text-transform: lowecase">
																						#fruitItem.getProductItem().getAttribute().getName()#: #fruitItem.getProductItem().getAttributeValue().getRawValue().getName()#
																					</span><br>
																				</cfloop>
																			</cfif>
																			<cfif !isNull(fruit.getNote()) && args.params.note>
																				<span style="font-size: 7pt; margin-top: 4pt;">
																					<i>( Note: #fruit.getNote()# )</i>
																				</span>
																			</cfif>
																		</span>
																	</li>
																</cfloop>
															</ul>
														</cfif>
													</div>
												</cfif>
												<!---
													Righe posizione da stampare. La quantità non si riporta
													più: è già nella sua colonna, qui era una ripetizione.
													Si costruisce prima l'elenco per non stampare
													l'intestazione "Posizioni:" quando poi sotto non
													resterebbe nulla — caso tipico dell'articolo in
													"Non assegnato" senza codici posizione.
												--->
												<cfset positionLines = []>
												<cfloop collection="#zones#" item="zoneName">
													<cfset thisPositions = zones[ zoneName ].positions>
													<cfset isUnassigned  = zoneName EQ 'Non assegnato'>

													<cfif ArrayLen( thisPositions ) AND isUnassigned>
														<cfset positionLines.add( ArrayToList( thisPositions, ", " ) )>
													<cfelseif ArrayLen( thisPositions )>
														<cfset positionLines.add( zoneName & ": " & ArrayToList( thisPositions, ", " ) )>
													<cfelseif !isUnassigned>
														<!--- zona nota ma senza codici: resta il nome, senza due punti a vuoto --->
														<cfset positionLines.add( zoneName )>
													</cfif>
												</cfloop>

												<cfif ArrayLen( positionLines )>
													<div style="font-size: 7pt; line-height: 15px;">
														#printLabel('positions', langId)#:
														<cfloop array="#positionLines#" index="positionLine">
															<div style="font-size: 7pt; line-height: 15px; padding-left: 3px;">#positionLine#</div>
														</cfloop>
													</div>
												</cfif>
											</td>
										</tr>
									</table>
								</td>
									<td style="vertical-align: top; padding-right: 0; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; padding-top: 5px; font-size: 7pt; line-height: 12px; text-align: right; white-space: nowrap; padding-right: 0.1in; width: 2.0cm !important;">#LSNumberFormat( prezzoPieno, "9,999.99", "it_IT" )# €</td>
									<cfif args.params.discounts><td style="vertical-align: top; padding-right: 0; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; padding-top: 5px; font-size: 7pt; line-height: 12px; text-align: right; white-space: nowrap; padding-right: 0.1in; width: 1.5cm !important;">#scontoTesto#</td></cfif>
									<td style="vertical-align: top; padding-right: 0; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; padding-top: 5px; font-size: 7pt; line-height: 12px; text-align: right; white-space: nowrap; padding-right: 0.1in; width: 1.0cm !important;">#quantity#</td>
									<td style="vertical-align: top; padding-right: 0; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; padding-top: 5px; font-size: 7pt; line-height: 12px; text-align: right; white-space: nowrap; padding-right: 0.1in; width: 2.1cm !important;">#LSNumberFormat( prezzoScontato, "9,999.99", "it_IT" )# €</td>
									<td style="vertical-align: top; padding-right: 0; border-left: 0; border-bottom: 1px solid black; border-top: 1px solid black; border-right: 1px solid black; padding-top: 5px; font-size: 7pt; line-height: 12px; text-align: right; white-space: nowrap; padding-right: 0.1in; width: 2.2cm !important;">#LSNumberFormat( quantity * prezzoScontato, "9,999.99", "it_IT" )# €</td>
						</tr>
							</cfloop>
							</tbody>
						</table>
					</cfif>
				</cfloop>
				<div style="width: 100%; height: 5mm;"></div>
				<cfif ArrayLen( args.data.articleItems ) GT 0>
					<!--- come per le voci: una tabella sola, intestazione nel <thead> --->
					<table style="border-collapse: collapse; width: 100%; -fs-table-paginate: paginate;">
						<thead>
							<tr>
								<td style="width: 12cm; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 1px solid black; border-right: 0; padding-left: 0.1in;">#printLabel('service', langId)#</td>
								<td style="width: 2cm; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; text-align: right; white-space: nowrap; padding-right: 0.1in;">#printLabel('qty', langId)#</td>
								<td style="width: 3cm; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; text-align: right; white-space: nowrap; padding-right: 0.1in;">#printLabel('price', langId)#</td>
								<td style="width: 3cm; border-left: 0; border-top: 1px solid black; border-bottom: 1px solid black; border-right: 1px solid black; text-align: right; white-space: nowrap; padding-right: 0.1in;">#printLabel('total', langId)#</td>
							</tr>
						</thead>
						<tbody>
						<cfloop array="#args.data.articleItems#" index="servizio">
							<cfset quantity = servizio.getQuantity()>
							<tr style="page-break-inside: avoid;">
								<td style="padding: 2mm 2mm 4mm 2mm; align-items: center; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 1px solid black; border-right: 0; width: 12cm !important;">
									<table class="hiddenTable">
										<tr>
											<td>
												<span style="font-size: 7pt; text-transform: lowecase">#servizio.getArticle().getName()#</span><br>
												<span style="font-size: 7pt; text-transform: lowecase">#servizio.getNote()#</span><br>
											</td>
										</tr>
									</table>
								</td>
								<td style="vertical-align: top; padding-right: 0; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; padding-top: 5px; font-size: 7pt; line-height: 12px; width: 3cm !important; text-align: right; white-space: nowrap; padding-right: 0.1in;">
									#quantity#
								</td>
								<td style="vertical-align: top; padding-right: 0; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; padding-top: 5px; font-size: 7pt; line-height: 12px; width: 3cm !important; text-align: right; white-space: nowrap; padding-right: 0.1in;">
									#LSNumberFormat( servizio.getPrice().getTotal(), "9,999.99", "it_IT" )# €
								</td>
								<td style="vertical-align: top; padding-right: 0; border-left: 0; border-bottom: 1px solid black; border-top: 1px solid black; border-right: 1px solid black; padding-top: 5px; font-size: 7pt; line-height: 12px; width: 3cm !important; text-align: right; white-space: nowrap; padding-right: 0.1in;">
									#LSNumberFormat( quantity * servizio.getPrice().getTotal(), "9,999.99", "it_IT" )# €
								</td>
					</tr>
						</cfloop>
						</tbody>
					</table>
				</cfif>

				<div style="width: 100%; text-align: right; page-break-inside: avoid; margin-top: 0.2in;">
					<table style="border: 0">
						<tr style="border: 0">
							<td style="width: 70%; border: 0"></td>
							<td style="width: 30%; border: 0">
									<!---
										Sconti del piede: prima uscivano due importi, il secondo
										senza nemmeno un'etichetta, e lo sconto incondizionato non
										compariva affatto pur essendo già scalato dal totale.
										Ora ogni riga porta la sua percentuale, come la colonna
										sconto delle righe di preventivo, e l'incondizionato ha
										la sua voce.
									--->
									<cfset totali          = args.data.quotationPrice.getCalculatedTotals()>
									<cfset scontoPerc1     = Val( totali[ 'discount1' ] )>
									<cfset scontoPerc2     = Val( totali[ 'discount2' ] )>
									<cfset scontoFlat      = Val( totali[ 'flatDiscount' ] )>
									<cfset merceLorda      = Val( totali[ 'totalGoods' ] )>
									<cfset scontoImporto1  = merceLorda * scontoPerc1 / 100>
									<cfset scontoImporto2  = ( merceLorda - scontoImporto1 ) * scontoPerc2 / 100>
									<cfset merceNetta      = merceLorda - scontoImporto1 - scontoImporto2>
									<cfset mostraSconti    = args.params.discounts AND ( scontoPerc1 GT 0 OR scontoPerc2 GT 0 OR scontoFlat GT 0 )>
									<table style="width: 4in; border-collapse: collapse;">
										<cfif !args.params.hideTotal>
										<tr>
											<td><strong>#printLabel('goodsTotal', langId)#</strong></td>
											<td>
												<cfif mostraSconti>
													#LSNumberFormat( merceLorda, "9,999.99", "it_IT" )# €
												<cfelse>
													<!--- sconti nascosti: si mostra il netto, incondizionato
													      compreso, altrimenti i conti in fondo non tornano --->
													#LSNumberFormat( merceNetta - scontoFlat, "9,999.99", "it_IT" )# €
												</cfif>
											</td>
										</tr>
										<cfif mostraSconti>
											<cfif scontoPerc1 GT 0>
												<tr>
													<td><strong>#printLabel('discount', langId)# #printPercent( scontoPerc1 )#</strong></td>
													<td>- #LSNumberFormat( scontoImporto1, "9,999.99", "it_IT" )# €</td>
												</tr>
											</cfif>
											<cfif scontoPerc2 GT 0>
												<tr>
													<td><strong>#printLabel('discount', langId)# #printPercent( scontoPerc2 )#</strong></td>
													<td>- #LSNumberFormat( scontoImporto2, "9,999.99", "it_IT" )# €</td>
												</tr>
											</cfif>
											<cfif scontoFlat GT 0>
												<tr>
													<td><strong>#printLabel('flatDiscount', langId)#</strong></td>
													<td>- #LSNumberFormat( scontoFlat, "9,999.99", "it_IT" )# €</td>
												</tr>
											</cfif>
										</cfif>
									<tr>
										<cfif #!isNull( args.data.quotation.getVatCode())#>
											<td>#args.data.quotation.getVatCode().getName()#</td>
										<cfelse>
											<td>#printLabel('vat', langId)#</td>
										</cfif>
										<td>#LSNumberFormat( args.data.quotationPrice.getCalculatedTotals()['vatAmount'], "9,999.99", "it_IT" )# €</td>
									</tr>
									</cfif>
									<cfif #!isNull( args.data.quotationPrice.getShippingCost())#>
										<tr>
											<td>#printLabel('shipping', langId)#</td>
											<td>#LSNumberFormat( args.data.quotationPrice.getShippingCost(), "9,999.99", "it_IT" )# €</td>
										</tr>
									</cfif>
									<cfif !args.params.hideTotal>
									<tr>
										<td><strong>#printLabel('invoiceTotal', langId)#</strong></td>
										<td><strong>#LSNumberFormat( args.data.quotationPrice.getCalculatedTotals()['total'], "9,999.99", "it_IT" )# €</strong></td>
									</tr>
									<cfif isProforma>
										<tr>
											<td><strong>#printLabel('amountToPay', langId)#</strong></td>
											<td><strong>#LSNumberFormat( proformaByAmount ? proformaAmount : args.data.quotationPrice.getCalculatedTotals()['total'] * proformaPercent / 100, "9,999.99", "it_IT" )# €</strong></td>
										</tr>
									</cfif>
									</cfif>
								</table>
							</td>
						</tr>
					</table>
				</div>
				<cfif isProforma>
					<div class="not-fiscal">#printLabel('notFiscalDocument', langId)#</div>
				</cfif>
				#getFinalForm( langId, isProforma )#
			</cfoutput>
		</div>
    </cfdocument>

</cfoutput>
