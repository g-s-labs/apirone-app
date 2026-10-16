-- Ordinamento "naturale" dei codici ( es. posizioni A1, A2, A10, B1 ): i numeri
-- dentro il testo si confrontano come numeri, maiuscole e minuscole uguali.
-- Si usa con ORDER BY campo COLLATE natural_sort ( righe del preventivo per posizione ).
CREATE COLLATION IF NOT EXISTS natural_sort ( provider = icu, locale = 'und-u-kn-true-ks-level2', deterministic = false );
