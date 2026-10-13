-- Progetti della pianificazione ( Gantt ), dopo 2026-10-08_gui_planning.sql:
-- un progetto ( nome + rif. libero ) compare nel Gantt come un preventivo, con
-- ore stimate e budget propri per attività. Può raggruppare zero o più
-- preventivi: un preventivo collegato non compare più da solo nel Gantt e, al
-- collegamento, i suoi blocchi passano al progetto.

CREATE TABLE planning_projects (
	project_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	name VARCHAR(255) NOT NULL,
	rif_libero VARCHAR(255) NULL,
	-- concluso: non compare più tra quelli da pianificare
	completed_at TIMESTAMP NULL,
	completed_by UUID NULL,
	created_at TIMESTAMP NOT NULL DEFAULT NOW(),
	created_by UUID NULL
);

-- Preventivi collegati: un preventivo sta al massimo in un progetto
CREATE TABLE planning_project_quotations (
	quotation_id UUID PRIMARY KEY REFERENCES quotations ( quotation_id ) ON UPDATE CASCADE ON DELETE CASCADE,
	project_id UUID NOT NULL REFERENCES planning_projects ( project_id ) ON UPDATE CASCADE ON DELETE CASCADE,
	created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
CREATE INDEX planning_project_quotations_project_idx ON planning_project_quotations ( project_id );

-- Ore di attività stimate e budget del progetto, una riga per tipo ( come quotation_work_hours )
CREATE TABLE planning_project_work_hours (
	project_id UUID NOT NULL REFERENCES planning_projects ( project_id ) ON UPDATE CASCADE ON DELETE CASCADE,
	work_type_id VARCHAR(3) NOT NULL,
	hours NUMERIC(7,2) NOT NULL DEFAULT 0,
	budget NUMERIC(10,2) NULL,
	updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
	PRIMARY KEY ( project_id, work_type_id )
);

-- Un blocco è di un preventivo oppure di un progetto
ALTER TABLE planning_blocks ALTER COLUMN quotation_id DROP NOT NULL;
ALTER TABLE planning_blocks ADD COLUMN project_id UUID NULL REFERENCES planning_projects ( project_id ) ON UPDATE CASCADE ON DELETE CASCADE;
ALTER TABLE planning_blocks ADD CONSTRAINT planning_blocks_owner_ck CHECK ( num_nonnulls( quotation_id, project_id ) = 1 );
CREATE INDEX planning_blocks_project_idx ON planning_blocks ( project_id );
