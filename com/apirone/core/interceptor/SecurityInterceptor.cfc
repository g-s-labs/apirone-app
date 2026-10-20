// interceptors/SecurityInterceptor.cfc
component extends="coldbox.system.Interceptor" {

	// property name="userService" inject="userService";
	//property name="securityService" inject="SecurityService";

	function preProcess( event, rc, prc ){
		// --- A. Preparazione dei dati ---

		var securityService = server["wirebox-apirone"].getInstance("securityService");

		//abort;

		// Recupera l'utente loggato. Assumiamo che restituisca un oggetto User
		// che risponde al metodo .hasPermission().
		var user = session.user;

		var module     = event.getCurrentModule();
		var eventName  = event.getCurrentEvent();
		var controller = event.getCurrentHandler();

		if ( module == "api" ) {
			// TODO: use this
			//storeRequest( event )

			//var svc = model.getInstance( "APIService" );

			try {
				var authToken = Trim( GetHTTPRequestData().Headers.authorization.replace( "Bearer", "" ) );

				// unico token ammesso: crm.api.token (system property o variabile d'ambiente).
				// Il confronto avviene sugli hash per non dipendere dalla lunghezza del prefisso uguale.
				var crmToken = server.system.properties[ "crm.api.token" ]
					?: server.system.environment[ "crm.api.token" ]
					?: "";

				if ( !Len( crmToken ) || !Len( authToken )
					|| Hash( authToken, "SHA-256" ) != Hash( crmToken, "SHA-256" ) ) {
					return arguments.event
						.renderData(
							data       = "Not Authorized. Token not valid.",
							statusCode = "401",
							statusText = "Unauthorized"
						)
						.noExecution();
				}
			} catch ( e ) {
				return arguments.event
					.renderData(
						data       = "Not Authorized.",
						statusCode = "401",
						statusText = "Unauthorized"
					)
					.noExecution();
			}
		}

		if ( module == "manager" ) {
			// Chiama il SecurityService per verificare i permessi.
			if ( !securityService.canAccess( user, eventName ) ) {
				var controller = event.getCurrentHandler();

				if ( controller CONTAINS "ajax" ) {
					return arguments.event
						.renderData(
							data       = "Not Authorized.",
							statusCode = "401",
							statusText = "Unauthorized"
						)
						.noExecution();
				} else {
					if ( user.isLogged() ) {
						// alla dashbord con messaggio

						// TODO: move to an helper, like in AbsController
						flash.put(
							"message",
							{
								"type"    = "warning",
								"message" = "Accesso negato. Non hai i permessi necessari per accedere a #eventName#",
								"title"   = "Accesso negato"
							}
						);

						relocate(
							uri               = "/manager/dashboard",
							postProcessExempt = false,
							addToken          = false
						);
					} else {
						relocate(
							uri               = "/manager/login",
							postProcessExempt = false,
							addToken          = false
						);
					}
				}
				event.noRender(); // Assicura che ColdBox non provi a renderizzare l'evento bloccato
				return;
			} 
		}

		// TODO: manage here other modules. stop execution if not allowed

		// Se hasAccess è true, l'esecuzione continua normalmente.
	}

	private String function storeRequest(
		required event,
		required prefix  = "api",
		required service = "apirone"
	){
		var code = "#arguments.prefix#_" & DateTimeFormat( Now(), "yyyy-mm-dd_HH-nn-ss" ) & "_" & RandRange( 0, 99999 );

		var dayPath  = DateTimeFormat( Now(), "yyyy/mm" );
		var response = "";

		var thisRequest = GetHTTPRequestData();

		var body = thisRequest.keyExists( "content" ) ? thisRequest.content : "not-exists";

		var meta = {
			"apiKey"    = "not-exists",
			"eventName" = event.getContext().event,
			"route"     = event.getPrivateContext().currentRoutedURL,
			"method"    = thisRequest.method,
			"eventId"   = event.prc.eventId
		};

		if ( thisRequest.keyExists( "headers" ) ) {
			if ( thisRequest.headers.keyExists( "authorization" ) ) {
				meta.apiKey = Trim(
					Replace(
						thisRequest.headers.authorization,
						"Bearer",
						""
					)
				);
			}
		}

		cffile(
			action = "append",
			file   = "#ExpandPath( "/../repository/private/logs/api.log" )#",
			output = "#Now()#;#cgi.REMOTE_ADDR#;#cgi.HTTP_USER_AGENT#;#meta.route#;#meta.eventName#;#meta.method#;#meta.apiKey#"
		);

		// TODO: nalla path "service" o "api"?
		var thisPath = ExpandPath( "/../repository/private/api/#arguments.service#/#dayPath#" );

		DirectoryCreate( thisPath, true, true );

		savecontent variable="report" {
			Echo( "<h2>ID: #code#</h2><br>Data: #Now()#" );

			Echo( "<h3>Meta</h3>" );
			cfdump( var = "#meta#", label = "meta" );

			Echo( "<h3>Request</h3>" );
			cfdump( var = "#body#", label = "Request body" );

			Echo( "<h3>Response</h3>" );
			cfdump( var = "#response#", label = "Response" );

			Echo( "<h3>CGI</h3>" );
			cfdump( var = "#cgi#", label = "CGI" );
		}

		FileWrite( "#thisPath#/#code#.html", report );

		return code;
	}	

}
