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
        number: "P.644/4",
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
                county: "FI",
                country: {
                    code: "IT"
                },
            }
        }
    },
    rows: [
        {
            product: {
                attributes: [
                    {
                        "finitura": "Ottone Industriale"
                    },
                    {
                        "colore": "Rosso"
                    },
                    {
                        "profilo": "Taglio Diritto"
                    },
                    {
                        "fissaggio": "Calamite"
                    },
                    {
                        "forma": "Rotonda"
                    }
                ],
                note: "COD.1 - FINITURA OTTONE CRUDO",
                image: {
                    url: "https://placehold.co/500x500.jpg"
                },
                quantity: 1,
                price: 10.5,
                total: 10.5
            },
            fruits: [ 
                {
                    id: "4.0-2",
                    name: "Deviatore a levetta - 1p 10ax",
                    description: "Finitura:Ottone satinato - Incisione Frutto:No - Forma Levetta:AVIO -",
                    position: "CUCINA/1"
                },
                {
                    id: "4.0-2",
                    name: "VerniciatoColore:Nero",
                    description: "Profilo:Taglio Diritto - Fissaggio:Calamite - Incisione Logo:No - Forma:Rettangolare - Orientamento:Orizzontale",
                    note: "PRESA NASCOSTE IN",
                    position: "CUCINA/2"
                }
            ],
            positions: [ 
                {
                    name: "01",
                    zone: {
                        id: "01_CUCINA"
                    }
                },
            ]
        },
        {
            product: {
                attributes: [
                    {
                        "finitura": "Ottone Industriale"
                    },
                    {
                        "colore": "Rosso"
                    },
                    {
                        "profilo": "Taglio Diritto"
                    },
                    {
                        "fissaggio": "Calamite"
                    },
                    {
                        "forma": "Rotonda"
                    }
                ],
                note: "COD.1 - FINITURA OTTONE CRUDO",
                image: {
                    url: "https://placehold.co/500x500.jpg"
                },
                quantity: 1,
                price: 10.5,
                total: 10.5
            },
            fruits: [ 
                {
                    id: "4.0-2",
                    name: "Deviatore a levetta - 1p 10ax",
                    description: "Finitura:Ottone satinato - Incisione Frutto:No - Forma Levetta:AVIO",
                    position: "CUCINA/1"
                },
                {
                    id: "4.0-2",
                    name: "VerniciatoColore:Nero",
                    description: "Profilo:Taglio Diritto - Fissaggio:Calamite - Incisione Logo:No - Forma:Rettangolare - Orientamento:Orizzontale",
                    note: "PRESA NASCOSTE IN",
                    position: "CUCINA/2"
                }
            ],
            positions: [ 
                {
                    name: "03",
                    zone: {
                        id: "01_CUCINA"
                    }
                },
            ]

        },

        {
            product: {
                code: "4.0-3",
                attributes: [
                    {
                        "finitura": "Verniciato"
                    },
                    {
                        "colore": "Nero"
                    },
                    {
                        "profilo": "Taglio Diritto"
                    },
                    {
                        "fissaggio": "Calamite"
                    },
                    {
                        "orientamento": "Orizzonale"
                    }
                ],
                note: "COD.1 - FINITURA OTTONE CRUDO",
                image: {
                    url: "https://placehold.co/500x500.jpg"
                },
                quantity: 1,
                price: 10.5,
                total: 10.5
            },
            fruits: [ 
                {
                    id: "4.0-2",
                    name: "Deviatore a levetta - 1p 10ax",
                    description: "Finitura:Ottone satinato - Incisione Frutto:No - Forma Levetta:AVIO",
                    position: "CUCINA/1"
                },
                {
                    id: "4.0-2",
                    name: "VerniciatoColore:Nero",
                    description: "Profilo:Taglio Diritto - Fissaggio:Calamite - Incisione Logo:No - Forma:Rettangolare - Orientamento:Orizzontale",
                    note: "PRESA NASCOSTE IN",
                    position: "CUCINA/2"
                }
            ],
            positions: [ 
                {
                    name: "03",
                    zone: {
                        id: "01_CUCINA"
                    }
                },
            ]

        }        
    ],


    footer: {
        totalGoods: 100,
        vat: {
            name: "Imposta 20%",
            value: 30
        },
        total:  120,
        discount: {
            name: "Sconto 50%",
            value: "50%"
        },
        shipment: {
            name: "Spedizione 6/8 Settimane",
            price: "520"
        },
        payment: {
            name: "30% anticipo-saldo da definire" 
        }
    }

}