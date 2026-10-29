<cffunction name="getPrintHeader">
    <!--- TODO: move website to variable --->
    <cfreturn "<img src='https://test.apirone.cc/assets/main/img/logo.png' alt='Apir' style='width: 100%; height: 40px;'>">
</cffunction>

<cffunction name="getPrintFullHeader">
	<cfoutput>
		<div style="width: 10cm">
			<br>
			<img src="#expandPath('/assets/main/img/logo_apir.png')#" alt="Apir" style="width: 3cm; height: 1.55cm;">
			<br>
			<strong style="font-size: 11pt;">APIR s.r.l. a socio unico</strong>
			<div style="line-height: 8pt;">
				<strong style="line-height: 10pt;">
					Via prato delle Valli, 58
					<br>
					47892 Acquaviva Repubblica di San Marino
				</strong>
				<br>
				<span style="font-size: 7pt; line-height: 8pt;">
					Cap.Soc. EURO 25.800,00 - Ric.Giur. del 06/05/99 Reg. Soc. N.1930
					<br>
					FROM ITALY: Tel.0549/962211 * Fax.0549/904636
					<br>
					FROM OTHER COUNTRIES: Tel(+)378/962211 * Fax.(+)378/904636
					<br>
					Cod. Oper. Econ. SM 07240
					<br>
					<div style="font-size: 8pt"><strong>E-Mail: <span class="blue" style="font-size: 8pt;">info@apir.com</span> - Web: <span class="blue" style="font-size: 8pt;">https://www.apir.com</span></strong></div>
				</span>
			</div>
		</div>

	</cfoutput>
</cffunction>

<!---
	Commerciale di riferimento: nome (dall'Account) e, sotto, telefono (dall'User) ed email (dall'Account).
	Le due righe di contatto compaiono solo se valorizzate.
--->
<cffunction name="printSalesAgent">
	<cfargument name="salesAgent" required="false">
	<cfargument name="langId" required="true" type="String">

	<cfsavecontent variable="local.html">
		<cfoutput>
			<cfif !IsNull( arguments.salesAgent )>
				<cfset local.account = arguments.salesAgent.getAccount()>
				<cfset local.phone   = Trim( arguments.salesAgent.getPhone() ?: "" )>
				<cfset local.email   = !IsNull( local.account ) ? Trim( local.account.getEmail() ?: "" ) : "">

				<cfif !IsNull( local.account )>#local.account.getName()#</cfif>

				<cfif Len( local.phone ) OR Len( local.email )>
					<div style="font-size: 7pt; line-height: 9pt;">
						<cfif Len( local.phone )>
							#printLabel('phone', arguments.langId)#: #local.phone#<cfif Len( local.email )><br></cfif>
						</cfif>
						<cfif Len( local.email )>
							#printLabel('email', arguments.langId)#: #local.email#
						</cfif>
					</div>
				</cfif>
			</cfif>
		</cfoutput>
	</cfsavecontent>

	<cfreturn local.html>
</cffunction>

<!---
	Filigrana "bozza" sulle stampe dei preventivi non ancora approvati: in lavorazione
	( LAV ) e in attesa di approvazione ( PEN ). Prima valeva solo per LAV, e un
	preventivo in attesa di approvazione si poteva stampare pulito e mandare al cliente
	prima del via libera. Soglia = ordine dello stato APR ( Approvato, orderby 35 ).
--->
<cffunction name="isQuotationDraftForPrint" returntype="boolean">
	<cfargument name="quotation" required="true">

	<cfif IsNull( arguments.quotation.getStatusHistory() ) OR IsNull( arguments.quotation.getStatusHistory().getStatus() )>
		<cfreturn true>
	</cfif>

	<cfreturn arguments.quotation.getStatusHistory().getStatus().getOrderBy() LT 35>
</cffunction>

<!---
	Pianta di una zona con i marker delle posizioni.

	Il centraggio del marker è fatto con margini negativi e non con translate(-50%,-50%):
	cfdocument ignora le trasformazioni CSS, così il pin resta comunque centrato sul punto.

	Per lo stesso motivo il marker è un PNG già ruotato lato server ( vedi
	pinImagePath() nel controller ) e non un div con transform: rotate(), che in
	stampa usciva sempre con la punta nella stessa direzione. Se il PNG non c'è si
	ripiega sul div colorato, che perde l'orientamento ma non fa saltare la stampa.
--->
<cffunction name="printPlant">
	<cfargument name="plant" required="true">
	<cfargument name="langId" default="IT">
	<!--- se valorizzato, il titolo di categoria viaggia dentro questo stesso blocco
	      non spezzabile, così non resta mai orfano in fondo a una pagina --->
	<cfargument name="sectionTitle" default="">

	<cfsavecontent variable="local.html">
		<cfoutput>
			<div class="plant">
				<cfif Len( arguments.sectionTitle )>
					<div class="category-section">#arguments.sectionTitle#</div>
				</cfif>
				<div class="plant-title">#printLabel('plant', arguments.langId)#: #arguments.plant.zoneName#</div>
				<div class="plant-canvas" style="width: #arguments.plant.boxWidth#cm; height: #arguments.plant.boxHeight#cm;">
					<img src="#arguments.plant.imagePath#" class="plant-image" style="width: #arguments.plant.boxWidth#cm; height: #arguments.plant.boxHeight#cm;">
					<cfloop array="#arguments.plant.markers#" index="local.marker">
						<cfset local.half   = Int( local.marker.size / 2 )>
						<cfset local.pinPath = StructKeyExists( local.marker, "pin" ) ? local.marker.pin : "">
						<cfif Len( local.pinPath )>
							<!--- la tela del PNG è più larga del marker per non tagliare la
							      punta ruotata: si centra sulla sua misura, non su quella
							      del marker --->
							<cfset local.box     = Ceiling( local.marker.size * 1.6 )>
							<cfset local.boxHalf = Int( local.box / 2 )>
							<img src="#local.pinPath#" class="plant-pin" style="left: #local.marker.x#%; top: #local.marker.y#%; width: #local.box#px; height: #local.box#px; margin-left: -#local.boxHalf#px; margin-top: -#local.boxHalf#px;">
						<cfelse>
							<div class="plant-pin plant-pin-flat" style="left: #local.marker.x#%; top: #local.marker.y#%; width: #local.marker.size#px; height: #local.marker.size#px; margin-left: -#local.half#px; margin-top: -#local.half#px; background-color: #local.marker.color#;"></div>
						</cfif>
						<div class="plant-pin-label" style="left: #local.marker.x#%; top: #local.marker.y#%; width: #local.marker.size#px; margin-left: -#local.half#px; margin-top: -6px;">#local.marker.label#</div>
					</cfloop>
				</div>
			</div>
		</cfoutput>
	</cfsavecontent>

	<cfreturn local.html>
</cffunction>

<!--- Percentuale senza decimali inutili: 30% invece di 30,00%, ma 32,5% resta tale. --->
<cffunction name="printPercent">
	<cfargument name="value" required="true">

	<cfset local.n = Val( arguments.value )>

	<cfif local.n EQ Int( local.n )>
		<cfreturn Int( local.n ) & "%">
	</cfif>

	<cfreturn LSNumberFormat( local.n, "9.99" ) & "%">
</cffunction>

<!---
	Riga dimensioni dell'articolo, sempre sotto al nome: "Dimensioni: 20 x 30 cm"
	( larghezza x altezza ). Quando c'è anche la terza quota ( accessori ecc. )
	l'altezza va in fondo marcata con la "h": "Dimensioni: 20 x 100 x h 30 cm".
	L'unità cambia col tipo di articolo: mm per placche e segnaletica, cm per
	tutto il resto.
--->
<cffunction name="printDimensions" output="false">
	<cfargument name="modelConfig" required="true">
	<cfargument name="langId" required="true">
	<cfargument name="unit" required="false" default="cm">

	<cfset local.sizes = !IsNull( arguments.modelConfig.getLength() )
		? arguments.modelConfig.getWidth() & " x " & arguments.modelConfig.getLength() & " x h " & arguments.modelConfig.getHeight()
		: arguments.modelConfig.getWidth() & " x " & arguments.modelConfig.getHeight()>

	<cfsavecontent variable="local.html"><cfoutput><div style="font-size: 7pt;">#printLabel( 'dimensions', arguments.langId )#: <span style="white-space: nowrap;">#local.sizes# #arguments.unit#</span></div></cfoutput></cfsavecontent>

	<cfreturn local.html>
</cffunction>

<!---
	Descrizione di una voce di stampa. Per i prodotti composti da linea, modello
	e finitura: linea e modello sulla prima riga, poi "Finitura: ..." e
	"Dimensioni: ..." ognuna su una riga sua. Gli altri prodotti stampano il
	nome, seguito dalle dimensioni se il modello le ha.
	Le dimensioni arrivano dalla modelConfigMap preparata dal controller.
--->
<cffunction name="printItemDescription" output="false">
	<cfargument name="item" required="true">
	<cfargument name="data" required="true">
	<cfargument name="langId" required="true">

	<cfset local.product = arguments.item.getProduct()>
	<cfset local.isComplex = IsInstanceOf( local.product, "com.apirone.core.model.bean.ProductComplex" )>

	<cfset local.dimHtml = "">
	<cfif StructKeyExists( arguments.data, "modelConfigMap" ) && StructKeyExists( arguments.data.modelConfigMap, local.product.getId() )>
		<cfset local.typeId = ( !IsNull( local.product.getCategory() ) && !IsNull( local.product.getCategory().getType() ) ) ? local.product.getCategory().getType().getId() : "">
		<cfset local.dimHtml = printDimensions(
			arguments.data.modelConfigMap[ local.product.getId() ],
			arguments.langId,
			( local.typeId EQ "PLA" OR local.typeId EQ "SEG" ) ? "mm" : "cm"
		)>
	</cfif>

	<cfsavecontent variable="local.html"><cfoutput>
		<cfif local.isComplex>
			<span style="font-size: 7pt; text-transform: lowecase">#local.product.getLine().getName()# #local.product.getModel().getName()# (#local.product.getModel().getCode()#)</span><br>
			<cfif !IsNull( local.product.getFinish() )>
				<div style="font-size: 7pt;">#printLabel( 'finish', arguments.langId )#: #local.product.getFinish().getName()#</div>
			</cfif>
		<cfelse>
			<span style="font-size: 7pt; text-transform: lowecase">#local.product.getDescription()#</span><br>
		</cfif>
		#local.dimHtml#
	</cfoutput></cfsavecontent>

	<cfreturn local.html>
</cffunction>

<!---
	Immagine di una voce inscritta in un box fisso, uguale per tutte le immagini
	della stessa stampa.

	Perche' non basta imporre la larghezza, com'era prima: lo snapshot della placca
	e' un canvas di dimensione fissa che cambia con l'orientamento ( 1200x500 px se
	la placca e' orizzontale, 500x1200 se verticale: applyPlateCanvasSize in
	app-quotation-plate-vue.js ) e l'armatura ci viene disegnata dentro a 4 px/mm.
	Quel canvas copre quindi 300 mm di placca in orizzontale contro 125 in verticale:
	dando a entrambi la stessa larghezza di stampa la stessa placca usciva a due
	scale diverse ( 2,4 volte ), e le verticali venivano alte 26 cm.

	Inscrivendo invece ogni immagine nello stesso box si normalizza il lato lungo
	del canvas, che e' 1200 px in tutti e due gli orientamenti: HOR e VER tornano
	alla stessa scala fisica, e fra placche diverse le proporzioni restano giuste
	perche' a canvas e scala di disegno fissi l'ingombro nel PNG e' proporzionale
	ai millimetri veri.

	width e height vengono scritte esplicite in cm: max-width/max-height non sono
	affidabili in cfdocument, e il rapporto lo calcoliamo comunque noi dai pixel
	dell'immagine ( colonne width/height di files, valorizzate al salvataggio in
	FileService ).
