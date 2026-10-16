<cfcomponent extends="com.apirone.core.model.dao.AbsDAO" accessors="true">

	<!--- ======================= Tipologie di attività ======================= --->

	<cffunction name="findWorkTypes" returntype="Query" access="public">
		<cfquery name="local.q" datasource="apirone">
			SELECT work_type_id, name, color
			FROM planning_work_types
			ORDER BY orderby, name
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!--- ======================= Persone ======================= --->

	<!---
		Utenti con tipologie di attività ( work_type_ids: elenco separato da
		virgole, nell'ordine delle tipologie ) e ore disponibili ( pagina
		Disponibilità persone ). onlyWithType: solo quelli che si pianificano
		( almeno una tipologia, Gantt ).
	--->
	<cffunction name="findPeople" returntype="Query" access="public">
		<cfargument name="onlyWithType" type="Boolean" default="false">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				u.user_id::varchar AS user_id,
				COALESCE( NULLIF( u.user_name, '' ), a.account ) AS name,
				u.role_id,
				u.status_id,
				(
					SELECT string_agg( pw.work_type_id, ',' ORDER BY wt.orderby )
					FROM planning_person_work_types pw
					JOIN planning_work_types wt ON wt.work_type_id = pw.work_type_id
					WHERE pw.user_id = u.user_id
				) AS work_type_ids,
				<!--- priorità sulle tipologie: "WAY:1,MON:" ( vuota = dopo quelle numerate ) --->
				(
					SELECT string_agg( pw.work_type_id || ':' || COALESCE( pw.priority::varchar, '' ), ',' )
					FROM planning_person_work_types pw
					WHERE pw.user_id = u.user_id
				) AS work_type_priorities,
				u.hours_mon, u.hours_tue, u.hours_wed, u.hours_thu, u.hours_fri, u.hours_sat, u.hours_sun,
				EXTRACT( EPOCH FROM u.day_start )::int / 60 AS day_start_minutes,
				cur.hourly_cost,
				cur.valid_from AS cost_valid_from
			FROM membership.users u
			JOIN membership.accounts a ON a.account_id = u.account_id
			<!--- tariffa in vigore oggi --->
			LEFT JOIN LATERAL (
				SELECT c.hourly_cost, c.valid_from
				FROM planning_person_costs c
				WHERE c.user_id = u.user_id AND c.valid_from <= CURRENT_DATE
				ORDER BY c.valid_from DESC
				LIMIT 1
			) cur ON true
			WHERE 1=1
				<cfif arguments.onlyWithType>
					AND EXISTS ( SELECT 1 FROM planning_person_work_types pw WHERE pw.user_id = u.user_id )
				</cfif>
			ORDER BY 2
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<cffunction name="updatePerson" returntype="void" access="public">
		<cfargument name="userId" type="String" required="true">
		<cfargument name="hours" type="Array" required="true">
		<!--- ora di inizio giornata "HH:MM" --->
		<cfargument name="dayStart" type="String" required="true">

		<cfquery datasource="apirone">
			UPDATE membership.users SET
				day_start = <cfqueryparam cfsqltype="varchar" value="#arguments.dayStart#">::time,
				hours_mon = <cfqueryparam cfsqltype="numeric" scale="2" value="#arguments.hours[ 1 ]#">,
				hours_tue = <cfqueryparam cfsqltype="numeric" scale="2" value="#arguments.hours[ 2 ]#">,
				hours_wed = <cfqueryparam cfsqltype="numeric" scale="2" value="#arguments.hours[ 3 ]#">,
				hours_thu = <cfqueryparam cfsqltype="numeric" scale="2" value="#arguments.hours[ 4 ]#">,
				hours_fri = <cfqueryparam cfsqltype="numeric" scale="2" value="#arguments.hours[ 5 ]#">,
				hours_sat = <cfqueryparam cfsqltype="numeric" scale="2" value="#arguments.hours[ 6 ]#">,
				hours_sun = <cfqueryparam cfsqltype="numeric" scale="2" value="#arguments.hours[ 7 ]#">
			WHERE user_id = <cfqueryparam cfsqltype="varchar" value="#arguments.userId#">::uuid
		</cfquery>
	</cffunction>

	<!---
		Tipologie della persona: sostituisce quelle che aveva ( vuoto: non si
		pianifica ). priorities: tipo -> priorità ( intero >= 1; assente = nessuna ).
	--->
	<cffunction name="savePersonWorkTypes" returntype="void" access="public">
		<cfargument name="userId" type="String" required="true">
		<cfargument name="workTypeIds" type="Array" required="true">
		<cfargument name="priorities" type="Struct" default="#{}#">

		<cfquery datasource="apirone">
			DELETE FROM planning_person_work_types
			WHERE user_id = <cfqueryparam cfsqltype="varchar" value="#arguments.userId#">::uuid
		</cfquery>

		<cfloop array="#arguments.workTypeIds#" item="local.workTypeId">
			<cfset local.priority = arguments.priorities[ local.workTypeId ] ?: "">
			<cfquery datasource="apirone">
				INSERT INTO planning_person_work_types ( user_id, work_type_id, priority )
				SELECT
					<cfqueryparam cfsqltype="varchar" value="#arguments.userId#">::uuid,
					work_type_id,
					<cfqueryparam cfsqltype="integer" value="#Val( local.priority )#" null="#!IsNumeric( local.priority )#">
				FROM planning_work_types
				WHERE work_type_id = <cfqueryparam cfsqltype="varchar" value="#local.workTypeId#">
			</cfquery>
		</cfloop>
	</cffunction>

	<!--- ======================= Ore dei preventivi ======================= --->

	<!--- budget: stringa vuota = nessun budget --->
	<cffunction name="saveQuotationWorkHours" returntype="void" access="public">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="workTypeId" type="String" required="true">
		<cfargument name="hours" type="Numeric" required="true">
		<cfargument name="budget" type="String" default="">

		<cfquery datasource="apirone">
			INSERT INTO quotation_work_hours ( quotation_id, work_type_id, hours, budget )
			VALUES (
				<cfqueryparam cfsqltype="varchar" value="#arguments.quotationId#">::uuid,
				<cfqueryparam cfsqltype="varchar" value="#arguments.workTypeId#">,
				<cfqueryparam cfsqltype="numeric" scale="2" value="#arguments.hours#">,
				<cfqueryparam cfsqltype="numeric" scale="2" value="#Val( arguments.budget )#" null="#!IsNumeric( arguments.budget )#">
			)
			ON CONFLICT ( quotation_id, work_type_id ) DO UPDATE
				SET hours = EXCLUDED.hours, budget = EXCLUDED.budget, updated_at = NOW()
		</cfquery>
	</cffunction>

	<!--- ======================= Costi orari ======================= --->

	<cffunction name="findPersonCosts" returntype="Query" access="public">
		<cfargument name="userId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT cost_id, valid_from, hourly_cost
			FROM planning_person_costs
			WHERE user_id = <cfqueryparam cfsqltype="varchar" value="#arguments.userId#">::uuid
			ORDER BY valid_from DESC
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<cffunction name="savePersonCost" returntype="void" access="public">
		<cfargument name="userId" type="String" required="true">
		<cfargument name="validFrom" type="Date" required="true">
		<cfargument name="hourlyCost" type="Numeric" required="true">
		<cfargument name="createdBy" type="String" default="">

		<cfquery datasource="apirone">
			INSERT INTO planning_person_costs ( user_id, valid_from, hourly_cost, created_by )
			VALUES (
				<cfqueryparam cfsqltype="varchar" value="#arguments.userId#">::uuid,
				<cfqueryparam cfsqltype="date" value="#arguments.validFrom#">,
				<cfqueryparam cfsqltype="numeric" scale="2" value="#arguments.hourlyCost#">,
				<cfqueryparam cfsqltype="varchar" value="#arguments.createdBy#" null="#!Len( arguments.createdBy )#">::uuid
			)
			ON CONFLICT ( user_id, valid_from ) DO UPDATE SET hourly_cost = EXCLUDED.hourly_cost
		</cfquery>
	</cffunction>

	<cffunction name="deletePersonCost" returntype="void" access="public">
		<cfargument name="costId" type="Numeric" required="true">

		<cfquery datasource="apirone">
			DELETE FROM planning_person_costs
			WHERE cost_id = <cfqueryparam cfsqltype="integer" value="#arguments.costId#">
		</cfquery>
	</cffunction>

	<!---
		Costi dei progetti per tipo di attività: ore pianificate × tariffa della
		persona in vigore quel giorno; "done" = giorni fino a oggi; missing_rate_hours
		= ore di persone senza tariffa a quella data ( costo non calcolabile ).
		quotation_id è la voce del Gantt: il preventivo o il progetto del blocco.
	--->
	<cffunction name="findCostStats" returntype="Query" access="public">
		<cfquery name="local.q" datasource="apirone">
			SELECT
				COALESCE( b.project_id, b.quotation_id )::varchar AS quotation_id,
				b.work_type_id,
				SUM( d.hours ) AS hours,
				SUM( CASE WHEN d.day <= CURRENT_DATE THEN d.hours ELSE 0 END ) AS done_hours,
				SUM( d.hours * COALESCE( r.hourly_cost, 0 ) ) AS cost,
				SUM( CASE WHEN d.day <= CURRENT_DATE THEN d.hours * COALESCE( r.hourly_cost, 0 ) ELSE 0 END ) AS done_cost,
				SUM( CASE WHEN r.hourly_cost IS NULL THEN d.hours ELSE 0 END ) AS missing_rate_hours,
				SUM( CASE WHEN b.extra THEN d.hours ELSE 0 END ) AS extra_hours,
				SUM( CASE WHEN b.extra THEN d.hours * COALESCE( r.hourly_cost, 0 ) ELSE 0 END ) AS extra_cost
			FROM planning_blocks b
			JOIN planning_block_days d ON d.block_id = b.block_id
			LEFT JOIN LATERAL (
				SELECT c.hourly_cost
				FROM planning_person_costs c
				WHERE c.user_id = b.user_id AND c.valid_from <= d.day
				ORDER BY c.valid_from DESC
				LIMIT 1
			) r ON true
			GROUP BY COALESCE( b.project_id, b.quotation_id ), b.work_type_id
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Pianificazione del preventivo nel Gantt: stato ( COR / CLS / SOS / DAP ),
		data con tipo ( RIC / TAS; indipendente dalla "data prevista evasione" del
		preventivo ), priorità ( A / B / C ) e note. completed_at:
		quando è stato concluso ( vuoto se non concluso ).
	--->
	<cffunction name="saveQuotationPlanning" returntype="void" access="public">
		<cfargument name="quotationId" type="String" required="true">
		<cfargument name="planning" type="Struct" required="true">
		<cfargument name="userId" type="String" default="">

		<cfset local.p = arguments.planning>
		<cfset local.done = local.p.statusId == "CLS">

		<cfquery datasource="apirone">
			INSERT INTO planning_quotations ( quotation_id, status_id, due_date, date_type, priority, note, completed_at, completed_by )
			VALUES (
				<cfqueryparam cfsqltype="varchar" value="#arguments.quotationId#">::uuid,
				<cfqueryparam cfsqltype="varchar" value="#local.p.statusId#">,
				<cfqueryparam cfsqltype="date" value="#local.p.dueDate#" null="#!IsDate( local.p.dueDate )#">,
				<cfqueryparam cfsqltype="varchar" value="#local.p.dateType#" null="#!Len( local.p.dateType )#">,
				<cfqueryparam cfsqltype="varchar" value="#local.p.priority#" null="#!Len( local.p.priority )#">,
				<cfqueryparam cfsqltype="longvarchar" value="#local.p.note#" null="#!Len( local.p.note )#">,
				<cfif local.done>NOW()<cfelse>NULL</cfif>,
				<cfqueryparam cfsqltype="varchar" value="#arguments.userId#" null="#!local.done OR !Len( arguments.userId )#">::uuid
			)
			ON CONFLICT ( quotation_id ) DO UPDATE SET
				status_id = EXCLUDED.status_id,
				due_date = EXCLUDED.due_date,
				date_type = EXCLUDED.date_type,
				priority = EXCLUDED.priority,
				note = EXCLUDED.note,
				<!--- già concluso: resta la data di quando lo è diventato --->
				completed_at = CASE WHEN EXCLUDED.status_id = 'CLS' THEN COALESCE( planning_quotations.completed_at, NOW() ) ELSE NULL END,
				completed_by = CASE WHEN EXCLUDED.status_id = 'CLS' THEN COALESCE( planning_quotations.completed_by, EXCLUDED.completed_by ) ELSE NULL END
		</cfquery>
	</cffunction>

	<!--- Revisione / duplica: le ore stimate passano al nuovo preventivo --->
	<cffunction name="copyQuotationWorkHours" returntype="void" access="public">
		<cfargument name="fromQuotationId" type="String" required="true">
		<cfargument name="toQuotationId" type="String" required="true">

		<cfquery datasource="apirone">
			INSERT INTO quotation_work_hours ( quotation_id, work_type_id, hours, budget )
			SELECT <cfqueryparam cfsqltype="varchar" value="#arguments.toQuotationId#">::uuid, work_type_id, hours, budget
			FROM quotation_work_hours
			WHERE quotation_id = <cfqueryparam cfsqltype="varchar" value="#arguments.fromQuotationId#">::uuid
			ON CONFLICT ( quotation_id, work_type_id ) DO NOTHING
		</cfquery>
	</cffunction>

	<!--- ======================= Gantt ======================= --->

	<!---
		Preventivi pianificabili: attivi e in qualunque stato tranne "Perso" ed
		"Estinto" ( isPlannableSql ), qualunque versione. Anche quelli che hanno
		già blocchi nel Gantt e nel frattempo hanno cambiato stato ( plannable
		false ). Esclusi quelli collegati a un progetto: nel Gantt ci sono tramite
		il progetto. I conclusi ( planning_quotations ) li scarta il chiamante.
	--->
	<cffunction name="findPlannableQuotations" returntype="Query" access="public">
		<cfquery name="local.q" datasource="apirone">
			SELECT
				q.quotation_id::varchar AS quotation_id,
				q.quotation_number,
				q.version_number,
				q.quotation AS name,
				q.rif_libero,
				COALESCE( h.status_id, q._status_id ) AS status_id,
				s.status AS status_name,
				( #isPlannableSql()# ) AS plannable,
				<!--- pianificazione: senza riga in planning_quotations "Da programmare" --->
				COALESCE( pq.status_id, 'DAP' ) AS planning_status_id,
				<!--- data della pianificazione; la "data prevista evasione" del preventivo a parte, in sola lettura --->
				pq.due_date,
				q.data_evasione AS delivery_date,
				q.created_at,
				pq.date_type,
				pq.priority,
				pq.note AS planning_note,
				ca.name AS customer
			FROM quotations q
			LEFT JOIN quotation_status_history h ON h.quotation_status_history_id = q.quotation_status_history_id
			LEFT JOIN statuses s ON s.status_id = COALESCE( h.status_id, q._status_id )
			LEFT JOIN planning_quotations pq ON pq.quotation_id = q.quotation_id
			LEFT JOIN crm_accounts ca ON ca.id = q.customer_id::varchar
			WHERE ( #isPlannableSql()#
					OR q.quotation_id IN ( SELECT quotation_id FROM planning_blocks WHERE quotation_id IS NOT NULL ) )
				AND NOT EXISTS ( SELECT 1 FROM planning_project_quotations ppq WHERE ppq.quotation_id = q.quotation_id )
			ORDER BY q.quotation_number, q.version_number
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!--- Ore stimate e pianificate per preventivo e tipo ( preventivi pianificabili ) --->
	<cffunction name="findPlannableQuotationHours" returntype="Query" access="public">
		<cfquery name="local.q" datasource="apirone">
			WITH plannable AS (
				SELECT q.quotation_id
				FROM quotations q
				LEFT JOIN quotation_status_history h ON h.quotation_status_history_id = q.quotation_status_history_id
				WHERE #isPlannableSql()#
				UNION
				SELECT quotation_id FROM planning_blocks WHERE quotation_id IS NOT NULL
				EXCEPT
				SELECT quotation_id FROM planning_project_quotations
			),
			<!--- le ore extra non consumano la stima: a parte --->
			planned AS (
				SELECT
					b.quotation_id,
					b.work_type_id,
					SUM( CASE WHEN b.extra THEN 0 ELSE d.hours END ) AS hours,
					SUM( CASE WHEN b.extra THEN d.hours ELSE 0 END ) AS extra_hours
				FROM planning_blocks b
				JOIN planning_block_days d ON d.block_id = b.block_id
				WHERE b.quotation_id IN ( SELECT quotation_id FROM plannable )
				GROUP BY b.quotation_id, b.work_type_id
			)
			SELECT
				COALESCE( e.quotation_id, p.quotation_id )::varchar AS quotation_id,
				COALESCE( e.work_type_id, p.work_type_id ) AS work_type_id,
				COALESCE( e.hours, 0 ) AS estimated,
				e.budget,
				COALESCE( p.hours, 0 ) AS planned,
				COALESCE( p.extra_hours, 0 ) AS extra
			FROM ( SELECT * FROM quotation_work_hours WHERE quotation_id IN ( SELECT quotation_id FROM plannable ) ) e
			FULL OUTER JOIN planned p ON p.quotation_id = e.quotation_id AND p.work_type_id = e.work_type_id
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Blocchi con almeno un giorno nell'intervallo, con tutti i loro giorni
		( servono inizio, fine e totale del blocco anche fuori dall'intervallo ).
	--->
	<cffunction name="findBlocks" returntype="Query" access="public">
		<cfargument name="fromDate" type="Date" required="true">
		<cfargument name="toDate" type="Date" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				b.block_id,
				<!--- voce del Gantt: il progetto o il preventivo del blocco --->
				COALESCE( b.project_id, b.quotation_id )::varchar AS quotation_id,
				b.user_id::varchar AS user_id,
				b.work_type_id,
				b.use_saturday,
				b.force_holidays,
				b.note,
				b.extra,
				b.locked_at,
				( SELECT COALESCE( NULLIF( lu.user_name, '' ), la.account )
					FROM membership.users lu
					JOIN membership.accounts la ON la.account_id = lu.account_id
					WHERE lu.user_id = b.locked_by ) AS locked_by_name,
				d.day,
				d.hours,
				<!--- ora di inizio nel giorno, in minuti; senza: inizio giornata della persona --->
				EXTRACT( EPOCH FROM COALESCE( d.start_time, u.day_start ) )::int / 60 AS start_minutes
			FROM planning_blocks b
			JOIN planning_block_days d ON d.block_id = b.block_id
			JOIN membership.users u ON u.user_id = b.user_id
			WHERE b.block_id IN (
				SELECT block_id FROM planning_block_days
				WHERE day BETWEEN <cfqueryparam cfsqltype="date" value="#arguments.fromDate#">
					AND <cfqueryparam cfsqltype="date" value="#arguments.toDate#">
			)
			ORDER BY b.block_id, d.day
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Pianificazione automatica: blocchi con almeno un giorno da fromDate in poi,
		con tutti i loro giorni ( il primo giorno dice se il blocco è già iniziato ).
	--->
	<cffunction name="findBlocksFrom" returntype="Query" access="public">
		<cfargument name="fromDate" type="Date" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				b.block_id,
				COALESCE( b.project_id, b.quotation_id )::varchar AS item_id,
				b.user_id::varchar AS user_id,
				b.work_type_id,
				b.extra,
				b.locked_at,
				d.day,
				d.hours,
				EXTRACT( EPOCH FROM COALESCE( d.start_time, u.day_start ) )::int / 60 AS start_minutes
			FROM planning_blocks b
			JOIN planning_block_days d ON d.block_id = b.block_id
			JOIN membership.users u ON u.user_id = b.user_id
			WHERE b.block_id IN (
				SELECT block_id FROM planning_block_days
				WHERE day >= <cfqueryparam cfsqltype="date" value="#arguments.fromDate#">
			)
			ORDER BY b.block_id, d.day
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!--- ======================= Blocchi ======================= --->

	<cffunction name="readPerson" returntype="Query" access="public">
		<cfargument name="userId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				u.user_id::varchar AS user_id,
				(
					SELECT string_agg( pw.work_type_id, ',' )
					FROM planning_person_work_types pw
					WHERE pw.user_id = u.user_id
				) AS work_type_ids,
				u.hours_mon, u.hours_tue, u.hours_wed, u.hours_thu, u.hours_fri, u.hours_sat, u.hours_sun,
				EXTRACT( EPOCH FROM u.day_start )::int / 60 AS day_start_minutes
			FROM membership.users u
			WHERE u.user_id = <cfqueryparam cfsqltype="varchar" value="#arguments.userId#">::uuid
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<cffunction name="readBlock" returntype="Query" access="public">
		<cfargument name="blockId" type="Numeric" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				b.block_id,
				b.quotation_id::varchar AS quotation_id,
				b.project_id::varchar AS project_id,
				b.user_id::varchar AS user_id,
				b.work_type_id,
				b.use_saturday,
				b.force_holidays,
				b.note,
				b.extra,
				b.locked_at,
				b.start_day,
				d.day,
				d.hours,
				EXTRACT( EPOCH FROM COALESCE( d.start_time, u.day_start ) )::int / 60 AS start_minutes
			FROM planning_blocks b
			JOIN membership.users u ON u.user_id = b.user_id
			LEFT JOIN planning_block_days d ON d.block_id = b.block_id
			WHERE b.block_id = <cfqueryparam cfsqltype="integer" value="#arguments.blockId#">
			ORDER BY d.day
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!---
		Pezzi di giornata già pianificati per una persona ( escluso un blocco ):
		giorno, inizio in minuti, ore.
	--->
	<cffunction name="findBookedSegments" returntype="Query" access="public">
		<cfargument name="userId" type="String" required="true">
		<cfargument name="fromDate" type="Date" required="true">
		<cfargument name="toDate" type="Date" required="true">
		<cfargument name="excludeBlockId" type="Numeric" default="0">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				d.day,
				d.hours,
				EXTRACT( EPOCH FROM COALESCE( d.start_time, u.day_start ) )::int / 60 AS start_minutes
			FROM planning_block_days d
			JOIN planning_blocks b ON b.block_id = d.block_id
			JOIN membership.users u ON u.user_id = b.user_id
			WHERE b.user_id = <cfqueryparam cfsqltype="varchar" value="#arguments.userId#">::uuid
				AND d.day BETWEEN <cfqueryparam cfsqltype="date" value="#arguments.fromDate#">
					AND <cfqueryparam cfsqltype="date" value="#arguments.toDate#">
				AND b.block_id <> <cfqueryparam cfsqltype="integer" value="#arguments.excludeBlockId#">
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!--- quotationId oppure projectId ( vincolo planning_blocks_owner_ck ) --->
	<cffunction name="insertBlock" returntype="Numeric" access="public">
		<cfargument name="quotationId" type="String" default="">
		<cfargument name="projectId" type="String" default="">
		<cfargument name="userId" type="String" required="true">
		<cfargument name="workTypeId" type="String" required="true">
		<cfargument name="useSaturday" type="Boolean" default="false">
		<cfargument name="forceHolidays" type="Boolean" default="false">
		<cfargument name="startDay" type="String" default="">
		<cfargument name="note" type="String" default="">
		<cfargument name="extra" type="Boolean" default="false">
		<cfargument name="createdBy" type="String" default="">

		<cfquery name="local.q" datasource="apirone">
			INSERT INTO planning_blocks ( quotation_id, project_id, user_id, work_type_id, use_saturday, force_holidays, start_day, note, extra, created_by )
			VALUES (
				<cfqueryparam cfsqltype="varchar" value="#arguments.quotationId#" null="#!Len( arguments.quotationId )#">::uuid,
				<cfqueryparam cfsqltype="varchar" value="#arguments.projectId#" null="#!Len( arguments.projectId )#">::uuid,
				<cfqueryparam cfsqltype="varchar" value="#arguments.userId#">::uuid,
				<cfqueryparam cfsqltype="varchar" value="#arguments.workTypeId#">,
				<cfqueryparam cfsqltype="boolean" value="#arguments.useSaturday#">,
				<cfqueryparam cfsqltype="boolean" value="#arguments.forceHolidays#">,
				<cfqueryparam cfsqltype="date" value="#arguments.startDay#" null="#!IsDate( arguments.startDay )#">,
				<cfqueryparam cfsqltype="varchar" value="#arguments.note#" null="#!Len( Trim( arguments.note ) )#">,
				<cfqueryparam cfsqltype="boolean" value="#arguments.extra#">,
				<cfqueryparam cfsqltype="varchar" value="#arguments.createdBy#" null="#!Len( arguments.createdBy )#">::uuid
			)
			RETURNING block_id
		</cfquery>

		<cfreturn local.q.block_id>
	</cffunction>

	<cffunction name="updateBlock" returntype="void" access="public">
		<cfargument name="blockId" type="Numeric" required="true">
		<cfargument name="userId" type="String" required="true">
		<cfargument name="useSaturday" type="Boolean" required="true">
		<cfargument name="forceHolidays" type="Boolean" required="true">
		<cfargument name="startDay" type="String" required="true">

		<cfquery datasource="apirone">
			UPDATE planning_blocks SET
				user_id = <cfqueryparam cfsqltype="varchar" value="#arguments.userId#">::uuid,
				use_saturday = <cfqueryparam cfsqltype="boolean" value="#arguments.useSaturday#">,
				force_holidays = <cfqueryparam cfsqltype="boolean" value="#arguments.forceHolidays#">,
				start_day = <cfqueryparam cfsqltype="date" value="#arguments.startDay#" null="#!IsDate( arguments.startDay )#">
			WHERE block_id = <cfqueryparam cfsqltype="integer" value="#arguments.blockId#">
		</cfquery>
	</cffunction>

	<cffunction name="updateBlockExtra" returntype="void" access="public">
		<cfargument name="blockId" type="Numeric" required="true">
		<cfargument name="extra" type="Boolean" required="true">

		<cfquery datasource="apirone">
			UPDATE planning_blocks
			SET extra = <cfqueryparam cfsqltype="boolean" value="#arguments.extra#">
			WHERE block_id = <cfqueryparam cfsqltype="integer" value="#arguments.blockId#">
		</cfquery>
	</cffunction>

	<!--- Lucchetto: userId vuoto lo toglie --->
	<cffunction name="updateBlockLock" returntype="void" access="public">
		<cfargument name="blockId" type="Numeric" required="true">
		<cfargument name="userId" type="String" default="">

		<cfset local.locked = Len( arguments.userId ) GT 0>

		<cfquery datasource="apirone">
			UPDATE planning_blocks SET
				locked_at = <cfif local.locked>NOW()<cfelse>NULL</cfif>,
				locked_by = <cfqueryparam cfsqltype="varchar" value="#arguments.userId#" null="#!local.locked#">::uuid
			WHERE block_id = <cfqueryparam cfsqltype="integer" value="#arguments.blockId#">
		</cfquery>
	</cffunction>

	<cffunction name="updateBlockNote" returntype="void" access="public">
		<cfargument name="blockId" type="Numeric" required="true">
		<cfargument name="note" type="String" required="true">

		<cfquery datasource="apirone">
			UPDATE planning_blocks
			SET note = <cfqueryparam cfsqltype="varchar" value="#Trim( arguments.note )#" null="#!Len( Trim( arguments.note ) )#">
			WHERE block_id = <cfqueryparam cfsqltype="integer" value="#arguments.blockId#">
		</cfquery>
	</cffunction>

	<!--- Sostituisce i giorni del blocco: days [ { day ( yyyy-mm-dd ), hours, start ( minuti, facoltativo ) } ] --->
	<cffunction name="replaceBlockDays" returntype="void" access="public">
		<cfargument name="blockId" type="Numeric" required="true">
		<cfargument name="days" type="Array" required="true">

		<cfquery datasource="apirone">
			DELETE FROM planning_block_days
			WHERE block_id = <cfqueryparam cfsqltype="integer" value="#arguments.blockId#">
		</cfquery>

		<cfloop array="#arguments.days#" item="local.day">
			<cfquery datasource="apirone">
				<cfset local.start = local.day.start ?: "">
				INSERT INTO planning_block_days ( block_id, day, hours, start_time )
				VALUES (
					<cfqueryparam cfsqltype="integer" value="#arguments.blockId#">,
					<cfqueryparam cfsqltype="date" value="#local.day.day#">,
					<cfqueryparam cfsqltype="numeric" scale="2" value="#local.day.hours#">,
					<cfif IsNumeric( local.start )>
						make_time( <cfqueryparam cfsqltype="integer" value="#Int( local.start / 60 )#">, <cfqueryparam cfsqltype="integer" value="#local.start mod 60#">, 0 )
					<cfelse>
						NULL
					</cfif>
				)
			</cfquery>
		</cfloop>
	</cffunction>

	<cffunction name="deleteBlock" returntype="void" access="public">
		<cfargument name="blockId" type="Numeric" required="true">

		<cfquery datasource="apirone">
			DELETE FROM planning_blocks
			WHERE block_id = <cfqueryparam cfsqltype="integer" value="#arguments.blockId#">
		</cfquery>
	</cffunction>

	<!---
		Condizione SQL "preventivo pianificabile" ( alias q = quotations, h =
		quotation_status_history ): attivo e in qualunque stato tranne Perso ( PER )
		ed Estinto ( EST ); senza stato conta come pianificabile. Testo fisso, senza
		input dell'utente.
	--->
	<cffunction name="isPlannableSql" returntype="String" access="private">
		<cfreturn "q.active = 1 AND COALESCE( h.status_id, q._status_id, '' ) NOT IN ( 'PER', 'EST' )">
	</cffunction>

	<!--- ======================= Progetti ======================= --->

	<!---
		Progetti ( nome + rif. libero ): nel Gantt valgono come un preventivo.
		Senza projectId tutti, dal più recente.
	--->
	<cffunction name="findProjects" returntype="Query" access="public">
		<cfargument name="projectId" type="String" default="">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				p.project_id::varchar AS project_id,
				p.name,
				p.rif_libero,
				p.status_id AS planning_status_id,
				p.due_date,
				p.date_type,
				p.priority,
				p.note AS planning_note,
				p.created_at
			FROM planning_projects p
			<cfif Len( arguments.projectId )>
				WHERE p.project_id = <cfqueryparam cfsqltype="varchar" value="#arguments.projectId#">::uuid
			</cfif>
			ORDER BY p.created_at DESC
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!--- Ore stimate e pianificate per progetto e tipo ( come findPlannableQuotationHours ) --->
	<cffunction name="findProjectHours" returntype="Query" access="public">
		<cfquery name="local.q" datasource="apirone">
			WITH planned AS (
				SELECT
					b.project_id,
					b.work_type_id,
					SUM( CASE WHEN b.extra THEN 0 ELSE d.hours END ) AS hours,
					SUM( CASE WHEN b.extra THEN d.hours ELSE 0 END ) AS extra_hours
				FROM planning_blocks b
				JOIN planning_block_days d ON d.block_id = b.block_id
				WHERE b.project_id IS NOT NULL
				GROUP BY b.project_id, b.work_type_id
			)
			SELECT
				COALESCE( e.project_id, p.project_id )::varchar AS project_id,
				COALESCE( e.work_type_id, p.work_type_id ) AS work_type_id,
				COALESCE( e.hours, 0 ) AS estimated,
				e.budget,
				COALESCE( p.hours, 0 ) AS planned,
				COALESCE( p.extra_hours, 0 ) AS extra
			FROM planning_project_work_hours e
			FULL OUTER JOIN planned p ON p.project_id = e.project_id AND p.work_type_id = e.work_type_id
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!--- Preventivi collegati ai progetti, con numero, nome, cliente e stato --->
	<cffunction name="findProjectQuotations" returntype="Query" access="public">
		<cfquery name="local.q" datasource="apirone">
			SELECT
				ppq.project_id::varchar AS project_id,
				q.quotation_id::varchar AS quotation_id,
				q.quotation_number,
				q.version_number,
				q.quotation AS name,
				q.rif_libero,
				h.status_id,
				ca.name AS customer
			FROM planning_project_quotations ppq
			JOIN quotations q ON q.quotation_id = ppq.quotation_id
			LEFT JOIN quotation_status_history h ON h.quotation_status_history_id = q.quotation_status_history_id
			LEFT JOIN crm_accounts ca ON ca.id = q.customer_id::varchar
			ORDER BY q.quotation_number, q.version_number
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<cffunction name="insertProject" returntype="String" access="public">
		<cfargument name="name" type="String" required="true">
		<cfargument name="rifLibero" type="String" default="">
		<cfargument name="createdBy" type="String" default="">

		<cfquery name="local.q" datasource="apirone">
			INSERT INTO planning_projects ( name, rif_libero, created_by )
			VALUES (
				<cfqueryparam cfsqltype="varchar" value="#Trim( arguments.name )#">,
				<cfqueryparam cfsqltype="varchar" value="#Trim( arguments.rifLibero )#" null="#!Len( Trim( arguments.rifLibero ) )#">,
				<cfqueryparam cfsqltype="varchar" value="#arguments.createdBy#" null="#!Len( arguments.createdBy )#">::uuid
			)
			RETURNING project_id::varchar AS project_id
		</cfquery>

		<cfreturn local.q.project_id>
	</cffunction>

	<cffunction name="updateProject" returntype="void" access="public">
		<cfargument name="projectId" type="String" required="true">
		<cfargument name="name" type="String" required="true">
		<cfargument name="rifLibero" type="String" default="">

		<cfquery datasource="apirone">
			UPDATE planning_projects SET
				name = <cfqueryparam cfsqltype="varchar" value="#Trim( arguments.name )#">,
				rif_libero = <cfqueryparam cfsqltype="varchar" value="#Trim( arguments.rifLibero )#" null="#!Len( Trim( arguments.rifLibero ) )#">
			WHERE project_id = <cfqueryparam cfsqltype="varchar" value="#arguments.projectId#">::uuid
		</cfquery>
	</cffunction>

	<!--- Elimina il progetto con le sue ore, i collegamenti e i blocchi ( ON DELETE CASCADE ) --->
	<cffunction name="deleteProject" returntype="void" access="public">
		<cfargument name="projectId" type="String" required="true">

		<cfquery datasource="apirone">
			DELETE FROM planning_projects
			WHERE project_id = <cfqueryparam cfsqltype="varchar" value="#arguments.projectId#">::uuid
		</cfquery>
	</cffunction>

	<cffunction name="countProjectBlocks" returntype="Numeric" access="public">
		<cfargument name="projectId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT COUNT(*) AS n
			FROM planning_blocks
			WHERE project_id = <cfqueryparam cfsqltype="varchar" value="#arguments.projectId#">::uuid
		</cfquery>

		<cfreturn local.q.n>
	</cffunction>

	<!--- budget: stringa vuota = nessun budget --->
	<cffunction name="saveProjectWorkHours" returntype="void" access="public">
		<cfargument name="projectId" type="String" required="true">
		<cfargument name="workTypeId" type="String" required="true">
		<cfargument name="hours" type="Numeric" required="true">
		<cfargument name="budget" type="String" default="">

		<cfquery datasource="apirone">
			INSERT INTO planning_project_work_hours ( project_id, work_type_id, hours, budget )
			VALUES (
				<cfqueryparam cfsqltype="varchar" value="#arguments.projectId#">::uuid,
				<cfqueryparam cfsqltype="varchar" value="#arguments.workTypeId#">,
				<cfqueryparam cfsqltype="numeric" scale="2" value="#arguments.hours#">,
				<cfqueryparam cfsqltype="numeric" scale="2" value="#Val( arguments.budget )#" null="#!IsNumeric( arguments.budget )#">
			)
			ON CONFLICT ( project_id, work_type_id ) DO UPDATE
				SET hours = EXCLUDED.hours, budget = EXCLUDED.budget, updated_at = NOW()
		</cfquery>
	</cffunction>

	<!--- Pianificazione del progetto: come saveQuotationPlanning --->
	<cffunction name="saveProjectPlanning" returntype="void" access="public">
		<cfargument name="projectId" type="String" required="true">
		<cfargument name="planning" type="Struct" required="true">
		<cfargument name="userId" type="String" default="">

		<cfset local.p = arguments.planning>
		<cfset local.done = local.p.statusId == "CLS">

		<cfquery datasource="apirone">
			UPDATE planning_projects SET
				status_id = <cfqueryparam cfsqltype="varchar" value="#local.p.statusId#">,
				due_date = <cfqueryparam cfsqltype="date" value="#local.p.dueDate#" null="#!IsDate( local.p.dueDate )#">,
				date_type = <cfqueryparam cfsqltype="varchar" value="#local.p.dateType#" null="#!Len( local.p.dateType )#">,
				priority = <cfqueryparam cfsqltype="varchar" value="#local.p.priority#" null="#!Len( local.p.priority )#">,
				note = <cfqueryparam cfsqltype="longvarchar" value="#local.p.note#" null="#!Len( local.p.note )#">,
				completed_at = <cfif local.done>COALESCE( completed_at, NOW() )<cfelse>NULL</cfif>,
				completed_by = <cfif local.done>COALESCE( completed_by, <cfqueryparam cfsqltype="varchar" value="#arguments.userId#" null="#!Len( arguments.userId )#">::uuid )<cfelse>NULL</cfif>
			WHERE project_id = <cfqueryparam cfsqltype="varchar" value="#arguments.projectId#">::uuid
		</cfquery>
	</cffunction>

	<!---
		Stato di pianificazione di una voce del Gantt ( progetto o preventivo ):
		COR / CLS / SOS / DAP; un preventivo mai impostato è "Da programmare".
	--->
	<cffunction name="findPlanningStatus" returntype="String" access="public">
		<cfargument name="itemId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT status_id FROM planning_projects
			WHERE project_id = <cfqueryparam cfsqltype="varchar" value="#arguments.itemId#">::uuid
			UNION ALL
			SELECT COALESCE( ( SELECT pq.status_id FROM planning_quotations pq WHERE pq.quotation_id = q.quotation_id ), 'DAP' )
			FROM quotations q
			WHERE q.quotation_id = <cfqueryparam cfsqltype="varchar" value="#arguments.itemId#">::uuid
		</cfquery>

		<cfreturn local.q.recordCount ? local.q.status_id : "">
	</cffunction>

	<!--- Progetto a cui è collegato il preventivo ( stringa vuota: nessuno ) --->
	<cffunction name="findQuotationProjectId" returntype="String" access="public">
		<cfargument name="quotationId" type="String" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT project_id::varchar AS project_id
			FROM planning_project_quotations
			WHERE quotation_id = <cfqueryparam cfsqltype="varchar" value="#arguments.quotationId#">::uuid
		</cfquery>

		<cfreturn local.q.recordCount ? local.q.project_id : "">
	</cffunction>

	<!---
		Collega il preventivo al progetto e gli passa i blocchi del preventivo:
		nel Gantt il preventivo collegato c'è solo tramite il progetto.
	--->
	<cffunction name="linkQuotation" returntype="void" access="public">
		<cfargument name="projectId" type="String" required="true">
		<cfargument name="quotationId" type="String" required="true">

		<cfquery datasource="apirone">
			INSERT INTO planning_project_quotations ( quotation_id, project_id )
			VALUES (
				<cfqueryparam cfsqltype="varchar" value="#arguments.quotationId#">::uuid,
				<cfqueryparam cfsqltype="varchar" value="#arguments.projectId#">::uuid
			)
		</cfquery>

		<cfquery datasource="apirone">
			UPDATE planning_blocks SET
				project_id = <cfqueryparam cfsqltype="varchar" value="#arguments.projectId#">::uuid,
				quotation_id = NULL
			WHERE quotation_id = <cfqueryparam cfsqltype="varchar" value="#arguments.quotationId#">::uuid
		</cfquery>
	</cffunction>

	<!--- Scollega il preventivo ( i blocchi già passati al progetto restano al progetto ) --->
	<cffunction name="unlinkQuotation" returntype="void" access="public">
		<cfargument name="projectId" type="String" required="true">
		<cfargument name="quotationId" type="String" required="true">

		<cfquery datasource="apirone">
			DELETE FROM planning_project_quotations
			WHERE quotation_id = <cfqueryparam cfsqltype="varchar" value="#arguments.quotationId#">::uuid
				AND project_id = <cfqueryparam cfsqltype="varchar" value="#arguments.projectId#">::uuid
		</cfquery>
	</cffunction>

	<!--- Revisione: la nuova versione resta nel progetto della precedente --->
	<cffunction name="copyProjectLink" returntype="void" access="public">
		<cfargument name="fromQuotationId" type="String" required="true">
		<cfargument name="toQuotationId" type="String" required="true">

		<cfquery datasource="apirone">
			INSERT INTO planning_project_quotations ( quotation_id, project_id )
			SELECT <cfqueryparam cfsqltype="varchar" value="#arguments.toQuotationId#">::uuid, project_id
			FROM planning_project_quotations
			WHERE quotation_id = <cfqueryparam cfsqltype="varchar" value="#arguments.fromQuotationId#">::uuid
			ON CONFLICT ( quotation_id ) DO NOTHING
		</cfquery>
	</cffunction>

	<!---
		Preventivi da collegare a un progetto: ricerca per numero ( anche
		"123/2" ), nome, rif. libero o cliente, qualunque stato. project_id: il
		progetto a cui è già collegato ( vuoto: nessuno ).
	--->
	<cffunction name="searchQuotations" returntype="Query" access="public">
		<cfargument name="str" type="String" required="true">
		<cfargument name="limit" type="Numeric" default="20">

		<cfset local.str = Trim( arguments.str )>
		<cfset local.number = ListFirst( local.str, "/" )>
		<cfset local.version = ListLen( local.str, "/" ) GT 1 ? ListGetAt( local.str, 2, "/" ) : "">

		<cfquery name="local.q" datasource="apirone">
			SELECT
				q.quotation_id::varchar AS quotation_id,
				q.quotation_number,
				q.version_number,
				q.quotation AS name,
				q.rif_libero,
				h.status_id,
				ca.name AS customer,
				ppq.project_id::varchar AS project_id
			FROM quotations q
			LEFT JOIN quotation_status_history h ON h.quotation_status_history_id = q.quotation_status_history_id
			LEFT JOIN crm_accounts ca ON ca.id = q.customer_id::varchar
			LEFT JOIN planning_project_quotations ppq ON ppq.quotation_id = q.quotation_id
			WHERE
				<cfif IsNumeric( local.number )>
					(
						q.quotation_number::varchar = <cfqueryparam cfsqltype="varchar" value="#local.number#">
						<cfif IsNumeric( local.version )>
							AND q.version_number::varchar = <cfqueryparam cfsqltype="varchar" value="#local.version#">
						</cfif>
					)
					OR
				</cfif>
				q.quotation ILIKE <cfqueryparam cfsqltype="varchar" value="%#local.str#%">
				OR q.rif_libero ILIKE <cfqueryparam cfsqltype="varchar" value="%#local.str#%">
				OR ca.name ILIKE <cfqueryparam cfsqltype="varchar" value="%#local.str#%">
			ORDER BY q.quotation_number DESC, q.version_number DESC
			LIMIT <cfqueryparam cfsqltype="integer" value="#arguments.limit#">
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<!--- ======================= Chiusure aziendali ======================= --->

	<cffunction name="findClosures" returntype="Query" access="public">
		<cfargument name="fromDate" type="Date" required="true">
		<cfargument name="toDate" type="Date" required="true">

		<cfquery name="local.q" datasource="apirone">
			SELECT closure_id, day, description
			FROM planning_closures
			WHERE day BETWEEN <cfqueryparam cfsqltype="date" value="#arguments.fromDate#">
				AND <cfqueryparam cfsqltype="date" value="#arguments.toDate#">
			ORDER BY day
		</cfquery>

		<cfreturn local.q>
	</cffunction>

	<cffunction name="saveClosure" returntype="void" access="public">
		<cfargument name="day" type="Date" required="true">
		<cfargument name="description" type="String" default="">

		<cfquery datasource="apirone">
			INSERT INTO planning_closures ( day, description )
			VALUES (
				<cfqueryparam cfsqltype="date" value="#arguments.day#">,
				<cfqueryparam cfsqltype="varchar" value="#arguments.description#">
			)
			ON CONFLICT ( day ) DO UPDATE SET description = EXCLUDED.description
		</cfquery>
	</cffunction>

	<cffunction name="deleteClosure" returntype="void" access="public">
		<cfargument name="closureId" type="Numeric" required="true">

		<cfquery datasource="apirone">
			DELETE FROM planning_closures
			WHERE closure_id = <cfqueryparam cfsqltype="integer" value="#arguments.closureId#">
		</cfquery>
	</cffunction>

</cfcomponent>
