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
        Session.set fContext.fieldId + '-editing', true
        fContext._disableEditStateTrigger()
    fContext._enableEditStateTrigger = () ->
        unless Session.get fContext.fieldId + '-editStateTrigger'
            Session.set fContext.fieldId + '-editStateTrigger', true
            Meteor.setTimeout fContext._disableEditStateTrigger, 2000
    fContext._disableEditStateTrigger = () ->
        Session.set fContext.fieldId + '-editStateTrigger', false

_wrapValidation = (fContext, fieldSpec) ->
    
    fContext.validChange = () ->
        fContext.changed() and fContext.valid()
    fContext.valid = () ->
        Session.get fContext.fieldId + '-valid'
    unless fContext.valid()?
        Session.set fContext.fieldId + '-valid', true
        
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
            if fieldSpec.type is 'date'
                valid = moment(newValue, fieldSpec.formats).isValid()
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
    

_wrapRich = (fContext,  fieldSpec) ->
    _wrapBasics fContext, fieldSpec
    fContext.editorId = fContext.fieldId.replace(/\./g,'-') + "-editor"
    fContext.toolbarId = fContext.fieldId.replace(/\./g,'-') + "-toolbar"
    
    _loadData fContext, fieldSpec
    
    _wrapValue fContext, fieldSpec
    _wrapUpdate fContext, fieldSpec
    _wrapEditState fContext
    _wrapValidation fContext, fieldSpec
    
    
_wrapSelect = (fContext,  fieldSpec) ->
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
    
    
_wrapSimple = (fContext,  fieldSpec) ->
    _wrapBasics fContext, fieldSpec
    _loadData fContext, fieldSpec
    
    _wrapValue fContext, fieldSpec
    _wrapEditState fContext
    _wrapUpdate fContext, fieldSpec
    _wrapValidation fContext, fieldSpec
    
_wrapDate = (fContext,  fieldSpec) ->
    _wrapBasics fContext, fieldSpec
    _loadData fContext, fieldSpec
    
    _wrapEditState fContext
    _wrapUpdate fContext, fieldSpec
    _wrapValidation fContext, fieldSpec
    
    fContext.value = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne
            refId: fContext._id
        
        if data? and data.interimValue? and data.interimValue.length > 0
            format = fieldSpec.formats[0]
            if fieldSpec.defaultFormat?
                format = fieldSpec.defaultFormat
            
            moment(data.interimValue, fieldSpec.formats).format(format)
    
    fContext.prettyValue = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne
            refId: fContext._id
        format = 'dddd, MMMM Do YYYY'
        if fieldSpec.displayFormat?
            format = fieldSpec.displayFormat
        
        if data? and data.interimValue? and data.interimValue.length > 0
            moment(data.interimValue, fieldSpec.formats).format(format)
    
_timeUnitFunctionMap =
    second:
        durationFormat: 'asSeconds'
        label: 'Seconds'
    minute:
        durationFormat: 'asMinutes'
        label: 'Minutes'
    hour:
        durationFormat: 'asHours'
        label: 'Hours'
    day:
        durationFormat: 'asDays'
        label: 'Days'
    week:
        durationFormat: 'asWeeks'
        label: 'Weeks'
    month:
        durationFormat: 'asMonths'
        label: 'Months'
    year:
        durationFormat: 'asYears'
        label: 'Years'

_wrapDuration = (fContext,  fieldSpec) ->
    _wrapBasics fContext, fieldSpec
    _loadData fContext, fieldSpec
    
    _wrapEditState fContext
    _wrapValidation fContext, fieldSpec
    
    fContext.currentUnit = () ->
        Session.get fContext.fieldId + '-durationUnit'
    
    unless fContext.currentUnit()?
        du = 'day'
        if fieldSpec.defaultUnit
            du = fieldSpec.defaultUnit
        Session.set fContext.fieldId + '-durationUnit', du
    
    fContext._unitForLabel = (label) ->
        for unit of _timeUnitFunctionMap
            if _timeUnitFunctionMap[unit].label is label
                return unit
        'days'
    
    fContext.choices = () ->
        choices = []
        if fieldSpec.units?
            fieldSpec.units.map (e) ->
                if typeof e is 'string'
                    choiceLabel: _timeUnitFunctionMap[e].label
                    choice: e
                    selected: _selected e
                else
                    choice: e.choice
                    choiceLabel: e.label
                    selected: _selected e
        else
            choices = _.keys(_timeUnitFunctionMap).map (e) ->
                choiceLabel: _timeUnitFunctionMap[e].label
                choice: e
                selected: _selected e
    
    fContext.value = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne
            refId: fContext._id
        value = data?.interimValue
        if value? and typeof value is 'number'
            duration = moment.duration value, 'seconds'
            unit = fContext.currentUnit()
            fn = _timeUnitFunctionMap[unit].durationFormat
            Math.round duration[fn]()
        
    fContext.prettyValue = () ->
        value = fContext.value()
        if value? and typeof value is 'number'
            moment.duration(value, fContext.currentUnit()).humanize()
    
    fContext._update = (newValue) ->
        unit = fContext.currentUnit()
        durInSeconds = moment.duration(parseInt(newValue), unit).asSeconds()
        
        collection = _col fieldSpec.colName
        data = collection.findOne {refId: fContext._id}
        collection.update {_id: data._id}, {$set: {interimValue: durInSeconds}}
        
    fContext.changed = () ->
        collection = _col fieldSpec.colName
        data = collection.findOne
            refId: fContext._id
        data?.interimValue isnt data?.value
        
    _selected = (e) ->
        if fContext.currentUnit() is e
            'selected'
    
    fContext._updateUnit = (newValue) ->
        Session.set fContext.fieldId + '-durationUnit', newValue
        