--->
<!---
	Fattore di stampa delle placche ritagliate: quanti cm di carta vale un mm di
	prodotto, uguale per tutto il documento.

	Si sceglie perche' la piu' grande riempia il box: le altre le restano
	proporzionate, mentre adattando ogni immagine al suo box una placca da 2 moduli
	uscirebbe grande come una da 8.

	Torna 0 se nel documento non c'e' nessun ritaglio ( placche legacy, immagini
	caricate a mano, armature non ritrovate ): printItemImage allora inscrive nel
	box, che e' il massimo che si puo' fare senza sapere quanto misura il soggetto.
--->
<cffunction name="printImageScale" output="false" returntype="numeric">
	<cfargument name="data" required="true">
	<cfargument name="boxWidthCm" type="numeric" required="true">
	<cfargument name="boxHeightCm" type="numeric" required="true">

	<cfif !StructKeyExists( arguments.data, "plateImages" )>
		<cfreturn 0>
	</cfif>

	<cfset local.maxWidthMm  = Val( arguments.data.plateImages.maxWidthMm )>
	<cfset local.maxHeightMm = Val( arguments.data.plateImages.maxHeightMm )>

	<cfif local.maxWidthMm LTE 0 OR local.maxHeightMm LTE 0>
		<cfreturn 0>
	</cfif>

	<cfreturn Min( arguments.boxWidthCm / local.maxWidthMm, arguments.boxHeightCm / local.maxHeightMm )>
</cffunction>

<!---
	Immagine centrata nella sua cella.

	Il centraggio e' doppio perche' i due casi convivono: fuori da .hiddenTable
	l'immagine resta inline e la centra il text-align del contenitore, dentro
	.hiddenTable il foglio di stile la rende display: block ( printStyle ) e allora
	la centrano i margini automatici. Una sola delle due regole lascerebbe meta'
	stampe con le immagini attaccate a sinistra, cosa che si vede da quando i
	ritagli sono piu' stretti della colonna.
