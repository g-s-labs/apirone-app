-- Pianificazione automatica ( Calendario ), dopo 2026-10-16_gui_planning_due_date_and_lock.sql:
-- 1. priorità di una persona su una tipologia di attività ( numero, più basso =
--    più alta; vuota = dopo quelle numerate ): la pianificazione automatica dà
--    le ore alla persona libera con la priorità più alta;
-- 2. le voci con data tassativa non hanno priorità ( vengono comunque per prime ).

ALTER TABLE planning_person_work_types ADD COLUMN priority INTEGER NULL;
ALTER TABLE planning_person_work_types ADD CONSTRAINT planning_person_work_types_priority_ck CHECK ( priority >= 1 );

UPDATE planning_quotations SET priority = NULL WHERE date_type = 'TAS';
UPDATE planning_projects SET priority = NULL WHERE date_type = 'TAS';
