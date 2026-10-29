-- Note di trasporto del preventivo ( max 20 caratteri ): si scrivono dal riquadro dei totali, accanto
-- alle spese di trasporto, e si stampano sotto di esse. Non vanno a Verticale.
ALTER TABLE quotations ADD COLUMN note_trasporto VARCHAR(20) NULL;
