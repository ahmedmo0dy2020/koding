class LoginView extends KDScrollView

  stop = (event)->
    event.preventDefault()
    event.stopPropagation()

  constructor:(options = {}, data)->

    {entryPoint} = KD.config
    options.cssClass = 'hidden'

    super options, data

    @hidden = yes

    @bindTransitionEnd()

    handler =(route, event)=>
      stop event
      @getSingleton('router').handleRoute route, {entryPoint}

    homeHandler       = handler.bind null, '/'
    learnMoreHandler  = handler.bind null, '/Join'
    loginHandler      = handler.bind null, '/Login'
    registerHandler   = handler.bind null, '/Register'
    joinHandler       = handler.bind null, '/Join'
    recoverHandler    = handler.bind null, '/Recover'

    @logo = new KDCustomHTMLView
      tagName     : "div"
      cssClass    : "logo"
      partial     : "Koding"
      click       : homeHandler

    @backToLoginLink = new KDCustomHTMLView
      tagName   : "a"
      partial   : "Go ahead and login"
      click     : loginHandler

    @goToRecoverLink = new KDCustomHTMLView
      tagName     : "a"
      partial     : "Recover password"
      click       : recoverHandler

    @goToRequestLink = new KDCustomHTMLView
      tagName     : "a"
      partial     : "Request an invite"
      click       : joinHandler

    @goToRegisterLink = new KDCustomHTMLView
      tagName     : "a"
      partial     : "Register an account"
      click       : registerHandler

    @loginOptions = new LoginOptions
      cssClass : "login-options-holder log"

    @registerOptions = new RegisterOptions
      cssClass : "login-options-holder reg"

    @loginForm = new LoginInlineForm
      cssClass : "login-form"
      callback : (formData)=>
        formData.clientId = $.cookie('clientId')
        @doLogin formData
        KD.track "Login", "SignInButtonClicked"

    @registerForm = new RegisterInlineForm
      cssClass : "login-form"
      callback : (formData)=>
        @doRegister formData
        KD.track "Login", "RegisterButtonClicked"

    @recoverForm = new RecoverInlineForm
      cssClass : "login-form"
      callback : (formData)=>
        @doRecover formData
        KD.track "Login", "RecoverButtonClicked"


    @resetForm = new ResetInlineForm
      cssClass : "login-form"
      callback : (formData)=>
        formData.clientId = $.cookie('clientId')
        @doReset formData
        KD.track "Login", "ResetButtonClicked"

    @requestForm = new RequestInlineForm
      cssClass : "login-form"
      callback : (formData)=>
        @doRequest formData
        KD.track "Login", "RequestButtonClicked"

    @headBanner = new KDCustomHTMLView
      domId    : "invite-recovery-notification-bar"
      cssClass : "invite-recovery-notification-bar hidden"
      partial  : "..."

    @getSingleton("mainController").on "landingSidebarClicked", => @unsetClass 'landed'

  viewAppended:->

    @setY -@getSingleton('windowController').winHeight
    @listenWindowResize()
    @setClass "login-screen login"

    @setTemplate @pistachio()
    @template.update()

  _windowDidResize:->
    if @hidden
      @setY -@getSingleton('windowController').winHeight

  pistachio:->
    """
    <div class="flex-wrapper">
      <div class="login-box-header">
        <a class="betatag">beta</a>
        {{> @logo}}
      </div>
      {{> @loginOptions}}
      {{> @registerOptions}}
      <div class="login-form-holder lf">
        {{> @loginForm}}
      </div>
      <div class="login-form-holder rf">
        {{> @registerForm}}
      </div>
      <div class="login-form-holder rcf">
        {{> @recoverForm}}
      </div>
      <div class="login-form-holder rsf">
        {{> @resetForm}}
      </div>
      <div class="login-form-holder rqf">
        <h3 class="kdview kdheaderview "><span>REQUEST AN INVITE:</span></h3>
        {{> @requestForm}}
      </div>
    </div>
    <div class="login-footer">
      <p class='reqLink'>Want to get in? {{> @goToRequestLink}}</p>
      <p class='regLink'>Have an invite? {{> @goToRegisterLink}}</p>
      <p class='recLink'>Trouble logging in? {{> @goToRecoverLink}}</p>
      <p class='logLink'>Already a user? {{> @backToLoginLink}}</p>
    </div>
    """

  doReset:({recoveryToken, password, clientId})->
    KD.remote.api.JPasswordRecovery.resetPassword recoveryToken, password, (err, username)=>
      @resetForm.button.hideLoader()
      @resetForm.reset()
      @headBanner.hide()
      @doLogin {username, password, clientId}

  doRecover:(formData)->
    KD.remote.api.JPasswordRecovery.recoverPassword formData['username-or-email'], (err)=>
      @recoverForm.button.hideLoader()
      if err
        new KDNotificationView
          title : "An error occurred: #{err.message}"
      else
        @recoverForm.reset()
        {entryPoint} = KD.config
        KD.getSingleton('router').handleRoute '/Login', {entryPoint}
        new KDNotificationView
          title     : "Check your email"
          content   : "We've sent you a password recovery token."
          duration  : 4500

  doRegister:(formData)->
    {kodingenUser} = formData
    formData.agree = 'on'
    @registerForm.notificationsDisabled = yes
    @registerForm.notification?.destroy()

    KD.remote.api.JUser.register formData, (err, account, replacementToken)=>
      @registerForm.button.hideLoader()
      if err
        {message} = err
        warn "An error occured while registering:", err
        @registerForm.notificationsDisabled = no
        @registerForm.emit "SubmitFailed", message
      else
        $.cookie 'clientId', replacementToken
        @getSingleton('mainController').accountChanged account
        new KDNotificationView
          cssClass  : "login"
          title     : if kodingenUser then '<span></span>Nice to see an old friend here!' else '<span></span>Good to go, Enjoy!'
          # content   : 'Successfully registered!'
          duration  : 2000
        KD.getSingleton('router').clear()
        setTimeout =>
          @hide()
          @registerForm.reset()
          @registerForm.button.hideLoader()
          # setTimeout =>
          #   @getSingleton('mainController').emit "ShowInstructionsBook"
          # , 1000
        , 1000

  doLogin:(credentials)->
    credentials.username = credentials.username.toLowerCase()
    KD.remote.api.JUser.login credentials, (err, account, replacementToken) =>
      @loginForm.button.hideLoader()

      {entryPoint} = KD.config

      if err
        new KDNotificationView
          title   : err.message
          duration: 1000
        @loginForm.resetDecoration()
      else
        $.cookie 'clientId', replacementToken  if replacementToken
        mainController = @getSingleton('mainController')
        mainView       = mainController.mainViewController.getView()
        mainController.accountChanged account
        mainView.show()
        mainView.$().css "opacity", 1

        @getSingleton('router').handleRoute '/Activity', {replaceState: yes, entryPoint}

        new KDNotificationView
          cssClass  : "login"
          title     : "<span></span>Happy Coding!"
          # content   : "Successfully logged in."
          duration  : 2000
        @loginForm.reset()

        @hide()

  doRequest:(formData)->
    {entryPoint} = KD.config
    slug = if entryPoint?.type is 'group' and entryPoint.slug\
           then entryPoint.slug else 'koding'
    KD.remote.cacheable slug, (err, [group])=>
      group.requestAccess formData, (err)=>
        if err
          warn err
          new KDNotificationView
            title     : 'Something went wrong, please try again!'
            duration  : 2000
        else
          @requestForm.reset()
          @requestForm.email.hide()
          @requestForm.button.hide()
          @$('.flex-wrapper').addClass 'expanded'
        @requestForm.button.hideLoader()

  showHeadBanner:(message, callback)->
    @headBannerMsg = message
    @headBanner.updatePartial @headBannerMsg
    @headBanner.unsetClass 'hidden'
    @headBanner.setClass 'show'
    $('body').addClass 'recovery'
    @headBanner.click = callback

  headBannerShowGoBackGroup:(groupTitle)->
    @showHeadBanner "<span>Go Back to</span> #{groupTitle}", =>
      @headBanner.hide()

      $('#group-landing').css 'height', '100%'
      $('#group-landing').css 'opacity', 1

  headBannerShowRecovery:(recoveryToken)->

    @showHeadBanner "Hi, seems like you came here to reclaim your account. <span>Click here when you're ready!</span>", =>
      @getSingleton('router').clear '/Recover/Password'
      @headBanner.updatePartial "You can now create a new password for your account"
      @resetForm.addCustomData {recoveryToken}
      @animateToForm "reset"

  headBannerShowInvitation:(invite)->

    @showHeadBanner "Cool! you got an invite! <span>Click here to register your account.</span>", =>
      @headBanner.hide()
      @getSingleton('router').clear @getRouteWithEntryPoint('Register')
      $('body').removeClass 'recovery'
      @show =>
        @animateToForm "register"
        @getSingleton('mainController').emit 'InvitationReceived', invite

  hide:(callback)->

    @setY -@getSingleton('windowController').winHeight

    cb = =>
      @requestForm.email.show()
      @requestForm.button.show()
      @$('.flex-wrapper').removeClass 'expanded'

      @emit "LoginViewHidden"
      @hidden = yes
      @hideTimer = @utils.wait 2000, => @setClass 'hidden'
      callback?()

    unless @hidden then do cb
    else @once "transitionend", cb

  show:(callback)->

    @utils.killWait @hideTimer
    cb = =>
      @emit "LoginViewShown"
      @hidden = no
      callback?()

    @unsetClass 'hidden'
    @utils.defer =>
      @setY 0
      unless @hidden then do cb
      else @once "transitionend", cb

  click:(event)->
    if $(event.target).is('.login-screen')
      @hide ->
        router = KD.getSingleton('router')
        routed = no
        for route in router.visitedRoutes by -1
          {entryPoint} = KD.config
          routeWithoutEntryPoint =
            if entryPoint?.type is 'group' and entryPoint.slug
            then route.replace "/#{entryPoint.slug}", ''
            else route
          unless routeWithoutEntryPoint in ['/Login', '/Register', '/Join', '/Recover']
            router.handleRoute route
            routed = yes
            break
        router.clear()  unless routed

  animateToForm: (name)->

    @show =>
      switch name
        when "register"
          # @utils.wait 5000, =>
          #   @utils.registerDummyUser()

          KD.remote.api.JUser.isRegistrationEnabled (status)=>
            if status is no
              log "Registrations are disabled!!!"
              @registerForm.$('.main-part').addClass 'hidden'
              @registerForm.disabledNotice.show()
            else
              @registerForm.disabledNotice.hide()
              @registerForm.$('.main-part').removeClass 'hidden'
        when "home"
          parent.notification?.destroy()
          if @headBannerMsg?
            @headBanner.updatePartial @headBannerMsg
            @headBanner.show()

      @unsetClass "join register recover login reset home"
      @emit "LoginViewAnimated", name
      @setClass name

  getRouteWithEntryPoint:(route)->
    {entryPoint} = KD.config
    if entryPoint and entryPoint.slug isnt 'koding'
      return "/#{entryPoint.slug}/#{route}"
    else
      return "/#{route}"
