-- Pianificazione ( Calendario ), dopo 2026-10-13_gui_planning_work_types_and_status.sql:
-- 1. data della pianificazione anche per i preventivi, modificabile ( prima era
--    la "data prevista evasione" del preventivo, in sola lettura );
-- 2. lucchetto sui blocchi: un blocco bloccato non si sposta né si modifica
--    ( lo toglie solo un ADM ).

ALTER TABLE planning_quotations ADD COLUMN due_date DATE NULL;

ALTER TABLE planning_blocks ADD COLUMN locked_at TIMESTAMP NULL;
ALTER TABLE planning_blocks ADD COLUMN locked_by UUID NULL REFERENCES membership.users ( user_id ) ON UPDATE CASCADE ON DELETE SET NULL;