_wrapGroup = (fContext,  fieldSpec) ->
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

_wrapMulti = (fContext,  fieldSpec) ->
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

_numberInputUpdateEvents = 
    'keydown .fields-content': (e) ->
        unless e.which <= 57 or (e.which is 86 and (e.metaKey or e.ctrlKey))
            e.preventDefault()
    'keyup .fields-content': (e) ->
        newValue = e.currentTarget.value
        @_update newValue
        
_textInputUpdateEvents = 
    'keyup .fields-content': (e) ->
        e.stopPropagation()
        newValue = e.currentTarget.value
        @_update newValue
        
        if @_valid newValue
            @_leaveInvalidState()
        else
            @_enterInvalidState()
    
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

Template.fieldsNumber.events _editStateEvents
Template.fieldsNumber.events _numberInputUpdateEvents
Template.fieldsNumber.events _clickSaveDiscardEvents

Template.fieldsDuration.events _editStateEvents
Template.fieldsDuration.events _clickSaveDiscardEvents
Template.fieldsDuration.events _numberInputUpdateEvents
Template.fieldsDuration.events
    'change .fields-select': (e) ->
        unit = @_unitForLabel e.currentTarget.value
        @_updateUnit unit

Template.fieldsDate.events _editStateEvents
Template.fieldsDate.events _textInputUpdateEvents
Template.fieldsDate.events _clickSaveDiscardEvents

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


Fields.lang = (lang) ->
    if lang?
        moment.lang(lang)
    else
        moment.lang()


Handlebars.registerHelper 'fieldsForm', (formName, options) ->
    self = {}
    self._id = @_id
    self._form = formName
    
    form = Fields.forms.findOne {form: formName}
    if form.lang?
        Fields.lang form.lang
    else
        Fields.lang 'en'
        
    self._fieldPath = [formName]
    options.fn self
    
Handlebars.registerHelper 'fieldsGroup', (fieldName, options) ->
    self = {}
    self._id = @_id
    self._form = @_form
    self._groupPath = @_fieldPath.concat [fieldName]
    self._fieldPath = @_fieldPath.concat [fieldName, 'elements']
    
    form = Fields.forms.findOne {form: self._form}
    groupSpec = self._groupPath[1..].reduce ((s, e) -> s[e]), form.formSpec
    
    _wrapGroup self, groupSpec
    
    Template.fieldsGroup options.fn self
    
Handlebars.registerHelper 'fieldsMulti', (fieldName, options) ->
    self = {}
    self._id = @_id
    self._form = @_form
    self._multiPath = @_fieldPath.concat [fieldName]
    self._fieldPath = @_fieldPath.concat [fieldName]
    
    form = Fields.forms.findOne {form: self._form}
    multiSpec = self._multiPath[1..].reduce ((s, e) -> s[e]), form.formSpec
    multiSpec.colName = self._multiPath.join '.'
    
    _wrapMulti self, multiSpec
    Template.fieldsMulti options.fn self
    
Handlebars.registerHelper 'fieldsField', (fieldName, options) ->
    self = {}
    self._id = @_id
    self._form = @_form
    path = @_fieldPath.concat [fieldName]
    form = Fields.forms.findOne {form: self._form}
    fieldSpec = path[1..].reduce ((s, e) -> s[e]), form.formSpec
    fieldSpec.colName = path.join '.'
    
    if @_container?
        @_container._registerElement self
    
    _wrapSaveDiscard self, fieldSpec
    
    switch fieldSpec.type 
        when 'simpletext'
            _wrapSimple self, fieldSpec
            Template.fieldsSimple options.fn self
        when 'number'
            _wrapSimple self, fieldSpec
            Template.fieldsNumber options.fn self
        when 'richtext'
            _wrapRich self, fieldSpec
            Template.fieldsRich options.fn self
        when 'select'
            _wrapSelect self, fieldSpec
            Template.fieldsSelect options.fn self
        when 'date'
            _wrapDate self, fieldSpec
            Template.fieldsDate options.fn self
        when 'duration'
            _wrapDuration self, fieldSpec
            Template.fieldsDuration options.fn self
    