--->
<cffunction name="printImageTag" output="false" returntype="string">
	<cfargument name="src" required="true">
	<cfargument name="widthCm" type="numeric" required="true">
	<!--- l'altezza manca solo quando non si riesce a leggere l'immagine --->
	<cfargument name="heightCm" type="numeric" required="false" default="0">

	<cfset local.size = "width: #arguments.widthCm#cm !important;">

	<cfif arguments.heightCm GT 0>
		<cfset local.size &= " height: #arguments.heightCm#cm !important;">
	</cfif>

	<cfsavecontent variable="local.html"><cfoutput><div style="text-align: center;"><img src="#arguments.src#" style="#local.size# margin-left: auto; margin-right: auto;"></div></cfoutput></cfsavecontent>

	<cfreturn local.html>
</cffunction>

<cffunction name="printItemImage" output="false">
	<cfargument name="item" required="true">
	<cfargument name="boxWidthCm" type="numeric" required="true">
	<cfargument name="boxHeightCm" type="numeric" required="true">
	<!--- args.data: ci sta dentro il ritaglio della placca, quando si e' potuto fare --->
	<cfargument name="data" required="false">
	<!--- cm di carta per mm di prodotto, da printImageScale: vale solo per i ritagli --->
	<cfargument name="cmPerMm" type="numeric" required="false" default="0">

	<!---
		Placca ritagliata sull'armatura ( buildPlateCrops nel controller ): l'immagine
		e' il prodotto e basta, e di quel prodotto si conoscono i millimetri, quindi
		si stampa in scala invece di adattarla al box.
	--->
	<cfset local.crop = platePrintCrop( arguments.item, arguments.data )>

	<cfif !IsNull( local.crop )>
		<cfif arguments.cmPerMm GT 0>
			<cfset local.cropWidth  = Round( local.crop.widthMm  * arguments.cmPerMm * 100 ) / 100>
			<cfset local.cropHeight = Round( local.crop.heightMm * arguments.cmPerMm * 100 ) / 100>
		<cfelse>
			<!--- senza fattore si ripiega sul box, ma con le proporzioni vere --->
			<cfset local.cropScale  = Min( arguments.boxWidthCm / local.crop.widthMm, arguments.boxHeightCm / local.crop.heightMm )>
			<cfset local.cropWidth  = Round( local.crop.widthMm  * local.cropScale * 100 ) / 100>
			<cfset local.cropHeight = Round( local.crop.heightMm * local.cropScale * 100 ) / 100>
		</cfif>

		<cfreturn printImageTag( local.crop.path, local.cropWidth, local.cropHeight )>
	</cfif>

	<cfset local.src = ExpandPath( '/assets/main/img/img-not-found.png' )>
	<cfset local.w   = 0>
	<cfset local.h   = 0>

	<cfif !IsNull( arguments.item.getImage() )>
		<!---
			getPath() e non getUri(): cfdocument legge l'immagine dal file system,
			non via HTTP. getUri() punta al repository pubblico ( altro host ) e
			getRelativePath() e' solo un frammento, quindi nessuno dei due si
			risolve nel PDF.
		--->
		<cfset local.image = arguments.item.getImage()>
		<cfset local.src   = local.image.getPath()>
		<cfset local.w     = IsNull( local.image.getWidth() )  ? 0 : Val( local.image.getWidth() )>
		<cfset local.h     = IsNull( local.image.getHeight() ) ? 0 : Val( local.image.getHeight() )>
	</cfif>

	<!--- misure non registrate ( immagini caricate prima che si salvassero ):
	      si leggono dal file --->
	<cfif local.w LTE 0 OR local.h LTE 0>
		<cftry>
			<cfset local.info = ImageInfo( local.src )>
			<cfset local.w    = local.info.width>
			<cfset local.h    = local.info.height>
			<cfcatch type="any">
				<cfset local.w = 0>
				<cfset local.h = 0>
			</cfcatch>
		</cftry>
	</cfif>

	<!--- file illeggibile: si ripiega sul comportamento di prima, larghezza del box --->
	<cfif local.w LTE 0 OR local.h LTE 0>
		<cfreturn printImageTag( local.src, arguments.boxWidthCm )>
	</cfif>

	<cfset local.scale       = Min( arguments.boxWidthCm / local.w, arguments.boxHeightCm / local.h )>
	<cfset local.printWidth  = Round( local.w * local.scale * 100 ) / 100>
	<cfset local.printHeight = Round( local.h * local.scale * 100 ) / 100>

	<cfreturn printImageTag( local.src, local.printWidth, local.printHeight )>
</cffunction>

<cffunction name="getPrintFooter">
    <cfsavecontent variable="local.html">
        <cfoutput>
            <div>
                <table style='width: 100%; border-collapse:collapse'>
                    <tr>
                        <td style='border: 0; padding-left:25px;'>#cfdocument.currentpagenumber#/#cfdocument.totalpagecount#</td>
                        <td style='border: 0; padding-right:25px;' align='right'>Apir Srl - #LsDateFormat( now(), 'dd/mm/yyyy' )#</td>
                    </tr>
                </table>
            </div>
        </cfoutput>
    </cfsavecontent>

    <cfreturn local.html>

</cffunction>

<cffunction name="printComponents">
    <!--- print components by a struct --->
    <cfargument name="components" required=true>
    <cfloop array="#components#" item="component">
        <cfoutput>
        - #component.shortId# - <b>#component.quantity#

            <cfif component?.typeId == "base">
                + #component.override.quantity# = #component.totalQuantity#
            </cfif>

            #component.rawProduct.measurementUnit.id#</b> x #component.rawProduct.name# (<i>#component.rawProduct.id#</i>)
            - #component.variant.name# (<i>#component.variant.id#</i>)
            - #component.color.name# (<i>#component.color.id#</i>)<br/>
        </cfoutput>
    </cfloop>
</cffunction>



