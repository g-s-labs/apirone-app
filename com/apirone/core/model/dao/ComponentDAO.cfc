<cfcomponent extends="com.apirone.core.model.dao.AbsDAO" accessors="true">
	<cffunction name="read">
		<cfargument name="componentId" type="Numeric" required="true">
		<cfargument name="productItemId" type="Numeric" required="false">

		<cfquery name="local.q" datasource="apirone">
			SELECT *
			FROM
				components
			WHERE
				component_id = <cfqueryparam cfsqltype="Integer" value="#arguments.componentId#">
		</cfquery>

		<cfreturn local.q>
	</cffunction>
	
	<cffunction name="priceCalculatorRead" returntype="struct">
		<cfargument name="componentId" type="numeric" required="false">
		<cfargument name="productItemId" type="numeric" required="false">

		<!--- Le espressioni CASE isDeleted/totalQuantity sono replicate in priceCalculatorReadByProductItemIds(): tenere sincronizzate. --->
		<cfquery name="componentQuery" datasource="apirone">
			SELECT
				c.component_id as id,
				
				CASE 
					WHEN co.deleted = true THEN true
					ELSE false
				END AS isDeleted,

				CASE
					WHEN co.deleted = true THEN 0
					WHEN co.quantity IS NOT NULL THEN c.quantity + co.quantity
					ELSE c.quantity
				END AS totalQuantity,

				c.raw_product_id,
				c.variant_id,
				c.color_id

			FROM components c

			LEFT JOIN component_overrides co 
				ON c.component_id = co.component_id 
				<cfif NOT IsNull(arguments.productItemId)>
					AND co.product_item_id = <cfqueryparam value="#arguments.productItemId#" cfsqltype="integer">
				</cfif>
			WHERE 1=1
			<cfif NOT IsNull(arguments.componentId)>
				AND c.component_id = <cfqueryparam value="#arguments.componentId#" cfsqltype="integer">
			</cfif>
			<cfif NOT IsNull(arguments.productItemId)>
				AND c.product_item_id = <cfqueryparam value="#arguments.productItemId#" cfsqltype="integer">
			</cfif>
		</cfquery>

		<cfif componentQuery.recordCount EQ 0>
			<cfreturn {} />
		</cfif>

		<cfset component = componentQuery.getRow(1)>
		<cfset component["costAmount"] = getComponentCost(
			rawProductId = component.raw_product_id,
			variantId    = component.variant_id,
			colorId      = component.color_id
		)>

		<cfset var rawProduct = getRawProductData( component.raw_product_id )>
		<cfset component["raw_product_name"] = rawProduct.raw_product_name>
		<cfset component["raw_product_processiong_type"] = rawProduct.raw_product_processiong_type>
		<cfset component["raw_product_unit"] = rawProduct.raw_product_unit>

		<cfreturn component>
	</cffunction>

	<!---
		Helper: restituisce lo struct di memoizzazione verticale della richiesta corrente,
		creandolo al primo utilizzo. Il DAO è un singleton WireBox: lo stato per-richiesta non deve
		essere conservato nel variables scope dell'istanza (condiviso tra tutte le richieste), bensì
		nel request scope, il cui ciclo di vita coincide con la singola richiesta HTTP. Si tratta
		di memoizzazione effimera per richiesta, NON di una cache.

		@param cacheKey  Nome dello struct da creare/leggere nel request scope
		@return          Lo struct di memo richiesto (vuoto al primo accesso della richiesta)
	--->
	<cffunction name="getVerticaleMemo" returntype="Struct" access="private">
		<cfargument name="cacheKey" type="String" required="true">

		<cfif !StructKeyExists( request, arguments.cacheKey )>
			<cfset request[ arguments.cacheKey ] = {}>
		</cfif>

		<cfreturn request[ arguments.cacheKey ]>
	</cffunction>

	<!---
		Recupera il costo (lispre) della materia prima dal gestionale verticale.
		Estratto da priceCalculatorRead() per essere riutilizzato dal path batch
		(priceCalculatorSearchByProductItemIds in ComponentService).
		Memoizza il risultato nel request scope (_componentCostCache): la stessa terna
		raw_product_id | variant_id | color_id viene interrogata una sola volta per richiesta,
		le chiamate successive restituiscono il costo già letto senza toccare il DB ERP.
	--->
	<cffunction name="getComponentCost" returntype="any" access="public">
		<cfargument name="rawProductId" required="true">
		<cfargument name="variantId" required="true">
		<cfargument name="colorId" required="true">

		<!--- Le query trimmano gli input: la chiave di memo usa i valori già trimmati, così input diversi ma equivalenti condividono la stessa voce. --->
		<cfset var memoKey  = Trim( arguments.rawProductId ) & "|" & Trim( arguments.variantId ) & "|" & Trim( arguments.colorId )>
		<cfset var costMemo = getVerticaleMemo( "_componentCostCache" )>

		<!--- Riuso: costo già letto dall'ERP in questa stessa richiesta. --->
		<cfif StructKeyExists( costMemo, memoKey )>
			<cfreturn costMemo[ memoKey ]>
		</cfif>

		<cfquery name="verticalCost" datasource="apirone">
			SELECT lispre
			FROM verticale_price_list
			WHERE TRIM(lisart) = <cfqueryparam value="#Trim(arguments.rawProductId)#" cfsqltype="varchar">
			AND (
				(
					TRIM(liscvr) = <cfqueryparam value="#Trim(arguments.variantId)#" cfsqltype="varchar"> AND
					TRIM(liscol) = <cfqueryparam value="#Trim(arguments.colorId)#" cfsqltype="varchar">
				)
				OR TRIM(liscvr) = <cfqueryparam value="#Trim(arguments.variantId)#" cfsqltype="varchar">
				OR TRIM(liscol) = <cfqueryparam value="#Trim(arguments.colorId)#" cfsqltype="varchar">
				OR 1=1
			)
			ORDER BY
				CASE
					WHEN
						TRIM(liscvr) = <cfqueryparam value="#Trim(arguments.variantId)#" cfsqltype="varchar">
						AND TRIM(liscol) = <cfqueryparam value="#Trim(arguments.colorId)#" cfsqltype="varchar">
						THEN 1
					WHEN
						TRIM(liscvr) = <cfqueryparam value="#Trim(arguments.variantId)#" cfsqltype="varchar">
						THEN 2
					WHEN
						TRIM(liscol) = <cfqueryparam value="#Trim(arguments.colorId)#" cfsqltype="varchar">
						THEN 3
					ELSE 4
				END
			LIMIT 1
		</cfquery>

		<!--- Memorizza il costo per i successivi riusi nella stessa richiesta, normalizzando i casi vuoti.
			Con la configurazione Lucee di default un NULL del DB arriva come stringa vuota; se mai venisse
			attivato il full null support, assegnare un null cancellerebbe la chiave dello struct rompendo
			la memo: per questo i casi vuoti diventano 0 (stesso fallback del caso nessuna riga trovata). --->
		<cfset var componentCost = 0>

		<cfif verticalCost.recordCount GT 0 AND Len( verticalCost.lispre[1] )>
			<cfset componentCost = verticalCost.lispre[1]>
		</cfif>

		<cfset costMemo[ memoKey ] = componentCost>

		<cfreturn costMemo[ memoKey ]>
	</cffunction>

	<!---
		Recupera nome e tipo di lavorazione della materia prima dal gestionale verticale.
		Estratto da priceCalculatorRead() per essere riutilizzato dal path batch.
		Memoizza il risultato nel request scope (_rawProductCache): lo stesso raw_product_id
		viene interrogato una sola volta per richiesta, le chiamate successive restituiscono
		i dati già letti senza toccare il DB ERP.
	--->
	<cffunction name="getRawProductData" returntype="Struct" access="public">
		<cfargument name="rawProductId" required="true">

		<cfset var dataMemo = getVerticaleMemo( "_rawProductCache" )>

		<!--- Riuso: dati già letti dall'ERP in questa stessa richiesta. --->
		<cfif StructKeyExists( dataMemo, arguments.rawProductId )>
			<cfreturn dataMemo[ arguments.rawProductId ]>
		</cfif>

		<cfquery name="rawProductData" datasource="apirone">
			SELECT
				ardesart as raw_product_name,
				CASE WHEN artipmat = 'LAV' THEN 'LV' ELSE 'MP' END AS raw_product_processiong_type,
				COALESCE( NULLIF( TRIM( arunmis1 ), '' ), 'PZ' ) AS raw_product_unit
			FROM
				verticale_raw_products a
			WHERE
				arcodart = <cfqueryparam cfsqltype="varchar" value="#arguments.rawProductId#">
		</cfquery>

		<!--- Memorizza i dati letti (o il fallback con stringhe vuote) per i successivi riusi nella stessa richiesta. --->
		<cfif rawProductData.recordCount GT 0>
			<cfset dataMemo[ arguments.rawProductId ] = {
				"raw_product_name"              = rawProductData.getRow(1).raw_product_name,
				"raw_product_processiong_type"  = rawProductData.getRow(1).raw_product_processiong_type,
				"raw_product_unit"              = rawProductData.getRow(1).raw_product_unit
			}>
		<cfelse>
			<cfset dataMemo[ arguments.rawProductId ] = { "raw_product_name" = "", "raw_product_processiong_type" = "", "raw_product_unit" = "PZ" }>
		</cfif>

		<cfreturn dataMemo[ arguments.rawProductId ]>
	</cffunction>

	<!---
		Legge in UNA sola query (apirone) raw_product_id/variant_id/color_id di più componenti.
		Serve per precompilare le memo di verticale prima dei priceCalculatorRead per componente.
	--->
	<cffunction name="getComponentTriplesByComponentIds" returntype="Query" access="public">
		<cfargument name="componentIds" type="Array" required="true">

		<cfquery name="q" datasource="apirone">
			SELECT
				c.component_id   AS component_id,
				c.raw_product_id AS raw_product_id,
				c.variant_id     AS variant_id,
				c.color_id       AS color_id
			FROM components c
			WHERE c.component_id IN (
				<cfqueryparam value="#ArrayToList( arguments.componentIds )#" list="true" cfsqltype="integer">
			)
		</cfquery>

		<cfreturn q>
	</cffunction>

	<!---
		Legge in una sola query (apirone) raw_product_id/variant_id/color_id di tutti i componenti
		di più prodotti (placca + frutti + tappi). Serve per il prewarm verticale a inizio pricing.
	--->
	<cffunction name="getComponentTriplesByProductIds" returntype="Query" access="public">
		<cfargument name="productIds" type="Array" required="true">

		<cfquery name="q" datasource="apirone">
			SELECT
				c.component_id   AS component_id,
				c.raw_product_id AS raw_product_id,
				c.variant_id     AS variant_id,
				c.color_id       AS color_id
			FROM components c
			WHERE c.product_id = ANY( ARRAY[<cfqueryparam value="#ArrayToList( arguments.productIds )#" list="true" cfsqltype="varchar">]::uuid[] )
		</cfquery>

		<cfreturn q>
	</cffunction>

	<!---
		Legge in una sola query (apirone) raw_product_id/variant_id/color_id dei componenti
		linea+modello (i "bundle" del calcolo prezzo). Serve per il prewarm verticale a inizio pricing.
	--->
	<cffunction name="getComponentTriplesByLineModel" returntype="Query" access="public">
		<cfargument name="lineId" type="String" required="true">
		<cfargument name="modelId" type="String" required="true">

		<cfquery name="q" datasource="apirone">
			SELECT
				c.component_id   AS component_id,
				c.raw_product_id AS raw_product_id,
				c.variant_id     AS variant_id,
				c.color_id       AS color_id
			FROM components c
			WHERE c.line_id = <cfqueryparam value="#arguments.lineId#" cfsqltype="varchar">::uuid
			AND c.model_id = <cfqueryparam value="#arguments.modelId#" cfsqltype="varchar">::uuid
		</cfquery>

		<cfreturn q>
	</cffunction>

	<!---
		Recupera in UNA sola query verticale i costi (lispre) di tutte le triple raw|variant|color pendenti.
		Per ogni terna è applicata la STESSA priorità del singolo getComponentCost():
		variant+color ( 1 ), solo variant ( 2 ), solo color ( 3 ), qualsiasi riga ( 4 ).
		Riempie la memo per request: i successivi getComponentCost() restituiscono il costo senza toccare l'ERP.
	--->
	<cffunction name="getComponentCostByTriples" returntype="void" access="public">
		<cfargument name="triples" type="Array" required="true">

		<cfif NOT ArrayLen( arguments.triples )>
			<cfreturn>
		</cfif>

		<cfset var costMemo = getVerticaleMemo( "_componentCostCache" )>

		<!--- Scarta le triple già presenti in memo: la query interroga solo il necessario. --->
		<cfset var pending = []>
		<cfloop array="#arguments.triples#" index="t">
			<cfset var memoKey = Trim( t.rawProductId ) & "|" & Trim( t.variantId ) & "|" & Trim( t.colorId )>
			<cfif NOT StructKeyExists( costMemo, memoKey )>
				<cfset ArrayAppend( pending, {
					rawProductId = Trim( t.rawProductId ),
					variantId    = Trim( t.variantId ),
					colorId      = Trim( t.colorId )
				} )>
			</cfif>
		</cfloop>

		<cfif NOT ArrayLen( pending )>
			<cfreturn>
		</cfif>

		<!---
			OUTER APPLY esegue la sottoquery ( SELECT TOP 1 ... ) una volta PER OGNI riga della lista
			valori t: è l'equivalente per-riga di un LEFT JOIN con TOP 1. Se per una terna non esiste
			nessuna riga di listino, la sottoquery non produce righe e la riga di t resta comunque nel
			resultato con lispre NULL. Il CASE nell'ORDER BY replica l'ordine di
			priorità del singolo getComponentCost(): terna esatta, poi variant, poi color, poi qualsiasi.
		--->
		<cfquery name="costsByTriple" datasource="apirone">
			SELECT
				t.rawProductId AS rawProductId,
				t.variantId    AS variantId,
				t.colorId      AS colorId,
				best.lispre    AS lispre
			FROM (
				VALUES
				<cfloop array="#pending#" index="i" item="p">
					<cfif i GT 1>,</cfif>
					(
						<cfqueryparam value="#p.rawProductId#" cfsqltype="varchar">,
						<cfqueryparam value="#p.variantId#" cfsqltype="varchar">,
						<cfqueryparam value="#p.colorId#" cfsqltype="varchar">
					)
				</cfloop>
			) AS t ( rawProductId, variantId, colorId )
			LEFT JOIN LATERAL (
				SELECT lispre
				FROM verticale_price_list l
				WHERE TRIM(lisart) = TRIM(t.rawProductId)
				AND (
					( TRIM(liscvr) = TRIM(t.variantId) AND TRIM(liscol) = TRIM(t.colorId) )
					OR TRIM(liscvr) = TRIM(t.variantId)
					OR TRIM(liscol) = TRIM(t.colorId)
					OR 1=1
				)
				ORDER BY
					CASE
						WHEN TRIM(liscvr) = TRIM(t.variantId) AND TRIM(liscol) = TRIM(t.colorId) THEN 1
						WHEN TRIM(liscvr) = TRIM(t.variantId) THEN 2
						WHEN TRIM(liscol) = TRIM(t.colorId) THEN 3
						ELSE 4
					END
				LIMIT 1
			) best ON true
		</cfquery>

		<!--- Stessa normalizzazione del singolo getComponentCost: lispre assente o vuota diventa 0. --->
		<cfloop query="costsByTriple">
			<cfset var memoKey2 = Trim( costsByTriple.rawProductId ) & "|" & Trim( costsByTriple.variantId ) & "|" & Trim( costsByTriple.colorId )>
			<cfset var componentCost = 0>
			<cfif Len( costsByTriple.lispre )>
				<cfset componentCost = costsByTriple.lispre>
			</cfif>
			<cfset costMemo[ memoKey2 ] = componentCost>
		</cfloop>
	</cffunction>

	<!---
		Recupera in UNA sola query verticale nome e tipo di lavorazione di tutti i raw product pendenti.
		Riempie la memo per request: i successivi getRawProductData() non toccano l'ERP.
		Le chiavi restano i valori passati così come sono (stesso comportamento del singolo getRawProductData).
	--->
	<cffunction name="getRawProductDataByIds" returntype="void" access="public">
		<cfargument name="rawProductIds" type="Array" required="true">

		<cfset var dataMemo = getVerticaleMemo( "_rawProductCache" )>

		<!--- Scarta gli id già in memo o vuoti. --->
		<cfset var pendingIds = []>
		<cfloop array="#arguments.rawProductIds#" index="rid">
			<cfif NOT StructKeyExists( dataMemo, rid ) AND Len( Trim( rid ) )>
				<cfset ArrayAppend( pendingIds, rid )>
			</cfif>
		</cfloop>

		<cfif NOT ArrayLen( pendingIds )>
			<cfreturn>
		</cfif>

		<cfquery name="rawProductsById" datasource="apirone">
			SELECT
				a.arcodart AS arcodart,
				a.ardesart AS ardesart,
				CASE WHEN a.artipmat = 'LAV' THEN 'LV' ELSE 'MP' END AS raw_product_processiong_type,
				COALESCE( NULLIF( TRIM( a.arunmis1 ), '' ), 'PZ' ) AS raw_product_unit
			FROM verticale_raw_products a
			WHERE a.arcodart IN (
				<cfqueryparam value="#ArrayToList( pendingIds )#" list="true" cfsqltype="varchar">
			)
		</cfquery>

		<cfset var rowsByName = {}>
		<cfloop query="rawProductsById">
			<cfset rowsByName[ Trim( rawProductsById.arcodart ) ] = {
				"raw_product_name"             = rawProductsById.ardesart,
				"raw_product_processiong_type" = rawProductsById.raw_product_processiong_type,
				"raw_product_unit"             = rawProductsById.raw_product_unit
			}>
		</cfloop>

		<!--- Chiave della memo: l'id COSÌ COME passato dal chiamante (stesso comportamento del singolo
			getRawProductData, che interroga arcodart = valore esatto ignorando gli spazi finali). --->
		<cfloop array="#pendingIds#" index="rid">
			<cfif StructKeyExists( rowsByName, Trim( rid ) )>
				<cfset dataMemo[ rid ] = rowsByName[ Trim( rid ) ]>
			<cfelse>
				<cfset dataMemo[ rid ] = { "raw_product_name" = "", "raw_product_processiong_type" = "", "raw_product_unit" = "PZ" }>
			</cfif>
		</cfloop>
	</cffunction>

	<cffunction returntype="Query" name="find">
		<cfargument name="lineId" type="String">
		<cfargument name="modelId" type="String">
		<cfargument name="productId" type="String">
		<cfargument name="productItemId" type="Numeric">
		<cfargument name="attributeValueId" type="String">
		<cfargument name="rawProductId" type="String">
		<cfargument name="variantId" type="String">
		<cfargument name="colorId" type="String">
		<cfargument name="signageConfigItemId" type="String">

		<cfargument name="signageItemProduct" type="Struct">
		<!--- productItemId AND SignageConfigItemId --->

		<cfargument name="limit" required="true" type="Numeric" default="0">
		<cfargument name="offset" required="true" type="Numeric" default="0">
		<cfargument name="orderby" required="true" type="String" default="created_at desc">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				component_id,
				COUNT(component_id) OVER() AS total
			FROM
				components
			WHERE 1=1

				<cfif !IsNull( arguments.signageItemProduct )>
					AND product_item_join_id = <cfqueryparam value="#arguments.signageItemProduct.productItemId#" cfsqltype="Integer">
					AND signage_config_item_join_id = <cfqueryparam value="#arguments.signageItemProduct.SignageConfigItemId#" cfsqltype="Integer">
				</cfif>

				<cfif !IsNull( arguments.productItemId )>
					AND product_item_id = <cfqueryparam value="#arguments.productItemId#" cfsqltype="Integer">
				</cfif>

				<cfif !IsNull( arguments.productId )>
					AND product_id = <cfqueryparam value="#arguments.productId#" cfsqltype="Varchar">::uuid
				</cfif>

				<cfif !IsNull( arguments.lineId )>
					AND line_id = <cfqueryparam value="#arguments.lineId#" cfsqltype="Varchar">::uuid
				</cfif>

				<cfif !IsNull( arguments.modelId )>
					AND model_id = <cfqueryparam value="#arguments.modelId#" cfsqltype="Varchar">::uuid
				</cfif>

				<cfif !IsNull( arguments.attributeValueId )>
					AND attribute_raw_value_id = <cfqueryparam value="#arguments.attributeValueId#" cfsqltype="Integer">
				</cfif>

				<cfif !IsNull( arguments.rawProductId )>
					AND TRIM(raw_product_id) = <cfqueryparam value="#arguments.rawProductId#" cfsqltype="Varchar">
				</cfif>

				<cfif !IsNull( arguments.variantId )>
					AND TRIM(variant_id) = <cfqueryparam value="#arguments.variantId#" cfsqltype="Varchar">
				</cfif>

				<cfif !IsNull( arguments.colorId )>
					AND TRIM(color_id) = <cfqueryparam value="#arguments.colorId#" cfsqltype="Varchar">
				</cfif>

				<cfif !IsNull( arguments.signageConfigItemId )>
					AND signage_config_item_id = <cfqueryparam value="#arguments.signageConfigItemId#" cfsqltype="Integer">
				</cfif>

			ORDER BY
				#super.sanitizeSQL( arguments.orderby )#

			<cfif arguments.limit GT 0>
				LIMIT
					<cfqueryparam cfsqltype="integer" value="#arguments.limit#">
				OFFSET
					<cfqueryparam cfsqltype="integer" value="#arguments.offset#">
			</cfif>
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<cffunction name="delete" returntype="Boolean">
		<cfargument name="componentId" type="Numeric" required="true">

		<cfquery name="local.q" datasource="apirone" result="result">
			DELETE FROM
				components
			WHERE
				component_id = <cfqueryparam cfsqltype="Integer" value="#arguments.componentId#">
		</cfquery>

		<cfreturn true>
	</cffunction>

	<cffunction name="deleteByParams" returntype="Boolean">
		<cfargument name="component" type="com.apirone.core.model.bean.Component" required="true">

		<cfset var meta = getFieldsAndValues( arguments.component )>

		<cfquery name="local.q" datasource="apirone" result="result">
			DELETE FROM components
			WHERE
				component_id = <cfqueryparam cfsqltype="Integer" value="#arguments.component.getId()#">

				<cfloop array="#meta.fields#" index="index" item="field">
					AND #field# = <cfif meta.values[ index ].type IS "uuid">
						<cfqueryparam cfsqltype="Varchar" value="#meta.values[ index ].value#">::uuid
					<cfelse>
						<cfqueryparam cfsqltype="#meta.values[ index ].type#" value="#meta.values[ index ].value#">
					</cfif>
				</cfloop>
		</cfquery>

		<cfreturn true>
	</cffunction>

	<cffunction name="insert" returntype="Numeric">
		<cfargument name="component" type="com.apirone.core.model.bean.Component" required="true">

		<cfset var meta = getFieldsAndValues( arguments.component )>

		<cfquery name="local.q" datasource="apirone">
			INSERT INTO components (
				raw_product_id,
				color_id,
				variant_id,
				quantity,

				#ArrayToList( meta.fields )#

			)
			VALUES (
				<cfqueryparam cfsqltype="Varchar" value="#arguments.component.getRawProduct().getId()#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.component.getColor().getId()#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.component.getVariant().getId()#">,
				<cfqueryparam cfsqltype="Numeric" value="#arguments.component.getQuantity()#">,

				<cfloop array="#meta.values#" item="item" index="index">
					<cfif item.type IS "uuid">
						<cfqueryparam cfsqltype="Varchar" value="#item.value#">::uuid
					<cfelse>
						<cfqueryparam cfsqltype="#item.type#" value="#item.value#">
					</cfif>
					<cfif Len( meta.values ) NEQ index>
						,
					</cfif>
				</cfloop>

			) RETURNING component_id
		</cfquery>

		<cfreturn local.q.component_id>
	</cffunction>

	<cffunction name="update" returntype="Numeric">
		<cfargument name="component" type="com.apirone.core.model.bean.Component" required="true">

		<!--- <cfset var meta = getFieldsAndValues( arguments.component )> --->

		<cfquery name="local.q" datasource="apirone">
			UPDATE components
			SET
				quantity = <cfqueryparam cfsqltype="Numeric" value="#arguments.component.getQuantity()#">
			WHERE
				component_id = <cfqueryparam cfsqltype="Numeric" value="#arguments.component.getId()#">
		</cfquery>

		<cffile action="APPEND" file="#ExpandPath( "/debug.log" )#" output="#Now()# ComponentDAO: update">

		<cfreturn arguments.component.getId()>
	</cffunction>

	<cffunction name="reassign" returntype="Numeric">
		<cfargument name="componentId" type="Numeric" required="true">
		<cfargument name="paramCategory" type="String">
		<cfargument name="newParam" type="String" required="true">

		<cfset var dbField = getDBField( "component.#arguments.paramCategory#" )>

		<cfquery name="local.q" datasource="apirone">
			UPDATE components
			SET #dbField.name# = <cfqueryparam cfsqltype="Varchar" value="#arguments.newParam#">
			WHERE
				component_id = <cfqueryparam cfsqltype="Numeric" value="#arguments.componentId#">
		</cfquery>
		<cfreturn arguments.componentId>
	</cffunction>

	<!--- private methods --->

	<cffunction name="getFieldsAndValues" returntype="Struct" access="private">
		<cfargument name="component" type="com.apirone.core.model.bean.Component" required="true">

		<cfset var meta = GetMetadata( arguments.component )>

		<cfset var field = []>
		<cfset var values = []>

		<cfswitch expression="#meta.fullname#">
			<cfcase value="com.apirone.core.model.bean.ComponentCatalogBundle">
				<cfset fields = [ "line_id", "model_id" ]>
				<cfset values = [
					{
						value = arguments.component.getLine().getId(),
						type  = "uuid"
					},
					{
						value = arguments.component.getModel().getId(),
						type  = "uuid"
					}
				]>
			</cfcase>

			<cfcase value="com.apirone.core.model.bean.ComponentProductItem">
				<cfset fields = [ "product_item_id" ]>
				<cfset values = [
					{
						value = arguments.component.getProductItem().getId(),
						type  = "Integer"
					}
				]>
			</cfcase>

			<cfcase value="com.apirone.core.model.bean.ComponentSignageConfigItem">
				<cfset fields = [ "signage_config_item_id" ]>
				<cfset values = [
					{
						value = arguments.component.getSignageConfigItem().getId(),
						type  = "Integer"
					}
				]>
			</cfcase>

			<cfcase value="com.apirone.core.model.bean.ComponentSignageItemProduct">
				<cfset fields = [ "signage_config_item_join_id", "product_item_join_id" ]>
				<cfset values = [
					{
						value = arguments.component.getSignageConfigItem().getId(),
						type  = "Integer"
					},
					{
						value = arguments.component.getProductItem().getId(),
						type  = "Integer"
					}
				]>
			</cfcase>

			<cfcase value="com.apirone.core.model.bean.ComponentProduct">
				<cfset fields = [ "product_id" ]>
				<cfset values = [
					{
						value = arguments.component.getProduct().getId(),
						type  = "uuid"
					}
				]>
			</cfcase>

			<cfcase value="com.apirone.core.model.bean.ComponentAttributeValue">
				<cfset fields = [ "attribute_raw_value_id" ]>
				<cfset values = [
					{
						value = arguments.component.getAttributeValue().getId(),
						type  = "Integer"
					}
				]>
			</cfcase>

			<cfdefaultcase>
				<cfset var meta = GetMetadata( component )>
				<cfthrow type="apirone.error.ComponentNotValid" message="Component [#meta.fullname#] not valid">
			</cfdefaultcase>
		</cfswitch>

		<cfreturn { "fields" = fields, "values" = values }>
	</cffunction>

	<!---
		Recupera in batch più componenti dato un array di ID.
		Utilizzato dal Service corrispondente per caricare i bean in blocco.
	--->
	<cffunction name="readByIds" returntype="Query" access="public">
		<cfargument name="ids" type="Array" required="true">

		<cfset var idsList = ArrayToList( arguments.ids )>

		<cfquery name="local.q" datasource="apirone">
			SELECT *
			FROM components
			WHERE component_id IN (
				<cfqueryparam value="#idsList#" list="true" cfsqltype="integer">
			)
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Recupera in batch i componenti collegati a una lista di product_item_id.
		Utilizzato da QuotationService.getComponents() per evitare N+1.
	--->
	<cffunction name="readByProductItemIds" returntype="Query" access="public">
		<cfargument name="productItemIds" type="Array" required="true">

		<cfset var idsList = ArrayToList( arguments.productItemIds )>

		<cfquery name="local.q" datasource="apirone">
			SELECT *
			FROM components
			WHERE product_item_id IN (
				<cfqueryparam value="#idsList#" list="true" cfsqltype="integer">
			)
			ORDER BY created_at desc
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Recupera in batch i componenti di tipo SignageItemProduct dato
		l'ID della config segnaletica e una lista di product_item_id (join).
		Utilizzato da QuotationService.getComponents() per evitare N+1.
	--->
	<cffunction name="readBySignageItemProductJoinIds" returntype="Query" access="public">
		<cfargument name="signageConfigItemId" type="String" required="true">
		<cfargument name="productItemIds" type="Array" required="true">

		<cfset var idsList = ArrayToList( arguments.productItemIds )>

		<cfquery name="local.q" datasource="apirone">
			SELECT *
			FROM components
			WHERE signage_config_item_join_id = <cfqueryparam value="#arguments.signageConfigItemId#" cfsqltype="Integer">
				AND product_item_join_id IN (
					<cfqueryparam value="#idsList#" list="true" cfsqltype="integer">
				)
			ORDER BY created_at desc
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Recupera in batch i componenti collegati agli attributi (attribute_raw_value_id).
		Utilizzato da QuotationService.getComponents() per il caricamento
		dei componenti base-attribute corrispondenti a includeBaseAttributeComponents=true.
	--->
	<cffunction name="readByAttributeValueIds" returntype="Query" access="public">
		<cfargument name="attributeValueIds" type="Array" required="true">

		<cfset var idsList = ArrayToList( arguments.attributeValueIds )>

		<cfquery name="local.q" datasource="apirone">
			SELECT *
			FROM components
			WHERE attribute_raw_value_id IN (
				<cfqueryparam value="#idsList#" list="true" cfsqltype="integer">
			)
			ORDER BY created_at desc
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Recupera in batch i componenti "own" (product_item_id) con override correlato
		per il calcolo prezzo. Sostituisce N chiamate a priceCalculatorRead() con una
		sola query apirone. L'override è scoped sul product_item_id del componente
		(equivalente al singolo priceCalculatorRead(componentId, productItemId)).
	--->
	<cffunction name="priceCalculatorReadByProductItemIds" returntype="Query" access="public">
		<cfargument name="productItemIds" type="Array" required="true">

		<cfif !ArrayLen( arguments.productItemIds )>
			<cfreturn QueryNew( "" )>
		</cfif>

		<cfset var idsList = ArrayToList( arguments.productItemIds )>

		<cfquery name="local.q" datasource="apirone">
			SELECT
				c.component_id as id,

				CASE 
					WHEN co.deleted = true THEN true
					ELSE false
				END AS isDeleted,

				CASE
					WHEN co.deleted = true THEN 0
					WHEN co.quantity IS NOT NULL THEN c.quantity + co.quantity
					ELSE c.quantity
				END AS totalQuantity,

				c.raw_product_id,
				c.variant_id,
				c.color_id,
				c.product_item_id

			FROM components c

			LEFT JOIN component_overrides co 
				ON c.component_id = co.component_id 
				AND co.product_item_id = c.product_item_id
			WHERE c.product_item_id IN (
				<cfqueryparam value="#idsList#" list="true" cfsqltype="integer">
			)
			ORDER BY c.created_at desc
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Recupera in batch gli override per una lista di (component_id, product_item_id)
		di componenti "base attribute".
	--->
	<cffunction name="readOverridesByComponentIdsAndProductItemIds" returntype="Query" access="public">
		<cfargument name="componentIds" type="Array" required="true">
		<cfargument name="productItemIds" type="Array" required="true">

		<cfif !ArrayLen( arguments.componentIds ) OR !ArrayLen( arguments.productItemIds )>
			<cfreturn QueryNew( "" )>
		</cfif>

		<cfset var componentIdsList   = ArrayToList( arguments.componentIds )>
		<cfset var productItemIdsList = ArrayToList( arguments.productItemIds )>

		<cfquery name="local.q" datasource="apirone">
			SELECT
				component_id,
				product_item_id,
				quantity,
				deleted
			FROM component_overrides
			WHERE component_id IN (
				<cfqueryparam value="#componentIdsList#" list="true" cfsqltype="integer">
			)
			AND product_item_id IN (
				<cfqueryparam value="#productItemIdsList#" list="true" cfsqltype="integer">
			)
		</cfquery>

		<cfreturn local.q>
	</cffunction>
</cfcomponent>
