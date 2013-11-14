Deps.autorun () ->
    Meteor.subscribe 'forms'

_col = (colName) ->
    [collection, created] = Fields._getCollection colName
    collection

_wrapBasics = (fContext, fieldSpec) ->
    fContext.label = fieldSpec.label
    fContext.hint = fieldSpec.hint
    fContext.inputClass = fieldSpec.inputClass
    fContext.fieldId = fieldSpec.colName + '-' + fContext._id

_wrapEditState = (fContext) ->
    fContext.editing = () ->
        Session.get fContext.fieldId + '-editing'
    fContext.showEditStateTrigger = () ->
        Session.get fContext.fieldId + '-editStateTrigger'
    
    fContext._enterEditState = () ->
        Session.set fContext.fieldId + '-editing', true
    fContext._enableEditStateTrigger = () ->
        unless Session.get fContext.fieldId + '-editStateTrigger'
            Session.set fContext.fieldId + '-editStateTrigger', true
            Meteor.setTimeout fContext._disableEditStateTrigger, 2000
    fContext._disableEditStateTrigger = () ->
        Session.set fContext.fieldId + '-editStateTrigger', false

_wrapValidation = (fContext, fieldSpec) ->
    Session.set fContext.fieldId + '-valid', true
    fContext.validChange = () ->
        fContext.changed() and fContext.valid()
    fContext.valid = () ->
        Session.get fContext.fieldId + '-valid'
    fContext.invalid = () ->
        not Session.get fContext.fieldId + '-valid'
    
    fContext._enterInvalidState = () ->
        Session.set fContext.fieldId + '-valid', false
    fContext._leaveInvalidState = () ->
        Session.set fContext.fieldId + '-valid', true
    fContext._valid = (newValue) ->
        valid = false
        if validator? and validator[fieldSpec.colName]?
            valid = validator[fieldSpec.colName] newValue
        else
            if fieldSpec.type is 'number'
                valid = (/^[1-9][0-9]*[\.,]?[0-9]*$/).test newValue
            else
                valid = newValue.replace(/\s/g, '').length > 0
        valid

_wrapValue = (fContext, fieldSpec) ->
    fContext.value = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne
            refId: fContext._id
        data?.interimValue

_wrapUpdate = (fContext, fieldSpec) ->
    fContext.changed = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne
            refId: fContext._id
        data?.interimValue isnt data?.value
    
    fContext._save = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        collection.update {_id: data._id}, {$set: {value: data.interimValue}}
        Session.set fContext.fieldId + '-editing', false
        Session.set fContext.fieldId + '-created', false
    fContext._discard = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        collection.update {_id: data._id}, {$set: {interimValue: data.value}}
        Session.set fContext.fieldId + '-editing', false
    fContext._update = (newValue) ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        collection.update {_id: data._id}, {$set: {interimValue: newValue}}
    

_loadData = (fContext, fieldSpec) ->
    fContext.ready = () ->
        Session.get fieldSpec.colName + '-ready'
    fContext.created = () ->
        Session.get fContext.fieldId + '-created'
        
    #subscribe to the referenced value
    Meteor.subscribe fieldSpec.colName, fContext._id, () ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        unless data?
            Session.set fContext.fieldId + '-created', true
            
            defaultValue = ''
            if fieldSpec.default?
                defaultValue = fieldSpec.default
            collection.insert 
                refId: fContext._id
                value: defaultValue
                interimValue: defaultValue
        Session.set fieldSpec.colName + '-ready', true
    

_wrapRich = (fContext, formSpec, fieldSpec) ->
    _wrapBasics fContext, fieldSpec
    fContext.editorId = fContext.fieldId.replace(/\./g,'-') + "-editor"
    fContext.toolbarId = fContext.fieldId.replace(/\./g,'-') + "-toolbar"
    
    _loadData fContext, fieldSpec
    
    _wrapValue fContext, fieldSpec
    _wrapUpdate fContext, fieldSpec
    _wrapEditState fContext
    _wrapValidation fContext, fieldSpec
    
    
