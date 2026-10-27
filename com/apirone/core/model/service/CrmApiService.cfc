/*
	es.
	https://api.test-crm.apirone.cc/api/accounts?token=c39bbed0-f211-46e7-8644-6d290dd00cd1&limit=5&offset=30

	var api = new AbsRestApi().init(
		baseUrl = "https://api.example.com",
		authToken = "my-secret-token"
	);

	// URL risultante: https://api.example.com/users?authToken=my-secret-token
	var users = api.get("/users");


	var api = new AbsRestApi().init(
		baseUrl = "https://api.example.com",
		apiKey = "my-key",
		defaultHeaders = { "User-Agent": "MyApp" }
	);

	// GET con params
	var users = api.get("/users", { limit: 10 });

	// POST con data
	var newUser = api.post("/users", { name: "Mario", email: "mario@example.com" });
*/

component extends="AbsRestApi" accessors="true" {

	/**
	 * Inizializza con URL CRM e token
	 */
	public CrmApiService function init(){
		super.init(
			baseUrl        = "https://api.crm.apirstudio.com/api",
			authToken      = getAuthToken(),
			defaultHeaders = { "Accept" = "application/json" }
		);
		return this;
	}

	/**
	 * Recupera dati cliente dal CRM via API
	 */
	public function getCustomer( required string customerId ){
		return get( "/accounts/#customerId#" );
	}

	/**
	 * Cerca clienti nel CRM
	 */
	public any function searchCustomers(required string str, numeric limit=10, numeric offset=0) {
		var params = {
			"name" = str,
			"limit" = limit,
			"offset" = offset
		};

		return get("/accounts", params);
	}

	/**
	 * Recupera dati cliente dal CRM via API
	 */
	public function getLead( required string leadId ){
		return get( "/leads/#leadId#" );
	}

	/**
	 * Cerca clienti nel CRM
	 */
	public any function searchLeads(required string str, numeric limit=10, numeric offset=0) {
		var params = {
			"name" = str,
			"limit" = limit,
			"offset" = offset
		};

		return get("/leads", params);
	}

	/**
	 * Recupera dati cliente dal CRM via API
	 */
	public function getOpportunity( required string opportunityId ){
		return get( "/opportunities/#opportunityId#" );
	}

	/**
	 * Cerca clienti nel CRM
	 */
	public any function searchOpportunities(required string str, numeric limit=10, numeric offset=0) {
		var params = {
			"name" = str,
			"limit" = limit,
			"offset" = offset
		};

		return get("/opportunities", params);
	}

	/**
	 * Metodo privato per ottenere il token auth
	 */
	private string function getAuthToken(){
		return "22fc379f600a7b033769d785652419805309588e0935d110df26cd04c9cb1688";
	}

}
