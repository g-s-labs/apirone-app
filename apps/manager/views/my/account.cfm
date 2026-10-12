<cfoutput>
    <div id="my-account-root">

        #pageTitle()#

        <div class="col-12">
            
            <section class="card">

                <div class="card-body">
                    
                    <div class="row g-5">

                        <div class="col-lg-6">
                            
                            <div class="row">

                                <div class="col-lg-12">
                                    <h3>Dettagli profilo</h3>
                                </div>

                                <hr class="mt-3">
                                
                                <div class="col-3 text-end">
                                    <b>ID:</b>
                                </div>
                                <div class="col-9">
                                    #prc.user.getShortId()#
                                </div>

                                <hr class="mt-3">

                                <div class="col-3 text-end">
                                    <b>Nome:</b>
                                </div>
                                <div class="col-9">
                                    #prc.user.getAccount().getName()#
                                </div>

                                <hr class="mt-3">

                                <div class="col-3 text-end">
                                    <b>Email:</b>
                                </div>
                                <div class="col-9">
                                    #prc.user.getAccount().getEmail()#
                                </div>

                                <hr class="mt-3">

                                <div class="col-3 text-end">
                                    <b>Lingua:</b>
                                </div>
                                <div class="col-9">
                                    #prc.user.getLang().getName()#
                                </div>

                                <hr class="mt-3">

                            </div>

                        </div>

                        <div class="col-lg-6">

                            <form id="my-account-detail-form">

                                <div class="row">

                                    <div class="col-lg-12">
                                        <h3>Modifica la password</h3>
                                    </div>

                                    <hr class="mt-3">

                                    <div class="col-3 text-end">
                                        <b>ID account:</b>
                                    </div>
                                    <div class="col-9">
                                        #prc.user.getAccount().getShortId()#
                                    </div>

                                    <hr class="mt-3">
                                    
                                    <div class="col-12">
                                        <div class="form-group pb-3">
                                            <label class="col-form-label" for="current-pwd">Password corrente</label>
                                            <input type="password" class="form-control" name="currentPwd" id="current-pwd"
                                                required
                                                maxlength="20"
                                                data-rule-required="true"
                                                data-msg-required="Password corrente richiesta"
                                            >
                                        </div>
                                    </div>
                                    
                                    <div class="col-12">
                                        <div class="form-group pb-3">
                                            <label class="col-form-label" for="new-pwd">Nuova password</label>
                                            <input type="password" class="form-control" name="newPwd" id="new-pwd"
                                                required
                                                maxlength="20"
                                                data-rule-required="true"
                                                data-msg-required="Password richiesta"
                                                data-rule-pwdRule="true"
                                                data-msg-pwdRule="Almeno 10 caratteri e contenere almeno un numero e un carattere speciale"
                                            >
                                        </div>
                                    </div>
                                    
                                    <div class="col-12">
                                        <div class="form-group pb-3">
                                            <label class="col-form-label" for="confirm-pwd">Conferma password</label>
                                            <input type="password" class="form-control" name="confirmPwd" id="confirm-pwd"
                                                required
                                                maxlength="20"
                                                data-rule-required="true"
                                                data-msg-required="La password di conferma è richiesta"
                                                data-rule-equalTo="##new-pwd"
                                                data-msg-equalTo="Le password non coincidono"
                                            >
                                        </div>
                                    </div>
                                    
                                    <div class="col-12 mt-3">
                                        #saveButton( label="Modifica password", size="md", bind="click:save")#

                                        <br clear="all">

                                        <div class="status mt-2"></div>
                                    </div>

                                </div>

                            </form>

                        </div>
                    </div>
                </div>                                
                
            </section>
            
        </div>
        
    </div>

</cfoutput>