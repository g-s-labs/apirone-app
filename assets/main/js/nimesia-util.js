NM.util = NM.util || {};
NM.form = NM.form || {};

NM.util.openModal = function( ele, onShow, useOverlap=false ) {

    var dialogs = $( ".modal.show" ); // opened dialog
    var currentId = ele.attr( "id" );

    var currentTop = 0;
    var currentLeft = 0;

    var n=1;

    for ( var dialog of dialogs ) {

        var $dialog = $( dialog );

        if( currentId !=  $dialog.attr( "id" ) ) {

            currentTop = 20*n;
            currentLeft = 20*n;

            n++;

        }

    }

    ele.modal( "show" );
    // ele.handleUpdate();

    if ( onShow ) {
        onShow();
    }

    // sulle pagine molto lunghe posiziona la modale in alto quando viene redisegnata.
    // su initUpload ad esempio.
    if ( useOverlap ) {
        ele.css( { left: 0, top: 0 } );
        ele.offset( { left: currentLeft, top: currentTop } );

    }

};


NM.util.ajax = function( setup ) {

    var defaults = {
        url: "",
        data: null,
        method: "GET",
        callback: {
            done: undefined,
            always: function( xhr, statusText ) {

                if ( statusText == "error" ) {

                    // un errore non gestito non deve lasciare lo spinner globale bloccato
                    // a schermo (es. chi ha chiamato l'ajax aveva fatto AP.loading.show()
                    // prima della richiesta, contando su un done() che qui non arriverà mai)
                    AP.loading?.hide?.();

                    if ( xhr.status == 500 ) {
                        // codice dell'errore salvato su error_logs ( apps/utils/errorReport.cfm )
                        var errorCode = xhr.getResponseHeader( "X-Error-Code" );
                        AP.widget.notify( "error", "Qualcosa è andato storto" + ( errorCode ? " (codice " + errorCode + ")" : "" ), "Ops!" );
                        return;
                    }

                    if ( xhr.status == 401 ) {
                        AP.widget.notify( "warning", "Accesso non consentito", "Ops!" );
                        return;
                    }

                    // voglio che i "400" arrivino sul client,
                    // usando done() non succederebbe
                    if ( xhr.status == 400 ) {
                        setup.callback?.done?.apply( null, [ xhr.responseJSON ] );
                        return;
                    }

                }

                if ( statusText == "success" ) {
                    setup.callback?.done?.apply( null, [ xhr ] );
                }

            },
        }
    };

    var settings = $.extend( true, defaults, setup );

    if ( settings.hasOwnProperty( "cache" ) ) {

        settings.cache = settings.cache;

        if ( !settings.cache ) {
            settings.headers = {
                "cache-control": "no-cache"
            };
        }
    }

    // Spinner globale automatico per le richieste che salvano ( non GET ):
    // loading: false per quelle di sfondo ( anteprime live, riordini ),
    // loading: true per mostrarlo anche su una GET.
    var withLoading = settings.hasOwnProperty( "loading" )
        ? !!settings.loading
        : String( settings.method ).toUpperCase() != "GET";

    if ( withLoading ) {
        AP.loading?.begin?.();
    }

    var ajaxOptions = {
        url: settings.url,
        method: settings.method,
        data: settings.data
    };

    // Body JSON ( JSON.stringify ): va inviato come application/json. Col content-type
    // di default ( form-urlencoded ) Lucee interpreta l'intero JSON come nome di un campo
    // form e crea uno struct annidato per ogni "." contenuto: con payload grandi ( es. placca
    // con molte liste SIMBOLO ) le migliaia di livelli mandano in StackOverflowError la
    // richiesta. I controller leggono comunque il body da GetHTTPRequestData().content.
    if ( typeof settings.data === "string"
        && String( settings.method ).toUpperCase() != "GET"
        && /^\s*[\[{]/.test( settings.data ) ) {
        ajaxOptions.contentType = "application/json; charset=UTF-8";
    }

    var data =
		$.ajax( ajaxOptions )
		/*
		    .done( function( xhr ) {

		        if ( xhr.error === undefined ) { // dal proxy
		            if ( settings.callback.done !== undefined ) {
		                settings.callback.done.apply( null, [ xhr ] );
		            }
		        } else {
		            window.location.href = "/";
		        }

		    } )
		    .fail( settings.callback.fail )
            */
		    .always( settings.callback.always );

    if ( withLoading ) {
        data.always( function() {
            AP.loading?.end?.();
        } );
    }

    return data;

};

NM.util.checkAll = function( button ) {

    var value = true;
    var thisForm = $( button.closest( "form" ) );

    var checks = thisForm.find( "input[name=selected]:checkbox" );

    if( button.checked == undefined ) {
        value = true;
    } else {
        value = button.checked;
    }

    checks.each( function() {
        $( this ).prop( "checked", value );
    } );

};

NM.util.autoHideMessage = function( ele, message ) {

    ele.html( message );

    setTimeout( function() {
        ele.html( "" );
    }, 1500 );

};

NM.util.copyText = function( text, onSuccess ) {

    return new Promise( ( resolve, reject ) => {

        // Prova prima l'API moderna
        if ( typeof window !== "undefined" && typeof window.navigator !== "undefined" && window.navigator.clipboard && window.navigator.clipboard.writeText ) {
            window.navigator.clipboard.writeText( text )
                .then( () => {
                    const result = { "result": "success", "text": text };
                    if ( onSuccess && typeof onSuccess === "function" ) {
                        onSuccess( result );
                    }
                    resolve( result );
                } )
                .catch( ( err ) => {
                    console.error( "Errore API moderna:", err );
                    // Fallback a execCommand se l'API moderna fallisce
                    fallbackCopyToClipboard( text, resolve, reject );
                } );
        } else {
            // Fallback diretto se l'API moderna non è disponibile
            fallbackCopyToClipboard( text, resolve, reject );
        }

        function fallbackCopyToClipboard( text, resolve, reject ) {

            const textArea = document.createElement( "textarea" );

            textArea.value = text;
            textArea.style.position = "fixed";
            textArea.style.left = "-999999px";
            textArea.style.top = "-999999px";

            document.body.appendChild( textArea );

            textArea.focus();
            textArea.select();

            try {
                const success = document.execCommand( "copy" );
                document.body.removeChild( textArea );

                if ( success ) {
                    const result = { "result": "success", "text": text };
                    if ( onSuccess && typeof onSuccess === "function" ) {
                        onSuccess( result );
                    }
                    resolve( result );
                } else {
                    reject( { "result": "error" } );
                }
            } catch ( err ) {
                console.error( "Fallback copy failed:", err );
                document.body.removeChild( textArea );
                reject( { "result": "error" } );
            }
        }

    } );

};

// Funzione per generare UUID semplice
NM.util.uuid = function() {
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace( /[xy]/g, function( c ) {
        var r = Math.random() * 16 | 0;
        var v = c == "x" ? r : ( r & 0x3 ) | 0x8;
        return v.toString( 16 );
    } );
};

NM.storage = {

    /*
        Naming:
            key: product.items.showUnlinked
            value: true | 123 | miaStringa | { id: 123, name: "pippo" }
    */

    set: function( key, value ) {
        if ( value != "undefined" ) {
            localStorage.setItem( key, JSON.stringify( value ) );
        }
    },

    get: function( key, defaultValue ) {
        var value = localStorage.getItem( key );
        if ( value == "undefined" ) {
            return "";
        }
        return value ? JSON.parse( value ) : defaultValue;
    },

    delete: function( key ) {
        localStorage.removeItem( key );
    }

};


/*
    form utils
*/

NM.form.clearMessages = function( formElement ) {

    // remove single message
    formElement.find( "label.error" ).remove();

    // remove class from input
    formElement.find( "input.error, select.error, textarea.error" ).removeClass( "error" );

    // remove global status in form
    formElement.find( ".status" ).html( "" );
    formElement.find( ".errors-counter" ).html( "" );

};

NM.form.removeRules = function( formElement ) {

    var thisForm = formElement.get( 0 );
    $.removeData( thisForm, "validator" );

    NM.form.clearMessages( formElement );

};

NM.form.showMessages = function( errors ) {
    // Prendi il primo campo della struttura errors
    var firstField = Object.keys( errors )[0];

    // Trova il campo nel DOM
    var firstInput = $( "[name='" + firstField + "']" );

    // Trova il form contenitore di quell'input
    var formElement = firstInput.closest( "form" );

    // Conta il totale degli errori
    var errorCount = 0;

    // Se c'è un errore generale, mostra la notifica
    if ( errors.general ) {
        // Usa il primo messaggio del campo general, se presente
        var generalMessage = Array.isArray( errors.general ) && errors.general.length > 0
            ? errors.general.map( function( e ){ return e.message; } ).join( "\n" )
            : "Ops! Si è verificato un errore generale.";
        AP.widget.notify( "error", generalMessage, "Ops!" );
    }

    // Cicla su ogni campo della struttura degli errori
    $.each( errors, function( field, errorList ) {
        errorCount += errorList.length;

        // Seleziona il campo nel form (input, select, textarea)
        var thisField = formElement.find( "[name='" + field + "']" );

        // Assegna la classe "error" al campo
        thisField.addClass( "error" );

        // Costruisci il messaggio HTML (ogni errore su una riga)
        var messages = errorList.map( function( e ) { return e.message; } ).join( "<br>" );

        // Cerca se esiste già il label per questo campo
        var label = $( "#" + field + "-error" );
        if ( label.length === 0 ) {
            // Se non esiste, crealo dopo il campo
            label = $( "<label class=\"error\" id=\"" + field + "-error\"></label>" );
            thisField.after( label );
        }
        // Svuota il label prima di riempirlo
        label.html( "" );
        // Inserisci i messaggi nel label
        label.html( messages ).show();
    } );

    // Se esiste un div.status nel form, mostra il numero di errori
    var status = formElement.find( ".status" );
    if ( status.length ) {
        status.text( "Ci sono " + errorCount + " errori" );
    }
};

/*
    // form utils
*/

function scaleCanvasToBase64( canvas, maxWidth ) {
    if ( canvas.width <= maxWidth ) {
        return canvas.toDataURL( "image/png" ).replace( /^data:image\/png;base64,/, "" );
    }
    var scale   = maxWidth / canvas.width;
    var scaled  = document.createElement( "canvas" );
    scaled.width  = maxWidth;
    scaled.height = Math.round( canvas.height * scale );
    scaled.getContext( "2d" ).drawImage( canvas, 0, 0, scaled.width, scaled.height );
    return scaled.toDataURL( "image/png" ).replace( /^data:image\/png;base64,/, "" );
}

function scaleDataUrlToBase64( dataUrl, maxWidth ) {
    return new Promise( function( resolve ) {
        var img = new Image();
        img.onload = function() {
            if ( img.width <= maxWidth ) {
                resolve( dataUrl.replace( /^data:image\/png;base64,/, "" ) );
                return;
            }
            var scale   = maxWidth / img.width;
            var canvas  = document.createElement( "canvas" );
            canvas.width  = maxWidth;
            canvas.height = Math.round( img.height * scale );
            canvas.getContext( "2d" ).drawImage( img, 0, 0, canvas.width, canvas.height );
            resolve( canvas.toDataURL( "image/png" ).replace( /^data:image\/png;base64,/, "" ) );
        };
        img.src = dataUrl;
    } );
}
