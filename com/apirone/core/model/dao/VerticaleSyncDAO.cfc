<cfcomponent extends="com.apirone.core.model.dao.AbsDAO" accessors="true">

	<!---
		Lock/stato sincronizzazione: riga singola (id = 1) in verticale_sync_status.
		tryAcquireLock() è l'UPDATE atomico che impedisce a due lanci concorrenti di partire insieme.
	--->

	<cffunction name="tryAcquireLock" access="public" returntype="Boolean">
		<!--- userId vuoto = lancio non riconducibile a un utente (es. schedulazione automatica): started_by_user_id resta NULL. --->
		<cfargument name="userId" type="String" required="false" default="">

		<cfquery name="local.q" datasource="apirone" result="local.result">
			UPDATE verticale_sync_status
			SET
				running = true,
				started_at = (now() AT TIME ZONE 'UTC'),
				started_by_user_id = <cfqueryparam cfsqltype="varchar" value="#arguments.userId#" null="#!Len( arguments.userId )#">::uuid,
				last_error = NULL
			WHERE
				id = 1
				AND running = false
		</cfquery>

		<cfreturn local.result.recordCount GT 0>
	</cffunction>

	<cffunction name="releaseLock" access="public" returntype="void">
		<cfargument name="succeeded" type="Boolean" required="true">
		<cfargument name="errorMessage" type="String" required="false" default="">

		<cfif arguments.succeeded>
			<cfquery datasource="apirone">
				UPDATE verticale_sync_status
				SET
					running = false,
					finished_at = (now() AT TIME ZONE 'UTC'),
					last_error = NULL
				WHERE
					id = 1
			</cfquery>
		<cfelse>
			<cfquery datasource="apirone">
				UPDATE verticale_sync_status
				SET
					running = false,
					last_error = <cfqueryparam cfsqltype="varchar" value="#Left( arguments.errorMessage, 4000 )#">
				WHERE
					id = 1
			</cfquery>
		</cfif>
	</cffunction>

	<cffunction name="getStatus" access="public" returntype="Query">
		<cfquery name="local.q" datasource="apirone">
			SELECT running, finished_at
			FROM verticale_sync_status
			WHERE id = 1
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Un metodo syncX() per dominio: legge dal vivo da Verticale e sostituisce
		per intero la tabella locale corrispondente. Ogni metodo è pensato per essere
		chiamato dentro un proprio try/catch dal chiamante (VerticaleSyncService),
		così un dominio che fallisce non blocca gli altri.
	--->

	<cffunction name="syncPriceList" access="public" returntype="void">
		<!---
			LTRIM/RTRIM sui codici: le colonne sorgente lato Verticale (SQL Server) sono
			a larghezza fissa (CHAR) e arrivano riempite di spazi finali. Senza il trim, i
			confronti esatti con i codici già puliti salvati lato Apirone (es. components.
			raw_product_id) falliscono silenziosamente - il prezzo/materiale/colore/variante
			risulta "non trovato" anche se in realtà è presente nello specchio locale.
			Confermato: leggendo dal vivo da Verticale il confronto invece risolve
			(SQL Server tratta gli spazi finali come insignificanti nel confronto CHAR),
			motivo per cui il problema si vedeva solo dopo la copia in Postgres.
		--->
		<cfquery name="local.q" datasource="verticale">
			SELECT
				LTRIM(RTRIM(lisart)) AS lisart,
				LTRIM(RTRIM(liscvr)) AS liscvr,
				LTRIM(RTRIM(liscol)) AS liscol,
				lispre
			FROM azapi_listin
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_price_list",
			columns = [
				{ name = "lisart", cfsqltype = "varchar" },
				{ name = "liscvr", cfsqltype = "varchar" },
				{ name = "liscol", cfsqltype = "varchar" },
				{ name = "lispre", cfsqltype = "decimal" }
			],
			sourceQuery = local.q
		)>
	</cffunction>

	<cffunction name="syncRawProducts" access="public" returntype="void">
		<cfquery name="local.q" datasource="verticale">
			SELECT
				LTRIM(RTRIM(arcodart))  AS arcodart,
				LTRIM(RTRIM(ardesart))  AS ardesart,
				LTRIM(RTRIM(artipmat))  AS artipmat,
				LTRIM(RTRIM(arsemlav))  AS arsemlav,
				LTRIM(RTRIM(arunmis1))  AS arunmis1,
				LTRIM(RTRIM(artipcol))  AS artipcol,
				LTRIM(RTRIM(arobsole))  AS arobsole
			FROM azapi_artico
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_raw_products",
			columns = [
				{ name = "arcodart", cfsqltype = "varchar" },
				{ name = "ardesart", cfsqltype = "varchar" },
				{ name = "artipmat", cfsqltype = "varchar" },
				{ name = "arsemlav", cfsqltype = "varchar" },
				{ name = "arunmis1", cfsqltype = "varchar" },
				{ name = "artipcol", cfsqltype = "varchar" },
				{ name = "arobsole", cfsqltype = "varchar" }
			],
			sourceQuery = local.q
		)>
	</cffunction>

	<cffunction name="syncRawProductTypes" access="public" returntype="void">
		<cfquery name="local.q" datasource="verticale">
			SELECT LTRIM(RTRIM(codtip)) AS codtip, LTRIM(RTRIM(destip)) AS destip
			FROM azapi_codtip
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_raw_product_types",
			columns = [
				{ name = "codtip", cfsqltype = "varchar" },
				{ name = "destip", cfsqltype = "varchar" }
			],
			sourceQuery = local.q
		)>
	</cffunction>

	<cffunction name="syncVariants" access="public" returntype="void">
		<cfquery name="local.variants" datasource="verticale">
			SELECT LTRIM(RTRIM(varcod)) AS varcod, LTRIM(RTRIM(vardes)) AS vardes
			FROM azapi_codvar
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_variants",
			columns = [
				{ name = "varcod", cfsqltype = "varchar" },
				{ name = "vardes", cfsqltype = "varchar" }
			],
			sourceQuery = local.variants
		)>

		<cfquery name="local.variantProducts" datasource="verticale">
			SELECT LTRIM(RTRIM(cbcodart)) AS cbcodart, LTRIM(RTRIM(cbcodvar)) AS cbcodvar
			FROM azapi_comvar
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_variant_products",
			columns = [
				{ name = "cbcodart", cfsqltype = "varchar" },
				{ name = "cbcodvar", cfsqltype = "varchar" }
			],
			sourceQuery = local.variantProducts
		)>
	</cffunction>

	<cffunction name="syncColors" access="public" returntype="void">
		<cfquery name="local.colors" datasource="verticale">
			SELECT LTRIM(RTRIM(clcodice)) AS clcodice, LTRIM(RTRIM(cldescri)) AS cldescri
			FROM azapi_colori
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_colors",
			columns = [
				{ name = "clcodice", cfsqltype = "varchar" },
				{ name = "cldescri", cfsqltype = "varchar" }
			],
			sourceQuery = local.colors
		)>

		<cfquery name="local.colorProducts" datasource="verticale">
			SELECT LTRIM(RTRIM(clcodart)) AS clcodart, LTRIM(RTRIM(clcodcol)) AS clcodcol
			FROM azapi_comcol
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_color_products",
			columns = [
				{ name = "clcodart", cfsqltype = "varchar" },
				{ name = "clcodcol", cfsqltype = "varchar" }
			],
			sourceQuery = local.colorProducts
		)>

		<cfquery name="local.colorVariantProducts" datasource="verticale">
			SELECT LTRIM(RTRIM(clcodart)) AS clcodart, LTRIM(RTRIM(clcodvar)) AS clcodvar, LTRIM(RTRIM(clcodcol)) AS clcodcol
			FROM azapi_cvrcom
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_color_variant_products",
			columns = [
				{ name = "clcodart", cfsqltype = "varchar" },
				{ name = "clcodvar", cfsqltype = "varchar" },
				{ name = "clcodcol", cfsqltype = "varchar" }
			],
			sourceQuery = local.colorVariantProducts
		)>
	</cffunction>

	<cffunction name="syncCurrencies" access="public" returntype="void">
		<cfquery name="local.q" datasource="verticale">
			SELECT
				LTRIM(RTRIM(valcod)) AS valcod,
				LTRIM(RTRIM(valdes)) AS valdes,
				LTRIM(RTRIM(valsim)) AS valsim
			FROM codval
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_currencies",
			columns = [
				{ name = "valcod", cfsqltype = "varchar" },
				{ name = "valdes", cfsqltype = "varchar" },
				{ name = "valsim", cfsqltype = "varchar" }
			],
			sourceQuery = local.q
		)>
	</cffunction>

	<cffunction name="syncVatCodes" access="public" returntype="void">
		<cfquery name="local.q" datasource="verticale">
			SELECT LTRIM(RTRIM(ivacod)) AS ivacod, LTRIM(RTRIM(ivades)) AS ivades, ivaper
			FROM codiva
		</cfquery>

		<!---
			Non si svuota la tabella come per le altre copie di Verticale: la colonna active ( codici selezionabili
			nel preventivo, 2026-10-27_gui_vat_codes_active.sql ) è solo nostra e va conservata. Si tolgono i codici
			eliminati in Verticale, si aggiornano descrizione e percentuale, i codici nuovi arrivano non attivi.
		--->
		<cftransaction>
			<cfquery datasource="apirone">
				DELETE FROM verticale_vat_codes
				<cfif local.q.recordCount>
					WHERE ivacod NOT IN ( <cfqueryparam value="#ValueList( local.q.ivacod )#" list="true" cfsqltype="varchar"> )
				</cfif>
			</cfquery>

			<cfloop query="local.q">
				<cfquery datasource="apirone">
					INSERT INTO verticale_vat_codes ( ivacod, ivades, ivaper )
					VALUES (
						<cfqueryparam value="#local.q.ivacod#" cfsqltype="varchar">,
						<cfqueryparam value="#local.q.ivades#" cfsqltype="varchar">,
						<cfqueryparam value="#local.q.ivaper#" cfsqltype="decimal" null="#!Len( Trim( local.q.ivaper ) )#">
					)
					ON CONFLICT ( ivacod ) DO UPDATE SET ivades = EXCLUDED.ivades, ivaper = EXCLUDED.ivaper
				</cfquery>
			</cfloop>
		</cftransaction>
	</cffunction>

	<cffunction name="syncPaymentMethods" access="public" returntype="void">
		<cfquery name="local.q" datasource="verticale">
			SELECT LTRIM(RTRIM(pagcod)) AS pagcod, LTRIM(RTRIM(pagdes)) AS pagdes
			FROM codpag
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_payment_methods",
			columns = [
				{ name = "pagcod", cfsqltype = "varchar" },
				{ name = "pagdes", cfsqltype = "varchar" }
			],
			sourceQuery = local.q
		)>
	</cffunction>

	<cffunction name="syncCountries" access="public" returntype="void">
		<cfquery name="local.q" datasource="verticale">
			SELECT LTRIM(RTRIM(ISONAZ)) AS isonaz, LTRIM(RTRIM(CODNAZ)) AS codnaz, LTRIM(RTRIM(DESNAZ)) AS desnaz
			FROM codnaz
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_countries",
			columns = [
				{ name = "isonaz", cfsqltype = "varchar" },
				{ name = "codnaz", cfsqltype = "varchar" },
				{ name = "desnaz", cfsqltype = "varchar" }
			],
			sourceQuery = local.q
		)>
	</cffunction>

	<!---
		Fatture soggette a reclamo: fatture ( MMCODDOC = 'FI' ) con partita aperta
		( importo dare > 0, non saldata, non sospesa ). Query fornita da Verticale;
		cast/trim perché le colonne sono a larghezza fissa e l'alfa può essere NULL.
	--->
	<cffunction name="syncClaimInvoices" access="public" returntype="void">
		<cfquery name="local.q" datasource="verticale">
			SELECT
				LTRIM(RTRIM(CAST(DATDOC.MMANNREG AS VARCHAR(4)))) AS anno,
				CAST(DATDOC.MMNUMDOC AS INT) AS numero,
				LTRIM(RTRIM(ISNULL(DATDOC.MMALFDOC, ''))) AS alfa
			FROM
				AZAPI_DATDOC DATDOC,
				AZAPI_PARTIT PARTIT
			WHERE
				DATDOC.MMSERIAL = PARTIT.SCSERDOC
				AND DATDOC.MMCODDOC = 'FI'
				AND PARTIT.SCIMPDAR > 0
				AND PARTIT.SCSALDAT <> 'S'
				AND PARTIT.SCSOSPES <> 'S'
			GROUP BY
				LTRIM(RTRIM(CAST(DATDOC.MMANNREG AS VARCHAR(4)))),
				CAST(DATDOC.MMNUMDOC AS INT),
				LTRIM(RTRIM(ISNULL(DATDOC.MMALFDOC, '')))
		</cfquery>

		<cfset replaceLocalTable(
			tableName = "verticale_claim_invoices",
			columns = [
				{ name = "anno", cfsqltype = "varchar" },
				{ name = "numero", cfsqltype = "integer" },
				{ name = "alfa", cfsqltype = "varchar" }
			],
			sourceQuery = local.q
		)>
	</cffunction>

	<cffunction name="listClaimInvoices" access="public" returntype="Array">
		<cfquery name="local.q" datasource="apirone" returntype="array">
			SELECT anno, numero, alfa
			FROM verticale_claim_invoices
			ORDER BY anno DESC, numero DESC, alfa
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		private methods
	--->

	<!---
		Svuota e ripopola una tabella locale (datasource apirone) a partire da una Query
		già letta da Verticale, dentro un'unica transazione (nessuna finestra con la
		tabella vuota se non in caso di errore, che fa comunque rollback del DELETE).
		Insert a blocchi da 500 righe per non generare un singolo statement enorme.
	--->
	<cffunction name="replaceLocalTable" access="private" returntype="void">
		<cfargument name="tableName" type="String" required="true">
		<cfargument name="columns" type="Array" required="true">
		<cfargument name="sourceQuery" type="Query" required="true">

		<cfset var safeTableName = sanitizeSQL( arguments.tableName )>
		<cfset var columnNames = []>
		<cfloop array="#arguments.columns#" index="col">
			<cfset ArrayAppend( columnNames, sanitizeSQL( col.name ) )>
		</cfloop>

		<cfset var batchSize = 500>
		<cfset var totalRows = arguments.sourceQuery.recordCount>

		<cftransaction>

			<cfquery datasource="apirone">
				DELETE FROM #safeTableName#
			</cfquery>

			<cfset var start = 1>
			<cfloop condition="start LTE totalRows">
				<cfset var thisEnd = Min( start + batchSize - 1, totalRows )>

				<cfquery datasource="apirone">
					INSERT INTO #safeTableName# ( #ArrayToList( columnNames )# )
					VALUES
					<cfloop from="#start#" to="#thisEnd#" index="rowIndex">
						<cfif rowIndex GT start>,</cfif>
						(
							<cfloop from="1" to="#ArrayLen( arguments.columns )#" index="colIndex">
								<cfif colIndex GT 1>,</cfif>
								<cfset var colDef = arguments.columns[ colIndex ]>
								<cfset var cellValue = arguments.sourceQuery[ colDef.name ][ rowIndex ]>
								<cfqueryparam
									value="#cellValue#"
									cfsqltype="#colDef.cfsqltype#"
									null="#( colDef.cfsqltype IS "decimal" AND !Len( Trim( cellValue ) ) )#">
							</cfloop>
						)
					</cfloop>
				</cfquery>

				<cfset start = thisEnd + 1>
			</cfloop>

		</cftransaction>
	</cffunction>

</cfcomponent>