<cffunction name="printLabel">
	<cfargument name="key" required="true">
	<cfargument name="langId" default="IT">
	<cfset local.lang = UCase(arguments.langId)>
	<cfset local.labels = {
		"IT": {
			"quotation":      "Preventivo",
			"date":           "Data",
			"offerValidity":  "Validità offerta",
			"paymentMethod":  "Tipo Pagamento",
			"customPaymentMethod": "Modalità di pagamento",
			"salesAgent":     "Commerciale di Riferimento",
			"shippingAddress":"Indirizzo Spedizione",
			"company":        "Ragione Sociale",
			"phone":          "Telefono",
			"email":          "Email",
			"vatNumber":      "Partita IVA",
			"address":        "Indirizzo",
			"lead":           "Lead",
			"opportunity":    "Opportunità",
			"shippingName":   "Nome",
			"article":        "Articolo",
			"qty":            "Qtà",
			"price":          "Prezzo",
			"total":          "Totale",
			"service":        "Servizio",
			"goodsTotal":     "Totale merce",
			"discounts":      "Sconti",
			"flatDiscount":   "Sconto incondizionato",
			"vat":            "Iva",
			"shipping":       "Spedizione",
			"invoiceTotal":   "Totale fattura",
			"unitPrice":    "Prezzo unit.",
			"discount":     "Sconto",
			"netUnitPrice": "Prezzo scont.",
			"proforma":     "Proforma",
			"advancePayment": "anticipato",
			"amountToPay":  "Totale a pagare",
			"notFiscalDocument": "DOCUMENTO NON VALIDO AI FINI FISCALI",
			"plant":        "Pianta",
			"position":       "Posizione",
			"positions":      "Posizioni",
			"fruitList":      "Lista Frutti",
			"offer":          "Offerta",
			"technicalPrint": "Stampa Tecnica",
			"photoPrint":     "Stampa Foto",
			"finish":         "Finitura",
			"dimensions":     "Dimensioni"
		},
		"EN": {
			"quotation":      "Quotation",
			"date":           "Date",
			"offerValidity":  "Offer validity",
			"paymentMethod":  "Payment method",
			"customPaymentMethod": "Payment terms",
			"salesAgent":     "Sales agent",
			"shippingAddress":"Shipping address",
			"company":        "Company",
			"phone":          "Phone",
			"email":          "Email",
			"vatNumber":      "VAT number",
			"address":        "Address",
			"lead":           "Lead",
			"opportunity":    "Opportunity",
			"shippingName":   "Name",
			"article":        "Article",
			"qty":            "Qty.",
			"price":          "Price",
			"total":          "Total",
			"service":        "Service",
			"goodsTotal":     "Goods total",
			"discounts":      "Discounts",
			"flatDiscount":   "Unconditional discount",
			"vat":            "VAT",
			"shipping":       "Shipping",
			"invoiceTotal":   "Invoice total",
			"unitPrice":    "Unit price",
			"discount":     "Discount",
			"netUnitPrice": "Net price",
			"proforma":     "Proforma",
			"advancePayment": "advance payment",
			"amountToPay":  "Amount to pay",
			"notFiscalDocument": "DOCUMENT NOT VALID FOR TAX PURPOSES",
			"plant":        "Floor plan",
			"position":       "Position",
			"positions":      "Positions",
			"fruitList":      "Fruit list",
			"offer":          "Offer",
			"technicalPrint": "Technical Print",
			"photoPrint":     "Photo Print",
			"finish":         "Finish",
			"dimensions":     "Dimensions"
		},
		"FR": {
			"quotation":      "Devis",
			"date":           "Date",
			"offerValidity":  "Validité de l'offre",
			"paymentMethod":  "Mode de paiement",
			"customPaymentMethod": "Modalités de paiement",
			"salesAgent":     "Commercial référent",
			"shippingAddress":"Adresse de livraison",
			"company":        "Raison sociale",
			"phone":          "Téléphone",
			"email":          "Email",
			"vatNumber":      "N° TVA",
			"address":        "Adresse",
			"lead":           "Lead",
			"opportunity":    "Opportunité",
			"shippingName":   "Nom",
			"article":        "Article",
			"qty":            "Qté.",
			"price":          "Prix",
			"total":          "Total",
			"service":        "Service",
			"goodsTotal":     "Total marchandises",
			"discounts":      "Remises",
			"flatDiscount":   "Remise inconditionnelle",
			"vat":            "TVA",
			"shipping":       "Livraison",
			"invoiceTotal":   "Total facture",
			"unitPrice":    "Prix unit.",
			"discount":     "Remise",
			"netUnitPrice": "Prix net",
			"proforma":     "Proforma",
			"advancePayment": "d'acompte",
			"amountToPay":  "Total à payer",
			"notFiscalDocument": "DOCUMENT SANS VALEUR FISCALE",
			"plant":        "Plan",
			"position":       "Position",
			"positions":      "Positions",
			"fruitList":      "Liste des fruits",
			"offer":          "Offre",
			"technicalPrint": "Impression Technique",
			"photoPrint":     "Impression Photo",
			"finish":         "Finition",
			"dimensions":     "Dimensions"
		},
		"ES": {
			"quotation":      "Presupuesto",
			"date":           "Fecha",
			"offerValidity":  "Validez de la oferta",
			"paymentMethod":  "Método de pago",
			"customPaymentMethod": "Condiciones de pago",
			"salesAgent":     "Agente comercial",
			"shippingAddress":"Dirección de envío",
			"company":        "Razón social",
			"phone":          "Teléfono",
			"email":          "Email",
			"vatNumber":      "N° de IVA",
			"address":        "Dirección",
			"lead":           "Lead",
			"opportunity":    "Oportunidad",
			"shippingName":   "Nombre",
			"article":        "Artículo",
			"qty":            "Cant.",
			"price":          "Precio",
			"total":          "Total",
			"service":        "Servicio",
			"goodsTotal":     "Total mercancías",
			"discounts":      "Descuentos",
			"flatDiscount":   "Descuento incondicional",
			"vat":            "IVA",
			"shipping":       "Envío",
			"invoiceTotal":   "Total factura",
			"unitPrice":    "Precio unit.",
			"discount":     "Descuento",
			"netUnitPrice": "Precio neto",
			"proforma":     "Proforma",
			"advancePayment": "anticipado",
			"amountToPay":  "Total a pagar",
			"notFiscalDocument": "DOCUMENTO NO VÁLIDO A EFECTOS FISCALES",
			"plant":        "Plano",
			"position":       "Posición",
			"positions":      "Posiciones",
			"fruitList":      "Lista de frutos",
			"offer":          "Oferta",
			"technicalPrint": "Impresión Técnica",
			"photoPrint":     "Impresión Fotográfica",
			"finish":         "Acabado",
			"dimensions":     "Dimensiones"
		},
		"DE": {
			"quotation":      "Angebot",
			"date":           "Datum",
			"offerValidity":  "Angebotsgültigkeit",
			"paymentMethod":  "Zahlungsmethode",
			"customPaymentMethod": "Zahlungsbedingungen",
			"salesAgent":     "Vertriebsmitarbeiter",
			"shippingAddress":"Lieferadresse",
			"company":        "Firma",
			"phone":          "Telefon",
			"email":          "E-Mail",
			"vatNumber":      "USt-IdNr.",
			"address":        "Adresse",
			"lead":           "Lead",
			"opportunity":    "Chance",
			"shippingName":   "Name",
			"article":        "Artikel",
			"qty":            "Menge",
			"price":          "Preis",
			"total":          "Gesamt",
			"service":        "Service",
			"goodsTotal":     "Warengesamt",
			"discounts":      "Rabatte",
			"flatDiscount":   "Bedingungsloser Rabatt",
			"vat":            "MwSt.",
			"shipping":       "Versand",
			"invoiceTotal":   "Rechnungsgesamt",
			"unitPrice":    "Einzelpreis",
			"discount":     "Rabatt",
			"netUnitPrice": "Nettopreis",
			"proforma":     "Proforma",
			"advancePayment": "Anzahlung",
			"amountToPay":  "Zu zahlender Betrag",
			"notFiscalDocument": "DOKUMENT OHNE STEUERLICHE GÜLTIGKEIT",
			"plant":        "Grundriss",
			"position":       "Position",
			"positions":      "Positionen",
			"fruitList":      "Fruchtliste",
			"offer":          "Angebot",
			"technicalPrint": "Technischer Druck",
			"photoPrint":     "Fotodruck",
			"finish":         "Ausführung",
			"dimensions":     "Abmessungen"
		}
	}>
	<cfif !structKeyExists(local.labels, local.lang)>
		<cfset local.lang = "IT">
	</cfif>
	<cfif structKeyExists(local.labels[local.lang], arguments.key)>
		<cfreturn local.labels[local.lang][arguments.key]>
	</cfif>
	<cfreturn local.labels["IT"][arguments.key]>
