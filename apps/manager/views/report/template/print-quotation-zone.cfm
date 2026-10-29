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
				<!--- il cambio zona e' una rottura: ogni zona parte da pagina nuova.
				      Si conta solo quello che si stampa davvero, le zone vuote sono
				      saltate e non devono lasciare una pagina bianca dietro di se'. --->
				<!--- fattore unico per le placche ritagliate: la piu' grande riempie il box,
				      le altre le restano proporzionate --->
				<cfset imgScale = printImageScale( data = args.data, boxWidthCm = 5, boxHeightCm = 5 )>
				<cfset zoneStampate = 0>
				<cfloop array="#args.data.zones#" index="stanza">
					<cfif stanza.zoneItems.len() EQ 0>
						<cfcontinue>
					</cfif>
					<cfset zoneItemsCount = ArrayLen( stanza.zoneItems )>
					<cfset zoneStampate = zoneStampate + 1>
				<!--- titolo della zona e intestazione colonne fuori dal ciclo voci:
				      prima ogni voce era una tabella a se' e l'intestazione si ripeteva
				      sopra ognuna. -fs-table-paginate la fa tornare a ogni salto pagina. --->
				<div style="border: 0; margin: 0; margin-top: .1in; padding: .2em; width: fit-content; font-size: 14pt; font-weight: bold;<cfif zoneStampate GT 1> page-break-before: always;</cfif>">
				<cfif stanza.getName() != 'Non assegnato'>
				#stanza.getName()#:
				</cfif>
				</div>
				<!--- piante della zona ( vedi printZone ), prima dei suoi articoli --->
				<cfloop array="#stanza.plants#" index="plant">
					#printPlant( plant = plant, langId = langId )#
				</cfloop>
				<table style="border-collapse: collapse; width: 100%; -fs-table-paginate: paginate;">
					<thead>
						<tr>
							<td style="width: 12cm; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 1px solid black; border-right: 0; padding-left: 0.1in;">#printLabel('article', langId)#</td>
							<td style="width: 2cm; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; text-align: right; padding-right: 0.1in;">#printLabel('qty', langId)#</td>
							<td style="width: 3cm; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; text-align: right; padding-right: 0.1in;">#printLabel('price', langId)#</td>
							<td style="width: 3cm; border-left: 0; border-top: 1px solid black; border-bottom: 1px solid black; border-right: 1px solid black; text-align: right; padding-right: 0.1in;">#printLabel('total', langId)#</td>
						</tr>
					</thead>
					<tbody>
					<cfloop from="1" to="#zoneItemsCount#" index="zoneItem">
						<cfset oggetto = stanza.zoneItems[zoneItem]>
						<tr style="page-break-inside: avoid;">
									<td style="margin: 0 !important; padding: 3px; align-items: center; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 1px solid black; border-right: 0; width: 12cm !important;">
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
													#printItemDescription( oggetto, args.data, langId )#
													<cfif !isNull(oggetto.getPosition())>
														<div style="font-size: 7pt; margin-top: 3px; text-transform: lowecase">#printLabel('position', langId)#: #oggetto.getPosition().getCode()#</div>
													</cfif>
													<cfif !isNull(oggetto.getItems()) && oggetto.getItems().len() GT 0>
														<cfset itemsCount = ArrayLen( oggetto.getItems() )>
														<cfloop from="1"  to="#itemsCount#" index="item">
															<cfset item = oggetto.getItems()[item]>
															<span style="font-size: 7pt; text-transform: lowecase">#item.getProductItem().getAttribute().getName()#: #item.getProductItem().getAttributeValue().getRawValue().getName()#</span><br>
														</cfloop>
														<cfif isNull(oggetto.getArticle()) && !isNull(oggetto.getNote()) && Len( Trim( oggetto.getNote() ) ) && args.params.note>
															<span style="font-size: 7pt; text-transform: lowecase">Note: #oggetto.getNote()#</span>
														</cfif>
													</cfif>
												</td>
											</tr>
											<tr>
												<!--- seconda riga del rowspan dell'immagine: stesso stacco
												      applicato alla descrizione --->
												<td style="vertical-align: bottom; padding: 3pt 3pt 3pt <cfif args.params.images>0.25cm<cfelse>3pt</cfif>;">
													<cfif IsInstanceOf(oggetto, "com.apirone.core.model.bean.QuotationItemPlate") && oggetto.getFruits().len() GT 0>
														<div style="font-size: 7pt; line-height: 15px; margin-top: 0.1in;">
															<b>#printLabel('fruitList', langId)#: </b>
															<cfif NOT isNull(oggetto.getFruits())>
																<cfset fruitsCount = ArrayLen( oggetto.getFruits() )>
																<ul style="padding: 0 0 0 14px;">
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
												</td>
											</tr>
										</table>
									</td>
									<td style="vertical-align: top; padding-right: 0; border-left: 0; border-right: 0; border-bottom: 1px solid black; line-height: 12px; width: 2cm !important; text-align: right; padding-right: 0.1in;">
										<cfset zoneQuantity = stanza.getQuantity()>
										<cfset parentZoneQuantity = !isNull(stanza.getOrigin()) ? stanza.getOrigin().getQuantity() : 1>
										<cfset oggettoQuantity = oggetto.getQuantity() * zoneQuantity * parentZoneQuantity>
										#oggettoQuantity#
									</td>
									<td style="vertical-align: top; padding-right: 0; border-left: 0; border-right: 0; border-bottom: 1px solid black; line-height: 12px; width: 3cm !important; text-align: right; padding-right: 0.1in;">
										<cfset prezzoFinale = oggetto.getPrice().getTotal()>
										<cfif args.params.discounts>
											<cfset sconto1 = oggetto.getPrice().getDiscount1()>
											<cfset sconto2 = oggetto.getPrice().getDiscount2()>
											<cfset moltiplicatore = (1 - (sconto1 / 100)) * (1 - (sconto2 / 100))>
											<cfif moltiplicatore EQ 0>
												<cfset prezzoIniziale = 0>
											<cfelse>
												<cfset prezzoIniziale = prezzoFinale / moltiplicatore>
											</cfif>
											<cfif sconto1 GT 0 OR sconto2 GT 0>
												<del>#LSNumberFormat( prezzoIniziale, "9,999.99", "it_IT" )# €</del> <br><br>
											</cfif>
										</cfif>
										#LSNumberFormat( prezzoFinale, "9,999.99", "it_IT" )# €
									</td>
									<td style="vertical-align: top; padding-right: 0; border-left: 0; border-bottom: 1px solid black; border-top: 1px solid black; border-right: 1px solid black; line-height: 12px; width: 3cm !important; text-align: right; padding-right: 0.1in;">
										#LSNumberFormat( oggetto.getQuantity() * oggetto.getPrice().getTotal(), "9,999.99", "it_IT" )# €
									</td>
						</tr>
					</cfloop>
					</tbody>
				</table>
				</cfloop>
				<div style="width: 100%; height: 5mm;"></div>
				<cfif ArrayLen( args.data.articleItems ) GT 0>
					<!--- come le voci: una tabella sola, intestazione nel <thead> --->
					<table style="border-collapse: collapse; width: 100%; -fs-table-paginate: paginate;">
						<thead>
							<tr>
								<td style="width: 12cm; border-top: 1px solid black; border-bottom: 1px solid black; border-left: 1px solid black; border-right: 0; padding-left: 0.1in;">#printLabel('service', langId)#</td>
								<td style="width: 2cm; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; text-align: right; padding-right: 0.1in;">#printLabel('qty', langId)#</td>
								<td style="width: 3cm; border-left: 0; border-right: 0; border-top: 1px solid black; border-bottom: 1px solid black; text-align: right; padding-right: 0.1in;">#printLabel('price', langId)#</td>
								<td style="width: 3cm; border-left: 0; border-top: 1px solid black; border-bottom: 1px solid black; border-right: 1px solid black; text-align: right; padding-right: 0.1in;">#printLabel('total', langId)#</td>
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
								<td style="vertical-align: top; padding-right: 0; border-left: 0; border-right: 0; border-bottom: 1px solid black; line-height: 12px; width: 3cm !important; text-align: right; padding-right: 0.1in;">
									#quantity#
								</td>
								<td style="vertical-align: top; padding-right: 0; border-left: 0; border-right: 0; border-bottom: 1px solid black; line-height: 12px; width: 3cm !important; text-align: right; padding-right: 0.1in;">
									#LSNumberFormat( servizio.getPrice().getTotal(), "9,999.99", "it_IT" )# €
								</td>
								<td style="vertical-align: top; padding-right: 0; border-left: 0; border-bottom: 1px solid black; border-top: 1px solid black; border-right: 1px solid black; line-height: 12px; width: 3cm !important; text-align: right; padding-right: 0.1in;">
									#LSNumberFormat( quantity * servizio.getPrice().getTotal(), "9,999.99", "it_IT" )# €
								</td>
							</tr>
						</cfloop>
						</tbody>
					</table>
				</cfif>

				<!--- Il blocco totali era in position: absolute, quindi fuori dal flusso:
				      il testo finale partiva da sopra e i due si sovrapponevano. Ora e'
				      impaginato come nel classic, in una cella allineata a destra. --->
				<div style="width: 100%; text-align: right; page-break-inside: avoid; margin-top: 0.2in;">
					<table style="border: 0">
						<tr style="border: 0">
							<td style="width: 70%; border: 0"></td>
							<td style="width: 30%; border: 0">
					<!--- stesso piede del classic: ogni sconto con la sua percentuale e
					      lo sconto incondizionato con la sua voce --->
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
									<!--- sconti nascosti: netto, incondizionato compreso --->
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
						<!--- spedizione prima del totale fattura, come nel classic --->
						<cfif #!isNull( args.data.quotationPrice.getShippingCost())#>
							<tr>
								<td>#printLabel('shipping', langId)#</td>
								<td>#LSNumberFormat( args.data.quotationPrice.getShippingCost(), "9,999.99", "it_IT" )# €</td>
							</tr>
						</cfif>
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
				#getFinalForm(langId)#
			</cfoutput>
		</div>
    </cfdocument>

</cfoutput>
