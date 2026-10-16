<cfcomponent extends="com.apirone.core.model.dao.AbsDAO" accessors="true">
	<cffunction name="read" returntype="Query">
		<cfargument name="quotationItemId" type="String" required="true">
		<cfquery name="local.q" datasource="apirone">
			SELECT
				quotation_items.quotation_item_id::varchar,
				quotation_items.quotation_id::varchar,
				quotation_items.quotation_zone_id::varchar,
				quotation_items.*,
				product_categories.product_category_type_id
			FROM
				quotation_items
				LEFT JOIN products ON products.product_id = quotation_items.product_id
				LEFT JOIN catalog_bundles ON catalog_bundles.catalog_bundle_id = products.catalog_bundle_id
				LEFT JOIN product_categories ON product_categories.product_category_id = catalog_bundles.product_category_id
			WHERE
				quotation_items.quotation_item_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItemId#">::uuid
		</cfquery>
		<cfreturn local.q>
	</cffunction>

	<cffunction name="find" returntype="Query">
		<cfargument name="quotationId" type="String" required="false">
		<cfargument name="quotationZoneId" type="String" required="false">
		<cfargument name="quotationZoneOriginId" type="String" required="false">
		<cfargument name="typeId" type="String" required="false">
		<cfargument name="orderBy" type="String" required="true" default="quotation_items.ordinamento, quotation_items.quotation_item_id">
		<cfargument name="limit" type="Numeric" required="true" default="15">
		<cfargument name="offset" type="Numeric" required="true" default="0">

		<cfquery name="local.q" datasource="apirone" result="result">
			SELECT
				quotation_item_id::varchar,
				quotation_items.quotation_id::varchar,
				quotation_zone_positions.quotation_zone_id::varchar,
				COUNT(quotation_item_id) OVER() AS total
			FROM quotation_items
					LEFT JOIN quotation_zone_positions ON quotation_items.quotation_zone_position_id = quotation_zone_positions.quotation_zone_position_id

				<cfif !IsNull( arguments.typeId )>
					<cfif arguments.typeId EQ "ART">
						INNER JOIN articles ON quotation_items.article_id = articles.article_id
					<cfelse>
						INNER JOIN products ON quotation_items.product_id = products.product_id
						INNER JOIN catalog_bundles ON catalog_bundles.catalog_bundle_id = products.catalog_bundle_id
						INNER JOIN product_categories ON catalog_bundles.product_category_id = product_categories.product_category_id
					</cfif>
				</cfif>
			WHERE 1=1

				<cfif !IsNull( arguments.quotationId )>
					AND quotation_items.quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid
				</cfif>

				<cfif !IsNull( arguments.quotationZoneId )>
					AND quotation_items.quotation_zone_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationZoneId#">::uuid
				</cfif>

				<cfif !IsNull( arguments.typeId )>
					<cfif arguments.typeId EQ "ART">
						AND quotation_items.article_id IS NOT NULL
					<cfelse>
						AND product_categories.product_category_type_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.typeId#">
					</cfif>
				</cfif>
			<!---
				a parità di ordine ( ordinamento 0: righe mai riordinate trascinandole )
				la posizione in ordine naturale ( A1, A2, A10; collation natural_sort ),
				senza posizione in fondo, poi l'ordine di inserimento
			--->
			ORDER BY
				<cfif Len( Trim( super.sanitizeSQL( arguments.orderBy ) ) )>#super.sanitizeSQL( arguments.orderBy )#,</cfif>
				quotation_zone_positions.code COLLATE natural_sort NULLS LAST,
				quotation_items.created_at,
				quotation_items.quotation_item_id

				<cfif arguments.limit GT 0>
					LIMIT <cfqueryparam value="#arguments.limit#" cfsqltype="integer">
					OFFSET <cfqueryparam value="#arguments.offset#" cfsqltype="integer">
				</cfif>
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<cffunction name="getMaxOrdinamento" returntype="Numeric">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="typeId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT COALESCE(MAX(quotation_items.ordinamento), 0) AS max_ord
			FROM quotation_items
			<cfif arguments.typeId EQ "ART">
				WHERE quotation_items.quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid
				  AND quotation_items.article_id IS NOT NULL
			<cfelse>
				INNER JOIN products ON quotation_items.product_id = products.product_id
				INNER JOIN catalog_bundles ON catalog_bundles.catalog_bundle_id = products.catalog_bundle_id
				INNER JOIN product_categories ON catalog_bundles.product_category_id = product_categories.product_category_id
				WHERE quotation_items.quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid
				  AND product_categories.product_category_type_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.typeId#">
			</cfif>
		</cfquery>
		<cfreturn Val(local.q.max_ord)>
	</cffunction>

	<cffunction name="insert" returntype="String">
		<cfargument name="quotationItem" type="com.apirone.core.model.bean.QuotationItem" required="true">

		<cfquery name="local.q" datasource="apirone">
			INSERT INTO quotation_items (
				special,
				custom_image,
				bozza,
				status_id,
				quotation_id,
				quotation_zone_id,
				product_id,
				article_id,
				note,
				quantity,
				quotation_zone_position_id,
				"hash",
				ordinamento,
				instance_group_id
				<cfif IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" )>
					,
					orientation_id,
					block_orientations
				</cfif>
				<cfif IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemSignage" )>
					,
					signage_config_item_id,
					char_count,
					height,
					height_in_pixel,
					row_count
				</cfif>
			) VALUES (
				<cfqueryparam cfsqltype="Boolean" value="#arguments.quotationItem.getSpecial()#">,
				<cfqueryparam cfsqltype="Boolean" value="#arguments.quotationItem.getCustomImage()#">,
				<cfqueryparam cfsqltype="Boolean" value="#arguments.quotationItem.getBozza()#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getStatus().getId()#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getQuotation().getId()#">::uuid,
				<cfif NOT IsNull( arguments.quotationItem.getQuotationZone() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getQuotationZone().getId()#">::uuid,
				<cfelse>
					NULL,
				</cfif>
				<cfif NOT IsNull( arguments.quotationItem.getProduct() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getProduct().getId()#">::uuid,
				<cfelse>
					NULL,
				</cfif>
				<cfif NOT IsNull( arguments.quotationItem.getArticle() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getArticle().getId()#">::uuid,
				<cfelse>
					NULL,
				</cfif>
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getNote()#">,
				<cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getQuantity()#">,
				<cfif NOT IsNull( arguments.quotationItem.getPosition() )>
					<cfqueryparam cfsqltype="Integer" value="#arguments.quotationItem.getPosition().getId()#">
				<cfelse>
					NULL
				</cfif>,
				<cfif NOT IsNull( arguments.quotationItem.getHash() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getHash()#">
				<cfelse>
					NULL
				</cfif>,
				<cfqueryparam cfsqltype="Integer" value="#arguments.quotationItem.getOrdinamento()#">,
				<cfif !IsNull( arguments.quotationItem.getInstanceGroupId() ) && Len( arguments.quotationItem.getInstanceGroupId() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getInstanceGroupId()#">::uuid
				<cfelse>
					NULL
				</cfif>
				<cfif IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" )>
					,
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getFrame().getOrientation().getId()#">,
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getBlockOrientations() ?: ''#" null="#IsNull( arguments.quotationItem.getBlockOrientations() ) || !Len( arguments.quotationItem.getBlockOrientations() )#">
				</cfif>

				<cfif IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemSignage" )>
					,
					<cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getSignageConfigItem().getId()#">,
					<cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getSignageConfigItem().getCharCount()#">,
					<cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getSignageConfigItem().getHeight()#">,
					<cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getSignageConfigItem().getHeightInPixel()#">,
					<cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getSignageConfigItem().getRowCount()#">
				</cfif>
			)
			RETURNING quotation_item_id
		</cfquery>
		<cfreturn local.q.quotation_item_id.toString()>
	</cffunction>

	<cffunction name="update" returntype="String">
		<cfargument name="quotationItem" type="com.apirone.core.model.bean.QuotationItem" required="true">
		<cfquery name="local.q" datasource="apirone">
			UPDATE quotation_items
			SET
				quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getQuotation().getId()#">::uuid,
				special = <cfqueryparam cfsqltype="Boolean" value="#arguments.quotationItem.getSpecial()#">,
				custom_image = <cfqueryparam cfsqltype="Boolean" value="#arguments.quotationItem.getCustomImage()#">,
				bozza = <cfqueryparam cfsqltype="Boolean" value="#arguments.quotationItem.getBozza()#">,
				status_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getStatus().getId()#">,
				<!--- Un articolo ha sempre una zona (almeno "Non assegnato"): un bean arrivato
					  senza zona non deve azzerarla, si mantiene quella già salvata. --->
				quotation_zone_id =
					<cfif NOT IsNull( arguments.quotationItem.getQuotationZone() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getQuotationZone().getId()#">::uuid
					<cfelse>
						quotation_zone_id
					</cfif>,
				quotation_zone_position_id =
					<cfif NOT IsNull( arguments.quotationItem.getPosition() )>
						<cfqueryparam cfsqltype="Integer" value="#arguments.quotationItem.getPosition().getId()#">
					<cfelse>
						NULL
					</cfif>,
				product_id =
					<cfif NOT IsNull( arguments.quotationItem.getProduct() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getProduct().getId()#">::uuid
					<cfelse>
						NULL
					</cfif>,
				article_id =
					<cfif NOT IsNull( arguments.quotationItem.getArticle() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getArticle().getId()#">::uuid
					<cfelse>
						NULL
					</cfif>,
				note = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getNote()#">,
				<!---- price = <cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getPrice()#">, ---->
				quantity = <cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getQuantity()#">,
				"hash" =
					<cfif NOT IsNull( arguments.quotationItem.getHash() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getHash()#">
					<cfelse>
						NULL
					</cfif>,
				instance_group_id =
					<cfif !IsNull( arguments.quotationItem.getInstanceGroupId() ) && Len( arguments.quotationItem.getInstanceGroupId() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getInstanceGroupId()#">::uuid
					<cfelse>
						NULL
					</cfif>
				<cfif IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemPlate" )>
					,
					orientation_id         = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getFrame().getOrientation().getId()#">,
					block_orientations     = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getBlockOrientations() ?: ''#" null="#IsNull( arguments.quotationItem.getBlockOrientations() ) || !Len( arguments.quotationItem.getBlockOrientations() )#">
				</cfif>
				<cfif IsInstanceOf( arguments.quotationItem, "com.apirone.core.model.bean.QuotationItemSignage" )>
					,
					char_count             = <cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getSignageConfigItem().getCharCount()#">,
					height                 = <cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getSignageConfigItem().getHeight()#">,
					height_in_pixel        = <cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getSignageConfigItem().getHeightInPixel()#">,
					row_count              = <cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getSignageConfigItem().getRowCount()#">,
					signage_config_item_id = <cfqueryparam cfsqltype="Numeric" value="#arguments.quotationItem.getSignageConfigItem().getId()#">
				</cfif>
			WHERE
				quotation_item_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItem.getId()#">::uuid
		</cfquery>
		<cfreturn arguments.quotationItem.getId()>
	</cffunction>

	<!---
		Elenco già ordinato ( ordinamento > 0 ): ordinamento a cui va una riga nuova
		con posizione code, cioè quello della prima riga ( nell'ordine dell'elenco )
		con posizione successiva in ordine naturale ( collation natural_sort ). Le
		righe senza posizione non contano. 0: nessuna, la riga va in fondo.
	--->
	<cffunction name="findInsertOrdinamento" returntype="Numeric">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="typeId" type="String" required="true">
		<cfargument name="code" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT COALESCE( MIN( quotation_items.ordinamento ), 0 ) AS ord
			FROM quotation_items
			INNER JOIN quotation_zone_positions ON quotation_zone_positions.quotation_zone_position_id = quotation_items.quotation_zone_position_id
			WHERE quotation_items.quotation_item_id IN ( #listItemsSql( arguments.quotationId, arguments.typeId )# )
				AND quotation_items.ordinamento > 0
				AND quotation_zone_positions.code COLLATE natural_sort > <cfqueryparam cfsqltype="Varchar" value="#arguments.code#">
		</cfquery>
		<cfreturn Val( local.q.ord )>
	</cffunction>

	<!--- Fa posto a una riga nuova: le righe dell'elenco da fromOrdinamento in poi scalano di 10 --->
	<cffunction name="shiftOrdinamento" returntype="void">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="typeId" type="String" required="true">
		<cfargument name="fromOrdinamento" type="Numeric" required="true">

		<cfquery datasource="apirone">
			UPDATE quotation_items
			SET ordinamento = ordinamento + 10
			WHERE quotation_item_id IN ( #listItemsSql( arguments.quotationId, arguments.typeId )# )
				AND ordinamento >= <cfqueryparam cfsqltype="Integer" value="#arguments.fromOrdinamento#">
		</cfquery>
	</cffunction>

	<!---
		Righe di un elenco del preventivo ( tipo ART / PLA / SEG / ACC, come
		getMaxOrdinamento ): sottoquery con gli id. Valori validati, niente input libero.
	--->
	<cffunction name="listItemsSql" returntype="String" access="private">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="typeId" type="String" required="true">

		<cfif !IsValid( "guid", arguments.quotationId ) AND !REFind( "^[0-9a-fA-F-]{36}$", arguments.quotationId )>
			<cfthrow message="quotationId non valido: #arguments.quotationId#">
		</cfif>
		<cfif !REFind( "^[A-Z]{3}$", arguments.typeId )>
			<cfthrow message="typeId non valido: #arguments.typeId#">
		</cfif>

		<cfif arguments.typeId EQ "ART">
			<cfreturn "SELECT qi.quotation_item_id FROM quotation_items qi WHERE qi.quotation_id = '#arguments.quotationId#'::uuid AND qi.article_id IS NOT NULL">
		</cfif>
		<cfreturn "SELECT qi.quotation_item_id FROM quotation_items qi
			INNER JOIN products p ON qi.product_id = p.product_id
			INNER JOIN catalog_bundles cb ON cb.catalog_bundle_id = p.catalog_bundle_id
			INNER JOIN product_categories pc ON cb.product_category_id = pc.product_category_id
			WHERE qi.quotation_id = '#arguments.quotationId#'::uuid AND pc.product_category_type_id = '#arguments.typeId#'">
	</cffunction>

	<cffunction name="updateOrdinamento" returntype="void">
		<cfargument name="quotationItemId" type="String" required="true">
		<cfargument name="ordinamento" type="Numeric" required="true">
		<cfquery datasource="apirone">
			UPDATE quotation_items
			SET ordinamento = <cfqueryparam cfsqltype="Integer" value="#arguments.ordinamento#">
			WHERE quotation_item_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItemId#">::uuid
		</cfquery>
	</cffunction>

	<cffunction name="updateHash" returntype="Boolean">
		<cfargument name="quotationItemId" type="String" required="true">
		<cfargument name="hash" type="String" required="true">
		<cfquery name="local.q" datasource="apirone">
			UPDATE quotation_items
			SET
				"hash" = <cfqueryparam cfsqltype="Varchar" value="#arguments.hash#">
			WHERE
				quotation_item_id = <cfqueryparam cfsqltype="Other" value="#arguments.quotationItemId#">::uuid
		</cfquery>
		<cfreturn true>
	</cffunction>

	<cffunction name="delete" returntype="Boolean">
		<cfargument name="quotationItemId" type="String" required="true">
		<cfquery name="local.q" datasource="apirone">
			DELETE
			FROM quotation_items
			WHERE
				quotation_item_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItemId#">::uuid
		</cfquery>
		<cfreturn true>
	</cffunction>

	<!---
		Righe di una zona con i soli dati che servono a cancellarle in blocco
		( QuotationItemService.deleteByZone ): tipo di riga e chiavi dei gruppi di
		ricalcolo prezzi. Linea e modello dal catalog_bundle ( fonte di verità ).
		is_plate segue la stessa regola del build: ha frutti o categoria placca.
	--->
	<cffunction name="listForZoneDeletion" returntype="Query">
		<cfargument name="quotationZoneId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				qi.quotation_item_id::varchar,
				qi.quotation_id::varchar,
				qi.article_id::varchar,
				qi.product_id::varchar,
				cb.line_id::varchar,
				p.finish_id::varchar,
				cb.model_id::varchar,
				(
					EXISTS ( SELECT 1 FROM quotation_item_fruits f WHERE f.quotation_item_id = qi.quotation_item_id )
					OR pc.product_category_type_id = 'PLA'
				) AS is_plate,
				( qi.signage_config_item_id IS NOT NULL ) AS is_signage
			FROM quotation_items qi
				LEFT JOIN products p ON p.product_id = qi.product_id
				LEFT JOIN catalog_bundles cb ON cb.catalog_bundle_id = p.catalog_bundle_id
				LEFT JOIN product_categories pc ON pc.product_category_id = cb.product_category_id
			WHERE qi.quotation_zone_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationZoneId#">::uuid
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!--- Cancella tutte le righe di una zona: i figli ( prezzi, frutti, attributi, posizioni, file ) vanno in cascata --->
	<cffunction name="deleteByZone" returntype="Numeric">
		<cfargument name="quotationZoneId" type="String" required="true">

		<cfquery datasource="apirone" result="local.r">
			DELETE FROM quotation_items
			WHERE quotation_zone_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationZoneId#">::uuid
		</cfquery>

		<cfreturn local.r.recordCount>
	</cffunction>

	<cffunction name="getQuantitaTotaleAltreRigheByQuotationLineIdAndFinishId" returntype="Numeric">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="quotationItemId" type="String" required="true">
		<cfargument name="lineId" type="String" required="true">
		<cfargument name="finishId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone" result="result">
			SELECT
				SUM(
					COALESCE(quotation_items.quantity, 0) * COALESCE(qz.quantity, 1) * COALESCE(qzo.quantity, 1)
				) AS total_quantity
			FROM quotation_items
				JOIN products ON quotation_items.product_id = products.product_id
				JOIN catalog_bundles cb ON cb.catalog_bundle_id = products.catalog_bundle_id
				LEFT JOIN quotation_zones qz ON qz.quotation_zone_id = quotation_items.quotation_zone_id
				LEFT JOIN quotation_zones qzo ON qzo.quotation_zone_id = qz.origin_id
			WHERE
				cb.line_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.lineId#">::uuid AND
				products.finish_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.finishId#">::uuid AND
				quotation_items.quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid

				<cfif arguments.quotationItemId != "" >
					AND quotation_items.quotation_item_id <> <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItemId#">::uuid
				</cfif>

		</cfquery>
		<cfreturn local.q.total_quantity ?: 0>
	</cffunction>

	<!---
		Come getQuantitaTotaleAltreRigheByQuotationLineIdAndFinishId, ma per il costo fisso
		linea/modello: righe con stessa linea+modello (qualsiasi finitura).
		Linea e modello si leggono da catalog_bundles: products.line_id/model_id sono
		colonne legacy, NULL per i prodotti creati dopo l'introduzione dei bundle.
	--->
	<cffunction name="getQuantitaTotaleAltreRigheByQuotationLineIdAndModelId" returntype="Numeric">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="quotationItemId" type="String" required="true">
		<cfargument name="lineId" type="String" required="true">
		<cfargument name="modelId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				SUM(
					COALESCE(quotation_items.quantity, 0) * COALESCE(qz.quantity, 1) * COALESCE(qzo.quantity, 1)
				) AS total_quantity
			FROM quotation_items
				JOIN products ON quotation_items.product_id = products.product_id
				JOIN catalog_bundles cb ON cb.catalog_bundle_id = products.catalog_bundle_id
				LEFT JOIN quotation_zones qz ON qz.quotation_zone_id = quotation_items.quotation_zone_id
				LEFT JOIN quotation_zones qzo ON qzo.quotation_zone_id = qz.origin_id
			WHERE
				cb.line_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.lineId#">::uuid AND
				cb.model_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.modelId#">::uuid AND
				quotation_items.quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid

				<cfif arguments.quotationItemId != "" >
					AND quotation_items.quotation_item_id <> <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItemId#">::uuid
				</cfif>
		</cfquery>
		<cfreturn local.q.total_quantity ?: 0>
	</cffunction>

	<cffunction name="getQuantitaTotaleAltreRigheByQuotationAndProduct" returntype="Numeric">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="quotationItemId" type="String" required="true">
		<cfargument name="productId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone" result="result">
			SELECT
				SUM(
					COALESCE(quotation_items.quantity, 0) * COALESCE(qz.quantity, 1) * COALESCE(qzo.quantity, 1)
				) AS total_quantity
			FROM quotation_items
				LEFT JOIN products ON quotation_items.product_id = products.product_id
				LEFT JOIN quotation_zones qz ON qz.quotation_zone_id = quotation_items.quotation_zone_id
				LEFT JOIN quotation_zones qzo ON qzo.quotation_zone_id = qz.origin_id
			WHERE
				products.product_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.productId#">::uuid AND
				quotation_items.quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid
				<cfif arguments.quotationItemId != "" >
					AND quotation_items.quotation_item_id <> <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItemId#">::uuid
				</cfif>

		</cfquery>
		<cfreturn local.q.total_quantity ?: 0>
	</cffunction>

	<!---
		Calcola in una sola query i totali di quantità ("altre righe") per più item dello
		stesso preventivo: per ogni item restituisce il totale delle righe con la stessa
		linea+finitura, quello delle righe con la stessa linea+modello (linea e modello da
		catalog_bundles) e quello delle righe con lo stesso prodotto, sempre escludendo
		l'item stesso (stessa semantica delle due funzioni singole getQuantitaTotaleAltreRighe).
		Serve all'aggregatore dei prezzi dei gemelli per pre-calcolare i totali in batch:
		due query di gruppo al posto di una SUM per sibling.
	--->
	<cffunction name="getQuantitaTotaliBatchByQuotationItemIds" returntype="Query">
		<cfargument name="quotationItemIds" type="Array" required="true">

		<cfset var idsList = ArrayToList( arguments.quotationItemIds )>

		<cfquery name="local.q" datasource="apirone">
			SELECT
				i.quotation_item_id::varchar AS quotation_item_id,
				(
					SELECT
						SUM(
							COALESCE(o.quantity, 0) * COALESCE(qz.quantity, 1) * COALESCE(qzo.quantity, 1)
						)
					FROM quotation_items o
						JOIN products po ON o.product_id = po.product_id
						JOIN catalog_bundles cbo ON cbo.catalog_bundle_id = po.catalog_bundle_id
						LEFT JOIN quotation_zones qz ON qz.quotation_zone_id = o.quotation_zone_id
						LEFT JOIN quotation_zones qzo ON qzo.quotation_zone_id = qz.origin_id
					WHERE
						o.quotation_id = i.quotation_id AND
						cbo.line_id = cbi.line_id AND
						po.finish_id = pi.finish_id AND
						o.quotation_item_id <> i.quotation_item_id
				) AS total_by_line_finish,
				(
					SELECT
						SUM(
							COALESCE(o3.quantity, 0) * COALESCE(qz3.quantity, 1) * COALESCE(qzo3.quantity, 1)
						)
					FROM quotation_items o3
						JOIN products po3 ON o3.product_id = po3.product_id
						JOIN catalog_bundles cbo3 ON cbo3.catalog_bundle_id = po3.catalog_bundle_id
						LEFT JOIN quotation_zones qz3 ON qz3.quotation_zone_id = o3.quotation_zone_id
						LEFT JOIN quotation_zones qzo3 ON qzo3.quotation_zone_id = qz3.origin_id
					WHERE
						o3.quotation_id = i.quotation_id AND
						cbo3.line_id = cbi.line_id AND
						cbo3.model_id = cbi.model_id AND
						o3.quotation_item_id <> i.quotation_item_id
				) AS total_by_line_model,
				(
					SELECT
						SUM(
							COALESCE(o2.quantity, 0) * COALESCE(qz2.quantity, 1) * COALESCE(qzo2.quantity, 1)
						)
					FROM quotation_items o2
						LEFT JOIN quotation_zones qz2 ON qz2.quotation_zone_id = o2.quotation_zone_id
						LEFT JOIN quotation_zones qzo2 ON qzo2.quotation_zone_id = qz2.origin_id
					WHERE
						o2.quotation_id = i.quotation_id AND
						o2.product_id = i.product_id AND
						o2.quotation_item_id <> i.quotation_item_id
				) AS total_by_product
			FROM quotation_items i
				JOIN products pi ON i.product_id = pi.product_id
				LEFT JOIN catalog_bundles cbi ON cbi.catalog_bundle_id = pi.catalog_bundle_id
			WHERE
				i.quotation_item_id = ANY( ARRAY[<cfqueryparam value="#idsList#" list="true" cfsqltype="varchar">]::uuid[] )
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Righe del preventivo che condividono un costo fisso con l'item: stessa linea e
		(stessa finitura oppure, se passato modelId, stesso modello).
	--->
	<cffunction name="getAltreRigheByQuotationLineIdAndFinishId" returntype="Query">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="quotationItemId" type="String" required="true">
		<cfargument name="lineId" type="String" required="true">
		<cfargument name="finishId" type="String" required="true">
		<cfargument name="modelId" type="String" required="false" default="">

		<cfquery name="local.q" datasource="apirone" result="result">
			SELECT
				quotation_items.*
			FROM quotation_items
			JOIN products ON quotation_items.product_id = products.product_id
			JOIN catalog_bundles cb ON cb.catalog_bundle_id = products.catalog_bundle_id
			WHERE
				cb.line_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.lineId#">::uuid AND
				(
					products.finish_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.finishId#">::uuid
					<cfif Len( arguments.modelId )>
						OR cb.model_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.modelId#">::uuid
					</cfif>
				) AND
				quotation_items.quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid AND
				quotation_items.quotation_item_id <> <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItemId#">::uuid
		</cfquery>
		<cfreturn local.q>
	</cffunction>

	<cffunction name="getAltreRigheByQuotationAndProductId" returntype="Query">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="quotationItemId" type="String" required="true">
		<cfargument name="productId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone" result="result">
			SELECT
				quotation_items.*
			FROM quotation_items
			LEFT JOIN products ON quotation_items.product_id = products.product_id
			WHERE
				products.product_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.productId#">::uuid AND
				quotation_items.quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid AND
				quotation_items.quotation_item_id <> <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItemId#">::uuid
		</cfquery>
		<cfreturn local.q>
	</cffunction>

	<!---
		Recupera in batch più righe di preventivo dato un array di ID.
		Utilizzato dal Service corrispondente per caricare i bean in blocco.
	--->
	<cffunction name="readByIds" returntype="Query" access="public">
		<cfargument name="ids" type="Array" required="true">

		<cfset var idsList = ArrayToList( arguments.ids )>

		<cfquery name="local.q" datasource="apirone">
			SELECT
				quotation_items.quotation_item_id::varchar,
				quotation_items.quotation_id::varchar,
				quotation_items.quotation_zone_id::varchar,
				quotation_items.*,
				product_categories.product_category_type_id
			FROM quotation_items
				LEFT JOIN products ON products.product_id = quotation_items.product_id
				LEFT JOIN catalog_bundles ON catalog_bundles.catalog_bundle_id = products.catalog_bundle_id
				LEFT JOIN product_categories ON product_categories.product_category_id = catalog_bundles.product_category_id
			WHERE quotation_items.quotation_item_id = ANY(
				ARRAY[<cfqueryparam value="#idsList#" list="true" cfsqltype="varchar">]::uuid[]
			)
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<cffunction name="updateInstanceGroupId" returntype="void">
		<cfargument name="quotationItemId" type="String" required="true">
		<cfargument name="instanceGroupId" type="String" required="false">
		<cfquery datasource="apirone">
			UPDATE quotation_items
			SET instance_group_id =
				<cfif !IsNull( arguments.instanceGroupId ) && Len( arguments.instanceGroupId )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.instanceGroupId#">::uuid
				<cfelse>
					NULL
				</cfif>
			WHERE quotation_item_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationItemId#">::uuid
		</cfquery>
	</cffunction>

	<cffunction name="findByInstanceGroupId" returntype="Query">
		<cfargument name="instanceGroupId" type="String" required="true">
		<cfquery name="local.q" datasource="apirone">
			SELECT
				quotation_item_id::varchar,
				quotation_id::varchar,
				quotation_zone_id::varchar,
				*
			FROM quotation_items
			WHERE instance_group_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.instanceGroupId#">::uuid
		</cfquery>
		<cfreturn local.q>
	</cffunction>

	<cffunction name="countByInstanceGroupId" returntype="Numeric">
		<cfargument name="instanceGroupId" type="String" required="true">
		<cfquery name="local.q" datasource="apirone">
			SELECT COUNT(*) AS cnt
			FROM quotation_items
			WHERE instance_group_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.instanceGroupId#">::uuid
		</cfquery>
		<cfreturn Val( local.q.cnt )>
	</cffunction>

</cfcomponent>