</cffunction>

<!---
	Titolo della sezione di raggruppamento per tipo di categoria prodotto.
	Se il tipo non è fra quelli noti ripiega sul nome che arriva dal DB.
--->
<cffunction name="printCategoryType">
	<cfargument name="typeId" required="true">
	<cfargument name="fallback" default="">
	<cfargument name="langId" default="IT">

	<cfset local.lang = UCase(arguments.langId)>
	<cfset local.names = {
		"IT": { "PLA": "Placche",     "FRU": "Frutti",   "SEG": "Segnaletica",   "ACC": "Accessori" },
		"EN": { "PLA": "Plates",      "FRU": "Fruits",   "SEG": "Signage",       "ACC": "Accessories" },
		"FR": { "PLA": "Plaques",     "FRU": "Fruits",   "SEG": "Signalétique",  "ACC": "Accessoires" },
		"ES": { "PLA": "Placas",      "FRU": "Frutos",   "SEG": "Señalética",    "ACC": "Accesorios" },
		"DE": { "PLA": "Abdeckungen", "FRU": "Früchte",  "SEG": "Beschilderung", "ACC": "Zubehör" }
	}>

	<cfif !structKeyExists(local.names, local.lang)>
		<cfset local.lang = "IT">
	</cfif>

	<cfset local.key = UCase(arguments.typeId)>
	<cfif structKeyExists(local.names[local.lang], local.key)>
		<cfreturn local.names[local.lang][local.key]>
	</cfif>

	<cfreturn arguments.fallback>
</cffunction>

