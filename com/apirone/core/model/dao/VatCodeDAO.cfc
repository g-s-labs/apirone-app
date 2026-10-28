<cfcomponent extends="com.apirone.core.model.dao.VerticaleDAO" accessors="true">
	
	<cffunction name="read">

		<cfargument name="vatCodeId" type="String" required="true">

		<cfif !request.loadFromVerticale>
			<cfreturn super.getMockedVatCode( arguments.vatCodeId )>
		</cfif>		

		<cfquery name="local.q" datasource="apirone">
			SELECT
				*
			FROM
				verticale_vat_codes
			WHERE
				ivacod = <cfqueryparam cfsqltype="varchar" value="#arguments.vatCodeId#">
		</cfquery>

		<cfreturn local.q>

	</cffunction>

	<cffunction name="find">

		<cfargument name="limit" required="true" type="Numeric" default="0">
        <cfargument name="offset" required="true" type="Numeric" default="0">
		<!--- solo i codici attivi ( selezionabili ), più includeId se non vuoto ( il codice del preventivo aperto ) --->
		<cfargument name="activeOnly" type="Boolean" default="false">
		<cfargument name="includeId" type="String" default="">

		<cfif !request.loadFromVerticale>
			<cfreturn super.listMockedVatCode()>
		</cfif>				

		<cfquery name="local.q" datasource="apirone">
			SELECT
				ivacod,
				COUNT(ivacod) OVER() AS total
			FROM
				verticale_vat_codes
			WHERE 1=1
			<cfif arguments.activeOnly>
				AND (
					active
					<cfif Len( arguments.includeId )>
						OR ivacod = <cfqueryparam cfsqltype="varchar" value="#arguments.includeId#">
					</cfif>
				)
			</cfif>
			<cfif arguments.limit GTE 0>
				LIMIT 
					<cfqueryparam cfsqltype="integer" value="#arguments.limit#">
				OFFSET
					<cfqueryparam cfsqltype="integer" value="#arguments.offset#">
			</cfif>
		</cfquery>

		<cfreturn local.q>

	</cffunction>

</cfcomponent>