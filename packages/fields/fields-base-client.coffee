Deps.autorun () ->
    Meteor.subscribe 'forms'


_col = (colName) ->
    [collection, created] = Fields._getCollection colName
    collection

_wrap = (fContext, formSpec, fieldSpec) ->
    refId = fContext._id
    fContext.label = fieldSpec.label
    
    fContext.fieldId = () ->
        fieldSpec.colName + '-' + refId
    fContext.ready = () ->
        Session.get fieldSpec.colName + '-ready'
    fContext.value = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne
            refId: refId
        data?.interimValue
    fContext.changed = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne
            refId: refId
        data?.interimValue isnt data?.value
    fContext.created = () ->
        Session.get fieldSpec.colName + '-' + refId + '-created'
    fContext.editing = () ->
        Session.get fieldSpec.colName + '-' + refId + '-editing'
    fContext.showEditStateTrigger = () ->
        Session.get fieldSpec.colName + '-' + refId + '-editStateTrigger'
    fContext.valid = () ->
        Session.get fieldSpec.colName + '-' + refId + '-valid'
    fContext.invalid = () ->
        not Session.get fieldSpec.colName + '-' + refId + '-valid'
    
    fContext._save = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: refId}
        collection.update {_id: data._id}, {$set: {value: data.interimValue}}
        Session.set fieldSpec.colName + '-' + refId + '-editing', false
        Session.set fieldSpec.colName + '-' + refId + '-created', false
    fContext._discard = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: refId}
        collection.update {_id: data._id}, {$set: {interimValue: data.value}}
        Session.set fieldSpec.colName + '-' + refId + '-editing', false
    fContext._update = (newValue) ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: refId}
        collection.update {_id: data._id}, {$set: {interimValue: newValue}}
    fContext._enterEditState = () ->
        Session.set fieldSpec.colName + '-' + refId + '-editing', true
    fContext._enableEditStateTrigger = () ->
        Session.set fieldSpec.colName + '-' + refId + '-editStateTrigger', true
    fContext._disableEditStateTrigger = () ->
        Session.set fieldSpec.colName + '-' + refId + '-editStateTrigger', false
    
    fContext._enterInvalidState = () ->
        Session.set fieldSpec.colName + '-' + refId + '-valid', false
    fContext._leaveInvalidState = () ->
        Session.set fieldSpec.colName + '-' + refId + '-valid', true
    
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
        
    if fieldSpec.type is 'select'
        fContext.choices = fieldSpec.choices
        
            
    
    #subscribe to the referenced value
    Meteor.subscribe fieldSpec.colName, refId, () ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: refId}
        unless data?
            Session.set fieldSpec.colName + '-' + refId + '-created', true
            
            defaultValue = ''
            if fieldSpec.default?
                defaultValue = fieldSpec.default
            collection.insert 
                refId: refId
                value: defaultValue
                interimValue: defaultValue
        Session.set fieldSpec.colName + '-ready', true
        
    
    
Template.fieldsBase.events
    'mouseenter': (e) ->
        @_enableEditStateTrigger()
    'mouseleave': (e) ->
        @_disableEditStateTrigger()
    'click .fields-edit-state-trigger': (e) ->
        e.stopPropagation()
        @_enterEditState()
    'keyup .fields-content': (e) ->
        e.stopPropagation()
        newValue = e.currentTarget.value
        if @_valid newValue
            @_leaveInvalidState()
            @_update newValue
        else
            e.currentTarget.value = @value()
            @_enterInvalidState
    'click .fields-save': (e) ->
        e.stopPropagation()
        @_save()
    'click .fields-cancel': (e) ->
        e.stopPropagation()
        @_discard()
    
    
    
Handlebars.registerHelper 'fieldsForm', (formName, options) ->
    self = {}
    self._id = @_id
    self._form = formName
    self._fieldPath = ['formSpec']
    options.fn self
    
Handlebars.registerHelper 'fieldsComplex', (fieldName, options) ->
    self = {}
    self._id = @_id
    self._form = @_form
    self._container = fieldName
    self._fieldPath = @_fieldPath.concat [fieldName, 'elements']
    
    Template.fieldsActions options.fn self
    
Handlebars.registerHelper 'fieldsField', (fieldName, options) ->
    self = {}
    self._id = @_id
    self._form = @_form
    path = @_fieldPath.concat [fieldName]
    formSpec = Fields.forms.findOne {form: self._form}
    fieldSpec = path.reduce ((s, e) -> s[e]), formSpec
    fieldSpec.colName = path.join '.'
    _wrap self, formSpec, fieldSpec
    
    if @_container?
        Template.fieldsBare options.fn self
    else
        Template.fieldsBase options.fn self