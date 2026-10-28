-- Codici IVA selezionabili nella testata del preventivo ( colonna active ).
--
-- verticale_vat_codes è la copia di codiva di Verticale. La sincronizzazione ( VerticaleSyncDAO.syncVatCodes /
-- VerticaleSyncService::syncVatCodes ) aggiorna descrizione e percentuale e non tocca active: un codice nuovo
-- arriva non attivo, uno eliminato in Verticale sparisce. Per attivare o disattivare un codice basta un UPDATE.
-- I preventivi con un codice non attivo lo tengono ( la tendina del preventivo aperto lo mostra comunque ).

ALTER TABLE verticale_vat_codes ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT false;

UPDATE verticale_vat_codes
SET active = ( TRIM( ivacod ) IN ( '201', '202', '203', '204', '205', '222', '223', '300', '400', '500' ) );