<cffunction name="getFinalForm">
	<cfargument name="langId" default="IT">
	<!--- compact: usato dalla proforma, che non è un modulo d'ordine.
	      Omette la nota in testa, il riquadro "Leggere e compilare" e le
	      condizioni generali di vendita, lasciando solo coordinate bancarie
	      e riga di firma: essendo poche righe, il page-break-inside: avoid
	      le fa risalire sulla pagina precedente quando c'è spazio. --->
	<cfargument name="compact" type="boolean" default="false">
	<cfset local.lang = UCase(arguments.langId)>
	<cfset local.tx = {
		"IT": {
			"topNote":        "L'ordine si intende confermato solo dopo il ricevimento dello stesso timbrato e firmato per accettazione, dell'eventuale conferma bozze e del pagamento anticipato ove previsto",
			"bankTitle":      "Coordinate Bancarie",
			"bank":           "Banca",
			"holder":         "Intestatario",
			"readAndFill":    "Leggere e compilare",
			"important":      "IMPORTANTE",
			"importantIntro": "Per confermare l'ordine si prega di compilare i seguenti campi:",
			"billingAddress": "Indirizzo di fatturazione :",
			"vatNo":          "N° P.IVA :",
			"sdi":            "N° SDI :",
			"deliveryAddress":"Indirizzo di consegna :",
			"receiverContact":"Nome e Numero di telefono della persona incaricata del ricevimento merce :",
			"termsTitle":     "CONDIZIONI GENERALI DI VENDITA",
			"art1":           "CONFERMA D'ORDINE: il presente modulo costituisce una conferma delle condizioni definitive per l'evasione dell'ordine e le parti riconoscono la sua efficacia anche se l'invio ad APIR SRL viene effettuato a mezzo telefax oppure a mezzo e-mail. (*) L'ordine si intende confermato solo dopo il ricevimento dello stesso timbrato e firmato per accettazione, dell'eventuale conferma bozze e del pagamento anticipato ove previsto.",
			"art2":           "VARIAZIONE DELL'ORDINE: ogni eventuale richiesta di modifica dell'ordine deve avvenire immediatamente dopo la ricezione della presente conferma. APIR SRL si riserva la facoltà di rifiutarla a suo insindacabile giudizio.",
			"art3":           "CONSEGNA: L'eventuale data di consegna indicata da APIR SRL è solo una data stimata ed approssimativa, non vincolante per APIR SRL.",
			"art4":           "RECLAMI: il cliente dovrà controllare la merce al momento della presa in consegna e le eventuali contestazioni per difetti o mancanze di materiali dovranno essere formalizzate esclusivamente per iscritto e dovranno pervenire ad APIR SRL entro 8 (otto) giorni dalla data di consegna della merce.",
			"art5":           "RITARDO PAGAMENTO: in applicazione del D.L. n° 231 del 09/10/2002 attuante la direttiva 2000/35/CE, in caso di ritardo pagamento saranno automaticamente addebitati gli interessi di mora che decorreranno dal giorno successivo alla scadenza del termine di pagamento.",
			"art6":           "FORO COMPETENTE: per qualsiasi controversia relativa alla esecuzione ed in generale a tutto ciò che comporta l'applicazione ed interpretazione del presente accordo è sempre competente il Foro di Rimini.",
			"signNote":       "Ad ogni effetto di legge dichiaro di approvare in modo espresso la clausola relativa al Foro competente e quella relativa ai reclami.",
			"date":           "Data",
			"signStamp":      "Firma e Timbro"
		},
		"EN": {
			"topNote":        "The order is confirmed only upon receipt of the same duly signed and stamped for acceptance, any proof approval, and advance payment where applicable.",
			"bankTitle":      "Bank Details",
			"bank":           "Bank",
			"holder":         "Account holder",
			"readAndFill":    "Please read and fill in",
			"important":      "IMPORTANT",
			"importantIntro": "To confirm the order, please fill in the following fields:",
			"billingAddress": "Billing address:",
			"vatNo":          "VAT No.:",
			"sdi":            "SDI No.:",
			"deliveryAddress":"Delivery address:",
			"receiverContact":"Name and phone number of the person in charge of receiving the goods:",
			"termsTitle":     "GENERAL TERMS AND CONDITIONS OF SALE",
			"art1":           "ORDER CONFIRMATION: This form constitutes a confirmation of the final conditions for fulfilling the order, and the parties acknowledge its validity even if sent to APIR SRL by fax or e-mail. (*) The order is confirmed only upon receipt of the same duly signed and stamped for acceptance, any proof approval, and advance payment where applicable.",
			"art2":           "ORDER MODIFICATION: Any request to modify the order must be made immediately after receiving this confirmation. APIR SRL reserves the right to refuse it at its sole discretion.",
			"art3":           "DELIVERY: Any delivery date indicated by APIR SRL is only an estimated and approximate date, not binding for APIR SRL.",
			"art4":           "CLAIMS: The customer must inspect the goods upon delivery; any objections regarding defects or missing materials must be formalized exclusively in writing and must reach APIR SRL within 8 (eight) days from the delivery date.",
			"art5":           "LATE PAYMENT: Pursuant to Legislative Decree no. 231 of 09/10/2002 implementing Directive 2000/35/EC, in case of late payment, default interest will be automatically charged from the day following the expiry of the payment deadline.",
			"art6":           "JURISDICTION: For any dispute relating to the execution and, in general, to everything involving the application and interpretation of this agreement, the Court of Rimini shall have exclusive jurisdiction.",
			"signNote":       "For all legal purposes, I declare to expressly approve the clause relating to the competent court and the one relating to complaints.",
			"date":           "Date",
			"signStamp":      "Signature and Stamp"
		},
		"FR": {
			"topNote":        "La commande n'est confirmée qu'à la réception du bon de commande tamponné et signé pour acceptation, de toute approbation de maquette éventuelle et du paiement anticipé si prévu.",
			"bankTitle":      "Coordonnées Bancaires",
			"bank":           "Banque",
			"holder":         "Titulaire du compte",
			"readAndFill":    "Lire et remplir",
			"important":      "IMPORTANT",
			"importantIntro": "Pour confirmer la commande, veuillez remplir les champs suivants :",
			"billingAddress": "Adresse de facturation :",
			"vatNo":          "N° TVA :",
			"sdi":            "N° SDI :",
			"deliveryAddress":"Adresse de livraison :",
			"receiverContact":"Nom et numéro de téléphone de la personne chargée de la réception des marchandises :",
			"termsTitle":     "CONDITIONS GÉNÉRALES DE VENTE",
			"art1":           "CONFIRMATION DE COMMANDE : le présent formulaire constitue une confirmation des conditions définitives pour l'exécution de la commande, et les parties reconnaissent sa validité même si l'envoi à APIR SRL est effectué par télécopieur ou par e-mail. (*) La commande n'est confirmée qu'à la réception du bon de commande tamponné et signé pour acceptation, de toute approbation de maquette et du paiement anticipé si prévu.",
			"art2":           "MODIFICATION DE COMMANDE : toute demande de modification de la commande doit être effectuée immédiatement après réception de la présente confirmation. APIR SRL se réserve le droit de la refuser à sa seule discrétion.",
			"art3":           "LIVRAISON : toute date de livraison indiquée par APIR SRL est uniquement une date estimée et approximative, non contraignante pour APIR SRL.",
			"art4":           "RÉCLAMATIONS : le client doit vérifier la marchandise au moment de la prise en charge ; toute contestation relative à des défauts ou des manques de matériaux doit être formalisée exclusivement par écrit et doit parvenir à APIR SRL dans les 8 (huit) jours suivant la date de livraison.",
			"art5":           "RETARD DE PAIEMENT : en application du décret législatif n° 231 du 09/10/2002 transposant la directive 2000/35/CE, en cas de retard de paiement, des intérêts de retard seront automatiquement facturés à compter du lendemain de l'échéance.",
			"art6":           "JURIDICTION COMPÉTENTE : pour tout litige relatif à l'exécution et, en général, à tout ce qui implique l'application et l'interprétation du présent accord, le Tribunal de Rimini est seul compétent.",
			"signNote":       "À tous effets de droit, je déclare approuver expressément la clause relative au tribunal compétent et celle relative aux réclamations.",
			"date":           "Date",
			"signStamp":      "Signature et Cachet"
		},
		"ES": {
			"topNote":        "El pedido se considera confirmado únicamente tras la recepción del mismo sellado y firmado como aceptación, de cualquier aprobación de prueba y del pago anticipado cuando sea necesario.",
			"bankTitle":      "Datos Bancarios",
			"bank":           "Banco",
			"holder":         "Titular de la cuenta",
			"readAndFill":    "Leer y completar",
			"important":      "IMPORTANTE",
			"importantIntro": "Para confirmar el pedido, por favor complete los siguientes campos:",
			"billingAddress": "Dirección de facturación:",
			"vatNo":          "N° IVA:",
			"sdi":            "N° SDI:",
			"deliveryAddress":"Dirección de entrega:",
			"receiverContact":"Nombre y número de teléfono de la persona encargada de recibir la mercancía:",
			"termsTitle":     "CONDICIONES GENERALES DE VENTA",
			"art1":           "CONFIRMACIÓN DE PEDIDO: el presente formulario constituye una confirmación de las condiciones definitivas para la ejecución del pedido, y las partes reconocen su validez aunque el envío a APIR SRL se realice por fax o correo electrónico. (*) El pedido se considera confirmado únicamente tras la recepción del mismo sellado y firmado como aceptación, de cualquier aprobación de prueba y del pago anticipado cuando sea necesario.",
			"art2":           "MODIFICACIÓN DEL PEDIDO: cualquier solicitud de modificación del pedido debe realizarse inmediatamente después de recibir la presente confirmación. APIR SRL se reserva el derecho a rechazarla a su entera discreción.",
			"art3":           "ENTREGA: cualquier fecha de entrega indicada por APIR SRL es únicamente una fecha estimada y aproximada, no vinculante para APIR SRL.",
			"art4":           "RECLAMACIONES: el cliente deberá verificar la mercancía en el momento de la recepción; cualquier objeción por defectos o falta de materiales deberá formalizarse exclusivamente por escrito y deberá llegar a APIR SRL en un plazo de 8 (ocho) días a partir de la fecha de entrega.",
			"art5":           "RETRASO EN EL PAGO: en aplicación del Decreto Legislativo n° 231 de 09/10/2002 que implementa la Directiva 2000/35/CE, en caso de retraso en el pago, se cargarán automáticamente intereses de mora a partir del día siguiente al vencimiento del plazo de pago.",
			"art6":           "JURISDICCIÓN COMPETENTE: para cualquier controversia relativa a la ejecución y, en general, a todo lo que conlleva la aplicación e interpretación del presente acuerdo, el Tribunal de Rímini tendrá jurisdicción exclusiva.",
			"signNote":       "A todos los efectos legales, declaro aprobar expresamente la cláusula relativa al tribunal competente y la relativa a las reclamaciones.",
			"date":           "Fecha",
			"signStamp":      "Firma y Sello"
		},
		"DE": {
			"topNote":        "Der Auftrag gilt als bestätigt erst nach Eingang desselben, gestempelt und unterschrieben zur Annahme, einer etwaigen Druckfreigabe und der Vorauszahlung, sofern vorgesehen.",
			"bankTitle":      "Bankverbindung",
			"bank":           "Bank",
			"holder":         "Kontoinhaber",
			"readAndFill":    "Bitte lesen und ausfüllen",
			"important":      "WICHTIG",
			"importantIntro": "Um die Bestellung zu bestätigen, füllen Sie bitte die folgenden Felder aus:",
			"billingAddress": "Rechnungsadresse:",
			"vatNo":          "USt-IdNr.:",
			"sdi":            "SDI-Nr.:",
			"deliveryAddress":"Lieferadresse:",
			"receiverContact":"Name und Telefonnummer der für den Warenempfang zuständigen Person:",
			"termsTitle":     "ALLGEMEINE GESCHÄFTSBEDINGUNGEN",
			"art1":           "AUFTRAGSBESTÄTIGUNG: Dieses Formular stellt eine Bestätigung der endgültigen Bedingungen für die Auftragsabwicklung dar; die Parteien erkennen seine Gültigkeit an, auch wenn die Übermittlung an APIR SRL per Telefax oder E-Mail erfolgt. (*) Der Auftrag gilt erst nach Eingang desselben, gestempelt und unterschrieben zur Annahme, einer etwaigen Druckfreigabe und der Vorauszahlung, sofern vorgesehen, als bestätigt.",
			"art2":           "AUFTRAGSÄNDERUNG: Jede etwaige Änderungsanfrage muss unmittelbar nach Erhalt dieser Bestätigung erfolgen. APIR SRL behält sich das Recht vor, diese nach eigenem Ermessen abzulehnen.",
			"art3":           "LIEFERUNG: Ein etwaig von APIR SRL angegebenes Lieferdatum ist lediglich ein geschätztes und ungefähres Datum, das für APIR SRL nicht verbindlich ist.",
			"art4":           "REKLAMATIONEN: Der Kunde muss die Ware bei der Übernahme prüfen; etwaige Beanstandungen wegen Mängeln oder fehlenden Materialien müssen ausschließlich schriftlich erfolgen und müssen APIR SRL innerhalb von 8 (acht) Tagen ab dem Lieferdatum zugehen.",
			"art5":           "ZAHLUNGSVERZUG: In Anwendung des Gesetzesdekrets Nr. 231 vom 09.10.2002 zur Umsetzung der Richtlinie 2000/35/EG werden im Falle eines Zahlungsverzugs automatisch Verzugszinsen ab dem auf den Fälligkeitstag folgenden Tag berechnet.",
			"art6":           "GERICHTSSTAND: Für etwaige Streitigkeiten im Zusammenhang mit der Ausführung und im Allgemeinen mit allem, was die Anwendung und Auslegung dieser Vereinbarung betrifft, ist ausschließlich das Gericht Rimini zuständig.",
			"signNote":       "Zu allen rechtlichen Zwecken erkläre ich, die Klausel bezüglich des zuständigen Gerichts und die Klausel bezüglich der Reklamationen ausdrücklich zu genehmigen.",
			"date":           "Datum",
			"signStamp":      "Unterschrift und Stempel"
		}
	}>
	<cfif !structKeyExists(local.tx, local.lang)>
		<cfset local.lang = "IT">
	</cfif>
	<cfset local.t = local.tx[local.lang]>
	<cfoutput>
		<div style="page-break-inside: avoid !important;">
			<cfif !arguments.compact><div class="top-note">#local.t.topNote#</div></cfif>

			<div class="bank" aria-label="#local.t.bankTitle#">
				<table role="table" summary="#local.t.bankTitle#">
				<thead><tr><th colspan="2">#local.t.bankTitle#</th></tr></thead>
				<tbody>
					<tr><td class="label">#local.t.bank#</td><td class="value">CREDIT AGRICOLE<br/><small>C/C 000030727461 &ndash; ABI 06230 &ndash; CAB 68102</small></td></tr>
					<tr><td class="label">IBAN</td><td class="value">IT 44 G 06230 68102 0000 3072 7461</td></tr>
					<tr><td class="label">BIC</td><td class="value">CRPPIT2P718</td></tr>
					<tr><td class="label">#local.t.holder#</td><td class="value">APIR SRL</td></tr>
				</tbody>
				</table>
			</div>

			<cfif !arguments.compact>
			<h2 class="section-title">#local.t.readAndFill#</h2>

			<div class="important-box" role="region" aria-label="#local.t.important#">
				<div class="important-header">#local.t.important#</div>
				<div class="important-content" style="padding: 0 0 0.1in 0.1in;">
					<p style="font-size: 9px;">#local.t.importantIntro#</p>
					<div>
						<table style="width: 95%">
							<tr>
								<td style="width: 35%; border: 0;">#local.t.billingAddress#</td>
								<td style="width: 65%; border: 0; border-bottom: 1px dotted black;">&nbsp;</td>
							</tr>
						</table>
					</div>
					<div>
						<table style="width: 95%">
							<tr>
								<td style="width: 35%; border: 0;">#local.t.vatNo#</td>
								<td style="width: 65%; border: 0; border-bottom: 1px dotted black;">&nbsp;</td>
							</tr>
						</table>
					</div>
					<div>
						<table class="field-row" style="width: 95%">
							<tr>
								<td style="width: 35%; border: 0;">#local.t.sdi#</td>
								<td style="width: 65%; border: 0; border-bottom: 1px dotted black;">&nbsp;</td>
							</tr>
						</table>
					</div>
					<div>
						<table class="field-row" style="width: 95%">
							<tr>
								<td style="width: 35%; border: 0;">#local.t.deliveryAddress#</td>
								<td style="width: 65%; border: 0; border-bottom: 1px dotted black;">&nbsp;</td>
							</tr>
						</table>
					</div>
					<div>
						<table class="field-row" style="width: 95%">
							<tr>
								<td style="width: 35%; border: 0; line-height: 14px;">#local.t.receiverContact#</td>
								<td style="width: 65%; border: 0; border-bottom: 1px dotted black;">&nbsp;</td>
							</tr>
						</table>
					</div>
				</div>
			</div>

			<div class="small-print">
				<strong>#local.t.termsTitle#</strong>
				<ol style="padding-left:14px; margin:6px 0 0 0;">
				<li style="margin-bottom:6px;">#local.t.art1#</li>
				<li style="margin-bottom:6px;">#local.t.art2#</li>
				<li style="margin-bottom:6px;">#local.t.art3#</li>
				<li style="margin-bottom:6px;">#local.t.art4#</li>
				<li style="margin-bottom:6px;">#local.t.art5#</li>
				<li style="margin-bottom:6px;">#local.t.art6#</li>
				</ol>
			</div>


			<div class="sign-rows">
				<table class="sign-rows-table">
					<tr>
						<td style="width: 50%; text-align: center">
							<p style="margin-top:6px; font-size: 9px;">#local.t.signNote#</p>
						</td>
						<td style="width: 10%">
							&nbsp;
						</td>
						<td style="width: 10%;">
							&nbsp;
						</td>
						<td style="width: 10%; text-align: right">
							#local.t.date#
						</td>
						<td style="width: 20%; text-align: center">#local.t.signStamp#</td>
					</tr>
					<tr>
						<td style="width: 50%; border-bottom: 1px solid black !important;"></td>
						<td style="width: 10%; text-align: center;">
							<img src="/assets/main/img/quotation-arrow-left.png" style="height: 0.5in; width: 0.5in;">
						</td>
						<td style="width: 10%; text-align: center;">
							<img src="/assets/main/img/quotation-arrow-right.png" style="height: 0.5in; width: 0.5in;">
						</td>
						<td style="width: 10%; border-bottom: 1px solid black !important;">
							&nbsp;
						</td>
						<td style="width: 20%; border-bottom: 1px solid black !important;"></td>
					</tr>
				</table>
			</div>
			</cfif>

			<!--- Le coordinate bancarie sono float: right. In compact non c'è più
			     nessun blocco dopo di loro a fare da clear, e senza questo il
			     contenitore collasserebbe lasciando lo specchietto fuori. --->
			<div style="clear: both;"></div>
		</div>
	</cfoutput>