_wrapSelect = (fContext, formSpec, fieldSpec) ->
    _wrapBasics fContext, fieldSpec
    _loadData fContext, fieldSpec
    
    _wrapValue fContext, fieldSpec
    _wrapUpdate fContext, fieldSpec
    _wrapEditState fContext
    
    _selected = (e) ->
        if fContext.value() is e
            'selected'
    
    fContext.choices = () ->
        fieldSpec.choices.map (e) ->
            {choice: e, selected: _selected e}
    
    
_wrapSimple = (fContext, formSpec, fieldSpec) ->
    _wrapBasics fContext, fieldSpec
    _loadData fContext, fieldSpec
    
    _wrapValue fContext, fieldSpec
    _wrapEditState fContext
    _wrapUpdate fContext, fieldSpec
    _wrapValidation fContext, fieldSpec
    

_editStateEvents = 
    'mouseenter': (e) ->
        @_enableEditStateTrigger()
    'click .fields-edit-state-trigger': (e) ->
        e.stopPropagation()
        @_enterEditState()
        
_textInputUpdateEvents = 
    'keyup .fields-content': (e) ->
        e.stopPropagation()
        newValue = e.currentTarget.value
        if newValue.replace(/\s/g, '').length is 0
            @_enterInvalidState()
        else
            if @_valid newValue
                @_leaveInvalidState()
                @_update newValue
            else
                e.currentTarget.value = @value()
                @_enterInvalidState
    
_clickSaveDiscardEvents = 
    'click .fields-save': (e) ->
        e.stopPropagation()
        @_save()
    'click .fields-cancel': (e) ->
        e.stopPropagation()
        @_discard()
    
        
Template.fieldsSimple.events _editStateEvents
Template.fieldsSimple.events _textInputUpdateEvents
Template.fieldsSimple.events _clickSaveDiscardEvents

Template.fieldsRich.events _editStateEvents
Template.fieldsRich.events _clickSaveDiscardEvents
Template.fieldsRich.events
    'click [data-edit]': (e) ->
        newValue = $("##{@editorId}").cleanHtml()
        if @_valid newValue
            @_leaveInvalidState()
            @_update newValue
        else
            e.currentTarget.value = @value()
            @_enterInvalidState
    'keyup div.editor': (e) ->
        e.stopPropagation()
        newValue = $(e.currentTarget).cleanHtml()
        if @_valid newValue
            @_leaveInvalidState()
            @_update newValue
        else
            e.currentTarget.value = @value()
            @_enterInvalidState
    
Template.fieldsRich.rendered = () ->
    e = @find '.editor'
    t = @find '.toolbar'
    if e? and t?
        $(e).wysiwyg
            toolbarSelector: "##{t.id}"

Template.fieldsSelect.events _editStateEvents
Template.fieldsSelect.events
    'change .fields-select': (e) ->
        @_update e.currentTarget.value
        @_save()
    
Handlebars.registerHelper 'fieldsForm', (formName, options) ->
    self = {}
    self._id = @_id
    self._form = formName
    self._fieldPath = ['formSpec']
    options.fn self
    
Handlebars.registerHelper 'fieldsGroup', (fieldName, options) ->
    self = {}
    self._id = @_id
    self._form = @_form
    self._container = fieldName
    self._fieldPath = @_fieldPath.concat [fieldName, 'elements']
    
    Template.fieldsGroup options.fn self
    
Handlebars.registerHelper 'fieldsField', (fieldName, options) ->
    self = {}
    self._id = @_id
    self._form = @_form
    path = @_fieldPath.concat [fieldName]
    formSpec = Fields.forms.findOne {form: self._form}
    fieldSpec = path.reduce ((s, e) -> s[e]), formSpec
    fieldSpec.colName = path.join '.'
    
    ###
    if @_container?
        Template.fieldsBare options.fn self
    else
        Template.fieldsBase options.fn self
    ###
    
    switch fieldSpec.type 
        when 'simpletext','number'
            _wrapSimple self, formSpec, fieldSpec
            Template.fieldsSimple options.fn self
        when 'richtext'
            _wrapRich self, formSpec, fieldSpec
            Template.fieldsRich options.fn self
        when 'select'
            _wrapSelect self, formSpec, fieldSpec
            Template.fieldsSelect options.fn self
        when 'date'
            _wrapDate self, formSpec, fieldSpec
            Template.fieldsDate options.fn self
        when 'duration'
            _wrapDuration self, formSpec, fieldSpec
            Template.fieldsDuration options.fn self
    