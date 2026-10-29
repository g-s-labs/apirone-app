component extends="com.apirone.core.model.bean.AbsBean" accessors="true" {

	property name="quotationNumber" type="String";
	property name="versionNumber" type="Numeric";
	property name="quotationDate" type="Date";
	property name="note" type="String";
	property name="validityDate" type="Date";
	property name="active" type="Numeric";
	property name="price" type="com.apirone.core.model.bean.QuotationPrice";
	property name="vatCode" type="com.apirone.core.model.bean.VatCode";
	property name="customer" type="com.apirone.core.model.bean.Customer";
	property name="opportunity" type="com.apirone.core.model.bean.Opportunity";
	property name="lead" type="com.apirone.core.model.bean.Lead";
	property name="paymentMethod" type="com.apirone.core.model.bean.PaymentMethod";
	// modalità di pagamento ( testo libero ), solo con pagamento 26 SCADENZE DA IMPUTARE
	property name="customPaymentMethod" type="String";
	property name="currency" type="com.apirone.core.model.bean.Currency";
	property name="statusHistory" type="com.apirone.core.model.bean.QuotationStatusHistory";
	property name="lang" type="com.apirone.core.model.bean.Lang";
	//property name="billingProfile" type="com.apirone.core.model.bean.BillingProfile";
	property name="shippingProfile" type="com.apirone.core.model.bean.ShippingProfile";
	property name="owner" type="com.apirone.core.model.bean.User";
	property name="salesAgent" type="com.apirone.core.model.bean.User";
	property name="graphicTechnician" type="com.apirone.core.model.bean.User";
	//property name="statusFile" type="com.apirone.core.model.bean.File"; //TODO: remove
	property name="calculatedAmount" type="Numeric";
	property name="serial" type="Numeric";
	property name="exported" type="Boolean";
	property name="nessunAgente" type="Boolean";
	property name="agente1" type="String";
	property name="agente2" type="String";
	property name="agente3" type="String";
	property name="agente4" type="String";
	property name="agente5" type="String";
	property name="commission1" type="Numeric";
	property name="commission2" type="Numeric";
	property name="commission3" type="Numeric";
	property name="commission4" type="Numeric";
	property name="commission5" type="Numeric";
	property name="referenteAmministrativo" type="String";
	property name="referenteSpedizione" type="String";
	property name="customerType" type="String";
	property name="industry" type="String";
	property name="rifLibero" type="String";
	property name="po" type="String";
	property name="reclamoAnno" type="String";
	property name="reclamoNumero" type="Numeric";
	property name="reclamoAlfa" type="String";
	property name="dataEvasione" type="Date";
	property name="sentToClient" type="Boolean";
	property name="dataConfermaOrdine" type="Date";
	property name="codiceSdi" type="String";

	public Quotation function init(){
		return this;
	}

	public String function getPaymentMethodName(){
		var paymentMethod = this.getPaymentMethod();
		if ( !IsNull( paymentMethod ) ) {
			return paymentMethod.getName();
		} else {
			return getCustomPaymentMethod();
		}
	}

	public String function getReferentName() {
		if ( Len( getCustomer()?.getName() ) ) {
			return getCustomer().getName();
		}

		if ( Len( getLead()?.getName() ) ) {
			return getLead().getName();
		}

		if ( Len( getOpportunity()?.getName() ) ) {
			return getOpportunity().getName();
		}

		// Se non c'è nessuna delle tre o se manca il campo nome specifico
		return "Nessun referente"
	}

	/**
	 * Perché il preventivo non è più modificabile ( stringa vuota se lo è ):
	 * inviato al cliente o convertito in ordine. Da bloccato si modifica solo
	 * creando una revisione ( createRevision ).
	 * L'esportazione verso Verticale porta il preventivo in "Convertito in ordine"
	 * ( vedi isExportable ).
	 */
	public String function lockReason(){
		if ( getSentToClient() ?: false ) {
			return "è stato inviato al cliente";
		}
		if ( !IsNull( getStatusHistory() ) && !IsNull( getStatusHistory().getStatus() )
			&& getStatusHistory().getStatus().getId() == "CON" ) {
			return "è stato convertito in ordine";
		}
		return "";
	}

	/**
	 * L'account è uno dei 5 agenti del preventivo ( ruolo Agente: vede solo questi ).
	 */
	public Boolean function hasAgent( required String accountId ){
		var agents = [ getAgente1(), getAgente2(), getAgente3(), getAgente4(), getAgente5() ];
		for ( var agent in agents ) {
			if ( !IsNull( agent ) && Len( agent ) && agent == arguments.accountId ) {
				return true;
			}
		}
		return false;
	}

	public Boolean function isLocked(){
		return Len( lockReason() ) > 0;
	}

	/**
	 * Si esporta verso Verticale solo un preventivo concluso: "Approvato" ( APR )
	 * o "Confermato da cliente" ( CCN ). Esportato, passa a "Convertito in ordine".
	 */
	public Boolean function isExportable(){
		return !IsNull( getStatusHistory() ) && !IsNull( getStatusHistory().getStatus() )
			&& ArrayContains( [ "APR", "CCN" ], getStatusHistory().getStatus().getId() );
	}

}
