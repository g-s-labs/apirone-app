-- Pianificazione ( Gantt ), dopo 2026-10-12_gui_planning_projects.sql:
-- 1. tipologie di attività su DB ( prima config/data/workTypes.json.cfm ),
--    sostituite dalle nuove; Montaggio mantiene il codice MON. Ore stimate e
--    blocchi delle tipologie eliminate si cancellano;
-- 2. una persona può avere più tipologie ( prima users.work_type_id );
-- 3. per ogni preventivo / progetto del Gantt: stato della pianificazione
--    ( al posto di concluso sì / no ), data con tipo ( richiesta / tassativa ),
--    priorità e note. Per i preventivi la data è la "data prevista evasione"
--    ( quotations.data_evasione ): qui se ne salva solo il tipo.

-- ======================= 1. Tipologie di attività =======================

CREATE TABLE planning_work_types (
	work_type_id VARCHAR(3) PRIMARY KEY,
	name VARCHAR(100) NOT NULL,
	color VARCHAR(7) NOT NULL,
	orderby INTEGER NOT NULL DEFAULT 0
);

INSERT INTO planning_work_types ( work_type_id, name, color, orderby ) VALUES
	( 'WAY', 'Wayfinding',         '#2f9e44', 10 ),
	( 'CNC', 'Concept',            '#0c8599', 20 ),
	( 'PRG', 'Progetto',           '#2771e8', 30 ),
	( 'SIC', 'Sicurezza',          '#495057', 40 ),
	( 'PPL', 'Progetto placche',   '#7048e8', 50 ),
	( 'S3D', 'Stampe 3D',          '#f08c00', 60 ),
	( 'PEV', 'Piante evacuazione', '#d6336c', 70 ),
	( 'SOP', 'Sopralluogo',        '#5c940d', 80 ),
	( 'MON', 'Montaggio',          '#e8590c', 90 );

-- dati delle tipologie eliminate ( COM, DIS, PRD, AMM, ALT )
DELETE FROM quotation_work_hours WHERE work_type_id NOT IN ( SELECT work_type_id FROM planning_work_types );
DELETE FROM planning_project_work_hours WHERE work_type_id NOT IN ( SELECT work_type_id FROM planning_work_types );
DELETE FROM planning_blocks WHERE work_type_id NOT IN ( SELECT work_type_id FROM planning_work_types );

ALTER TABLE quotation_work_hours ADD CONSTRAINT quotation_work_hours_work_type_fk
	FOREIGN KEY ( work_type_id ) REFERENCES planning_work_types ( work_type_id ) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE planning_project_work_hours ADD CONSTRAINT planning_project_work_hours_work_type_fk
	FOREIGN KEY ( work_type_id ) REFERENCES planning_work_types ( work_type_id ) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE planning_blocks ADD CONSTRAINT planning_blocks_work_type_fk
	FOREIGN KEY ( work_type_id ) REFERENCES planning_work_types ( work_type_id ) ON UPDATE CASCADE ON DELETE CASCADE;

-- ======================= 2. Tipologie delle persone =======================

-- una persona si pianifica se ha almeno una tipologia
CREATE TABLE planning_person_work_types (
	user_id UUID NOT NULL REFERENCES membership.users ( user_id ) ON UPDATE CASCADE ON DELETE CASCADE,
	work_type_id VARCHAR(3) NOT NULL REFERENCES planning_work_types ( work_type_id ) ON UPDATE CASCADE ON DELETE CASCADE,
	PRIMARY KEY ( user_id, work_type_id )
);

INSERT INTO planning_person_work_types ( user_id, work_type_id )
SELECT user_id, work_type_id
FROM membership.users
WHERE work_type_id IN ( SELECT work_type_id FROM planning_work_types );

ALTER TABLE membership.users DROP COLUMN work_type_id;

-- ======================= 3. Stato, data, priorità e note =======================

-- status_id: COR in corso, CLS concluso, SOS in sospeso, DAP da programmare
--   ( a sospesi e da programmare non si assegnano persone; i conclusi escono dal Gantt );
-- date_type: RIC data richiesta, TAS data tassativa; priority: A urgente, B mediamente urgente, C non urgente.
-- Preventivi: una riga in planning_quotations solo se impostati; senza riga valgono i default.
ALTER TABLE planning_quotations ADD COLUMN status_id VARCHAR(3) NOT NULL DEFAULT 'DAP';
ALTER TABLE planning_quotations ADD COLUMN date_type VARCHAR(3) NULL;
ALTER TABLE planning_quotations ADD COLUMN priority VARCHAR(1) NULL;
ALTER TABLE planning_quotations ADD COLUMN note TEXT NULL;
ALTER TABLE planning_quotations ADD CONSTRAINT planning_quotations_status_ck CHECK ( status_id IN ( 'COR', 'CLS', 'SOS', 'DAP' ) );
ALTER TABLE planning_quotations ADD CONSTRAINT planning_quotations_date_type_ck CHECK ( date_type IN ( 'RIC', 'TAS' ) );
ALTER TABLE planning_quotations ADD CONSTRAINT planning_quotations_priority_ck CHECK ( priority IN ( 'A', 'B', 'C' ) );

ALTER TABLE planning_projects ADD COLUMN status_id VARCHAR(3) NOT NULL DEFAULT 'DAP';
ALTER TABLE planning_projects ADD COLUMN due_date DATE NULL;
ALTER TABLE planning_projects ADD COLUMN date_type VARCHAR(3) NULL;
ALTER TABLE planning_projects ADD COLUMN priority VARCHAR(1) NULL;
ALTER TABLE planning_projects ADD COLUMN note TEXT NULL;
ALTER TABLE planning_projects ADD CONSTRAINT planning_projects_status_ck CHECK ( status_id IN ( 'COR', 'CLS', 'SOS', 'DAP' ) );
ALTER TABLE planning_projects ADD CONSTRAINT planning_projects_date_type_ck CHECK ( date_type IN ( 'RIC', 'TAS' ) );
ALTER TABLE planning_projects ADD CONSTRAINT planning_projects_priority_ck CHECK ( priority IN ( 'A', 'B', 'C' ) );

-- ciò che era già in pianificazione resta in corso, i conclusi diventano conclusi
UPDATE planning_quotations SET status_id = CASE WHEN completed_at IS NOT NULL THEN 'CLS' ELSE 'COR' END;
UPDATE planning_projects SET status_id = CASE WHEN completed_at IS NOT NULL THEN 'CLS' ELSE 'COR' END;

-- preventivi con blocchi ma senza riga: in corso
INSERT INTO planning_quotations ( quotation_id, status_id )
SELECT DISTINCT quotation_id, 'COR'
FROM planning_blocks
WHERE quotation_id IS NOT NULL
ON CONFLICT ( quotation_id ) DO NOTHING;
