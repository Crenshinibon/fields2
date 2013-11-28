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
        Meteor.subscribe fieldPath.join('.'), refId
        _traverseMulti fieldPath, fieldSpec, refId, out
    else
        Meteor.subscribe fieldPath.join('.'), refId
        [collection, created] = Fields._getCollection fieldPath.join '.'
        data = collection.findOne
            refId: refId
        
        if out?
            fieldName = fieldPath[fieldPath.length - 1]
            out[fieldName] = data?.value
        else
            value = data?.value
            if value? and value.length > 0
                out = data?.value
            else
                out = fieldSpec.default
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
    formName = fieldPath[0]
    form = Fields.forms.findOne {form: formName}
    
    fieldSpec = fieldPath[1..].reduce ((s,e) -> s[e]), form.formSpec
    if fieldSpec.type in ['group','multi']
        out = {}
        _getValue fieldPath, fieldSpec, refId, out
    else
        _getValue fieldPath, fieldSpec, refId
        