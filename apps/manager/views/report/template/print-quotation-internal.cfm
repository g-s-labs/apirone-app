<cfoutput>
	<cfdocument attributeCollection="#args.pdfArgs#"  marginLeft=".2" marginRight=".2">
		#printStyle()#
		<div>
			<cfdocumentitem type="header">
				<table style="border: 0; width: 19cm;">
					<tbody>
						<tr style="border: 0;">
							<td style="border: 0; width: 7cm;">
								#getPrintFullHeader()#
							</td>
							<td style="border: 0; width: 12cm; padding-left: 1in; padding-top: .4in">
								<h2>Preventivo N. #args.data.quotation.getQuotationNumber()#/#args.data.quotation.getVersionNumber()#</h2>
								<table style="width: 100%; border-collapse: collapse; border-top: 1px solid black; border-left: 1px solid black;">
									<tr>
										<td style="width: 40%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">Data</td>
										<td style="width: 60%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">#DateFormat( args.data.quotation.getQuotationDate(), "dd/mm/yyyy" )#</td>
									</tr>
									<tr>
										<td style="width: 40%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">Validità offerta</td>
										<td style="width: 60%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">#DateFormat( args.data.quotation.getValidityDate(), "dd/mm/yyyy" )#</td>
									</tr>
									<tr>
										<td style="width: 40%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">Tipo Pagamento</td>
										<td style="width: 60%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">#args.data.quotation.getPaymentMethodName()#</td>
									</tr>
									<cfif Len( args.data.quotation.getCustomPaymentMethod() ?: "" )>
										<tr>
											<td style="width: 40%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">Modalità di pagamento</td>
											<td style="width: 60%;border: 0; border-bottom: 1px solid black; border-right: 1px solid black;">#EncodeForHTML( args.data.quotation.getCustomPaymentMethod() )#</td>
										</tr>
									</cfif>
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
				<div style="padding-top: 1.2in;">
					<!-- Nota, l'unica UM supportata per i margini sono gli inches, quindi per coerenza
					li uso dappertutto, per allineare body a header uso un -.08in ---->
					<table class="cstmtable" style="margin-top: .1in; width: 100%;">
						<tr>
							<td style="width: 50%;"></td>
							<td style="width: 50%;"><strong>Indirizzo Spedizione</strong></td>
						</tr>
						<tr>
							<td>
								<table style="width: 100%; padding: 0; border: 0; border-collapse: collapse;">
									<tr style="border: 0">
										<td style="border: 0; font-weight: bold;">Ragione Sociale: </td>
										<td style="border: 0">#args.data.quotation.getCustomer().getCompany()#</td>
									</tr>
									<tr style="border: 0">
										<td style="border: 0; font-weight: bold;">Telefono: </td>
										<td style="border: 0">#args.data.quotation.getCustomer().getPhone()#</td>
									</tr>
									<tr style="border: 0">
										<td style="border: 0; font-weight: bold;">Email: </td>
										<td style="border: 0">#args.data.quotation.getCustomer().getEmail() ?: ""#</td>
									</tr>
									<tr style="border: 0">
										<td style="border: 0; font-weight: bold;">Partita IVA: </td>
										<td style="border: 0">#args.data.quotation.getCustomer().getVatNumber()#</td>
									</tr>
									<tr style="border: 0">
										<td style="border: 0; vertical-align: top; font-weight: bold;">Indirizzo: </td>
										<td style="border: 0">
											#args.data.quotation.getCustomer().getStreet()# #args.data.quotation.getCustomer().getPostalCode()#<br>
											#args.data.quotation.getCustomer().getCity()#<br>
											#args.data.quotation.getCustomer().getState()#<br>
											#args.data.quotation.getCustomer().getCountry()#
										</td>
									</tr>
								</table>
							</td>
							<td>
								<cfif structKeyExists(args.data, "customerShippingProfile")>
									<table style="width: 100%; padding: 0; border: 0; border-collapse: collapse;">
										<tr style="border: 0">
											<td style="border: 0; font-weight: bold;">Nome: </td>
											<td style="border: 0">#args.data.quotation.getCustomer().getCompany()#</td>
										</tr>
										<tr style="border: 0">
											<td style="border: 0; vertical-align: top; font-weight: bold;"">Indirizzo: </td>
											<td style="border: 0">
												#args.data.customerShippingProfile['name']#<br>
												#args.data.customerShippingProfile['via']# #args.data.customerShippingProfile['cap']#<br>
												#args.data.customerShippingProfile['provincia']#<br>
												#args.data.customerShippingProfile['paese']#<br>
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
				<cfset imgScale = printImageScale( data = args.data, boxWidthCm = 2.54, boxHeightCm = 2.54 )>
				<cfset i = 1>
				<!--- LOOP sulle stanze --->
				<cfloop array="#args.data.zones#" index="stanza">
					<cfif stanza.zoneItems.len() EQ 0>
						<cfcontinue>
					</cfif>
					<cfif i GT 1>
						<!--- Ogni stanza comincia su nuova pagina --->
						<div style="page-break-before: always; margin-top: 1.5in; border: 1px solid black; padding: .2em; font-size: 14pt; font-weight: bold;">
							<cfif !isNull(stanza.getOrigin())>
								#stanza.getOrigin().getName()# -
							</cfif>
							#stanza.getName()#
						</div>
					<cfelse>
						<div style="border: 1px solid black; margin: 0; margin-top: .1in; padding: .2em; width: fit-content; font-size: 14pt; font-weight: bold;">
							<cfif !isNull(stanza.getOrigin())>
								#stanza.getOrigin().getName()# -
							</cfif>
							#stanza.getName()#
						</div>
					</cfif>
					<!--- Loop sugli oggetti della stanza --->
					<cfset j = 1>
					<cfloop array="#stanza.zoneItems#" index="oggetto">
						<cfset itemsCount = stanza.zoneItems.len()>
						<cfif (i EQ 1 and j EQ 3) >
							<div style="page-break-before: always;"></div>
							<div style="margin-top: 1.4in">&nbsp;</div>
						</cfif>
						<cfif (i EQ 1 and j GT 3 and j MOD 3 EQ 0) >
							<div style="page-break-before: always;"></div>
							<div style="margin-top: 1.4in">&nbsp;</div>
						</cfif>

						<!--- wrapper per evitare che venga spezzato su due pagine --->
						<div class="item" style="page-break-inside: avoid; <cfif ( i GT 1 AND j MOD 3 EQ 0 AND itemsCount GT j AND args.data.zones.len() GT i )> page-break-after: always; </cfif><cfif ( j NEQ 1 and i GT 1 AND j MOD 3 EQ 1 )>margin-top: 1.4in;</cfif>">
							<table style="border-collapse: collapse; width: 100%;">
								<tr>
									<td style="width: 4in; border-right: 0;"><strong>Articolo</strong></td>
									<td style="width: 0.4cm; text-align: right;"><strong>Qtà.</strong></td>
									<td style="width: 1.2cm; text-align: right;"><strong>Prezzo</strong></td>
									<td style="width: 1.2cm; text-align: right;"><strong>Totale</strong></td>
								</tr>
								<tr style="height: 1.3in !important">
									<td style="width: 4in; padding-top: 5pt; padding-left: 5pt; padding-bottom: 5pt; height: 1.3in !important;">
										<table class="hiddenTable">
											<tr>
												<cfif args.params.images>
													<td style="width: 1.1in;">
														<!---
															Box di 1in ( 2,54 cm ) uguale per tutte le immagini: oltre a
															rimettere alla stessa scala placche orizzontali e verticali
															toglie lo schiacciamento, perche' prima 1in x 1in era imposto
															a qualsiasi proporzione.
														--->
														#printItemImage( item = oggetto, data = args.data, boxWidthCm = 2.54, boxHeightCm = 2.54, cmPerMm = imgScale )#
													</td>
													<td style="width: 2.9in; padding-left: 2pt; padding-right: 0">
														<span style="word-break: break-all; font-size: 7pt; overflow: hidden; text-transform: lowecase">#oggetto.getProduct().getDescription()#</span><br>
														<cfif !isNull(oggetto.getItems()) && oggetto.getItems().len() GT 0>
															<cfset itemsCount = ArrayLen( oggetto.getItems() ) GTE 9 ? 9 : ArrayLen( oggetto.getItems() )>
															<cfloop from="1"  to="#itemsCount#" index="item">
																<cfset item = oggetto.getItems()[item]>
																<span style="word-break: break-all; font-size: 7pt; overflow: hidden; text-transform: lowecase">#item.getProductItem().getAttribute().getName()#: #item.getProductItem().getAttributeValue().getRawValue().getName()#</span><br>
															</cfloop>
															<cfif !isNull(oggetto.getNote()) && Len( Trim( oggetto.getNote() ) ) && args.params.note>
																<span style="word-break: break-all; font-size: 7pt; overflow: hidden; text-transform: lowecase">Note: #oggetto.getNote()#</span>
															</cfif>
														</cfif>
													</td>
												<cfelse>
													<td style="width: 4in; padding-left: 2pt; padding-right: 0">
														<span style="word-break: break-all; font-size: 7pt; overflow: hidden; text-transform: lowecase">#oggetto.getProduct().getDescription()#</span><br>
														<cfif !isNull(oggetto.getItems()) && oggetto.getItems().len() GT 0>
															<cfset itemsCount = ArrayLen( oggetto.getItems() ) GTE 9 ? 9 : ArrayLen( oggetto.getItems() )>
															<cfloop from="1"  to="#itemsCount#" index="item">
																<cfset item = oggetto.getItems()[item]>
																<span style="word-break: break-all; font-size: 7pt; overflow: hidden; text-transform: lowecase">#item.getProductItem().getAttribute().getName()#: #item.getProductItem().getAttributeValue().getRawValue().getName()#</span><br>
															</cfloop>
															<cfif !isNull(oggetto.getNote()) && Len( Trim( oggetto.getNote() ) ) && args.params.note>
																<span style="word-break: break-all; font-size: 7pt; overflow: hidden; text-transform: lowecase">Note: #oggetto.getNote()#</span>
															</cfif>
														</cfif>
													</td>
												</cfif>
											</tr>
											<tr>
												<cfif IsInstanceOf(oggetto, "com.apirone.core.model.bean.QuotationItemPlate") && oggetto.getFruits().len() GT 0>
													<td colspan="2" style="font-size: 7pt; line-height: 20px; padding-top: 2pt !important; padding-left: 2pt;">
														<b>Lista Frutti: </b>
														<cfif NOT isNull(oggetto.getFruits())>
															<cfset fruitsCount = ArrayLen( oggetto.getFruits() )>
															<cfloop from="1" to="#fruitsCount#" index="fi">
																<cfset fruit = oggetto.getFruits()[fi]>
																Cod. <span style="text-transform: lowercase; font-size: 7pt;">
																	#fruit.getFruit().getCode()#<cfif fi LT fruitsCount>, </cfif>
																	<cfif !isNull(fruit.getNote()) && args.params.note>
																		<span style="font-size: 7pt; margin-top: 4pt;">
																			<i>(Note: #fruit.getNote()#)</i>
																		</span>
																	</cfif>
																</span>
															</cfloop>
														</cfif>
													</td>
												</cfif>
											</tr>
										</table>
									</td>
									<td style="width: 0.4in; text-align: right; font-size: 7pt;">#oggetto.getQuantity()#</td>
									<td style="width: 1.2in; text-align: right; font-size: 7pt;">#LSNumberFormat( oggetto.getPrice(), ".99", "it_IT" )# €</td>
									<td style="width: 1.2in; text-align: right; font-size: 7pt;">#LSNumberFormat( oggetto.getQuantity() * oggetto.getPrice(), ".99", "it_IT" )# €</td>
								</tr>
							</table>
						</div>
						<cfset j = j + 1>
					</cfloop>
					<cfset i = i + 1>
				</cfloop>
				<div style="width: 100%; text-align: right; position: relative;">
					<table style="width: 4in; border-collapse: collapse; position: absolute; right: 0; top: .1in;">
						<tr>
							<td><strong>Totale merce</strong></td>
							<td>#LSNumberFormat( args.data.quotation.getCalculatedAmount(), ".99", "it_IT" )# €</td>
						</tr>
						<tr>
							<td>IVA 20%</td>
							<td>Ancora da definire</td>
						</tr>
						<tr>
							<td>Sconto 50%</td>
							<td>Ancora da definire</td>
						</tr>
						<tr>
							<td><strong>Totale fattura</strong></td>
							<td>#LSNumberFormat( args.data.quotation.getCalculatedAmount(), ".99", "it_IT" )# €</td>
						</tr>
					</table>
				</div>

				#getFinalForm()#
			</cfoutput>
		</div>
    </cfdocument>

</cfoutput>
