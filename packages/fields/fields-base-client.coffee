Deps.autorun () ->
    Meteor.subscribe 'forms'

_col = (colName) ->
    [collection, created] = Fields._getCollection colName
    collection

_wrapBasics = (fContext, fieldSpec) ->
    fContext.label = fieldSpec.label
    fContext.hint = fieldSpec.hint
    fContext.inputClass = fieldSpec.inputClass
    
    if fieldSpec.type is 'group'
        fContext.fieldId = fContext._groupPath.join('.') + '-' + fContext._id
    else
        fContext.fieldId = fieldSpec.colName + '-' + fContext._id
    
    
_wrapEditState = (fContext) ->
    fContext.editing = () ->
        Session.get fContext.fieldId + '-editing'
    fContext.showEditStateTrigger = () ->
        Session.get fContext.fieldId + '-editStateTrigger'
    fContext._enterEditState = () ->
        console.log fContext
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
            if newValue.replace(/\s/g, '').length is 0
                valid = true
            else if fieldSpec.type is 'number'
                valid = (/^[1-9][0-9]*[\.,]?[0-9]*$/).test newValue
            else
                valid = true
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
    fContext._update = (newValue) ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        collection.update {_id: data._id}, {$set: {interimValue: newValue}}
    
_wrapSaveDiscard = (fContext, fieldSpec) ->
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
    

_wrapGroup = (fContext, formSpec, fieldSpec) ->
    fContext._container = fContext
    _wrapBasics fContext, fieldSpec
    
    fContext._elements = []
    fContext._registerElement = (element) ->
        fContext._elements.push element
    
    fContext.editing = () ->
        _.any fContext._elements, (e) ->
            e.editing()
    
    fContext.validChange = () ->
        valid = _.all fContext._elements, (e) ->
            if e.valid?
                e.valid()
            else
                true
        valid and fContext.changed()
        
    fContext.changed = () ->
        _.any fContext._elements, (e) ->
            e.changed()
    fContext._discard = () ->
        fContext._elements.forEach (e) ->
            e._discard()
    fContext._save = () ->
        fContext._elements.forEach (e) ->
            if e.changed() then e._save()

_wrapMulti = (fContext, formSpec, fieldSpec) ->
    _wrapBasics fContext, fieldSpec
    
    fContext.ready = () ->
        Session.get fieldSpec.colName + '-ready'
    fContext.created = () ->
        Session.get fContext.fieldId + '-created'
    
    fContext._moveUp = (elementId) ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        cIndex = data.elements.indexOf elementId
        if cIndex > 0
            other = data.elements[cIndex - 1]
            data.elements[cIndex] = other
            data.elements[cIndex - 1] = elementId
            
            collection.update {_id: data._id}, {$set: {elements: data.elements}}
        
    fContext._upMoveable = (elementId) ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        data.elements.indexOf(elementId) > 0
        
    fContext._moveDown = (elementId) ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        cIndex = data.elements.indexOf elementId
        if cIndex < (data.elements.length - 1)
            other = data.elements[cIndex + 1]
            data.elements[cIndex] = other
            data.elements[cIndex + 1] = elementId
            
            collection.update {_id: data._id}, {$set: {elements: data.elements}}
            
    fContext._downMoveable = (elementId) ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        data.elements.indexOf(elementId) < (data.elements.length - 1)
        
    
    fContext._add = () ->
        newId = Meteor.uuid()
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        collection.update {_id: data._id}, {$push: {elements: newId}}
        
    fContext._remove = (elementId) ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        collection.update {_id: data._id}, {$pull: {elements: elementId}}
    
    fContext.elements = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        if data?
            data.elements.map (e) -> 
                _id: e
                _form: fContext._form
                _fieldPath: fContext._fieldPath
                _multiPath: fContext._multiPath
                _remove: () ->
                    fContext._remove e
                upMoveable: () ->
                    fContext._upMoveable e
                _moveUp: () ->
                    fContext._moveUp e
                downMoveable: () ->
                    fContext._downMoveable e
                _moveDown: () ->
                    fContext._moveDown e
        else
            []
    
    #subscribe to the multi field and the referenced values
    Meteor.subscribe fieldSpec.colName, fContext._id, () ->
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        unless data?
            Session.set fContext.fieldId + '-created', true
            collection.insert 
                refId: fContext._id
                elements: []
        Session.set fieldSpec.colName + '-ready', true
        
    
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
    
Template.fieldsGroup.events _clickSaveDiscardEvents

Template.fieldsMulti.events
    'click .fields-add': (e) ->
        e.stopPropagation()
        @_add()
    'click .fields-remove': (e) ->
        e.stopPropagation()
        @_remove()
    'click .fields-move-up': (e) ->
        e.stopPropagation()
        @_moveUp()
    'click .fields-move-down': (e) ->
        e.stopPropagation()
        @_moveDown()
    
    
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
    self._groupPath = @_fieldPath.concat [fieldName]
    self._fieldPath = @_fieldPath.concat [fieldName, 'elements']
    
    formSpec = Fields.forms.findOne {form: self._form}
    groupSpec = self._groupPath.reduce ((s, e) -> s[e]), formSpec
    
    _wrapGroup self, formSpec, groupSpec
    
    Template.fieldsGroup options.fn self
    
Handlebars.registerHelper 'fieldsMulti', (fieldName, options) ->
    self = {}
    self._id = @_id
    self._form = @_form
    self._multiPath = @_fieldPath.concat [fieldName]
    self._fieldPath = @_fieldPath.concat [fieldName]
    
    formSpec = Fields.forms.findOne {form: self._form}
    multiSpec = self._multiPath.reduce ((s, e) -> s[e]), formSpec
    multiSpec.colName = self._multiPath.join '.'
    
    _wrapMulti self, formSpec, multiSpec
    Template.fieldsMulti options.fn self
    
Handlebars.registerHelper 'fieldsField', (fieldName, options) ->
    self = {}
    self._id = @_id
    self._form = @_form
    path = @_fieldPath.concat [fieldName]
    formSpec = Fields.forms.findOne {form: self._form}
    fieldSpec = path.reduce ((s, e) -> s[e]), formSpec
    fieldSpec.colName = path.join '.'
    
    if @_container?
        @_container._registerElement self
    
    _wrapSaveDiscard self, fieldSpec
    
    switch fieldSpec.type 
        when 'simpletext','number'
            _wrapSimple self, formSpec, fieldSpec
            #if fieldName is 'element'
            #    console.log self, self.ready()
    
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
    