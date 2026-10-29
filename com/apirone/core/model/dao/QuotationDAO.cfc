<cfcomponent extends="com.apirone.core.model.dao.AbsDAO" accessors="true">
	<cffunction name="read" returntype="Query">
		<cfargument name="quotationId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				quotations.quotation_id::varchar,
				<!--- status_id::varchar, ---->
				lang_id::varchar,
				pricelist_id::varchar,
				payment_method_id::varchar,
				currency_id::varchar,
				billing_profile_id::varchar,
				shipping_profile_id::varchar,
				sales_agent_account_id::varchar,
				graphic_technician_account_id::varchar,
				shipping_profile_id::varchar,
				*
			FROM quotations
				INNER JOIN quotation_status_history ON quotations.quotation_status_history_id = quotation_status_history.quotation_status_history_id
			WHERE quotations.quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<cffunction name="find" returntype="Query">
		<cfargument name="statusId" type="String" required="false">
		<cfargument name="langId" type="String" required="false">
		<cfargument name="pricelistId" type="String" required="false">
		<cfargument name="paymentMethodId" type="String" required="false">
		<cfargument name="currencyId" type="String" required="false">
		<cfargument name="billingProfileId" type="String" required="false">
		<cfargument name="shippingProfileId" type="String" required="false">
		<cfargument name="salesAgentId" type="String" required="false">
		<cfargument name="graphicTechnicianId" type="String" required="false">
		<cfargument name="ownerId" type="String" required="false">
		<!--- ruolo Agente: solo i preventivi in cui è uno dei 5 agenti ( id account ) --->
		<cfargument name="agentAccountId" type="String" required="false">
		<cfargument name="str" type="String" required="false">

		<!---
			Ricerca per referente: il nome non è su questa tabella, vive sul CRM
			(vedi Quotation.getReferentName). QuotationService interroga il CRM
			per nome e passa qui gli id trovati, che entrano in OR con la
			ricerca testuale sulle colonne locali.
		--->
		<cfargument name="referentCustomerIds" type="Array" required="false">
		<cfargument name="referentLeadIds" type="Array" required="false">
		<cfargument name="referentOpportunityIds" type="Array" required="false">

		<cfargument name="fromDate" type="String" required="false">
		<cfargument name="toDate" type="String" required="false">
		<cfargument name="active" type="String" required="false">

		<cfargument
			name    ="orderBy"
			type    ="String"
			required="true"
			default ="quotations.quotation_date, quotations.quotation_number"
		>

		<cfargument name="limit" type="Numeric" required="true" default="15">
		<cfargument name="offset" type="Numeric" required="true" default="0">

		<cfquery name="local.q" datasource="apirone" result="result">
			SELECT
				quotations.quotation_id::varchar,
				<!--- status_id::varchar, ---->
				lang_id::varchar,
				pricelist_id::varchar,
				payment_method_id::varchar,
				currency_id::varchar,
				billing_profile_id::varchar,
				shipping_profile_id::varchar,
				sales_agent_account_id::varchar,
				graphic_technician_account_id::varchar,
				shipping_profile_id::varchar,
				COUNT( quotations.quotation_id ) OVER() AS total,
				quotations.nessun_agente,
				quotations.agente1,
				quotations.agente2,
				quotations.agente3,
				quotations.agente4,
				quotations.agente5,
				quotations.commission1,
				quotations.commission2,
				quotations.commission3,
				quotations.commission4,
				quotations.commission5,
				quotations.referente_amministrativo,
				quotations.referente_spedizione
			FROM quotations
				INNER JOIN quotation_status_history ON quotations.quotation_status_history_id = quotation_status_history.quotation_status_history_id
			WHERE 1=1

			<cfif !IsNull( arguments.str )>
				AND (
					quotation ILIKE <cfqueryparam cfsqltype="VARCHAR" value="%#arguments.str#%">
					OR quotation_number ILIKE <cfqueryparam cfsqltype="VARCHAR" value="%#arguments.str#%">
					OR rif_libero ILIKE <cfqueryparam cfsqltype="VARCHAR" value="%#arguments.str#%">

					<!---
						Referenti che sul CRM corrispondono al testo cercato.
						Le colonne sono uuid: si passa un solo parametro come
						array literal Postgres e si casta, invece di un IN con
						N placeholder varchar (che non farebbero il cast e che
						su una ricerca generica sarebbero migliaia).
					--->
					<cfif !IsNull( arguments.referentCustomerIds ) AND ArrayLen( arguments.referentCustomerIds )>
						OR customer_id = ANY(
							<cfqueryparam cfsqltype="VARCHAR" value="{#ArrayToList( arguments.referentCustomerIds )#}">::uuid[]
						)
					</cfif>

					<cfif !IsNull( arguments.referentLeadIds ) AND ArrayLen( arguments.referentLeadIds )>
						OR lead_id = ANY(
							<cfqueryparam cfsqltype="VARCHAR" value="{#ArrayToList( arguments.referentLeadIds )#}">::uuid[]
						)
					</cfif>

					<cfif !IsNull( arguments.referentOpportunityIds ) AND ArrayLen( arguments.referentOpportunityIds )>
						OR opportunity_id = ANY(
							<cfqueryparam cfsqltype="VARCHAR" value="{#ArrayToList( arguments.referentOpportunityIds )#}">::uuid[]
						)
					</cfif>
				)
			</cfif>

			<cfif !IsNull( arguments.fromDate ) AND IsDate( arguments.fromDate )>
				AND quotations.quotation_date >= <cfqueryparam cfsqltype="DATE" value="#arguments.fromDate#">
			</cfif>

			<cfif !IsNull( arguments.toDate ) AND IsDate( arguments.toDate )>
				AND quotations.quotation_date <= <cfqueryparam cfsqltype="DATE" value="#arguments.toDate#">
			</cfif>

			<cfif !IsNull( arguments.active ) AND IsNumeric( arguments.active )>
				AND quotations.active = <cfqueryparam cfsqltype="INTEGER" value="#arguments.active#">
			</cfif>

			<cfif !IsNull( arguments.statusId )>
				AND quotation_status_history.status_id = <cfqueryparam cfsqltype="VARCHAR" value="#arguments.statusId#">
			</cfif>

			<cfif !IsNull( arguments.langId )>
				AND lang_id = <cfqueryparam cfsqltype="CHAR" value="#arguments.langId#">
			</cfif>

			<cfif !IsNull( arguments.pricelistId )>
				AND pricelist_id = <cfqueryparam cfsqltype="VARCHAR" value="#arguments.pricelistId#">
			</cfif>

			<cfif !IsNull( arguments.paymentMethodId )>
				AND payment_method_id = <cfqueryparam cfsqltype="VARCHAR" value="#arguments.paymentMethodId#">
			</cfif>

			<cfif !IsNull( arguments.currencyId )>
				AND currency_id = <cfqueryparam cfsqltype="VARCHAR" value="#arguments.currencyId#">
			</cfif>

			<cfif !IsNull( arguments.billingProfileId )>
				AND billing_profile_id = <cfqueryparam cfsqltype="VARCHAR" value="#arguments.billingProfileId#">::uuid
			</cfif>

			<cfif !IsNull( arguments.shippingProfileId )>
				AND shipping_profile_id = <cfqueryparam cfsqltype="VARCHAR" value="#arguments.shippingProfileId#">::uuid
			</cfif>

			<cfif !IsNull( arguments.salesAgentId )>
				AND sales_agent_account_id = <cfqueryparam cfsqltype="VARCHAR" value="#arguments.salesAgentId#">::uuid
			</cfif>

			<cfif !IsNull( arguments.graphicTechnicianId )>
				AND graphic_technician_account_id = <cfqueryparam cfsqltype="VARCHAR" value="#arguments.graphicTechnicianId#">::uuid
			</cfif>

			<cfif !IsNull( arguments.ownerId )>
				AND owner_id = <cfqueryparam cfsqltype="VARCHAR" value="#arguments.ownerId#">::uuid
			</cfif>

			<cfif !IsNull( arguments.agentAccountId )>
				AND <cfqueryparam cfsqltype="VARCHAR" value="#arguments.agentAccountId#"> IN ( agente1, agente2, agente3, agente4, agente5 )
			</cfif>

			ORDER BY
				#super.sanitizeSQL( arguments.orderby )#

			<cfif arguments.limit GT 0>
				LIMIT
					<cfqueryparam value="#arguments.limit#" cfsqltype="integer">
				OFFSET
					<cfqueryparam value="#arguments.offset#" cfsqltype="integer">
			</cfif>
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<cffunction name="insert" returntype="String">
		<cfargument name="quotation" type="com.apirone.core.model.bean.Quotation" required="true">
		<cfquery name="local.q" datasource="apirone">
			INSERT INTO quotations (
				quotation,
				quotation_number,
				version_number,
				quotation_date,
				note,
				validity_date,
				opportunity_id,
				lead_id,
				active,
				lang_id,
				customer_id,
				payment_method_id,
				currency_id,
				shipping_profile_id,
				sales_agent_account_id,
				graphic_technician_account_id,
				vat_code_id,
				owner_id,
				nessun_agente,
				agente1,
				agente2,
				agente3,
				agente4,
				agente5,
				commission1,
				commission2,
				commission3,
				commission4,
				commission5,
				referente_amministrativo,
				referente_spedizione,
				customer_type,
				industry,
				rif_libero,
				po,
				reclamo_anno,
				reclamo_numero,
				reclamo_alfa,
				custom_payment_method,
				note_trasporto,
				data_evasione,
				sent_to_client,
				data_conferma_ordine,
				codice_sdi
			) VALUES (
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getName()#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getQuotationNumber()#">,
				<cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getVersionNumber()#">,
				<cfqueryparam cfsqltype="Date" value="#arguments.quotation.getQuotationDate()#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getNote()#">,
				<cfqueryparam cfsqltype="Date" value="#arguments.quotation.getValidityDate()#">,
				<cfif !IsNull( arguments.quotation.getOpportunity()?.getId() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getOpportunity().getId()#">::uuid
				<cfelse>
					NULL
				</cfif>
				,
				<cfif !IsNull( arguments.quotation.getLead()?.getId() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getLead().getId()#">::uuid
				<cfelse>
					NULL
				</cfif>
				,
				<cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getActive()#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getLang().getId()#">,
				<cfif !IsNull( arguments.quotation.getCustomer()?.getId() ) >
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getCustomer().getId()#">::uuid
				<cfelse>
					NULL
				</cfif>
				,
				<cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getPaymentMethod().getId()#">,
				<cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getCurrency().getId()#">,
				<cfif !IsNull( arguments.quotation.getShippingProfile()?.getId() ) >
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getShippingProfile().getId()#">::uuid
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getSalesAgent()?.getId() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getSalesAgent().getId()#">::uuid
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getGraphicTechnician()?.getId() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getGraphicTechnician().getId()#">::uuid
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getVatCode()?.getId() ) >
					<cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getVatCode().getId()#">
				<cfelse>
					NULL
				</cfif>,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getOwner().getId()#">::uuid,
				<cfqueryparam cfsqltype="Boolean" value="#arguments.quotation.getNessunAgente()#">,
				<cfif !IsNull( arguments.quotation.getAgente1() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getAgente1()#">::uuid
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getAgente2() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getAgente2()#">::uuid
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getAgente3() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getAgente3()#">::uuid
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getAgente4() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getAgente4()#">::uuid
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getAgente5() )>
					<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getAgente5()#">::uuid
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getCommission1() )>
					<cfqueryparam cfsqltype="CF_SQL_DECIMAL" value="#arguments.quotation.getCommission1()#">
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getCommission2() )>
					<cfqueryparam cfsqltype="CF_SQL_DECIMAL" value="#arguments.quotation.getCommission2()#">
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getCommission3() )>
					<cfqueryparam cfsqltype="CF_SQL_DECIMAL" value="#arguments.quotation.getCommission3()#">
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getCommission4() )>
					<cfqueryparam cfsqltype="CF_SQL_DECIMAL" value="#arguments.quotation.getCommission4()#">
				<cfelse>
					NULL
				</cfif>,
				<cfif !IsNull( arguments.quotation.getCommission5() )>
					<cfqueryparam cfsqltype="CF_SQL_DECIMAL" value="#arguments.quotation.getCommission5()#">
				<cfelse>
					NULL
				</cfif>,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getReferenteAmministrativo() ?: ''#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getReferenteSpedizione() ?: ''#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getCustomerType() ?: ''#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getIndustry() ?: ''#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getRifLibero() ?: ''#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getPo() ?: ''#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getReclamoAnno() ?: ''#">,
				<cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getReclamoNumero() ?: ''#" null="#isNull(arguments.quotation.getReclamoNumero())#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getReclamoAlfa() ?: ''#">,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getCustomPaymentMethod() ?: ''#">,
				<cfqueryparam cfsqltype="Varchar" value="#Left( arguments.quotation.getNoteTrasporto() ?: '', 20 )#" null="#!Len( arguments.quotation.getNoteTrasporto() ?: '' )#">,
				<cfif !isNull(arguments.quotation.getDataEvasione()) && IsDate(arguments.quotation.getDataEvasione())>
					<cfqueryparam cfsqltype="Date" value="#arguments.quotation.getDataEvasione()#">
				<cfelse>
					NULL
				</cfif>,
				<cfqueryparam cfsqltype="Boolean" value="#arguments.quotation.getSentToClient() ?: false#">,
				<cfif !isNull(arguments.quotation.getDataConfermaOrdine()) && IsDate(arguments.quotation.getDataConfermaOrdine())>
					<cfqueryparam cfsqltype="Date" value="#arguments.quotation.getDataConfermaOrdine()#">
				<cfelse>
					NULL
				</cfif>,
				<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getCodiceSdi() ?: ''#">
			)
			RETURNING quotation_id
		</cfquery>

		<cfreturn local.q.quotation_id.toString()>
	</cffunction>

	<cffunction name="update" returntype="String">
		<cfargument name="quotation" type="com.apirone.core.model.bean.Quotation" required="true">

		<cfquery name="local.q" datasource="apirone" result="result">
			UPDATE quotations
			SET
				updated_at = now(),
				quotation = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getName()#">,
				quotation_date =
					<cfif !IsNull( arguments.quotation.getQuotationDate() )>
						<cfqueryparam cfsqltype="DATE" value="#arguments.quotation.getQuotationDate()#">
					<cfelse>
						NULL
					</cfif>
				,
				validity_date =
					<cfif !IsNull( arguments.quotation.getValidityDate() )>
						<cfqueryparam cfsqltype="DATE" value="#arguments.quotation.getValidityDate()#">
					<cfelse>
						NULL
					</cfif>
				,
				note = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getNote()#">,
				payment_method_id =
					<cfif !IsNull( arguments.quotation.getPaymentMethod() )>
						<cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getPaymentMethod().getId()#">
					<cfelse>
						NULL
					</cfif>
				,
				currency_id =
					<cfif !IsNull( arguments.quotation.getCurrency() )>
						<cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getCurrency().getId()#">
					<cfelse>
						NULL
					</cfif>
				,
				lang_id =
					<cfif !IsNull( arguments.quotation.getLang() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getLang().getId()#">
					<cfelse>
						NULL
					</cfif>
				,
				customer_id =
					<cfif !IsNull( arguments.quotation.getCustomer() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getCustomer().getId()#">::uuid
					<cfelse>
						NULL
					</cfif>
				,
				shipping_profile_id =
					<cfif !IsNull( arguments.quotation.getShippingProfile() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getShippingProfile().getId()#">::uuid
					<cfelse>
						NULL
					</cfif>
				,
				opportunity_id =
					<cfif !IsNull( arguments.quotation.getOpportunity() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getOpportunity().getId()#">::uuid
					<cfelse>
						NULL
					</cfif>
				,
				lead_id =
					<cfif !IsNull( arguments.quotation.getLead() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getLead().getId()#">::uuid
					<cfelse>
						NULL
					</cfif>
				,
				sales_agent_account_id =
					<cfif !IsNull( arguments.quotation.getSalesAgent() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getSalesAgent().getId()#">::uuid
					<cfelse>
						NULL
					</cfif>
				,
				graphic_technician_account_id =
					<cfif !IsNull( arguments.quotation.getGraphicTechnician() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getGraphicTechnician().getId()#">::uuid
					<cfelse>
						NULL
					</cfif>
				,
				<cfif !IsNull( arguments.quotation.getVersionNumber() )>
					version_number = <cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getVersionNumber()#">,
				</cfif>
				vat_code_id =
					<cfif !IsNull( arguments.quotation.getVatCode() )>
						<cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getVatCode().getId()#">
					<cfelse>
						NULL
					</cfif>
				,
				exported =
					<cfif !IsNull( arguments.quotation.getExported() )>
						<cfqueryparam cfsqltype="Boolean" value="#arguments.quotation.getExported()#">
					<cfelse>
						NULL
					</cfif>

				,
				nessun_agente =
					<cfif !IsNull( arguments.quotation.getNessunAgente() )>
						<cfqueryparam cfsqltype="Boolean" value="#arguments.quotation.getNessunAgente()#">
					<cfelse>
						NULL
					</cfif>,


				agente1 =
					<cfif !IsNull( arguments.quotation.getAgente1() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getAgente1()#">::uuid
					<cfelse>
						NULL
					</cfif>,


				agente2 =
					<cfif !IsNull( arguments.quotation.getAgente2() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getAgente2()#">::uuid
					<cfelse>
						NULL
					</cfif>,


				agente3 =
					<cfif !IsNull( arguments.quotation.getAgente3() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getAgente3()#">::uuid
					<cfelse>
						NULL
					</cfif>,


				agente4 =
					<cfif !IsNull( arguments.quotation.getAgente4() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getAgente4()#">::uuid
					<cfelse>
						NULL
					</cfif>,

				agente5 =
					<cfif !IsNull( arguments.quotation.getAgente5() )>
						<cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getAgente5()#">::uuid
					<cfelse>
						NULL
					</cfif>,

				commission1 =
					<cfif !IsNull( arguments.quotation.getCommission1() )>
						<cfqueryparam cfsqltype="CF_SQL_DECIMAL" value="#arguments.quotation.getCommission1()#">
					<cfelse>
						NULL
					</cfif>,

				commission2 =
					<cfif !IsNull( arguments.quotation.getCommission2() )>
						<cfqueryparam cfsqltype="CF_SQL_DECIMAL" value="#arguments.quotation.getCommission2()#">
					<cfelse>
						NULL
					</cfif>,

				commission3 =
					<cfif !IsNull( arguments.quotation.getCommission3() )>
						<cfqueryparam cfsqltype="CF_SQL_DECIMAL" value="#arguments.quotation.getCommission3()#">
					<cfelse>
						NULL
					</cfif>,

				commission4 =
					<cfif !IsNull( arguments.quotation.getCommission4() )>
						<cfqueryparam cfsqltype="CF_SQL_DECIMAL" value="#arguments.quotation.getCommission4()#">
					<cfelse>
						NULL
					</cfif>,

				commission5 =
					<cfif !IsNull( arguments.quotation.getCommission5() )>
						<cfqueryparam cfsqltype="CF_SQL_DECIMAL" value="#arguments.quotation.getCommission5()#">
					<cfelse>
						NULL
					</cfif>,

				referente_amministrativo = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getReferenteAmministrativo() ?: ''#">,
				referente_spedizione = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getReferenteSpedizione() ?: ''#">,
				customer_type = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getCustomerType() ?: ''#">,
				industry = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getIndustry() ?: ''#">,
				rif_libero = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getRifLibero() ?: ''#">,
				po = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getPo() ?: ''#">,
				reclamo_anno = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getReclamoAnno() ?: ''#">,
				reclamo_numero = <cfqueryparam cfsqltype="Integer" value="#arguments.quotation.getReclamoNumero() ?: ''#" null="#isNull(arguments.quotation.getReclamoNumero())#">,
				reclamo_alfa = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getReclamoAlfa() ?: ''#">,
				custom_payment_method = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getCustomPaymentMethod() ?: ''#">,
				data_evasione =
					<cfif !isNull(arguments.quotation.getDataEvasione()) && IsDate(arguments.quotation.getDataEvasione())>
						<cfqueryparam cfsqltype="Date" value="#arguments.quotation.getDataEvasione()#">
					<cfelse>
						NULL
					</cfif>,
				sent_to_client = <cfqueryparam cfsqltype="Boolean" value="#arguments.quotation.getSentToClient() ?: false#">,
				data_conferma_ordine =
					<cfif !isNull(arguments.quotation.getDataConfermaOrdine()) && IsDate(arguments.quotation.getDataConfermaOrdine())>
						<cfqueryparam cfsqltype="Date" value="#arguments.quotation.getDataConfermaOrdine()#">
					<cfelse>
						NULL
					</cfif>,
				codice_sdi = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getCodiceSdi() ?: ''#">

			WHERE
				quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotation.getId()#">::uuid
		</cfquery>

		<cfreturn arguments.quotation.getId()>
	</cffunction>

	<!--- Le note di trasporto si scrivono dal riquadro dei totali e non da update(): la testata
	      ricostruisce il bean dal suo JSON, che non le porta --->
	<cffunction name="updateNoteTrasporto" returntype="void">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="noteTrasporto" type="String" required="true">

		<cfquery datasource="apirone">
			UPDATE quotations
			SET note_trasporto = <cfqueryparam cfsqltype="Varchar" value="#Left( Trim( arguments.noteTrasporto ), 20 )#" null="#!Len( Trim( arguments.noteTrasporto ) )#">,
				updated_at = now()
			WHERE quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid
		</cfquery>
	</cffunction>

	<cffunction name="readNoteTrasporto" returntype="String">
		<cfargument name="quotationId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT note_trasporto
			FROM quotations
			WHERE quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid
		</cfquery>

		<cfreturn local.q.note_trasporto ?: "">
	</cffunction>

	<cffunction name="markAsSent" returntype="void">
		<cfargument name="quotationId" type="String" required="true">

		<cfquery datasource="apirone">
			UPDATE quotations
			SET sent_to_client = TRUE, updated_at = now()
			WHERE quotation_id = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationId#">::uuid
		</cfquery>
	</cffunction>

	<cffunction name="delete" returntype="Boolean">
		<cfargument name="quotationId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			DELETE FROM quotations
			WHERE quotation_id = <cfqueryparam cfsqltype="VARCHAR" value="#arguments.quotationId#">::uuid
		</cfquery>

		<cfreturn true>
	</cffunction>

	<cffunction name="deleteExport" returntype="Boolean">
		<cfargument name="quotationNumber" type="String" required="true">

		<cfquery name="local.q" datasource="verticaleExport">
			DELETE FROM ORDINI_APIR
			WHERE CAST(
				LEFT(MMNUMDOC, CHARINDEX('/', MMNUMDOC + '/') - 1)
				AS INT
			) = <cfqueryparam cfsqltype="integer" value="#arguments.quotationNumber#">
		</cfquery>

		<cfreturn true>
	</cffunction>

	<cffunction name="exportProduct" returntype="Boolean">
		<cfargument name="data" type="Struct" required="true">
		<cfset var qCheck = ""/>
		<cfset var success = true/>

		<cfquery name="qCheck" datasource="verticaleExport">
			SELECT AR_CHIAVE
			FROM ARTICO_APIR
			WHERE AR_CHIAVE = <cfqueryparam value="#arguments.data.AR_CHIAVE#" cfsqltype="varchar">
		</cfquery>

		<cfif qCheck.recordCount EQ 0>
			<cfquery datasource="verticaleExport">
				INSERT INTO ARTICO_APIR (
					AR_CHIAVE,
					ARCODART,
					ARDESART,
					ARDESSUP,
					ARDATCAR,
					ARUNMIS1,
					VARCOD,
					VARNOT,
					CLCODICE,
					CLANNOTA,
					AR_STATO,
					CL_STATO,
					VAR_STATO,
					ARIMG_64,
					ARSPECIA,
					ARCODNOM
				)
				VALUES (
					<cfqueryparam value="#arguments.data.AR_CHIAVE#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.ARCODART#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.ARDESART#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.ARDESSUP#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.ARDATCAR#" cfsqltype="date">,
					<cfqueryparam value="#arguments.data.ARUNMIS1#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.VARCOD#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.VARNOT#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.CLCODICE#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.CLANNOTA#" cfsqltype="varchar">,
					'N', <!--- nuovo ---->
					'N',
					'N',
					<cfqueryparam value="#arguments.data.ARIMG_64#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.ARSPECIA#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.ARCODNOM#" cfsqltype="varchar">
				)
			</cfquery>
		</cfif>

		<cfreturn success/>
	</cffunction>

	<cffunction name="exportDiba" returntype="Boolean">
		<cfargument name="data" type="Struct" required="true">
		<cfset var qCheck = ""/>
		<cfset var success = true/>
		<cfset var uniqueKey = arguments.data.DS_CHIAVE & arguments.data.CPROWNUM>

		<cfquery name="qCheck" datasource="verticaleExport">
			SELECT CONCAT(DS_CHIAVE, CPROWNUM)
			FROM DISBAS_APIR
			WHERE CONCAT(DS_CHIAVE, CPROWNUM) = '#uniqueKey#'
		</cfquery>

		<cfif qCheck.recordCount EQ 0>
			<cfquery datasource="verticaleExport">
				INSERT INTO DISBAS_APIR (
					DS_CHIAVE,
					DSCODART,
					DSCODVAR,
					DSCODCOL,
					DSCODMAT,
					DSVARMAT,
					DSCOLMAT,
					DSQTAMOV,
					DSUNMIS1,
					CPROWNUM,
					CPROWORD,
					DSTIPRIG,
					DS_STATO,
					DSDATCRE
				)
				VALUES (
					<cfqueryparam value="#arguments.data.DS_CHIAVE#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.DSCODART#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.DSCODVAR#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.DSCODCOL#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.DSCODMAT#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.DSVARMAT#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.DSCOLMAT#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.DSQTAMOV#" cfsqltype="numeric">,
					<cfqueryparam value="#arguments.data.DSUNMIS1#" cfsqltype="varchar">,
					<cfqueryparam value="#arguments.data.CPROWNUM#" cfsqltype="numeric">,
					<cfqueryparam value="#arguments.data.CPROWORD#" cfsqltype="numeric">,
					<cfqueryparam value="#arguments.data.DSTIPRIG#" cfsqltype="varchar">,
					'N', <!--- nuovo --->
					<cfqueryparam value="#arguments.data.DSDATCRE#" cfsqltype="date">
				)
			</cfquery>
		</cfif>

		<cfreturn success/>
	</cffunction>

	<cffunction name="export" returntype="Boolean">
		<cfargument name="data" type="Struct" required="true">
		<cfset var success = true/>

		<cfset var agentCode  = (!isNull(arguments.data.MMCODAGE) && IsNumeric(arguments.data.MMCODAGE)) ? val(arguments.data.MMCODAGE) : 0 />
		<cfset var agentCode2 = (!isNull(arguments.data.MMCODAG2) && IsNumeric(arguments.data.MMCODAG2)) ? val(arguments.data.MMCODAG2) : 0 />
		<cfset var agentCode3 = (!isNull(arguments.data.MMCODAG3) && IsNumeric(arguments.data.MMCODAG3)) ? val(arguments.data.MMCODAG3) : 0 />
		<cfset var agentCode4 = (!isNull(arguments.data.MMCODAG4) && IsNumeric(arguments.data.MMCODAG4)) ? val(arguments.data.MMCODAG4) : 0 />
		<cfset var agentCode5 = (!isNull(arguments.data.MMCODAG5) && IsNumeric(arguments.data.MMCODAG5)) ? val(arguments.data.MMCODAG5) : 0 />

		<cfquery datasource="verticaleExport">
			INSERT INTO ORDINI_APIR (
				CF_IDCLI, CF___CAP, CFBLOCCO, CFDESCR1, CFINDIRI, CFLOCALI, CFMOROSO, CFPARIVA,
				CFPROVIN, CFREFAMM, CFSTAISO, CFTELEFO, CPROWNUM, CPROWORD, DEDESDOD, DEDESMER,
				DEIDDMER, DEINDDOD, DEINDMER, DELOCDOD, DELOCMER, DENAZDOD, DENAZMER,
				DEPRODOD, DEPROMER, DECAPDOC, DECAPDES, MM_STATO, CFLINGUA, MMCODAGE, MMCODAG2, MMCODAG3, MMCODAG4,
				MMCODAG5, MMCODART, MMCODCOL, MMCODPAG,
				MMSCOCF1, MMSCOCF2, MMSPETRA, MMCODVAL, MMCODVAR, MMDATDOC, MMDATEVA,
				MMEVASIO, MMNUMDOC, MMNUMLIS, MMQTAMOV, MMRIFORD, MMSCOAR1, MMSCOAR2,
				MMSERIAL, MMVALUNI, MMUTECOM, MMUTETEC,
				MMPERPRO, MMPERPR2, MMPERPR3, MMPERPR4, MMPERPR5,
				MMRIFSPE, CFTIPCLF, CFCODDES, MMORDPRO, MMNOTPOS, MMANNDET, CFEMAIL, MMANNTES,
				MMRIF_PO, MMCODIVA,
				MMESEREC, MMDOCREC, MMALFREC,
				MMNOTPAG
			)
			VALUES (
				<cfqueryparam value="#left(arguments.data.CF_IDCLI,36)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CF___CAP ?: '',10)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFBLOCCO,1)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFDESCR1,40)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFINDIRI,35)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFLOCALI,30)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFMOROSO,1)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFPARIVA,11)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFPROVIN,2)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFREFAMM,70)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFSTAISO,3)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFTELEFO,18)#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.CPROWNUM ?: 0#" cfsqltype="integer">,
				<cfqueryparam value="#arguments.data.CPROWORD ?: 0#" cfsqltype="integer">,
				<cfqueryparam value="#left(arguments.data.DEDESDOD,35)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DEDESMER,35)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DEIDDMER,36)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DEINDDOD,30)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DEINDMER,30)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DELOCDOD,35)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DELOCMER,35)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DENAZDOD,3)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DENAZMER,3)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DEPRODOD,2)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DEPROMER,2)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DECAPDOC ?: '',10)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.DECAPDES ?: '',10)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.MM_STATO,1)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFLINGUA,2)#" cfsqltype="varchar">,
				<cfqueryparam value="#agentCode#" cfsqltype="integer">,
				<cfqueryparam value="#agentCode2#" cfsqltype="integer">,
				<cfqueryparam value="#agentCode3#" cfsqltype="integer">,
				<cfqueryparam value="#agentCode4#" cfsqltype="integer">,
				<cfqueryparam value="#agentCode5#" cfsqltype="integer">,
				<cfqueryparam value="#left(arguments.data.MMCODART,15)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.MMCODCOL,6)#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.MMCODPAG ?: 0#" cfsqltype="integer">,
				<cfqueryparam value="#arguments.data.MMSCOCF1 ?: 0#" cfsqltype="integer">,
				<cfqueryparam value="#arguments.data.MMSCOCF2 ?: 0#" cfsqltype="integer">,
				<cfqueryparam value="#arguments.data.MMSPETRA ?: 0#" cfsqltype="integer">,
				<cfqueryparam value="#arguments.data.MMCODVAL ?: 0#" cfsqltype="integer">,
				<cfqueryparam value="#left(arguments.data.MMCODVAR,10)#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.MMDATDOC#" cfsqltype="date">,
				<cfqueryparam value="#arguments.data.MMDATEVA ?: ''#" cfsqltype="date" null="#!StructKeyExists(arguments.data, 'MMDATEVA') || IsNull(arguments.data.MMDATEVA) || !Len(arguments.data.MMDATEVA)#">,
				<cfqueryparam value="#arguments.data.MMEVASIO#" cfsqltype="date">,
				<cfqueryparam value="#left(arguments.data.MMNUMDOC,10)#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.MMNUMLIS ?: 1#" cfsqltype="integer">,
				<cfqueryparam value="#arguments.data.MMQTAMOV ?: 0#" cfsqltype="decimal" scale="6">,
				<cfqueryparam value="#left(arguments.data.MMRIFORD,25)#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.MMSCOAR1 ?: 0#" cfsqltype="decimal" scale="6">,
				<cfqueryparam value="#arguments.data.MMSCOAR2 ?: 0#" cfsqltype="decimal" scale="6">,
				<cfqueryparam value="#left(arguments.data.MMSERIAL,12)#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.MMVALUNI ?: 0#" cfsqltype="decimal" scale="6">,
				<cfqueryparam value="#arguments.data.MMUTECOM#" cfsqltype="integer">,
				<cfqueryparam value="#arguments.data.MMUTETEC#" cfsqltype="integer">,
				<cfqueryparam value="#arguments.data.MMPERPRO ?: 0#" cfsqltype="decimal" scale="2">,
				<cfqueryparam value="#arguments.data.MMPERPR2 ?: 0#" cfsqltype="decimal" scale="2">,
				<cfqueryparam value="#arguments.data.MMPERPR3 ?: 0#" cfsqltype="decimal" scale="2">,
				<cfqueryparam value="#arguments.data.MMPERPR4 ?: 0#" cfsqltype="decimal" scale="2">,
				<cfqueryparam value="#arguments.data.MMPERPR5 ?: 0#" cfsqltype="decimal" scale="2">,
				<cfqueryparam value="#left(arguments.data.MMRIFSPE,40)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFTIPCLF,50)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.CFCODDES ?: '',15)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.MMORDPRO ?: 'N',1)#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.MMNOTPOS ?: ''#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.MMANNDET ?: ''#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.CFEMAIL ?: ''#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.MMANNTES ?: ''#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.MMRIF_PO ?: '',50)#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.MMCODIVA ?: ''#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.MMESEREC ?: '',4)#" cfsqltype="varchar">,
				<cfqueryparam value="#arguments.data.MMDOCREC ?: 0#" cfsqltype="integer">,
				<cfqueryparam value="#left(arguments.data.MMALFREC ?: '',2)#" cfsqltype="varchar">,
				<cfqueryparam value="#left(arguments.data.MMNOTPAG ?: '',255)#" cfsqltype="varchar">
			)
		</cfquery>

		<cfreturn success/>
	</cffunction>

	<cffunction name="getQuotationTotal" access="public" returntype="numeric">
		<cfargument name="quotationId" type="String" required="true">

		<cfset var local = {}>

		<cfquery name="local.qTotal" datasource="apirone">
			SELECT
			COALESCE(SUM(price * quantity), 0) AS total_amount
			FROM quotation_items
			WHERE quotation_id = <cfqueryparam cfsqltype="varchar" value="#arguments.quotationId#">::uuid
		</cfquery>

		<cfreturn local.qTotal.total_amount>
	</cffunction>

	<!---
		Calcola in batch il totale per una lista di quotationId.
		Evita l'N+1 di getQuotationTotal() chiamato per ogni riga in getMany().
	--->
	<cffunction name="getQuotationTotals" access="public" returntype="Struct">
		<cfargument name="quotationIds" type="Array" required="true">

		<cfset var result   = {} />
		<cfset var idsList  = ArrayToList( arguments.quotationIds ) />

		<!--- nessun preventivo: niente query ( con la lista vuota diventerebbe ''::uuid, errore ) --->
		<cfif !ArrayLen( arguments.quotationIds )>
			<cfreturn result />
		</cfif>

		<cfquery name="local.q" datasource="apirone">
			SELECT quotation_id, COALESCE(SUM(price * quantity), 0) AS total_amount
			FROM quotation_items
			WHERE quotation_id = ANY(
				ARRAY[<cfqueryparam value="#idsList#" list="true" cfsqltype="varchar">]::uuid[]
			)
			GROUP BY quotation_id
		</cfquery>

		<cfloop query="local.q">
			<cfset result[ local.q.quotation_id ] = local.q.total_amount />
		</cfloop>

		<cfreturn result />
	</cffunction>

	<cffunction name="readNextNumber" access="public" returntype="numeric">

		<cfquery name="local.q" datasource="apirone">
			SELECT nextval('quotation_number_seq');
		</cfquery>

		<cfreturn local.q.nextval>
	</cffunction>

	<!---
		Lock per numero di preventivo fino alla fine della transazione corrente: chi
		calcola la prossima versione ( max + 1 ) e la inserisce lo fa sotto questo lock,
		così due richieste ravvicinate non ottengono lo stesso numero. Va chiamato dentro
		una transazione: fuori si rilascerebbe subito.
	--->
	<cffunction name="lockVersionNumbering" access="public" returntype="void">
		<cfargument name="quotationNumber" type="String" required="true">

		<cfquery datasource="apirone">
			SELECT pg_advisory_xact_lock( hashtext( 'quotation_version:' || <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationNumber#"> ) )
		</cfquery>
	</cffunction>

	<cffunction name="readMaxVersionNumber" access="public" returntype="numeric">
		<cfargument name="quotationNumber" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT COALESCE( MAX( version_number ), 0 ) AS max_version
			FROM quotations
			WHERE quotation_number = <cfqueryparam cfsqltype="Varchar" value="#arguments.quotationNumber#">
		</cfquery>

		<cfreturn local.q.max_version>
	</cffunction>

	<!---
		Recupera in batch più preventivi dato un array di ID.
		Utilizzato dal Service corrispondente per caricare i bean in blocco.
	--->
	<cffunction name="readByIds" returntype="Query" access="public">
		<cfargument name="ids" type="Array" required="true">

		<cfset var idsList = ArrayToList( arguments.ids )>

		<cfquery name="local.q" datasource="apirone">
			SELECT
				quotations.quotation_id::varchar,
				lang_id::varchar,
				pricelist_id::varchar,
				payment_method_id::varchar,
				currency_id::varchar,
				billing_profile_id::varchar,
				shipping_profile_id::varchar,
				sales_agent_account_id::varchar,
				graphic_technician_account_id::varchar,
				*
			FROM quotations
				INNER JOIN quotation_status_history ON quotations.quotation_status_history_id = quotation_status_history.quotation_status_history_id
			WHERE quotations.quotation_id = ANY(
				ARRAY[<cfqueryparam value="#idsList#" list="true" cfsqltype="varchar">]::uuid[]
			)
		</cfquery>

		<cfreturn local.q>
	</cffunction>
</cfcomponent>
