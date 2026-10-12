[
	{
		href: "/manager/dashboard",
		icon: "bx bx-home-alt",
		title: "Dashboard",
		roles: "ALL",
	},
	{
		href: "#",
		icon: "fas fa-comment-dollar",
		title: "Preventivi",
		items: [
			{
				href: "/manager/quotations",
				icon: "fas fa-list",
				title: "Elenco",
			},
			{
				href: "/manager/quotations/new",
				icon: "fas fa-plus",
				title: "Nuovo preventivo",
			},
		]

	},
	{
		href: "#",
		icon: "fas fa-plug",
		title: "Prodotti",
		items: [
			{
				href: "/manager/fruits",
				icon: "fas fa-apple-alt",
				title: "Prodotti base",
			},
			{
				href: "/manager/products",
				icon: "fas fa-vector-square",
				title: "Prodotti complessi",
			},
			{
				href: "/manager/lines/categories",
				icon: "fas fa-bezier-curve",
				title: "Prodotti per linea",
			},

			{
				href: "/manager/articles",
				icon: "far fa-lemon",
				title: "Servizi",
			},
		]
	},
	{
		href: "#",
		icon: "fas fa-cogs",
		title: "Configurazioni",
		roles: "ADM",
		items: [
			{
				href: "/manager/countries",
				icon: "fas fa-globe-europe",
				title: "Nazioni",
			},
			{
				href: "/manager/product-categories",
				icon: "fas fa-stream",
				title: "Categorie prodotti",
			},
			{
				href: "/manager/lines",
				icon: "fas fa-layer-group",
				title: "Linee",
			},
			{
				href: "/manager/models",
				icon: "fas fa-expand-alt",
				title: "Modelli",
			},
			{
				href: "/manager/catalog-bundles",
				icon: "fas fa-palette",
				title: "Bundle catalogo",
			},
			{
				href: "/manager/finishes",
				icon: "fas fa-palette",
				title: "Finiture",
			},
			{
				href: "/manager/frames",
				icon: "fas fa-shield-alt",
				title: "Armature",
			},
			{
				href: "/manager/raw-values",
				icon: "fas fa-palette",
				title: "Valori base",
			},
			{
				href: "/manager/attributes",
				icon: "fas fa-external-link-square-alt",
				title: "Attributi e valori",
			},
			{
				href: "/manager/prices/types",
				icon: "fas fa-dollar-sign",
				title: "Tipo prezzi",
			},
			{
				href: "/manager/production-times",
				icon: "fas fa-clock",
				title: "Tempi di produzione",
			},
			{
				href: "/manager/fonts",
				icon: "fas fa-font",
				title: "Font",
			},
			{
				href: "/manager/font-families",
				icon: "fas fa-font",
				title: "Font Family",
			},
			{
				href: "/manager/lines/costs",
				icon: "fas fa-cogs",
				title: "Costi per linea/finitura",
			},
			{
				href: "/manager/lines/model-costs",
				icon: "fas fa-cogs",
				title: "Costi per linea/modello",
			},
			{
				href: "/manager/metadata-types",
				icon: "fas fa-fan",
				title: "Metadata",
			},
			{
				href: "/manager/global-metadata",
				icon: "fas fa-cogs",
				title: "Setting generali",
			},
			{
				href: "/manager/texts",
				icon: "fas fa-language",
				title: "Traduzioni",
			},
			{
				href: "/manager/reports",
				icon: "fas fa-print",
				title: "Report",
			},
			{
				href: "/manager/frames",
				icon: "fas fa-border-all",
				title: "Configurazione placche",
			},
		]

	},
	{
		href: "#",
		icon: "fas fa-users",
		title: "Utenze",
		roles: "ADM",
		items: [
			{
				href: "/manager/accounts",
				icon: "fas fa-running",
				title: "Lista degli account",
			},
			{
				href: "/manager/users",
				icon: "fas fa-user",
				title: "Lista degli utenti",
			},
			{
				href: "/manager/roles",
				icon: "fa fa-user-tie",
				title: "Lista dei ruoli",
			}
		]

	},
	{
		href: "#",
		icon: "fas fa-fill",
		title: "Manutenzioni",
		items: [
			{
				href: "/manager/prices/manage",
				icon: "fas fa-dollar-sign",
				title: "Aggiorna prezzi",
			},
			{
				href: "/manager/components",
				icon: "fas fa-stream",
				title: "Componenti",
			},
			{
				href: "/manager/components/reassign",
				icon: "fas fa-stream",
				title: "Gestione componenti",
			},
			{
				href: "/manager/quotation-items-exported",
				icon: "fas fa-stream",
				title: "Prodotti esportati",
			},
			{
				href: "/manager/quotations-exported",
				icon: "fas fa-stream",
				title: "Preventivi esportati",
			},
		]
	},

	{
		href: "#",
		icon: "fas fa-calendar-alt",
		title: "Pianificazione",
		roles: "ADM",
		items: [
			{
				href: "/manager/planning/gantt",
				icon: "fas fa-stream",
				title: "Gantt",
				roles: "ADM",
			},
			{
				href: "/manager/planning/projects",
				icon: "fas fa-tasks",
				title: "Ore progetti",
				roles: "ADM",
			},
			{
				href: "/manager/planning/people",
				icon: "fas fa-user-clock",
				title: "Disponibilità persone",
				roles: "ADM",
			},
			{
				href: "/manager/planning/stats",
				icon: "fas fa-chart-bar",
				title: "Statistiche progetti",
				roles: "ADM",
			},
		]
	},
	{
		href: "#",
		icon: "fab fa-redhat",
		title: "Sistema",
		items: [
			{
				href: "/manager/audit-entries",
				icon: "fas fa-folder-open",
				title: "Audit log",
			},
			{
				href: "/manager/error-logs",
				icon: "fas fa-bug",
				title: "Log errori",
				roles: "ADM",
			},
			{
				href: "/manager/system",
				icon: "fas fa-cogs",
				title: "Impostazioni",
			},

		]
	}
]