</cffunction>

<cffunction name="printStyle">
	<style>	
		/*
			Il font-size di base sta solo sugli elementi che fanno da contenitore.
			Elencando anche span e div, la regola vinceva sull'ereditarietà: uno
			span senza dimensione esplicita dentro a un blocco a 7pt tornava a
			11px. Si vedeva sulla riga delle dimensioni, più grande del codice
			articolo e degli attributi accanto. Ora span e div ereditano dal loro
			contenitore, mentre il font-family resta su tutti perché lì
			l'ereditarietà da sola non basta.
		*/
		body, td, th, p { font-family: 'Poppins'; font-size: 11px }
		span, div { font-family: 'Poppins' }
		
		table {
			border-collapse: collapse;
		}

		.blue {
			color: #007bff;
			text-decoration: none;
		}
		/* tabella dentro td articolo */
		.hiddenTable {
			border-collapse: collapse;
			border: 0;
			width: 100%;        /* usa tutta la larghezza della cella contenitore */
			table-layout: fixed;/* evita ricalcoli dinamici delle colonne */
			box-sizing: border-box;
		}
		.hiddenTable td,
		.hiddenTable th {
			border: 0 !important;
			padding: 0;         /* rimuovi padding interni, gestiscilo a livello della cella esterna se serve */
			vertical-align: top;
			box-sizing: border-box;
			line-height: 10px;
		}
		.hiddenTable td img {
			max-width: 100%;   /* mai oltre la larghezza della cella */
			height: auto;      /* mantiene il rapporto */
			display: block;    /* evita spazi extra dai baseline */
		}
		/* fine */

		/* pianta con i marker delle posizioni */
		.plant {
			page-break-inside: avoid;
			margin-bottom: 0.3in;
			text-align: center;
		}
		.plant-title {
			font-size: 10px;
			font-weight: bold;
			text-align: left;
			margin-bottom: 0.06in;
		}
		.plant-canvas {
			position: relative;
			display: inline-block;
		}
		.plant-image {
			display: block;
		}
		.plant-pin {
			position: absolute;
		}
		/* ripiego quando il PNG ruotato non è disponibile: stessa goccia, ferma */
		.plant-pin-flat {
			border-radius: 50% 50% 50% 0;
		}
		.plant-pin-label {
			position: absolute;
			font-size: 10px;
			line-height: 1.2;
			color: white;
			text-align: center;
		}
		/* fine */

		/* intestazione di sezione del raggruppamento per tipo categoria.
		   Nessuna riga sotto: la tabella che segue ha già il border-top e le due
		   linee vicine sembravano un errore. */
		.category-section {
			text-align: left;
			margin-top: 0.18in;
			margin-bottom: 0.04in;
			font-size: 12px;
			font-weight: bold;
			text-transform: uppercase;
		}
		/* fine */

		/* avviso proforma, fra i totali e le coordinate bancarie */
		.not-fiscal {
			clear: both;
			margin-top: 0.25in;
			margin-bottom: 0.1in;
			padding: 6px;
			border: 2px solid #000;
			text-align: center;
			font-size: 14px;
			font-weight: bold;
			text-transform: uppercase;
		}
		/* fine */

		/* form finale con iban banca e firme */
		.top-note {
			font-size: 12px;
			font-weight: bold;
		}
		.bank {
			width: 4.5in;
			float: right;
			margin-right: 20px;
			text-align: left;
		}
		.bank table {
			width:100%;
			border:1px solid #000;
			border-collapse: collapse;
			text-align:left;
		}
		.bank th {
			background:#f0f0f0;
			text-align:center;
			font-size: 11px;
			border-bottom:1px solid #000;
		}
		.bank td { padding:6px 8px; border-top:1px solid #000; vertical-align: middle; }
		.bank .label { width:120px; font-weight:600; border-right:1px solid #000; text-align:left; padding-left:8px; }
		.bank .value { padding-left:10px; }
		.section-title {
			clear: both;
			margin-top:0.2in;
			font-size:12px;
			font-weight: 700;
		}
		.important-box {
			border:1px solid #000;
			margin-top:0.1in;
			padding:0;
		}
		.important-header {
			background:#f3f3f3;
			border-bottom:1px solid #000;
			text-align:center;
			font-weight:800;
			padding:8px 6px;
			font-size:12px;
		}
		.important-content {
			padding:3px 10px;
			line-height:1.4;
		}
		.small-print {
			clear: both;
			margin-top:0.2in;
			font-size:8px;
			line-height:1.05;
		}
		.sign-rows {
			/*
				Le coordinate bancarie sono float: right. Il clear stava solo su
				.small-print, che nella proforma non viene emesso (getFinalForm
				compact): senza, questo blocco risaliva accanto allo specchietto
				e ci finiva sopra. Va tenuto qui, così non dipende da quale
				blocco lo precede.
			*/
			clear: both;
			margin-top: 0.4in;
		}
		.sign-rows-table {
			border-collapse: collapse;
			border: 0;
		}
		.sign-rows-table td,
		.sign-rows-table tr {
			border: 0 !important;
		}
		/* fine */
	</style>
</cffunction>

<!---
	Ritaglio della placca per questa voce, se il controller e' riuscito a farlo.
	Torna null quando la voce non e' una placca a blocchi, quando l'immagine e'
	caricata a mano, quando l'armatura non si e' ritrovata dal codice modello o
	quando la stampa e' costruita da un controller che non prepara i ritagli.
--->
<cffunction name="platePrintCrop" output="false">
	<cfargument name="item" required="true">
	<cfargument name="data" required="false">

	<cfif IsNull( arguments.data ) OR !IsStruct( arguments.data ) OR !StructKeyExists( arguments.data, "plateImages" )>
		<cfreturn>
	</cfif>

	<cfset local.itemId = arguments.item.getId()>

	<cfif IsNull( local.itemId ) OR !StructKeyExists( arguments.data.plateImages.byItem, local.itemId )>
		<cfreturn>
	</cfif>

	<cfreturn arguments.data.plateImages.byItem[ local.itemId ]>
</cffunction>
