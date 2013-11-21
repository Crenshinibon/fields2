Fields.forms = new Meteor.Collection 'fields-forms'

Fields._collections = {}
Fields._getCollection = (name) ->
    unless name?
        return [new Meteor.Collection(null), true]
    
    unless Fields._collections[name]?
        Fields._collections[name] = new Meteor.Collection name
        [Fields._collections[name], true]
    else
        [Fields._collections[name], false]
        
_traverseGroup = (groupPath, groupSpec, refId, out) ->
    groupOut = {}
    for key of groupSpec.elements
        fieldPath = groupPath.concat ['elements', key]
        fieldSpec = groupSpec.elements[key]
        _getValue fieldPath, fieldSpec, refId, groupOut
    
    groupName = groupPath[groupPath.length - 1]
    out[groupName] = groupOut
    
    out
        
_traverseMulti = (multiPath, multiSpec, refId, out) ->
    [collection, created] = Fields._getCollection multiPath.join '.'
    data = collection.findOne
        refId: refId
    
    elements = []
    data?.elements.forEach (e) ->
        element = {}
        elements.push element
        _getValue multiPath.concat('element'), multiSpec.element, e, element
    
    multiName = multiPath[multiPath.length - 1]
    out[multiName] = elements
        
    
_getValue = (fieldPath, fieldSpec, refId, out) ->
    if fieldSpec.type is 'group'
        _traverseGroup fieldPath, fieldSpec, refId, out
    else if fieldSpec.type is 'multi'
        _traverseMulti fieldPath, fieldSpec, refId, out
    else
        [collection, created] = Fields._getCollection fieldPath.join '.'
        data = collection.findOne
            refId: refId
        
        if out?
            fieldName = fieldPath[fieldPath.length - 1]
            out[fieldName] = data?.value
        else
            out = data?.value
    out

Fields.currentFormValues = (formName, refId) ->
    form = Fields.forms.findOne {form: formName}
    out = {}
    for key of form.formSpec
        path = [formName, key]
        out[key] = Fields.currentFieldValues path, refId
    out
    
Fields.currentFieldValues = (fieldPath, refId) ->
    unless _.isArray fieldPath
        fieldPath = fieldPath.split '.'
    console.log fieldPath
    formName = fieldPath[0]
    form = Fields.forms.findOne {form: formName}
    
    fieldSpec = fieldPath[1..].reduce ((s,e) -> s[e]), form.formSpec
    if fieldSpec.type in ['group','multi']
        out = {}
        _getValue fieldPath, fieldSpec, refId, out
    else
        _getValue fieldPath, fieldSpec, refId