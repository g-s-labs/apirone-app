{

    header: {
        company: {
            name: "APIR",
            phone: "378/962211",
            email: "info@apir.com",
            vat: "SM 07240",
            address: "Via Prato delle Valli,58",
            city: "San Marino",
            county: "SM",
            country: {
                code: "RSM"
            },
            bankAccount: {
                bank: {
                    name: "CREDIT AGRICOLE",
                    description: "C/C 000030727461 – ABI 06230 – CAB 68102"
                },
                iban: "IT 44 G 06230 68102 0000 3072 7461",
                bic: "CRPPIT2P718"
            }
        },
        currency: "EUR",
        date: "2024-05-20",
        validUntil: "2024-06-20",
        number: "59336/2",
        project: {
            name: "Segnaletica in acciaio inox inossidabile 316 + finitura a polvere."
        },
        customer: {
            name: "BORGHI VALERIA",
            phone: "393477107657",
            email: "valeriaborghi@acqstudio.com",
            vat: "077000001",
            address: "Via Andrea Del Castagno, 34",
            city: "Firenze",
            county: "FM",
            country: {
                code: "ID"
            },
            shipment: {
                name: "BORGHI VALERIA",
                phone: "393477107657",
                address: "Via Andrea Del Castagno 34",
                city: "Firenze",
                county: "FM",
                country: {
                    code: "ID"
                },
            },
            contactPerson: {
                name: "Cristina Pancotti",
                email: "cristina@apir.com"
            }
        }
    },

    rows: [

        groups: [ 
            {
                id: "",
                name: "Camere",
                products: [
                    {
                        image: {
                            url: "https://placehold.co/600x400.jpg"
                        },                        
                        code:"SAV1",
                        name: "Targa con 1 riga di testo",
                        description: "Speciale",
                        quantity: 6,
                        price: 37,
                        total: 222,
                        references: [ "RIF 1+ 9 + 11 +19 + 20A + 38" ]
                    },
                    {
                        image: {
                            url: "https://placehold.co/600x400.jpg"
                        },                        
                        code:"MAP-A3",
                        name: "Cornice portainformazioni A3 -planimetria non inclusa",
                        description: "Speciale",
                        quantity: 8,
                        price: 21,
                        total: 105,
                        references: [""]
                    }
                ]
            },
            {
                id: "",
                name: "PIANO 2",
                products: [
                    {
                        image: {
                            url: "https://placehold.co/600x400.jpg"
                        },                        
                        code:"SAV3",
                        name: "Cod. SAV3 Targa con 3 righe di testo",
                        description: "Speciale",
                        quantity: 19,
                        price: 91.50,
                        total: 1738.50,
                        references: [ "RIF 2 + 3 + 7 + 16 +18(X3) + 20 + 21 + 26 + 28 + 30 + 32 + 34 +35 + 42 + 44 + 48 +50" ]
                    },
                    {
                        image: {
                            url: "https://placehold.co/600x400.jpg"
                        },                        
                        code:"SAVLET",
                        name: "Scritta ritagliata per porta, massimo 10 caratteri",
                        description: "Speciale",
                        quantity: 4,
                        price: 22.50,
                        total: 90,
                        references: [ "RIF 6 (4x) Private" ]
                    }
                ]
            },
            {
                id: "",
                name: "ESTERNO",
                products: [
                    {
                        image: {
                            url: "https://placehold.co/200x600.jpg"
                        },                        
                        code:"PICTO2",
                        name: "Cod. PICTO2 - Simbolo Ritagliato",
                        description: "Speciale",
                        quantity: 4,
                        price: 19,
                        total: 76,
                        references: [
                            "RIF 7 (2x)",
                            "RIF 66 (2x)"
                        ]
                    },
                ]
            },
            {
                id: "",
                name: "SERVIZI",
                products: [
                    {
                        image: {
                            url: "https://placehold.co/200x600.jpg"
                        },                        
                        code:"PROGETTO",
                        name: "Progetto",
                        description: "Base",
                        quantity: 1,
                        price: 3500,
                        total: 3500,
                        references: [
                            "Progetto di Wayfinding e presentazione linea dedicata, ideati dal nostro studio interno per la segnaletica personalizzata del vostro Resort.",
                            "Tale servizio include un accurato studio delle planimetrie, presentazione puntuale di proposte di linea per il Front of House , Back of House e Sicurezza",
                            "Il tutto verrà corredato di capitolato specifico con disegni, quantità, dettagli, simboli, testi e posizionamenti di ogni insegna.",
                            "Le indicazioni saranno appositamente studiate e perfezionate tramite sopralluogo in loco di un nostro tecnico, pertanto risulteranno puntuali e semplici per il facile orientamento all'interno del resort."
                        ]
                    }
                ]
            }
            
        ]

    ],

    footer: {
        totalGoods: 60750.40,
        vat: {
            name: "Imposta esente",
            value: 0
        },
        total:  120,
        discount: {
            name: "Sconto 10%",
            value: "3%"
        },
        shipment: {
            name: "Spedizione 6/8 Settimane" 
        },
        payment: {
            name: "Da definire",
        },
        note: "Installazione/posa in opera non compresa se non espressamente indicato."
    }    

}